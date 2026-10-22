"""Offline regression tests. No production access, network calls or application boots."""
import gzip
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


single_flight = load('single_flight', COMMANDS / 'verify-single-flight.py')


def access(stamp='13/Oct/2026:08:20:00 +0000', status=200, path='/graphql?token=secret', suffix=''):
    return f'192.0.2.1 - - [{stamp}] "POST {path} HTTP/1.1" {status} 4 "-" "agent with \\"quoted\\" text"{suffix}\n'


class Helpers(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.log = self.root / 'log'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env = {k: v for k, v in os.environ.items() if k not in
                    ('WINDOW', 'START_UTC', 'END_UTC', 'NETLIFY_LOG_CAP')}
        self.env['PATH'] = str(self.bin) + os.pathsep + self.env['PATH']

    def run_helper(self, script, *args, **env):
        return subprocess.run(['bash', str(COMMANDS / script), *map(str, args)],
                              env={**self.env, **env}, text=True, capture_output=True)

    def mock(self, name, body):
        p = self.bin / name
        p.write_text('#!/usr/bin/env bash\n' + body + '\n')
        p.chmod(0o755)

    def test_utc_window_and_chronological_buckets(self):
        self.log.write_text(access('01/Nov/2026:00:00:00 +0000')
                            + access('31/Oct/2026:23:59:00 +0000')
                            + access('01/Nov/2026:00:59:00 +0100'))
        result = self.run_helper('apache/request-rate.sh', self.log)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['2026-10-31T23:59Z 2', '2026-11-01T00:00Z 1'])
        result = self.run_helper('apache/status-distribution.sh', self.log,
                                 START_UTC='2026-10-31T23:59:00Z', END_UTC='2026-11-01T00:00:00Z')
        self.assertEqual(result.stdout.strip(), '200 2 100.00%')

    def test_all_access_helpers_handle_empty_and_bad_filters(self):
        for script in ['request-rate', 'status-distribution', 'top-clients', 'top-paths', 'method-by-path']:
            with self.subTest(script=script):
                self.log.write_text(access())
                extra = ['/graphql'] if script == 'method-by-path' else []
                invalid = self.run_helper(f'apache/{script}.sh', self.log, *extra, WINDOW='[')
                self.assertNotEqual(invalid.returncode, 0)
                self.assertEqual(invalid.stdout, '')
                self.assertIn('invalid WINDOW', invalid.stderr)
                empty = self.run_helper(f'apache/{script}.sh', self.log, *extra, WINDOW='2025')
                self.assertEqual(empty.returncode, 0, empty.stderr)
                self.assertEqual(empty.stdout, '')
                self.assertIn('No matching records', empty.stderr)

    def test_corrupt_gzip_missing_file_and_bad_record(self):
        self.log.write_bytes(gzip.compress(access().encode())[:-6])
        for script in ['request-rate', 'top-paths', 'error-log-summary']:
            result = self.run_helper(f'apache/{script}.sh', self.log)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')
        self.log.write_text(access() + 'invalid input\n')
        result = self.run_helper('apache/status-distribution.sh', self.log)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertIn('rejected_records=1', result.stderr)
        self.log.unlink()
        self.assertNotEqual(self.run_helper('apache/top-clients.sh', self.log).returncode, 0)

    def test_quoted_fields_query_redaction_and_gzip(self):
        self.log.write_bytes(gzip.compress(access().encode()))
        paths = self.run_helper('apache/top-paths.sh', self.log)
        self.assertEqual(paths.returncode, 0, paths.stderr)
        self.assertIn('100.0%  /graphql', paths.stdout)
        self.assertNotIn('secret', paths.stdout)
        methods = self.run_helper('apache/method-by-path.sh', self.log, '/graphql')
        self.assertEqual(methods.stdout.strip(), '1 POST 200')
        self.assertNotEqual(self.run_helper('apache/top-paths.sh', self.log, 0).returncode, 0)

    def test_latency_requires_explicit_field_and_separates_errors(self):
        self.log.write_text(access(suffix=' duration_us=2000') + access(status=500, suffix=' duration_us=1000'))
        result = self.run_helper('apache/latency-summary.sh', self.log)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('success n=1 p50_ms=2.000', result.stdout)
        self.assertIn('error n=1 p50_ms=1.000', result.stdout)
        self.log.write_text(access())
        self.assertNotEqual(self.run_helper('apache/latency-summary.sh', self.log).returncode, 0)

    def test_error_summary_continues_without_memory_failure(self):
        self.log.write_text('[Tue Oct 13] AH00161 worker limit\n[Tue Oct 13] resuming normal operations\n')
        result = self.run_helper('apache/error-log-summary.sh', self.log)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('restarts / shutdowns', result.stdout)
        self.assertIn('resuming normal operations', result.stdout)
        self.log.write_text('')
        self.assertEqual(self.run_helper('apache/error-log-summary.sh', self.log).returncode, 0)
        self.assertNotEqual(self.run_helper('apache/error-log-summary.sh', self.log, WINDOW='[').returncode, 0)

    def test_laravel_counts_headers_once_and_honours_window(self):
        self.log.write_text('[2026-10-13 08:20:00] production.ERROR: Failure 123\n'
                            '#0 traceback production.ERROR: secondary\n'
                            '[2026-10-13 08:21:00] production.ERROR: Failure 456\n')
        result = self.run_helper('laravel/error-summary.sh', self.log, WINDOW='08:20:')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '1 Failure N')
        self.assertNotEqual(self.run_helper('laravel/error-summary.sh', self.log, WINDOW='[').returncode, 0)
        self.log.write_text('')
        self.assertEqual(self.run_helper('laravel/error-summary.sh', self.log).returncode, 0)

    def test_netlify_json_failure_cap_and_bounds(self):
        self.mock('netlify', '''printf '%s\\n' "$*" > "$CAPTURE"
printf '%s\\n' '{"message":"a"}' '{"message":"b"}' ''')
        capture = self.root / 'args'
        result = self.run_helper('netlify/window-counts.sh', 'server', 5, '2026-10-13T08:20:00Z',
                                 CAPTURE=str(capture), NETLIFY_LOG_CAP='2')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('2 log_records', result.stdout)
        self.assertIn('possibly_truncated=true', result.stdout)
        self.assertIn('--until 2026-10-13T08:20:05Z', capture.read_text())
        self.mock('netlify', "echo 'permission denied' >&2; exit 7")
        result = self.run_helper('netlify/window-counts.sh', 'server', 5, '2026-10-13T08:20:00Z')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, '')
        self.assertIn('permission denied', result.stderr)
        self.mock('netlify', "echo 'not json'")
        self.assertNotEqual(self.run_helper('netlify/window-counts.sh', 'server', 5, '2026-10-13T08:20:00Z').returncode, 0)
        self.assertNotEqual(self.run_helper('netlify/window-counts.sh', 'server', 5).returncode, 0)
        self.assertNotEqual(self.run_helper('netlify/window-counts.sh', 'server', 0, '2026-10-13T08:20:00Z').returncode, 0)

    def test_linux_failures_do_not_report_healthy(self):
        self.mock('ss', 'echo denied >&2; exit 9')
        self.mock('journalctl', 'echo denied >&2; exit 9')
        self.mock('systemctl', 'echo policy')
        for script in ['linux/connections.sh', 'linux/oom-events.sh', 'linux/service-recovery.sh']:
            result = self.run_helper(script)
            self.assertEqual(result.returncode, 9, (script, result.stderr))
            self.assertNotIn('No matching', result.stdout)

    def test_connections_ipv4_ipv6(self):
        self.mock('ss', "printf '%s\\n' '0 0 192.0.2.2:443 198.51.100.4:2345' '0 0 [::1]:443 [2001:db8::1]:9999'")
        result = self.run_helper('linux/connections.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('established on :443: 2', result.stdout)
        self.assertIn('1 2001:db8::1', result.stdout)
        self.assertIn('1 198.51.100.4', result.stdout)

    def test_worker_helper_does_not_recommend_rss_limit_and_preserves_failure(self):
        self.mock('apache2ctl', 'echo current_config')
        self.mock('ps', 'echo "10 1 100000 01:00 apache2"')
        self.mock('systemctl', 'echo "MemoryMax=1073741824"')
        result = self.run_helper('apache/worker-capacity.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('No safe worker count calculated', result.stdout)
        self.assertNotIn('estimated safe workers:', result.stdout)
        self.mock('apache2ctl', 'echo config_failed >&2; exit 8')
        self.assertEqual(self.run_helper('apache/worker-capacity.sh').returncode, 8)

    def test_utc_conversion_across_dst(self):
        self.log.write_text(access('25/Oct/2026:01:30:00 +0100')
                            + access('25/Oct/2026:01:30:00 +0000')
                            + access('29/Mar/2026:02:30:00 +0100')
                            + access('29/Mar/2026:01:30:00 +0000'))
        result = self.run_helper('apache/request-rate.sh', self.log)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['2026-03-29T01:30Z 2',
                                                     '2026-10-25T00:30Z 1', '2026-10-25T01:30Z 1'])

    def test_combined_log_with_rotations(self):
        self.log.write_text(access())
        rotation = self.root / 'log.1.gz'
        rotation.write_bytes(gzip.compress(access('13/Oct/2026:08:19:00 +0000').encode()))
        rows = []
        for path in (self.log, rotation):
            result = self.run_helper('apache/request-rate.sh', path)
            self.assertEqual(result.returncode, 0, result.stderr)
            rows.extend(result.stdout.splitlines())
        self.assertEqual(sum(int(row.split()[1]) for row in rows), 2)

    def test_british_summer_and_winter_date_examples(self):
        for date, expected in [('2026-10-13', '08:17:00Z'), ('2026-12-13', '09:17:00Z')]:
            result = subprocess.run(['date', '-u', '-d', f'TZ="Europe/London" {date} 09:17', '+%H:%M:%SZ'],
                                    text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout.strip(), expected)


class SingleFlight(unittest.TestCase):
    def events(self):
        base = {'run_id': 'run', 'key_hash': 'key'}
        def event(kind, time, **fields):
            return {**base, 'event': kind, 'utc': f'2026-10-13T08:20:0{time}Z', **fields}
        return [event('upstream_start', 1, fetch_id='fetch'),
                event('cache_miss', 0, request_id='a', instance_id='one'),
                event('cache_miss', 2, request_id='b', instance_id='two'),
                event('upstream_finish', 3, fetch_id='fetch', ok=True, value_hash='value'),
                event('cache_write', 4, value_hash='value'),
                event('client_result', 5, request_id='a', ok=True, value_hash='value'),
                event('client_result', 5, request_id='b', ok=True, value_hash='value')]

    def test_valid_ledger(self):
        self.assertIn('PASS', single_flight.verify(self.events(), 'run', 'key', 2))

    def test_duplicate_upstream_wrong_value_missing_caller_and_warm_call_fail(self):
        variants = []
        events = self.events(); events.append(events[0].copy()); variants.append(events)
        events = self.events(); events[-1]['value_hash'] = 'wrong'; variants.append(events)
        events = self.events(); events.pop(); variants.append(events)
        events = self.events(); events[2]['utc'] = '2026-10-13T08:20:06Z'; variants.append(events)
        events = self.events(); events[2]['instance_id'] = 'one'; variants.append(events)
        events = self.events(); events[2]['key_hash'] = 'different'; variants.append(events)
        for events in variants:
            with self.subTest(events=events):
                with self.assertRaises(ValueError):
                    single_flight.verify(events, 'run', 'key', 2)


if __name__ == '__main__':
    unittest.main()
