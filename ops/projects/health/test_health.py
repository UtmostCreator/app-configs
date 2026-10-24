"""Isolated health failure regressions; no real services or configuration."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HEALTH = Path(__file__).resolve().parent


class HealthRunner(unittest.TestCase):
    def run_check(self, body, mode='--json', fail_aggregation=False):
        with tempfile.TemporaryDirectory() as tmp:
            projects = Path(tmp) / 'projects'
            target = projects / 'health'
            shutil.copytree(HEALTH, target)
            shutil.copyfile(HEALTH.parent / 'lib.sh', projects / 'lib.sh')
            for check in (target / 'checks.d').glob('*.sh'):
                check.unlink()
            if body is not None:
                (target / 'checks.d/check.sh').write_text(body)
            # Exercise pretty mode without the renderer's optional terminal dependencies.
            (target / 'render.sh').unlink()
            env = dict(os.environ)
            if fail_aggregation:
                binary = Path(tmp) / 'bin'; binary.mkdir()
                real_jq = shutil.which('jq')
                mock_jq = binary / 'jq'
                mock_jq.write_text('#!/bin/bash\n'
                                   'for arg in "$@"; do [[ "$arg" == --slurpfile ]] && exit 9; done\n'
                                   'exec "$REAL_TEST_JQ" "$@"\n')
                mock_jq.chmod(0o755)
                env.update(PATH=str(binary) + os.pathsep + env['PATH'], REAL_TEST_JQ=real_jq)
            arguments = ['bash', str(target / 'run.sh')] + ([mode] if mode else [])
            result = subprocess.run(arguments, env=env, text=True, capture_output=True, timeout=10)
            record = json.loads(result.stdout) if result.stdout else None
            return result, record

    def test_check_failure_empty_malformed_and_invalid_status_fail(self):
        for body in ('exit 7', 'exit 0', 'echo broken', 'echo "[]"',
                     'echo \'{"name":"x","section":"x","note":"x","status":"healthy"}\''):
            with self.subTest(body=body):
                result, record = self.run_check(body)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(record['overall']['status'], 'fail')

    def test_partial_success_then_exit_failure_cannot_pass(self):
        result, record = self.run_check('echo \'{"name":"x","section":"x","note":"x","status":"ok"}\'\nexit 3')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(record['overall']['passed'], 0)

    def test_no_checks_fail(self):
        result, record = self.run_check(None)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(record['overall']['failed'], 1)

    def test_valid_record_passes(self):
        result, record = self.run_check('echo \'{"name":"x","section":"x","note":"x","status":"ok"}\'')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(record['overall']['passed'], 1)

    def test_all_modes_preserve_ok_warn_and_fail_exit_contract(self):
        for mode in ('--json', '--quiet', ''):
            for status in ('ok', 'warn', 'fail'):
                with self.subTest(mode=mode, status=status):
                    row = dict(name='example', section='example', note='mock check', status=status)
                    result, record = self.run_check('printf \'%s\\n\' \'' + json.dumps(row) + '\'', mode)
                    self.assertEqual(result.returncode, int(status == 'fail'), result.stderr)
                    if mode == '--quiet':
                        self.assertEqual(result.stdout, '')
                    else:
                        self.assertEqual(record['overall']['status'], status)
                        self.assertEqual(record['overall']['warned'], int(status == 'warn'))
                        self.assertEqual(record['overall']['failed'], int(status == 'fail'))

    def test_aggregation_failure_cannot_report_success_in_any_mode(self):
        for mode in ('--json', '--quiet', ''):
            with self.subTest(mode=mode):
                row = dict(name='example', section='example', note='mock', status='ok')
                result, record = self.run_check('echo \'' + json.dumps(row) + '\'', mode,
                                                fail_aggregation=True)
                self.assertEqual(result.returncode, 1)
                self.assertIsNone(record)
                self.assertIn('could not aggregate health results', result.stderr)

    def test_mixed_valid_and_invalid_records_are_discarded(self):
        row = dict(name='example', section='example', note='mock', status='ok')
        result, record = self.run_check('echo \'' + json.dumps(row) + '\'\necho \'{"status":"ok"}\'')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(record['overall']['passed'], 0)
        self.assertEqual(record['overall']['failed'], 1)


class ProcessIdentity(unittest.TestCase):
    def run_process(self, unit='', start='npm run dev', active=0, available=True, match=0):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'checks.d').mkdir()
            script = root / 'checks.d/process.sh'
            shutil.copyfile(HEALTH / 'checks.d/30-process.sh', script)
            (root / 'lib.sh').write_text('''
proj_health_for_each_project() { echo example; }
proj_field() {
  case "$2" in
    service.unit) printf '%s\\n' "$TEST_UNIT" ;;
    service.start_cmd) printf '%s\\n' "$TEST_START" ;;
  esac
}
command() {
  if [[ "$*" == '-v systemctl' && "$TEST_SYSTEMCTL_AVAILABLE" == 0 ]]; then return 1; fi
  builtin command "$@"
}
systemctl() { printf 'systemctl:%s\\n' "$*" >>"$TEST_CALLS"; return "$TEST_ACTIVE"; }
pgrep() { printf 'pgrep:%s\\n' "$*" >>"$TEST_CALLS"; return "$TEST_MATCH"; }
proj_emit() { jq -nc --arg status "$1" --arg note "$3" '{status:$status,note:$note}'; }
''')
            calls = root / 'calls'
            env = dict(os.environ, TEST_UNIT=unit, TEST_START=start, TEST_ACTIVE=str(active),
                       TEST_SYSTEMCTL_AVAILABLE=str(int(available)), TEST_CALLS=str(calls),
                       TEST_MATCH=str(match))
            result = subprocess.run(['bash', str(script)], env=env, text=True,
                                    capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout), calls.read_text() if calls.exists() else ''

    def test_explicit_active_unit_uses_exact_identity_and_qualifies_readiness(self):
        record, calls = self.run_process(unit='example@worker-1.service')
        self.assertEqual(record['status'], 'ok')
        self.assertIn('application readiness unverified', record['note'])
        self.assertEqual(calls.strip(), 'systemctl:is-active --quiet -- example@worker-1.service')

    def test_inactive_or_inaccessible_unit_cannot_fall_back_to_generic_process(self):
        for active in (1, 3, 4):
            with self.subTest(active=active):
                record, calls = self.run_process(unit='example.service', active=active, match=0)
                self.assertEqual(record['status'], 'fail')
                self.assertIn('not active or inaccessible', record['note'])
                self.assertNotIn('pgrep:', calls)

    def test_invalid_unit_names_never_invoke_systemctl_or_pgrep(self):
        for unit in ('example', 'example.service other.service', '../example.service',
                     '--example.service', 'example.service;true'):
            with self.subTest(unit=unit):
                record, calls = self.run_process(unit=unit)
                self.assertEqual(record['status'], 'fail')
                self.assertIn('invalid service.unit', record['note'])
                self.assertEqual(calls, '')

    def test_explicit_unit_without_systemctl_fails_without_process_fallback(self):
        record, calls = self.run_process(unit='example.service', available=False)
        self.assertEqual(record['status'], 'fail')
        self.assertIn('systemctl unavailable', record['note'])
        self.assertEqual(calls, '')

    def test_missing_unit_and_start_command_warns_without_claiming_identity(self):
        for missing in ('', 'null'):
            with self.subTest(missing=missing):
                record, calls = self.run_process(unit=missing, start=missing)
                self.assertEqual(record['status'], 'warn')
                self.assertIn('no service.start_cmd', record['note'])
                self.assertEqual(calls, '')

    def test_unmatched_generic_process_is_failure(self):
        record, calls = self.run_process(match=1)
        self.assertEqual(record['status'], 'fail')
        self.assertNotIn('systemctl:', calls)
        self.assertIn('pgrep:', calls)

    def test_unrelated_same_executable_never_claims_healthy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'checks.d').mkdir()
            script = root / 'checks.d/process.sh'
            shutil.copyfile(HEALTH / 'checks.d/30-process.sh', script)
            (root / 'lib.sh').write_text('''
proj_health_for_each_project() { echo example; }
proj_field() { if [[ "$2" == service.start_cmd ]]; then echo 'npm run dev'; fi; }
pgrep() { return 0; }
proj_emit() { printf '%s\\n' "$1"; }
''')
            result = subprocess.run(['bash', str(script)], text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), 'warn')


if __name__ == '__main__':
    unittest.main()
