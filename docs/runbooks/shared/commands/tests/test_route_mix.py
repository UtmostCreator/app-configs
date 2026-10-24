"""Offline tests for apache/route-mix.sh (log_summary.py route-mix). Synthetic fixtures only."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]
CLASSES = 'gql=^/graphql$;redir=netlify-redirects;region=/region$'


def access(minute, path, agent='node', status=200, method='GET'):
    return f'198.51.100.7 - - [15/Jan/2001:12:{minute}:05 +0000] "{method} {path} HTTP/1.1" {status} 9 "-" "{agent}"\n'


class RouteMix(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.log = Path(self.tmp.name) / 'access.log'
        self.env = {k: v for k, v in os.environ.items()
                    if k not in ('WINDOW', 'START_UTC', 'END_UTC', 'ROUTE_CLASSES', 'UA_MATCH')}

    def run_mix(self, **env):
        return subprocess.run(['bash', str(COMMANDS / 'apache/route-mix.sh'), str(self.log)],
                              env={**self.env, **env}, text=True, capture_output=True)

    def test_per_minute_classes_in_given_order_with_other(self):
        self.log.write_text(access('22', '/graphql', method='POST')
                            + access('22', '/example/region/tours/x?utm=1', agent='Mozilla/5.0')
                            + access('23', '/api/content/v1/netlify-redirects')
                            + access('23', '/api/content/v1/netlify-redirects?x=1')
                            + access('23', '/api/content/v1/region', method='POST')
                            + access('23', '/graphql', method='POST'))
        result = self.run_mix(ROUTE_CLASSES=CLASSES)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            '2001-01-15T12:22Z total=2 gql=1 redir=0 region=0 other=1',
            '2001-01-15T12:23Z total=4 gql=1 redir=2 region=1 other=0',
        ])

    def test_first_class_wins_and_query_is_ignored(self):
        self.log.write_text(access('23', '/graphql?redir=netlify-redirects'))
        out = self.run_mix(ROUTE_CLASSES='gql=^/graphql$;redir=netlify-redirects').stdout
        self.assertEqual(out.strip(), '2001-01-15T12:23Z total=1 gql=1 redir=0 other=0')

    def test_optional_user_agent_share(self):
        self.log.write_text(access('23', '/graphql') + access('23', '/graphql', agent='Mozilla/5.0'))
        out = self.run_mix(ROUTE_CLASSES=CLASSES, UA_MATCH='^node$').stdout
        self.assertIn('other=0 ua_match=1', out)

    def test_utc_bounds_and_window_are_honoured(self):
        self.log.write_text(access('22', '/graphql') + access('23', '/graphql'))
        out = self.run_mix(ROUTE_CLASSES=CLASSES, START_UTC='2001-01-15T12:23:00Z', END_UTC='2001-01-15T12:24:00Z').stdout
        self.assertEqual(len(out.splitlines()), 1)
        self.assertTrue(out.startswith('2001-01-15T12:23Z'))

    def test_classes_are_required_and_validated(self):
        self.log.write_text(access('23', '/graphql'))
        for bad in (None, '', 'noequals', 'x=[', 'other=/x', 'a=/x;a=/y', 'total=/x', 'bad name=/x'):
            with self.subTest(bad=bad):
                env = {} if bad is None else {'ROUTE_CLASSES': bad}
                result = self.run_mix(**env)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')

    def test_rejected_records_emit_no_aggregate(self):
        self.log.write_text(access('23', '/graphql') + 'garbage\n')
        result = self.run_mix(ROUTE_CLASSES=CLASSES)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertIn('rejected_records=1', result.stderr)


if __name__ == '__main__':
    unittest.main()
