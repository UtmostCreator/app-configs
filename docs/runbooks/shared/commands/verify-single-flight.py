#!/usr/bin/env python3
"""Validate a complete, isolated staging cold-key test export; never generates traffic."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import sys


def verify(events, run_id, key_hash, requests):
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
        value = datetime.fromisoformat(event['utc'].replace('Z', '+00:00'))
        require(value.utcoffset() is not None, 'timezone required')
        return value
    starts, finishes = group('upstream_start'), group('upstream_finish')
    require(len(starts) == len(finishes) == 1, 'expected exactly one actual upstream attempt and completion')
    require(bool(starts[0].get('fetch_id')) and starts[0]['fetch_id'] == finishes[0].get('fetch_id'),
            'upstream attempt IDs must match')
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
    require(all(at(e) < at(finishes[0]) for e in misses), 'all callers must observe cold state before upstream release')
    require(len(writes) == 1 and at(writes[0]) >= at(finishes[0]), 'expected one cache write after upstream completion')
    digest = writes[0].get('value_hash')
    require(bool(digest) and digest == finishes[0].get('value_hash'), 'cached value must match the upstream value')
    require(all(e.get('ok') is True and e.get('value_hash') == digest
                and at(e) >= at(writes[0]) for e in results), 'all callers must receive the expected value after cache publication')
    return f'PASS: {requests} cold callers across {len(instances)} instances, one upstream attempt, one cache write'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export')
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--key-hash', required=True)
    parser.add_argument('--requests', type=int, default=100)
    args = parser.parse_args()
    events = [json.loads(line) for line in Path(args.export).read_text().splitlines() if line.strip()]
    print(verify(events, args.run_id, args.key_hash, args.requests))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'FAIL / unresolved: {exc}', file=sys.stderr)
        sys.exit(1)
