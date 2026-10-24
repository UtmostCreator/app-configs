"""Offline origin-reconciliation regressions; these do not qualify a live deployment."""
import copy
import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

COMMANDS = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('single_flight_origin', COMMANDS / 'verify-single-flight.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class IndependentOriginLedger(unittest.TestCase):
    def setUp(self):
        base = {'run_id': 'run', 'key_hash': 'key'}
        def event(kind, second, **fields):
            return {**base, 'event': kind, 'utc': f'2001-01-15T10:00:{second:02d}Z', **fields}
        self.events = [event('cache_miss', 0, request_id=str(i), instance_id=str(i % 2))
                       for i in range(100)]
        self.events += [event('upstream_start', 1, fetch_id='fetch'),
                        event('upstream_finish', 3, fetch_id='fetch', ok=True, value_hash='value'),
                        event('cache_write', 4, value_hash='value')]
        self.events += [event('client_result', 5, request_id=str(i), ok=True, value_hash='value')
                        for i in range(100)]
        self.origin = [dict(event('origin_attempt', 1, fetch_id='fetch', ok=True, value_hash='value',
                                  finished_utc='2001-01-15T10:00:03Z'), source='mock-origin'),
                       dict(event('origin_ledger_complete', 6, complete=True, attempt_count=1),
                            source='mock-origin')]

    def verify(self, events=None, origin=None):
        return verifier.verify(self.events if events is None else events, 'run', 'key', 100,
                               self.origin if origin is None else origin)

    def test_100_callers_two_instances_and_independent_origin_pass(self):
        self.assertIn('100 cold callers across 2 instances', self.verify())

    def test_application_only_evidence_is_unresolved(self):
        with self.assertRaisesRegex(ValueError, 'independent complete'):
            verifier.verify(self.events, 'run', 'key', 100)

    def test_unknown_application_retry_cannot_silently_pass(self):
        retry = {**self.events[0], 'event': 'upstream_retry', 'fetch_id': 'retry'}
        with self.assertRaisesRegex(ValueError, 'unknown application'):
            self.verify(events=self.events + [retry])

    def test_extra_independent_attempt_cannot_pass(self):
        origin = copy.deepcopy(self.origin)
        origin.insert(0, {**origin[0], 'fetch_id': 'retry'})
        origin[-1]['attempt_count'] = 2
        with self.assertRaisesRegex(ValueError, 'one independently'):
            self.verify(origin=origin)

    def test_unknown_origin_event_cannot_pass(self):
        with self.assertRaisesRegex(ValueError, 'unknown origin'):
            self.verify(origin=self.origin + [{**self.origin[0], 'event': 'origin_retry'}])

    def test_partial_mismatched_and_premature_ledgers_are_unresolved(self):
        mutations = [('count', lambda rows: rows[-1].update(attempt_count=2)),
                     ('incomplete', lambda rows: rows[-1].update(complete=False)),
                     ('fetch', lambda rows: rows[0].update(fetch_id='different')),
                     ('value', lambda rows: rows[0].update(value_hash='different')),
                     ('source', lambda rows: rows[0].update(source='application')),
                     ('early_close', lambda rows: rows[-1].update(utc='2001-01-15T10:00:04Z')),
                     ('unclosed', lambda rows: rows.pop()),
                     ('unfinished', lambda rows: rows[0].update(finished_utc=None))]
        for name, mutate in mutations:
            with self.subTest(name=name):
                rows = copy.deepcopy(self.origin)
                mutate(rows)
                with self.assertRaises(ValueError):
                    self.verify(origin=rows)

    def test_export_limits_fail_instead_of_truncating(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'events.jsonl'
            path.write_text('{}\n{}\n')
            with patch.object(verifier, 'MAX_EXPORT_BYTES', 5):
                with self.assertRaisesRegex(ValueError, 'exceeds 16 MiB'):
                    verifier.read_export(path)
            with patch.object(verifier, 'MAX_EXPORT_RECORDS', 1):
                with self.assertRaisesRegex(ValueError, '100000-record'):
                    verifier.read_export(path)

    def test_cache_selection_and_window_are_explicit(self):
        text = (COMMANDS.parents[1] / 'response/11-validation-review.md').read_text()
        section = text.split('## VAL-02\n')[1].split('## VAL-03\n')[0]
        self.assertIn('**not-applicable**', section)
        self.assertIn('Uncertain relevance is unresolved, never not-applicable', section)
        self.assertIn('Cache cases documented not-applicable with rationale', section)
        self.assertNotIn('2001-01-15T', text)


if __name__ == '__main__':
    unittest.main()
