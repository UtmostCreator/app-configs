"""Offline tests for check-anonymized.sh additions: cloud hostnames and a private denylist file."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]


class Anonymizer(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / 'tree'
        self.root.mkdir()
        self.env = {k: v for k, v in os.environ.items() if k != 'ANON_DENYLIST'}

    def check(self, text, name='note.md', **env):
        (self.root / name).write_text(text)
        return subprocess.run(['bash', str(COMMANDS / 'check-anonymized.sh'), str(self.root)],
                              env={**self.env, **env}, text=True, capture_output=True)

    def test_cloud_internal_hostname_is_flagged(self):
        host = '-'.join(['ip', '10', '0', '9', '8'])
        result = self.check(f'server_name {host}\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('cloud hostname', result.stderr)
        self.assertEqual(self.check('ip-<redacted> and ip-address notes\n').returncode, 0)

    def test_private_denylist_terms_are_flagged_case_insensitively_without_echoing_the_list(self):
        deny = Path(self.tmp.name) / 'deny.txt'
        deny.write_text('# private terms, one per line\nAcmeTours\n\nacme-internal\n')
        result = self.check('Logs from the acmetours checkout\n', ANON_DENYLIST=str(deny))
        self.assertEqual(result.returncode, 1)
        self.assertIn('denylist term', result.stderr)
        clean = self.check('Logs from the <brand> checkout\n', ANON_DENYLIST=str(deny))
        self.assertEqual(clean.returncode, 0, clean.stderr)

    def test_missing_denylist_file_fails_closed(self):
        result = self.check('clean\n', ANON_DENYLIST=str(Path(self.tmp.name) / 'missing.txt'))
        self.assertEqual(result.returncode, 2)

    def test_denylist_outside_scanned_tree_is_not_itself_reported(self):
        deny = Path(self.tmp.name) / 'deny.txt'
        deny.write_text('acmetours\n')
        self.assertEqual(self.check('clean\n', ANON_DENYLIST=str(deny)).returncode, 0)


if __name__ == '__main__':
    unittest.main()
