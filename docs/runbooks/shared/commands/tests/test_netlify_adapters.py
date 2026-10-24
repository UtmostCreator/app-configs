"""Offline adapter regressions using synthetic, documented-schema records."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ADAPTERS = Path(__file__).resolve().parents[1] / 'netlify'


@unittest.skipUnless(shutil.which('jq'), 'jq is required for adapter verification')
class NetlifyAdapters(unittest.TestCase):
    def traffic(self, url='https://example.invalid/payments/abc', **fields):
        return dict(log_type='traffic', request_id='synthetic-request',
                    timestamp='2001-01-15T10:00:00Z', status_code=503,
                    duration=12.5, url=url, **fields)

    def adapt(self, row, adapter='traffic', *args):
        return subprocess.run(['jq', '-ce', *args, '-f', str(ADAPTERS / f'{adapter}-metrics.jq')],
                              input=json.dumps(row), text=True, capture_output=True)

    def test_netlify_absolute_url_drops_credentials(self):
        for authority in ['reader:private' + '@' + 'example.invalid', 'other.invalid:443']:
            row = self.traffic(f'https://{authority}/payments/abc?token=private#private')
            result = self.adapt(row, 'traffic', '--argjson', 'public_path_segments', '["payments"]')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['path'], '/payments/:redacted')
            for secret in ['reader', 'private', 'example.invalid', 'other.invalid', 'abc']:
                self.assertNotIn(secret, result.stdout)

    def test_redacts_short_and_encoded_path_identifiers_by_default(self):
        for path in ['/a/token/%65mail%40example.invalid', '/payments/abc']:
            result = self.adapt(self.traffic('https://example.invalid' + path))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['path'], '/:redacted' * path.count('/'))
        result = self.adapt(self.traffic('https://example.invalid?token=private'))
        self.assertEqual(json.loads(result.stdout)['path'], '/')

    def test_malformed_and_unsupported_urls_cannot_silently_disappear(self):
        for url in ['https:///payments/abc', 'https://', '/relative/path', 'javascript:private',
                    'https://user@@example.invalid/path', 'https://example.invalid:99999/path',
                    'https://' + '.'.join(['999', '1', '1', '1']) + '/path',
                    'https://127.1/path', 'https://' + '.'.join(['01', '2', '3', '4']) + '/path',
                    'https://bad..invalid/path', 'https://-bad.invalid/path',
                    'https://example.invalid/path with spaces', 'https://example.invalid/\\private',
                    'https://example.invalid/%Q1', 'https://example.invalid\n/private',
                    'https://[::1]/path']:
            with self.subTest(url=url):
                result = self.adapt(self.traffic(url))
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(result.stdout, '')

    def test_invalid_public_segment_policy_fails(self):
        for policy in ['["a/b"]', 'false', 'null', '"public"', '[42]', '["health\\n"]']:
            result = self.adapt(self.traffic(), 'traffic', '--argjson', 'public_path_segments', policy)
            self.assertNotEqual(result.returncode, 0, policy)

    def function(self, function_type='regular'):
        row = self.traffic()
        del row['url']
        row.update(log_type='functions', function_type=function_type,
                   function_name='synthetic-handler', path='/payments/private?token=private')
        return row

    def test_netlify_legacy_standard_requires_type_evidence(self):
        for function_type in ['standard', 'background', 'edge', None]:
            result = self.adapt(self.function(function_type), 'function', '--arg', 'duration_unit', 'ms')
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')
        result = self.adapt(self.function('standard'), 'function', '--arg', 'duration_unit', 'ms')
        self.assertIn('unresolved', result.stderr)

    def test_verified_duration_units_and_function_path_redaction(self):
        for unit, expected in [('ms', 12.5), ('us', .0125), ('s', 12500)]:
            result = self.adapt(self.function(), 'function', '--arg', 'duration_unit', unit)
            self.assertEqual(result.returncode, 0, result.stderr)
            output = json.loads(result.stdout)
            self.assertAlmostEqual(output['duration_ms'], expected)
            self.assertEqual(output['path'], '/:redacted/:redacted')
            self.assertNotIn('private', result.stdout)
        for unit in ['', 'unknown', 'nanoseconds']:
            self.assertNotEqual(self.adapt(self.function(), 'function', '--arg', 'duration_unit', unit).returncode, 0)

    def test_cli_records_missing_identity_and_invalid_metrics_rejected(self):
        for row in [{'message': 'application message'},
                    {**self.traffic(), 'request_id': ''},
                    {**self.traffic(), 'status_code': 200.5},
                    {**self.traffic(), 'duration': -1}]:
            self.assertNotEqual(self.adapt(row).returncode, 0)


if __name__ == '__main__':
    unittest.main()
