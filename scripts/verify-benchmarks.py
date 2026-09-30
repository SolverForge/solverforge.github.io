#!/usr/bin/env python3
"""Verify the checked-in DWH snapshot without querying or running benchmarks."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('benchmark_import', ROOT / 'scripts/import-benchmarks.py')
assert spec is not None and spec.loader is not None
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class BenchmarkSnapshotTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.snapshot = json.loads((ROOT / 'src/benchmarks/results.json').read_text())
        cls.summary = json.loads((ROOT / 'src/_data/benchmarks.json').read_text())

    def test_summary_matches_recorded_evidence(self):
        self.assertEqual(importer.summarize(self.snapshot), self.summary)

    def test_versions_are_present(self):
        for row in self.snapshot['results']:
            self.assertTrue(row['solver_version'])
            self.assertGreater(row['time_limit_seconds'], 0)

    def test_only_full_runs(self):
        for run in self.snapshot['runs']:
            self.assertEqual(run['run_kind'], 'candidate')
            self.assertIs(run['nightly'], True)
            self.assertIs(run['git_dirty'], False)
        self.assertTrue(all(row['dataset_set'] == 'canonical' for row in self.snapshot['results']))
        self.assertIn('employee-scheduling', [p['id'] for p in self.summary['unavailable']])

    def test_partial_snapshot_rejected(self):
        broken = deepcopy(self.snapshot)
        broken['results'].pop()
        with self.assertRaises(ValueError):
            importer.summarize(broken)

    def test_quick_run_rejected(self):
        broken = deepcopy(self.snapshot)
        broken['runs'][0]['run_kind'] = 'quick'
        with self.assertRaises(ValueError):
            importer.summarize(broken)

    def test_custom_dataset_rejected(self):
        broken = deepcopy(self.snapshot)
        broken['results'][0]['dataset_set'] = 'custom'
        with self.assertRaises(ValueError):
            importer.summarize(broken)

    def test_duplicate_result_rejected(self):
        broken = deepcopy(self.snapshot)
        broken['results'][1] = deepcopy(broken['results'][0])
        with self.assertRaises(ValueError):
            importer.summarize(broken)

    def test_infeasible_quality_not_averaged(self):
        changed = deepcopy(self.snapshot)
        row = next(r for r in changed['results'] if r['hard_feasible'] is False)
        row['quality_ratio'] = 999999
        self.assertEqual(importer.summarize(changed), self.summary)


if __name__ == '__main__':
    unittest.main()
