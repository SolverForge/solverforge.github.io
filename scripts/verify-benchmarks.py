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


TOLERANCE = 1e-9


def assert_summaries_equivalent(case, recomputed, stored, path=''):
    """Compare two summaries, allowing last-bit float noise but nothing else.

    Returns the count of numeric leaves compared, so a caller can assert the
    comparison actually walked the document instead of two empty structures.
    """
    compared = 0
    if isinstance(recomputed, dict) and isinstance(stored, dict):
        case.assertEqual(sorted(recomputed.keys()), sorted(stored.keys()), f'{path}: key sets differ')
        for key in recomputed:
            compared += assert_summaries_equivalent(case, recomputed[key], stored[key], f'{path}.{key}')
    elif isinstance(recomputed, list) and isinstance(stored, list):
        case.assertEqual(len(recomputed), len(stored), f'{path}: lengths differ')
        for index, (left, right) in enumerate(zip(recomputed, stored)):
            compared += assert_summaries_equivalent(case, left, right, f'{path}[{index}]')
    elif isinstance(recomputed, bool) or isinstance(stored, bool):
        case.assertEqual(recomputed, stored, f'{path}: boolean differs')
        compared += 1
    elif isinstance(recomputed, (int, float)) and isinstance(stored, (int, float)):
        case.assertAlmostEqual(recomputed, stored, delta=TOLERANCE, msg=f'{path}: value differs')
        compared += 1
    else:
        case.assertEqual(recomputed, stored, f'{path}: value differs')
        compared += 1
    return compared


class BenchmarkSnapshotTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.snapshot = json.loads((ROOT / 'src/benchmarks/results.json').read_text())
        cls.summary = json.loads((ROOT / 'src/_data/benchmarks.json').read_text())

    def test_summary_matches_recorded_evidence(self):
        # Recomputed means are compared with a tolerance, not for equality.
        # Floating-point summation is not bit-reproducible across interpreter
        # builds, and this gate runs on whatever python the CI runner happens to
        # ship while the snapshot was generated on another, so an exact compare
        # fails on the interpreter rather than on the evidence. The tolerance is
        # far below any published precision: the page renders two decimals.
        assert_summaries_equivalent(self, importer.summarize(self.snapshot), self.summary)

    def test_each_budget_ranks_feasibility_then_time_then_quality(self):
        for problem in self.summary['problems']:
            for budget in problem['time_limits_seconds']:
                rows = [r for r in problem['summaries'] if r['budget'] == budget]
                expected = [r['solver'] for r in sorted(rows, key=lambda r: (
                    r['total'] - r['feasible'],
                    r['mean_feasible_seconds'] if r['mean_feasible_seconds'] is not None else float('inf'),
                    r['gap_percent'] if r['gap_percent'] is not None else float('inf'),
                    r['solver'],
                ))]
                self.assertEqual(problem['solver_orders'][str(budget)], expected)
                if budget == max(problem['time_limits_seconds']):
                    self.assertEqual(problem['solvers'], expected)

    def test_cvrp_overview_puts_fastest_fully_feasible_solver_first(self):
        problem = next(p for p in self.summary['problems'] if p['benchmark_name'] == 'cvrp')
        self.assertEqual(problem['solvers'][0], 'vroom')
        self.assertEqual(problem['solver_orders']['1'][0], 'ortools')

    def test_versions_are_present(self):
        for row in self.snapshot['results']:
            self.assertTrue(row['solver_version'])
            self.assertGreater(row['time_limit_seconds'], 0)

    def test_only_full_runs(self) -> None:
        for run in self.snapshot['runs']:
            self.assertEqual(run['run_kind'], 'candidate')
            self.assertIs(run['nightly'], True)
            self.assertIs(run['git_dirty'], False)
        self.assertTrue(all(row['dataset_set'] == 'canonical' for row in self.snapshot['results']))

    def test_published_problems_have_hand_written_copy(self) -> None:
        """A problem must arrive with its own introduction, never a generated one."""
        self.assertTrue(self.summary['problems'], 'no publishable problem is on the page')
        for problem in self.summary['problems']:
            self.assertIn(problem['benchmark_name'], importer.LABELS)
            title, description = importer.LABELS[problem['benchmark_name']]
            self.assertEqual(problem['title'], title)
            self.assertEqual(problem['description'], description)

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
        assert_summaries_equivalent(self, importer.summarize(changed), self.summary)

    def test_comparison_walks_the_whole_summary(self):
        """A comparison that silently walks nothing would pass on any evidence."""
        compared = assert_summaries_equivalent(self, importer.summarize(self.snapshot), self.summary)
        self.assertGreater(compared, 100, 'summary comparison saw almost no values')

    def test_numeric_drift_beyond_tolerance_is_rejected(self):
        changed = deepcopy(self.summary)
        changed['problems'][0]['summaries'][0]['gap_percent'] += 1e-4
        with self.assertRaises(AssertionError):
            assert_summaries_equivalent(self, importer.summarize(self.snapshot), changed)

    def test_recorded_drift_is_only_floating_point_noise(self):
        """The stored snapshot must be a recomputation, not a different run."""
        recomputed = importer.summarize(self.snapshot)

        def numeric_leaves(left, right, path=''):
            if isinstance(left, dict):
                for key in left:
                    yield from numeric_leaves(left[key], right[key], f'{path}.{key}')
            elif isinstance(left, list):
                for index, (a, b) in enumerate(zip(left, right)):
                    yield from numeric_leaves(a, b, f'{path}[{index}]')
            elif isinstance(left, (int, float)) and not isinstance(left, bool):
                yield path, left, right

        worst_path, worst_relative = '', 0.0
        for path, left, right in numeric_leaves(recomputed, self.summary):
            relative = abs(left - right) / max(abs(left), 1.0)
            if relative > worst_relative:
                worst_path, worst_relative = path, relative
        # Anything above float summation noise means the evidence was swapped,
        # not recomputed on another interpreter.
        self.assertLess(worst_relative, 1e-12, f'numeric drift at {worst_path} is {worst_relative}')


if __name__ == '__main__':
    unittest.main()
