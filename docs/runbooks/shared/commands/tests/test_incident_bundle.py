"""Offline tests for linux/incident-bundle.sh using mocked system tools. No production access."""
import gzip
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]
PEER = '.'.join(['10', '0', '0', '7'])


class IncidentBundle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.logs = self.root / 'logs'
        self.logs.mkdir()
        self.capture = self.root / 'artisan-calls'
        (self.logs / 'access.log').write_text(
            f'{PEER} - - [15/Jan/2001:00:00:01 +0000] "GET /example/resource?token=x HTTP/1.1" 200 1 "-" "agent"\n'
            f'{PEER} - - [15/Jan/2001:23:59:59 +0000] "GET /example/resource HTTP/1.1" 500 1 "-" "agent"\n')
        (self.logs / 'error.log').write_text(
            f'[Mon Jan 15 00:30:52.266488 2001] [php:error] [pid 1] [client {PEER}:1] PHP Fatal error: x\n')
        (self.logs / 'access.log.2.gz').write_bytes(gzip.compress(
            f'{PEER} - - [14/Jan/2001:00:00:02 +0000] "GET / HTTP/1.1" 200 1 "-" "agent"\n'.encode()))
        for name, body in {
            'date': 'echo 2001-01-15T11:21:05Z',
            'timedatectl': 'printf "Timezone=Etc/UTC\\nNTPSynchronized=yes\\n"',
            'uptime': 'echo " 11:21:05 up 7 days, load average: 1.00, 1.00, 1.00"',
            'nproc': 'echo 4',
            'free': 'echo "Mem: 15000 2000 13000"',
            'vmstat': 'echo "r b swpd"',
            'apache2ctl': 'case "$1" in -V) echo "Server MPM: prefork";; -M) echo " mpm_prefork_module (shared)"; echo " php_module (shared)";; *) echo cfg;; esac',
            'pgrep': 'echo 151',
            'ps': 'printf "R\\nR\\nS\\n"',
            'ss': 'echo "LISTEN 326 511 *:80 *:*"',
            'journalctl': 'echo denied >&2; exit 9',
            'systemctl': 'echo Restart=no',
            'php': f'echo "$*" >> "{self.capture}"; echo "PHP 8.3.0 (cli)"',
        }.items():
            path = self.bin / name
            path.write_text('#!/usr/bin/env bash\n' + body + '\n')
            path.chmod(0o755)
        self.env = {**os.environ, 'PATH': f'{self.bin}{os.pathsep}{os.environ["PATH"]}',
                    'LOG_DIR': str(self.logs), 'APACHE_CONF_DIR': str(self.root / 'no-apache-conf')}
        self.env.pop('ALLOW_ARTISAN', None)
        self.env.pop('APP_ROOT', None)

    def run_bundle(self, *args, **env):
        return subprocess.run(['bash', str(COMMANDS / 'linux/incident-bundle.sh'), *args],
                              env={**self.env, **env}, text=True, capture_output=True)

    def test_every_section_runs_and_failures_are_labelled_not_hidden(self):
        result = self.run_bundle('2001-01-15 00:00', '2001-01-16 00:00')
        self.assertEqual(result.returncode, 3, result.stderr)
        for header in ('== clock ==', '== host load ==', '== apache model ==', '== workers and backlog ==',
                       '== kernel OOM ==', '== apache unit journal ==', '== log inventory ==', '== summary =='):
            self.assertIn(header, result.stdout)
        self.assertIn('-- exit=9', result.stdout)
        self.assertIn('failed=', result.stdout)
        self.assertIn('kernel OOM', result.stdout.split('== summary ==')[1])
        self.assertIn('Server MPM: prefork', result.stdout)
        self.assertIn('LISTEN 326 511', result.stdout)

    def test_log_inventory_prints_boundaries_without_addresses_or_paths(self):
        out = self.run_bundle().stdout
        self.assertIn('access.log first=15/Jan/2001:00:00:01 +0000 last=15/Jan/2001:23:59:59 +0000', out)
        self.assertIn('access.log.2.gz first=14/Jan/2001:00:00:02 +0000 last=not-read(gzip)', out)
        self.assertIn('error.log first=Mon Jan 15 00:30:52.266488 2001', out)
        self.assertNotIn(PEER, out)
        self.assertNotIn('example/resource', out)

    def test_application_commands_require_explicit_opt_in(self):
        app = self.root / 'app'
        (app / 'bootstrap' / 'cache').mkdir(parents=True)
        self.run_bundle(APP_ROOT=str(app))
        self.assertFalse(self.capture.exists() and 'artisan' in self.capture.read_text())
        out = self.run_bundle(APP_ROOT=str(app), ALLOW_ARTISAN='1').stdout
        self.assertIn('artisan about --only=drivers', self.capture.read_text())
        self.assertIn('== application (boots the framework) ==', out)

    def test_bad_arguments_fail_before_collecting(self):
        result = self.run_bundle('a', 'b', 'c')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')

    def test_slow_section_is_bounded_and_reported_as_timed_out(self):
        (self.bin / 'vmstat').write_text('#!/usr/bin/env bash\nsleep 30\n')
        result = self.run_bundle(SECTION_TIMEOUT='1')
        self.assertEqual(result.returncode, 3)
        self.assertIn('-- exit=124 (timed out after 1s)', result.stdout)
        self.assertIn('host load', result.stdout.split('== summary ==')[1])
        self.assertIn('== log inventory ==', result.stdout)
        self.assertNotEqual(self.run_bundle(SECTION_TIMEOUT='0').returncode, 0)


if __name__ == '__main__':
    unittest.main()
