#!/usr/bin/env python3
"""Join Apache/mod_php memory fatals to the access-log 5xx that caused them, in one offline pass.

Answers in one run what otherwise takes many bounded greps: how many requests (not lines) hit the
PHP memory limit, where the first allocation failed, which route/status they were served as, who
called it (classified, never raw), when (UTC hour) and since when (route status by day).

No network calls, application boot or writes. Output is aggregate-only: routes are templated
(numeric, uuid, hash, email and long segments replaced, query dropped) unless --raw-paths.
"""
import argparse
from bisect import bisect_left, bisect_right
from collections import Counter
from datetime import datetime, timedelta, timezone
import importlib.util
import ipaddress
from pathlib import Path
import re
import sys
import zlib

sys.dont_write_bytecode = True  # importing the sibling helper must not leave __pycache__ in the repo
_spec = importlib.util.spec_from_file_location('log_summary', Path(__file__).resolve().parents[1] / 'log_summary.py')
log_summary = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(log_summary)

MONTHS = log_summary.MONTHS
ERROR_HEADER = re.compile(r'^\[\w{3} (\w{3}) +(\d{1,2}) (\d{2}):(\d{2}):(\d{2})(\.\d+)? (\d{4})\] ')
PID = re.compile(r'\[pid (\d+)(?::tid \d+)?\]')
MEMORY = re.compile(r'Allowed memory size of (\d+) bytes exhausted')
LOCATION = re.compile(r' in (\S+) on line (\d+)')
RELEASE = re.compile(r'/releases/([^/]+)/')

# First match wins; order matters (AI crawlers often also say "Mozilla" and "compatible").
AGENT_CLASSES = [
    ('health-check', r'ELB-HealthChecker|kube-probe|UptimeRobot|Pingdom|StatusCake|Uptime|HealthCheck'),
    ('ai-crawler', r'ClaudeBot|Claude-User|anthropic-ai|GPTBot|ChatGPT-User|OAI-SearchBot|PerplexityBot|CCBot'
                   r'|Bytespider|Amazonbot|Applebot-Extended|meta-externalagent|cohere-ai|Diffbot|Timpibot'),
    ('search-crawler', r'Googlebot|bingbot|Applebot|YandexBot|Baiduspider|DuckDuckBot|Slurp|PetalBot|SeznamBot'),
    ('seo-crawler', r'AhrefsBot|SemrushBot|MJ12bot|DotBot|rogerbot|Screaming Frog|DataForSeoBot|BLEXBot'),
    ('script-client', r'^(curl|Wget|python-|Go-http-client|axios|node-fetch|undici|okhttp|Java/|libwww|HTTPie'
                      r'|PostmanRuntime|GuzzleHttp|ofetch|node$)'),
    ('other-bot', r'bot|crawl|spider|scan'),
    ('browser', r'^Mozilla/5\.0 '),
]
AGENT_RULES = [(name, re.compile(rx, re.I)) for name, rx in AGENT_CLASSES]
UUID = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.I)
SAFE_SEGMENT = re.compile(r'^[A-Za-z0-9._~-]{1,40}$')


def agent_class(agent):
    if agent in ('', '-'):
        return 'empty'
    for name, rule in AGENT_RULES:
        if rule.search(agent):
            return name
    return 'other'


def peer_class(peer):
    try:
        address = ipaddress.ip_address(peer)
    except ValueError:
        return 'unparsed'
    if address.is_loopback:
        return 'loopback'
    return 'private' if address.is_private else 'public'


def template(path):
    out = []
    for segment in path.split('/'):
        if segment == '':
            out.append(segment)
        elif segment.isdigit():
            out.append('{n}')
        elif UUID.match(segment):
            out.append('{uuid}')
        elif '@' in segment:
            out.append('{email}')
        elif re.fullmatch(r'[0-9a-fA-F]{12,}', segment) or (len(segment) >= 16 and re.search(r'\d', segment)
                                                              and re.search(r'[A-Za-z]', segment) and '-' not in segment):
            out.append('{id}')
        elif not SAFE_SEGMENT.match(segment):
            out.append('{seg}')
        else:
            out.append(segment)
    return '/'.join(out) or '/'


def error_time(match, offset):
    month = MONTHS.get(match[1])
    if not month:
        raise ValueError('unsupported error-log timestamp')
    naive = datetime(int(match[7]), month, int(match[2]), int(match[3]), int(match[4]), int(match[5]),
                     int(float(match[6] or 0) * 1_000_000))
    return (naive - offset).replace(tzinfo=timezone.utc)


def parse_offset(value):
    match = re.fullmatch(r'([+-])(\d{2}):?(\d{2})', value)
    if not match:
        raise ValueError('--error-offset must look like +0000 or -05:00')
    delta = timedelta(hours=int(match[2]), minutes=int(match[3]))
    return delta if match[1] == '+' else -delta


def short_location(path):
    path = RELEASE.split(path, maxsplit=1)[-1] if RELEASE.search(path) else path
    return re.sub(r'^.*?/(vendor|app|routes|config|resources|addons)/', r'\1/', '/' + path.lstrip('/'))


def read_fatals(paths, offset, max_bytes, max_line):
    """Memory-fatal lines grouped into requests: same PID within --burst seconds of the previous line."""
    events, scanned, rejected = [], 0, 0
    for path in paths:
        for line in log_summary.lines(path, max_bytes, max_line):
            scanned += 1
            memory = MEMORY.search(line)
            if not memory:
                continue
            header, pid, location = ERROR_HEADER.match(line), PID.search(line), LOCATION.search(line)
            if not (header and pid and location):
                rejected += 1
                continue
            release = RELEASE.search(location[1])
            events.append((error_time(header, offset), pid[1], f'{short_location(location[1])}:{location[2]}',
                           memory[1], release[1] if release else 'unknown'))
    return events, scanned, rejected


def group_requests(events, burst):
    requests, open_by_pid = [], {}
    for event in sorted(events, key=lambda e: (e[1], e[0])):
        current = open_by_pid.get(event[1])
        if current and (event[0] - current[-1][0]).total_seconds() <= burst:
            current.append(event)
        else:
            open_by_pid[event[1]] = [event]
            requests.append(open_by_pid[event[1]])
    return sorted(requests, key=lambda r: r[0][0])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--error-log', action='append', required=True, help='Apache error log (plain or gzip); repeatable')
    parser.add_argument('--access-log', action='append', required=True, help='Apache access log (plain or gzip); repeatable')
    parser.add_argument('--error-offset', required=True,
                        help='UTC offset of error-log timestamps, verified via RB-01/EVD-02 (for example +0000)')
    parser.add_argument('--max-gap', type=float, default=30.0, help='seconds a request may run before its fatal (default 30)')
    parser.add_argument('--burst', type=float, default=1.0, help='seconds joining same-PID fatal lines into one request (default 1)')
    parser.add_argument('--raw-paths', action='store_true', help='print request paths without templating (query still dropped)')
    args = parser.parse_args()
    offset = parse_offset(args.error_offset)
    if args.max_gap <= 0 or args.burst <= 0:
        raise ValueError('--max-gap and --burst must be positive')
    for kind, paths in (('--error-log', args.error_log), ('--access-log', args.access_log)):
        resolved = [Path(p).resolve() for p in paths]
        if len(set(resolved)) != len(resolved):
            raise ValueError(f'the same {kind} file was given more than once; it would be double counted')
    max_bytes = log_summary.limit('LOG_MAX_BYTES', 256 * 1024 * 1024, 256 * 1024 * 1024)
    max_line = log_summary.limit('LOG_MAX_LINE_BYTES', 256 * 1024, 1024 * 1024)
    max_keys = log_summary.limit('LOG_MAX_KEYS', 200000, 200000)
    max_failures = log_summary.limit('LOG_MAX_RECORDS', 500000, 2000000)  # retained 5xx candidates

    events, error_lines, error_rejected = read_fatals(args.error_log, offset, max_bytes, max_line)
    requests = group_requests(events, args.burst)

    # Access pass: keep every 5xx (candidates) and a route x status x day counter for the history table.
    route_of = (lambda p: p) if args.raw_paths else template
    failures, history = [], Counter()
    hourly_5xx = Counter()
    records = rejected = 0
    for path in args.access_log:
        for line in log_summary.lines(path, max_bytes, max_line):
            match = log_summary.ACCESS.fullmatch(line.rstrip('\r\n'))
            if not match:
                rejected += 1
                continue
            peer, stamp, request, status, _referer, agent, _suffix = match.groups()
            parts = request.split()
            if len(parts) != 3:
                rejected += 1
                continue
            try:
                when = log_summary.access_time(stamp)
            except ValueError:
                rejected += 1
                continue
            records += 1
            route = route_of(parts[1].split('?', 1)[0])
            key = (when.strftime('%Y-%m-%d'), parts[0], route, status)
            if key not in history and len(history) >= max_keys:
                raise ValueError('distinct route key limit exceeded; no aggregate emitted')
            history[key] += 1
            if status.startswith('5'):
                if len(failures) >= max_failures:
                    raise ValueError('5xx candidate limit exceeded; narrow the input files; no aggregate emitted')
                hourly_5xx[when.strftime('%Y-%m-%dT%H')] += 1
                failures.append((when, parts[0], route, status, agent_class(agent), peer_class(peer)))

    print(f'error_lines={error_lines} memory_fatal_lines={len(events)} error_rejected={error_rejected} '
          f'access_records={records} rejected_records={rejected} access_5xx={len(failures)}', file=sys.stderr)
    if rejected or error_rejected:
        raise ValueError('unparsable records; no aggregate emitted')
    if not events:
        print('No memory fatals found (coverage must be verified separately)', file=sys.stderr)

    # FIFO join: each fatal takes the earliest unmatched 5xx received 0..max_gap seconds before it.
    failures.sort(key=lambda f: f[0])
    times = [f[0] for f in failures]
    used, joined, gaps, ambiguous, unmatched = set(), [], [], 0, 0
    hourly_fatal, hourly_joined = Counter(), Counter()
    for req in requests:
        start = req[0][0]
        hourly_fatal[start.strftime('%Y-%m-%dT%H')] += 1
        window = range(bisect_left(times, start - timedelta(seconds=args.max_gap)), bisect_right(times, start))
        candidates = [i for i in window if i not in used]
        if not candidates:
            unmatched += 1
            continue
        ambiguous += len(candidates) > 1
        used.add(candidates[0])
        joined.append(failures[candidates[0]])
        gaps.append((start - failures[candidates[0]][0]).total_seconds())
        hourly_joined[start.strftime('%Y-%m-%dT%H')] += 1

    print('== fatal requests ==')
    print(f'requests={len(requests)} secondary_lines={len(events) - len(requests)} '
          f'limit_bytes={",".join(f"{k}:{v}" for k, v in sorted(Counter(r[0][3] for r in requests).items()))} '
          f'releases={",".join(f"{k}:{v}" for k, v in sorted(Counter(r[0][4] for r in requests).items()))}')
    print('== first allocation site (where the limit was hit, not necessarily the owner) ==')
    for site, count in Counter(r[0][2] for r in requests).most_common(15):
        print(count, site)
    print(f'== join (access 5xx received 0-{args.max_gap:g}s before the fatal; candidate, not proof) ==')
    line = f'joined={len(joined)} unmatched_fatals={unmatched} ambiguous={ambiguous}'
    if gaps:
        gaps.sort()
        line += f' gap_s_min={gaps[0]:.1f} gap_s_p50={gaps[len(gaps) // 2]:.1f} gap_s_max={gaps[-1]:.1f}'
    print(line)
    print('== joined routes ==')
    joined_routes = Counter((f[1], f[2], f[3]) for f in joined)
    for (method, route, status), count in joined_routes.most_common(20):
        print(count, method, route, status)
    print('== joined callers (classified; user agents are self-declared) ==')
    for kind, index in (('ua', 4), ('peer', 5)):
        for name, count in Counter(f[index] for f in joined).most_common():
            print(kind, name, count)
    print('== hourly UTC: fatal_requests joined_5xx all_5xx ==')
    for hour in sorted(set(hourly_fatal) | set(hourly_5xx)):
        print(hour, hourly_fatal[hour], hourly_joined[hour], hourly_5xx[hour])
    print('== route status by day (joined routes, all statuses, all access input) ==')
    wanted = {(method, route) for method, route, _status in joined_routes}
    for (day, method, route, status), count in sorted(history.items()):
        if (method, route) in wanted:
            print(day, method, route, status, count)
    if not wanted:
        print('none joined')


if __name__ == '__main__':
    try:
        main()
    except (OSError, EOFError, ValueError, zlib.error) as exc:
        print('ERROR: ' + ('invalid text encoding' if isinstance(exc, UnicodeError) else str(exc)), file=sys.stderr)
        sys.exit(2)
