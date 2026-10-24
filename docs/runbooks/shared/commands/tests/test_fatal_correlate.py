"""Offline tests for apache/fatal-correlate.py. Synthetic fixtures only; no production access."""
import gzip
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]
SCRIPT = COMMANDS / 'apache' / 'fatal-correlate.py'
# Built from parts so the anonymisation lint does not mistake fixtures for real addresses.
PRIVATE_PEER = '.'.join(['10', '0', '0', '7'])
PUBLIC_PEER = '198.51.100.20'
AI_AGENT = 'ExampleBot/1.0'
SEARCH_AGENT = 'ExampleCrawler/2.0'
# Synthetic addresses assembled at runtime for the same reason.
PERSON = '@'.join(['person', 'example.com'])
USER = '@'.join(['user', 'example.com'])
BROWSER_AGENT = 'Mozilla/5.0 (compatible; ExampleBrowser/1.0)'


def fatal(stamp, pid, site, line, alloc=20480, release='sample-release'):
    return (f'[Mon Jan 15 {stamp} 2001] [php:error] [pid {pid}] [client {PRIVATE_PEER}:4138] '
            f'PHP Fatal error:  Allowed memory size of 268435456 bytes exhausted (tried to allocate {alloc} bytes) '
            f'in /srv/example/releases/{release}/{site} on line {line}\n')


def request(stamp, path, status, agent, peer=PRIVATE_PEER, method='GET', size=311, day='15'):
    return f'{peer} - - [{day}/Jan/2001:{stamp} +0000] "{method} {path} HTTP/1.1" {status} {size} "-" "{agent}"\n'


PAGE = 'app/Export/Builder.php'
HANDLER = 'app/Support/ErrorHandler.php'
LOADER = 'app/Support/Loader.php'
DB = 'app/Storage/Reader.php'

ERRORS = (
    '[Mon Jan 15 00:00:01.000000 2001] [mpm_prefork:notice] [pid 1] AH00163: resuming normal operations\n'
    # Request 1 and request 3 reuse PID 4100: PID alone must not merge them.
    + fatal('00:30:52.266488', 4100, PAGE, 165)
    + fatal('00:30:52.267293', 4100, HANDLER, 1, alloc=32768)
    + fatal('00:31:42.626322', 4200, DB, 425)
    + fatal('00:31:42.627136', 4200, LOADER, 571, alloc=65536)
    + fatal('01:03:34.034268', 4100, PAGE, 165)
    + fatal('01:03:34.035107', 4100, HANDLER, 1, alloc=32768)
)

ACCESS = (
    request('00:30:40', '/example/export', 200, BROWSER_AGENT, size=168127)
    + request('00:30:45', '/example/export', 500, AI_AGENT)
    + request('00:30:50', f'/example/resource/12345/orders?email={PERSON}&token=abc', 200, BROWSER_AGENT, PUBLIC_PEER)
    + request('00:31:00', '/example/other-action', 503, BROWSER_AGENT, PUBLIC_PEER, method='POST')
    + request('00:31:35', '/example/export', 500, SEARCH_AGENT)
    + request('01:03:26', '/example/export?page=2', 500, AI_AGENT)
    + request('09:00:00', '/example/export', 500, AI_AGENT)
    + request('09:00:00', '/example/export', 500, AI_AGENT, day='16')
)


class FatalCorrelate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.err = self.root / 'error.log'
        self.acc = self.root / 'access.log'
        self.err.write_text(ERRORS)
        self.acc.write_text(ACCESS)

    def run_tool(self, *args, offset='+0000', err=None, acc=None):
        cmd = [sys.executable, '-I', str(SCRIPT)]
        if offset is not None:
            cmd += ['--error-offset', offset]
        cmd += ['--error-log', str(err or self.err), '--access-log', str(acc or self.acc), *args]
        return subprocess.run(cmd, text=True, capture_output=True)

    def test_pairs_by_pid_burst_not_pid_alone(self):
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('requests=3 secondary_lines=3', result.stdout)
        self.assertIn('2 app/Export/Builder.php:165', result.stdout)
        self.assertIn('1 app/Storage/Reader.php:425', result.stdout)
        self.assertIn('limit_bytes=268435456:3', result.stdout)
        self.assertIn('releases=sample-release:3', result.stdout)

    def test_joins_each_fatal_to_the_5xx_received_before_it(self):
        out = self.run_tool().stdout
        self.assertIn('joined=3 unmatched_fatals=0 ambiguous=0', out)
        self.assertIn('3 GET /example/export 500', out)
        self.assertNotIn('/example/other-action', out.split('== joined routes')[1].split('==')[1])
        self.assertIn('gap_s_min=7.3 gap_s_p50=7.6 gap_s_max=8.0', out)

    def test_callers_are_classified_without_raw_agents_or_addresses(self):
        out = self.run_tool().stdout
        self.assertIn('ua other-bot 2', out)
        self.assertIn('ua browser 1', out)
        self.assertIn('peer private 3', out)
        for secret in (PRIVATE_PEER, PUBLIC_PEER, 'ExampleBot/1.0', PERSON, 'token=abc', 'page=2'):
            self.assertNotIn(secret, out)

    def test_hourly_table_and_route_history_by_day(self):
        out = self.run_tool().stdout
        self.assertIn('2001-01-15T00 2 2 3', out)
        self.assertIn('2001-01-15T09 0 0 1', out)
        self.assertIn('2001-01-15 GET /example/export 200 1', out)
        self.assertIn('2001-01-15 GET /example/export 500 3', out)
        self.assertIn('2001-01-16 GET /example/export 500 1', out)

    def test_route_templates_hide_identifiers_unless_raw_requested(self):
        self.acc.write_text(request('00:30:45', f'/example/resource/12345/{USER}/0f8fad5b-d9cb-469f-a165-70867728950e', 500,
                                    BROWSER_AGENT))
        out = self.run_tool().stdout
        self.assertIn('/example/resource/{n}/{email}/{uuid}', out)
        self.assertNotIn(USER, out)
        raw = self.run_tool('--raw-paths').stdout
        self.assertIn(f'/example/resource/12345/{USER}/', raw)

    def test_error_offset_is_required_and_applied(self):
        missing = self.run_tool(offset=None)
        self.assertNotEqual(missing.returncode, 0)
        self.assertEqual(missing.stdout, '')
        # The same events written in local +0100 time must join identically after conversion.
        shifted = ERRORS.replace('[Mon Jan 15 00:', '[Mon Jan 15 01:', 3)
        shifted = shifted.replace('[Mon Jan 15 00:31', '[Mon Jan 15 01:31')
        shifted = shifted.replace('[Mon Jan 15 01:03', '[Mon Jan 15 02:03')
        local = self.root / 'error-local.log'
        local.write_text(shifted)
        out = self.run_tool(offset='+0100', err=local).stdout
        self.assertIn('joined=3 unmatched_fatals=0', out)

    def test_unmatched_and_ambiguous_are_reported(self):
        self.acc.write_text(request('00:30:44', '/example/export', 500, AI_AGENT)
                            + request('00:30:45', '/example/export', 500, AI_AGENT))
        out = self.run_tool().stdout
        self.assertIn('joined=1 unmatched_fatals=2 ambiguous=1', out)
        # FIFO: the earliest unmatched candidate is assigned to the earliest fatal.
        self.assertIn('1 GET /example/export 500', out)

    def test_gzip_and_multiple_access_files(self):
        gz = self.root / 'access.log.2.gz'
        gz.write_bytes(gzip.compress(ACCESS.encode()))
        result = self.run_tool('--access-log', str(self.acc), acc=gz)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('access_records=16', result.stderr)

    def test_bad_input_fails_without_aggregate(self):
        self.acc.write_text(ACCESS + 'not an access record\n')
        result = self.run_tool()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertIn('rejected_records=1', result.stderr)
        self.err.write_text('[garbled header] PHP Fatal error:  Allowed memory size of 1 bytes exhausted\n')
        self.acc.write_text(ACCESS)
        result = self.run_tool()
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        result = self.run_tool(err=self.root / 'missing.log')
        self.assertEqual(result.returncode, 2)

    def test_join_crosses_midnight_and_rotation_boundary(self):
        # The request is in yesterday's access file; its fatal is logged after midnight in today's error log.
        self.err.write_text(fatal('00:00:05.500000', 4300, PAGE, 165).replace('Mon Jan 15', 'Tue Jan 16'))
        yesterday = self.root / 'access.log.1'
        yesterday.write_text(request('23:59:58', '/example/export', 500, AI_AGENT))
        today = self.root / 'access.log'
        today.write_text(request('00:00:30', '/', 200, BROWSER_AGENT, day='16'))
        result = self.run_tool('--access-log', str(today), acc=yesterday)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('joined=1 unmatched_fatals=0 ambiguous=0 gap_s_min=7.5', result.stdout)

    def test_truncated_gzip_fails_without_aggregate(self):
        gz = self.root / 'access.log.3.gz'
        gz.write_bytes(gzip.compress(ACCESS.encode())[:-8])
        result = self.run_tool(acc=gz)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')

    def test_same_file_twice_is_rejected_instead_of_double_counted(self):
        result = self.run_tool('--access-log', str(self.acc))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertIn('more than once', result.stderr)

    def test_no_memory_fatals_is_an_explicit_empty_result(self):
        self.err.write_text('[Mon Jan 15 00:00:01.000000 2001] [core:notice] [pid 1] AH00094: started\n')
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('requests=0', result.stdout)
        self.assertIn('coverage must be verified separately', result.stderr)


if __name__ == '__main__':
    unittest.main()
