#!/usr/bin/env python3
"""Validate a complete, isolated staging cold-key test export; never generates traffic."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import sys


def verify(events, run_id, key_hash, requests, origin_events=None):
    def require(condition, message):
        if not condition:
            raise ValueError(message)
    require(requests >= 2, 'at least two callers required')
    require(bool(events), 'empty export')
    require(all(isinstance(e, dict) and e.get('run_id') == run_id
                and e.get('key_hash') == key_hash for e in events),
            'all records must belong to the isolated run and effective cache key')
    def group(kind):
        return [e for e in events if e.get('event') == kind]
    def at(event):
        require(isinstance(event.get('utc'), str), 'timestamp must be an offset-bearing ISO string')
        value = datetime.fromisoformat(event['utc'].replace('Z', '+00:00'))
        require(value.utcoffset() is not None, 'timezone required')
        return value
    allowed = {'cache_miss', 'upstream_start', 'upstream_finish', 'cache_write', 'client_result'}
    require(all(e.get('event') in allowed for e in events),
            'unknown application event type; origin-attempt semantics unresolved')
    for event in events:
        at(event)
    require(bool(origin_events), 'independent complete mock-origin ledger required')
    require(all(isinstance(e, dict) and e.get('run_id') == run_id
                and e.get('key_hash') == key_hash and e.get('source') == 'mock-origin'
                for e in origin_events), 'origin ledger must identify the isolated mock-origin run')
    require(all(e.get('event') in {'origin_attempt', 'origin_ledger_complete'} for e in origin_events),
            'unknown origin event type; attempt completeness unresolved')
    attempts = [e for e in origin_events if e['event'] == 'origin_attempt']
    closures = [e for e in origin_events if e['event'] == 'origin_ledger_complete']
    require(len(closures) == 1 and closures[0].get('complete') is True,
            'exactly one complete origin ledger closure required')
    require(type(closures[0].get('attempt_count')) is int
            and closures[0]['attempt_count'] == len(attempts), 'origin ledger totals do not reconcile')
    require(len(attempts) == 1, 'expected exactly one independently observed origin attempt')
    origin = attempts[0]
    require(origin.get('ok') is True and bool(origin.get('fetch_id')),
            'origin attempt must be identified and successful')
    origin_finish = at({'utc': origin['finished_utc']})
    require(at(origin) < origin_finish <= at(closures[0]), 'origin ledger interval/closure is invalid')
    starts, finishes = group('upstream_start'), group('upstream_finish')
    require(len(starts) == len(finishes) == 1, 'expected exactly one actual upstream attempt and completion')
    require(bool(starts[0].get('fetch_id')) and starts[0]['fetch_id'] == finishes[0].get('fetch_id'),
            'upstream attempt IDs must match')
    require(origin['fetch_id'] == starts[0]['fetch_id'], 'application and origin attempt IDs differ')
    require(origin.get('value_hash') == finishes[0].get('value_hash'),
            'application and independent origin values differ')
    require(at(starts[0]) <= at(origin) < origin_finish <= at(finishes[0]),
            'application and origin intervals do not reconcile')
    require(finishes[0].get('ok') is True, 'upstream must succeed')
    require(at(starts[0]) < at(finishes[0]), 'upstream interval must be positive')
    misses, results, writes = group('cache_miss'), group('client_result'), group('cache_write')
    require(len(misses) == len(results) == requests, 'missing or duplicate caller evidence')
    miss_ids = {e.get('request_id') for e in misses}
    result_ids = {e.get('request_id') for e in results}
    require(None not in miss_ids and '' not in miss_ids and len(miss_ids) == requests
            and miss_ids == result_ids, 'caller IDs must be unique and match')
    instances = {e.get('instance_id') for e in misses}
    require(None not in instances and '' not in instances and len(instances) >= 2,
            'cache misses must span at least two identified instances')
    require(all(at(e) < origin_finish for e in misses), 'all callers must observe cold state before upstream release')
    require(len(writes) == 1 and at(writes[0]) >= at(finishes[0]), 'expected one cache write after upstream completion')
    digest = writes[0].get('value_hash')
    require(bool(digest) and digest == finishes[0].get('value_hash'), 'cached value must match the upstream value')
    require(all(e.get('ok') is True and e.get('value_hash') == digest
                and at(e) >= at(writes[0]) for e in results), 'all callers must receive the expected value after cache publication')
    require(all(at(e) <= at(closures[0]) for e in results),
            'origin ledger must close after all callers finish and admission stops')
    return f'PASS: {requests} cold callers across {len(instances)} instances, one upstream attempt, one cache write'


MAX_EXPORT_BYTES = 16 * 1024 * 1024
MAX_EXPORT_RECORDS = 100000


def read_export(path):
    # Bound raw input before decoding/JSON parsing; no implicit truncation can pass.
    with Path(path).open('rb') as source:
        raw = source.read(MAX_EXPORT_BYTES + 1)
    if len(raw) > MAX_EXPORT_BYTES:
        raise ValueError('export exceeds 16 MiB policy; prepare a complete isolated-run export')
    events = []
    for line in raw.decode('utf-8').splitlines():
        if line.strip():
            if len(events) >= MAX_EXPORT_RECORDS:
                raise ValueError('export exceeds 100000-record policy')
            events.append(json.loads(line))
    return events


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export')
    parser.add_argument('--origin-ledger', required=True, help='separate unsampled mock-origin JSONL export')
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--key-hash', required=True)
    parser.add_argument('--requests', type=int, default=100)
    args = parser.parse_args()
    events = read_export(args.export)
    origin_events = read_export(args.origin_ledger)
    print(verify(events, args.run_id, args.key_hash, args.requests, origin_events))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'FAIL / unresolved: {exc}', file=sys.stderr)
        sys.exit(1)
