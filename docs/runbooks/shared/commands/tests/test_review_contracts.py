"""Documentation safety contracts and schema/rollback fixtures; no production commands."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

COMMANDS = Path(__file__).resolve().parents[1]
RUNBOOKS = COMMANDS.parents[1]


class ReviewContracts(unittest.TestCase):
    def adapter(self, name, records, unit=None):
        command = ['jq', '-c']
        if unit is not None:
            command += ['--arg', 'duration_unit', unit]
        command += ['-f', str(COMMANDS / 'netlify' / (name + '-metrics.jq'))]
        return subprocess.run(command, input=''.join(json.dumps(r) + '\n' for r in records),
                              text=True, capture_output=True)

    def test_traffic_and_function_schemas_do_not_accept_cli_records(self):
        traffic = dict(log_type='traffic', status_code=504, duration=6000,
                       url='https://example.com/page?token=private', request_id='request', timestamp='2001-01-15T08:20:00Z')
        result = self.adapter('traffic', [traffic])
        self.assertEqual(result.returncode, 0, result.stderr)
        row = json.loads(result.stdout)
        self.assertEqual(row['duration_ms'], 6000)
        self.assertNotIn('private', result.stdout)
        self.assertNotEqual(self.adapter('traffic', [{'level': 'info', 'message': 'hello'}]).returncode, 0)
        function = dict(log_type='functions', function_type='regular', status_code=200,
                        duration=6, function_name='server', path='/page', request_id='request', timestamp=traffic['timestamp'])
        self.assertEqual(json.loads(self.adapter('function', [function], 's').stdout)['duration_ms'], 6000)
        self.assertNotEqual(self.adapter('function', [function], 'unknown').returncode, 0)
        self.assertNotEqual(self.adapter('function', [traffic], 'ms').returncode, 0)
        self.assertNotEqual(self.adapter('traffic', [dict(traffic, duration=None)]).returncode, 0)

    def test_multiple_log_rows_per_invocation_are_only_log_records(self):
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / 'netlify'
            records = [dict(invocation_id='one', message=message) for message in ('started', 'application message', 'finished')]
            binary.write_text('#!/bin/sh\ncat <<\'EOF\'\n' + '\n'.join(json.dumps(r) for r in records) + '\nEOF\n')
            binary.chmod(0o755)
            env = {**os.environ, 'PATH': tmp + os.pathsep + os.environ['PATH']}
            env.pop('NETLIFY_LOG_CAP', None)
            result = subprocess.run(['bash', str(COMMANDS / 'netlify/window-counts.sh'), 'server', '5',
                                     '2001-01-15T08:20:00Z'], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('3 log_records', result.stdout)
            self.assertNotIn('invocations', result.stdout)

    def test_all_steps_have_decisions_objectives_and_evidence(self):
        runbooks = [p for p in RUNBOOKS.rglob('*.md') if '\ntype: runbook\n' in p.read_text()]
        self.assertEqual(len(runbooks), 12)
        for path in runbooks:
            text = path.read_text()
            steps = re.search(r'^steps: \[(.*)\]$', text, re.M)[1].replace(' ', '').split(',')
            for step in steps:
                section = re.search(r'^## ' + step + r'\n(.*?)(?=^## |\Z)', text, re.M | re.S)[1]
                with self.subTest(path=path.name, step=step):
                    self.assertIn('**Objective:**', section)
                    self.assertIn('### Decision', section)
                    self.assertIn('**Evidence to record:**', section)

    def test_production_routes_require_approval_and_unknowns_block(self):
        for path in RUNBOOKS.rglob('*.md'):
            text = path.read_text()
            if path.name != '10-mitigation-recovery.md' and '\ntype: runbook\n' in text:
                self.assertNotRegex(text, r'\]\([^)]*10-mitigation-recovery\.md#mit-0[3-6]\)')
        mitigation = (RUNBOOKS / 'response/10-mitigation-recovery.md').read_text()
        self.assertIn('Unknown approval or target: Block; no production commands.', mitigation)
        for step in ('MIT-03', 'MIT-04', 'MIT-06'):
            section = re.search(r'^## ' + step + r'\n(.*?)(?=^## |\Z)', mitigation, re.M | re.S)[1]
            self.assertIn('mandatory state-transition gates above apply independently', section)

    def test_link_validator_catches_dangling_anchor_and_unsafe_route(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'response').mkdir()
            target = root / 'response/10-mitigation-recovery.md'
            target.write_text('---\nid: RB-10\ntitle: mitigation\ntype: runbook\nstatus: active\nupdated: undated\n---\n## MIT-04\n')
            source = root / 'source.md'
            source.write_text('---\nid: RB-TEST\ntitle: source\ntype: runbook\nstatus: active\nupdated: undated\n---\n'
                              '[apply](response/10-mitigation-recovery.md#mit-04)\n[missing](#absent)\n')
            result = subprocess.run(['bash', str(COMMANDS / 'validate-runbook-links.sh'), tmp],
                                    text=True, capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('external mitigation entry bypasses approval', result.stderr)
            self.assertIn('missing anchor', result.stderr)

    def test_mitigation_shell_examples_parse_without_running(self):
        text = (RUNBOOKS / 'response/10-mitigation-recovery.md').read_text()
        for snippet in re.findall(r'```bash\n(.*?)\n```', text, re.S):
            result = subprocess.run(['bash', '-n'], input=snippet, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_rollback_restores_previous_configuration(self):
        text = (RUNBOOKS / 'response/10-mitigation-recovery.md').read_text()
        self.assertIn('scoped-config-rollback.py" restore "$CHANGE_DIR/apache.json"', text)
        self.assertNotIn('rsync -ac --delete', text)
        self.assertIn('exclusive edit', text)
        # Filesystem restoration, xattrs and drift are exercised in test_scoped_rollback.py.

    def test_php_sapi_and_worker_metric_unknowns_are_explicit(self):
        application = (RUNBOOKS / 'diagnostics/04-laravel.md').read_text()
        self.assertIn('do not establish the effective Apache/FPM configuration', application)
        capacity = (RUNBOOKS / 'diagnostics/03-apache-capacity.md').read_text()
        self.assertIn('If worker status is missing, worker utilisation is unknown.', capacity)


if __name__ == '__main__':
    unittest.main()
