"""Failure cases for capture budgets and text-lint coverage; no server access."""
import gzip
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]


class CaptureLimits(unittest.TestCase):
    def run_log(self, data, mode='top-paths', compressed=False, **limits):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'input'
            path.write_bytes(gzip.compress(data) if compressed else data)
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith('LOG_MAX_') and k not in ('WINDOW', 'START_UTC', 'END_UTC')}
            env.update({k: str(v) for k, v in limits.items()})
            return subprocess.run(['python3', str(COMMANDS / 'log_summary.py'), mode, str(path)],
                                  env=env, capture_output=True, text=True, timeout=10)

    @staticmethod
    def access(path='/page'):
        return ('192.0.2.1 - - [15/Jan/2001:08:20:00 +0000] "GET '
                + path + ' HTTP/1.1" 200 1 "-" "agent" duration_us=1000\n').encode()

    def test_decompressed_byte_limit_and_exact_boundary(self):
        data = self.access()
        self.assertEqual(self.run_log(data, LOG_MAX_BYTES=len(data)).returncode, 0)
        result = self.run_log(data * 100, compressed=True, LOG_MAX_BYTES=len(data))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertIn('byte limit', result.stderr)

    def test_large_line_fails_before_aggregate(self):
        result = self.run_log(b'x' * 10000, LOG_MAX_LINE_BYTES=100)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertIn('line byte limit', result.stderr)

    def test_record_key_and_duration_limits(self):
        cases = [dict(LOG_MAX_RECORDS=1), dict(LOG_MAX_KEYS=1)]
        for limits in cases:
            result = self.run_log(self.access('/one') + self.access('/two'), **limits)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertEqual(result.stdout, '')
        result = self.run_log(self.access() * 2, mode='latency-summary', LOG_MAX_DURATIONS=1)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')

    def test_invalid_or_excessive_limits_fail(self):
        for value in ('bad', 0, -1, 999999999999):
            result = self.run_log(self.access(), LOG_MAX_BYTES=value)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, '')


class AnonymizerCoverage(unittest.TestCase):
    def test_python_jq_and_fixture_formats_reject_synthetic_credential(self):
        for suffix in ('.py', '.jq', '.json', '.jsonl', '.yaml', '.toml', '.txt', '.log', '.env'):
            with self.subTest(suffix=suffix), tempfile.TemporaryDirectory() as tmp:
                Path(tmp, 'synthetic' + suffix).write_text('ghp' + '_' + 'A' * 32)
                result = subprocess.run(['bash', str(COMMANDS / 'check-anonymized.sh'), tmp],
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 1)
                self.assertIn('token-like string', result.stderr)

    def test_documentation_address_is_allowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, 'fixture.json').write_text('{"address":"192.0.2.1"}')
            result = subprocess.run(['bash', str(COMMANDS / 'check-anonymized.sh'), tmp],
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
