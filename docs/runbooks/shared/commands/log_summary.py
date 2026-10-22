#!/usr/bin/env python3
"""Offline summaries of explicit log files. No network calls or application boot."""
import argparse
from collections import Counter, deque
from datetime import datetime, timezone
import gzip
import math
import os
from pathlib import Path
import re
import sys
import zlib

# Combined format, with optional appended fields. Quoted fields may contain escaped quotes.
QUOTED = r'"((?:[^"\\]|\\.)*)"'
ACCESS = re.compile(
    r'^(\S+) \S+ \S+ \[([^]]+)\] ' + QUOTED
    + r' ([1-5][0-9]{2}) (?:[0-9]+|-) ' + QUOTED + ' ' + QUOTED + r'(.*)$'
)
MONTHS = {name: n for n, name in enumerate(
    'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split(), 1)}


def utc_bound(value):
    dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if dt.utcoffset() is None:
        raise ValueError('UTC bounds require an explicit timezone')
    return dt.astimezone(timezone.utc)


def access_time(value):
    match = re.fullmatch(r'(\d{2})/([A-Za-z]{3})/(\d{4}):(\d{2}:\d{2}:\d{2}) ([+-]\d{4})', value)
    if not match or match[2] not in MONTHS:
        raise ValueError('unsupported access timestamp')
    return datetime.strptime(
        f'{match[3]}-{MONTHS[match[2]]:02}-{match[1]} {match[4]} {match[5]}',
        '%Y-%m-%d %H:%M:%S %z').astimezone(timezone.utc)


def lines(path):
    with Path(path).open('rb') as probe:
        compressed = probe.read(2) == b'\x1f\x8b'
    opener = gzip.open if compressed else open
    with opener(path, 'rt', encoding='utf-8', errors='strict') as stream:
        yield from stream


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['request-rate', 'status-distribution', 'top-clients',
                                       'top-paths', 'method-by-path', 'latency-summary',
                                       'error-log-summary', 'laravel-errors'])
    parser.add_argument('log')
    parser.add_argument('extra', nargs='?')
    args = parser.parse_args()
    top = 20
    if args.mode in ('top-clients', 'top-paths', 'laravel-errors') and args.extra:
        top = int(args.extra)
        if top < 1:
            raise ValueError('N must be a positive integer')
    if args.mode == 'method-by-path' and not args.extra:
        raise ValueError('method-by-path requires PATH')
    window = re.compile(os.environ['WINDOW']) if os.environ.get('WINDOW') else None
    start = utc_bound(os.environ['START_UTC']) if os.environ.get('START_UTC') else None
    end = utc_bound(os.environ['END_UTC']) if os.environ.get('END_UTC') else None
    if bool(start) != bool(end) or (start and start >= end):
        raise ValueError('provide both START_UTC and END_UTC with start < end')
    if start and args.mode in ('error-log-summary', 'laravel-errors'):
        raise ValueError('UTC bounds are supported only for Apache access logs; use WINDOW for these logs')
    counts = Counter()
    durations = {'all': [], 'success': [], 'error': []}
    restarts = deque(maxlen=15)
    raw = selected = rejected = errors = 0
    error_header = re.compile(r'^\[([^]]+)\] [\w.-]+\.(ERROR|CRITICAL|ALERT|EMERGENCY): (.*)')
    event_header = re.compile(r'^\[\d{4}-\d{2}-\d{2}[^]]*\] [\w.-]+\.\w+:')
    for line in lines(args.log):
        raw += 1
        if args.mode == 'laravel-errors':
            # Only event headers count. Multiline traces remain available in the source file.
            if not event_header.match(line):
                if line.startswith('[') and re.match(r'^\[\d{4}-\d{2}-\d{2}', line):
                    rejected += 1
                continue
            match = error_header.match(line)
            if match and (not window or window.search(match[1])):
                selected += 1
                counts[re.sub(r'\d+', 'N', match[3][:120])] += 1
            continue
        if args.mode == 'error-log-summary':
            if window and not window.search(line):
                continue
            selected += 1
            errors += 'AH00161' in line
            location = re.search(r'Allowed memory size of \d+ bytes exhausted.* in (\S+) on line (\d+)', line)
            if location:
                counts[re.sub(r'^.*/vendor/', 'vendor/', location[1]) + ':' + location[2]] += 1
            if re.search(r'resuming normal operations|SIGUSR1|SIGTERM|Graceful restart|unclean|caught SIGWINCH', line):
                restarts.append(line.rstrip())
            continue
        match = ACCESS.fullmatch(line.rstrip('\r\n'))
        if not match:
            rejected += 1
            continue
        client, stamp, request, status, _referer, _agent, suffix = match.groups()
        try:
            dt = access_time(stamp)
        except ValueError:
            rejected += 1
            continue
        if window and not window.search(stamp):
            continue
        if start and not (start <= dt < end):
            continue
        selected += 1
        parts = request.split()
        valid_request = len(parts) == 3 and parts[2].startswith('HTTP/')
        if args.mode in ('top-paths', 'method-by-path') and not valid_request:
            rejected += 1
            continue
        if args.mode == 'request-rate':
            counts[dt.strftime('%Y-%m-%dT%H:%MZ')] += 1
        elif args.mode == 'status-distribution':
            counts[status] += 1
        elif args.mode == 'top-clients':
            counts[client] += 1
        elif args.mode == 'top-paths':
            counts[parts[1].split('?', 1)[0]] += 1
        elif args.mode == 'method-by-path':
            if parts[1].split('?', 1)[0] == args.extra:
                counts[parts[0] + ' ' + status] += 1
        elif args.mode == 'latency-summary':
            timing = re.search(r'(?:^|\s)duration_us=(\d+)(?=\s|$)', suffix)
            if not timing:
                rejected += 1
                continue
            duration = int(timing[1]) / 1000
            durations['all'].append(duration)
            if 200 <= int(status) < 400:
                durations['success'].append(duration)
            elif int(status) >= 400:
                durations['error'].append(duration)
    print(f'raw_lines={raw} selected_records={selected} rejected_records={rejected}', file=sys.stderr)
    if rejected:
        raise ValueError('unparsable records or missing required fields; no aggregate emitted')
    if not selected:
        print('No matching records (coverage must be verified separately)', file=sys.stderr)
    if args.mode == 'error-log-summary':
        print('== worker limit (AH00161) ==\n' + str(errors))
        print('== PHP memory exhaustion by location ==')
        for key, count in counts.most_common(15):
            print(count, key)
        print('== restarts / shutdowns ==')
        print('\n'.join(restarts) if restarts else 'No matching restart records')
    elif args.mode == 'latency-summary':
        for group, values in durations.items():
            values.sort()
            if values:
                quantiles = [values[math.ceil(len(values) * q) - 1] for q in (.5, .95, .99)]
                print(f'{group} n={len(values)} p50_ms={quantiles[0]:.3f} p95_ms={quantiles[1]:.3f} p99_ms={quantiles[2]:.3f}')
            else:
                print(f'{group} n=0 latency=unknown')
    else:
        items = sorted(counts.items()) if args.mode in ('request-rate', 'status-distribution') else counts.most_common()
        if args.mode in ('top-clients', 'top-paths', 'laravel-errors'):
            items = items[:top]
        for key, count in items:
            if args.mode == 'request-rate':
                print(key, count)
            elif args.mode == 'status-distribution':
                print(f'{key} {count} {100 * count / selected:.2f}%')
            elif args.mode == 'top-paths':
                print(f'{count:7d} {100 * count / selected:5.1f}%  {key}')
            else:
                print(count, key)


if __name__ == '__main__':
    try:
        main()
    except (OSError, EOFError, ValueError, re.error, zlib.error) as exc:
        # Do not echo a rejected line or an invalid filter, which may contain credentials.
        if isinstance(exc, re.error):
            message = 'invalid WINDOW regular expression'
        elif isinstance(exc, UnicodeError):
            message = 'invalid text encoding'
        else:
            message = str(exc)
        print('ERROR: ' + message, file=sys.stderr)
        sys.exit(2)
