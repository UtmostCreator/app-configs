"""Exercise the documented filesystem inverse in temporary directories only."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]
RUNBOOKS = COMMANDS.parents[1]


class ScopedRollback(unittest.TestCase):
    def call(self, *arguments):
        return subprocess.run([sys.executable, str(COMMANDS / 'scoped-config-rollback.py'),
                               *map(str, arguments)], capture_output=True, text=True)

    def checked(self, *arguments):
        result = self.call(*arguments)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def test_scoped_rollback_preserves_extended_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'live'; root.mkdir()
            state = Path(tmp) / 'before.json'
            original = root / 'original.conf'; original.write_text('original\n')
            original.chmod(0o640)
            os.utime(original, ns=(1700000000123456789, 1700000000123456789))
            (root / 'enabled.conf').symlink_to('original.conf')
            try:
                os.setxattr(original, 'user.rollback-test', b'preserved')
            except OSError as error:
                self.skipTest('filesystem has no writable xattrs: ' + str(error))
            self.checked('snapshot', root, state, 'original.conf', 'enabled.conf', 'introduced.conf')
            manifest = json.loads(state.read_text())
            original.write_text('changed\n'); original.chmod(0o600)
            os.removexattr(original, 'user.rollback-test')
            (root / 'enabled.conf').unlink()
            (root / 'introduced.conf').write_text('introduced\n')
            self.checked('checkpoint', state)
            (root / 'unrelated.conf').write_text('independent change\n')
            self.checked('restore', state)
            self.assertEqual(original.read_text(), 'original\n')
            self.assertEqual(os.getxattr(original, 'user.rollback-test'), b'preserved')
            self.assertEqual(os.readlink(root / 'enabled.conf'), 'original.conf')
            self.assertFalse((root / 'introduced.conf').exists())
            self.assertEqual((root / 'unrelated.conf').read_text(), 'independent change\n')
            verified = Path(tmp) / 'verified.json'
            self.checked('snapshot', root, verified, *manifest['before'])
            self.assertEqual(json.loads(verified.read_text())['before'], manifest['before'])

    def test_scoped_drift_blocks_before_any_restore(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'live'; root.mkdir()
            state = Path(tmp) / 'before.json'
            for name in ('a.conf', 'z.conf'):
                (root / name).write_text('original')
            self.checked('snapshot', root, state, 'a.conf', 'z.conf')
            for name in ('a.conf', 'z.conf'):
                (root / name).write_text('approved')
            self.checked('checkpoint', state)
            (root / 'z.conf').write_text('concurrent change')
            result = self.call('restore', state)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('scoped drift', result.stderr)
            self.assertEqual((root / 'a.conf').read_text(), 'approved')
            self.assertEqual((root / 'z.conf').read_text(), 'concurrent change')

    @unittest.skipUnless(shutil.which('setfacl'), 'setfacl unavailable; ACL qualification outstanding')
    def test_scoped_rollback_restores_posix_acl(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'live'; root.mkdir()
            state = Path(tmp) / 'before.json'
            original = root / 'a.conf'; original.write_text('original')
            result = subprocess.run(['setfacl', '-m', 'u:12345:r--', str(original)],
                                    capture_output=True, text=True)
            if result.returncode:
                self.skipTest('ACL unsupported on fixture filesystem: ' + result.stderr)
            expected_acl = os.getxattr(original, 'system.posix_acl_access')
            self.checked('snapshot', root, state, 'a.conf')
            subprocess.run(['setfacl', '-b', str(original)], check=True, capture_output=True)
            original.write_text('modified')
            self.checked('checkpoint', state)
            self.checked('restore', state)
            self.assertEqual(os.getxattr(original, 'system.posix_acl_access'), expected_acl)

    def test_missing_checkpoint_cannot_restore(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'live'; root.mkdir()
            state = Path(tmp) / 'before.json'
            (root / 'a.conf').write_text('original')
            self.checked('snapshot', root, state, 'a.conf')
            (root / 'a.conf').write_text('changed')
            self.assertNotEqual(self.call('restore', state).returncode, 0)
            self.assertEqual((root / 'a.conf').read_text(), 'changed')

    def test_checkpoint_cannot_be_overwritten_to_hide_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'live'; root.mkdir()
            state = Path(tmp) / 'before.json'
            (root / 'a.conf').write_text('original')
            self.checked('snapshot', root, state, 'a.conf')
            (root / 'a.conf').write_text('approved')
            self.checked('checkpoint', state)
            (root / 'a.conf').write_text('drift')
            self.assertNotEqual(self.call('checkpoint', state).returncode, 0)
            self.assertNotEqual(self.call('restore', state).returncode, 0)
            self.assertEqual((root / 'a.conf').read_text(), 'drift')

    def test_oversized_configuration_and_directory_scope_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'live'; root.mkdir()
            (root / 'directory').mkdir()
            with (root / 'large.conf').open('wb') as stream:
                stream.truncate(4 * 1024 * 1024 + 1)
            for name in ('large.conf', 'directory'):
                result = self.call('snapshot', root, Path(tmp) / 'before.json', name)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((Path(tmp) / 'before.json').exists())

    def test_scope_cannot_follow_parent_symlink_or_restore_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'live'; root.mkdir()
            outside = Path(tmp) / 'outside'; outside.mkdir()
            (outside / 'secret.conf').write_text('secret')
            (root / 'escape').symlink_to(outside)
            for name in ('escape/secret.conf', '../outside/secret.conf', '.'):
                with self.subTest(name=name):
                    self.assertNotEqual(self.call('snapshot', root, Path(tmp) / 'bad.json', name).returncode, 0)

    def test_historical_oom_uses_incident_bounds(self):
        text = (RUNBOOKS / 'diagnostics/03-apache-capacity.md').read_text()
        section = text.split('## CAP-03\n')[1].split('## CAP-04\n')[0]
        self.assertIn('oom-events.sh "$START_UTC" "$END_UTC"', section)
        self.assertNotIn('60 minutes ago', section)

    def test_intake_has_no_homepage_probe_or_circular_preconditions(self):
        intake = (RUNBOOKS / '00-incident-intake.md').read_text()
        self.assertNotIn('https://<site>/<health-or-home-path>', intake)
        section = intake.split('## INC-03\n')[1].split('## INC-04\n')[0]
        self.assertIn('curl --connect-timeout 3 --max-time 15 --retry 0', section)
        self.assertIn('No reviewed safe endpoint', section)
        bootstrap = intake.split('## INC-02\n')[1].split('## INC-03\n')[0]
        self.assertNotIn('**Preconditions:** Time window and sources validated', bootstrap)
        evidence = (RUNBOOKS / 'foundations/01-evidence-attribution.md').read_text()
        bootstrap = evidence.split('## EVD-02\n')[1].split('## EVD-03\n')[0]
        self.assertNotIn('**Preconditions:** Time window and sources validated', bootstrap)


if __name__ == '__main__':
    unittest.main()
