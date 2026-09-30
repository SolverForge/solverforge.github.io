#!/usr/bin/env python3
"""Read existing publishable DWH results; never execute benchmark workloads."""
import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
QUERY = """
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '60s';
SET LOCAL jit = off;
SET LOCAL enable_nestloop = off;
WITH selected AS MATERIALIZED (
  SELECT DISTINCT ON (benchmark_name)
    id, benchmark_name, completed_at, run_kind, nightly, result_count,
    git_commit, git_dirty, solvers, time_limits_seconds
  FROM publishable_benchmark_runs r
  WHERE run_kind = 'candidate' AND nightly IS TRUE
    AND EXISTS (SELECT 1 FROM publishable_benchmark_result_facts f WHERE f.run_id = r.id)
    AND NOT EXISTS (SELECT 1 FROM publishable_benchmark_result_facts f
      WHERE f.run_id = r.id AND f.dataset_set IS DISTINCT FROM 'canonical')
  ORDER BY benchmark_name, completed_at DESC, id DESC
)
SELECT json_build_object(
  'source', 'publishable_benchmark_result_facts',
  'selection', 'Latest publishable full canonical nightly candidate run per problem, by completed_at',
  'runs', (SELECT json_agg(selected ORDER BY benchmark_name) FROM selected),
  'results', (SELECT json_agg(row_to_json(public_result) ORDER BY benchmark_name, instance, time_limit_seconds, solver)
    FROM (
      SELECT f.run_id, f.benchmark_name, f.dataset, f.dataset_set, f.instance,
        f.solver, f.solver_version, f.time_limit_seconds, f.hard_feasible,
        f.cost, f.reference_cost, f.quality_ratio, f.actual_time_seconds,
        f.wall_time_over_limit, f.watchdog_killed,
        (NULLIF(f.run_error, '') IS NOT NULL OR NULLIF(f.validation_error, '') IS NOT NULL) AS error
      FROM publishable_benchmark_result_facts f JOIN selected s ON s.id = f.run_id
    ) public_result)
);
COMMIT;
"""
LABELS = {
    'cvrp': ('Capacitated vehicle routing', 'Assign customers to vehicle routes while respecting capacity. Lower route cost is better.'),
    'employee-scheduling': ('Employee scheduling', 'Assign nurses to shifts while respecting hard rules. Among feasible schedules, lower penalty cost is better.'),
    'job-shop-scheduling': ('Job-shop scheduling', 'Sequence jobs on machines while respecting operation order and machine capacity. Lower makespan is better.'),
}


def summarize(snapshot):
    runs = snapshot.get('runs') or []
    results = snapshot.get('results') or []
    if not runs or not results:
        raise ValueError('No publishable warehouse results')
    if len({run['benchmark_name'] for run in runs}) != len(runs):
        raise ValueError('Expected one selected run per problem')
    problems = []
    for run in runs:
        rows = [row for row in results if row['run_id'] == run['id']]
        if run['run_kind'] != 'candidate' or run['nightly'] is not True or any(r['dataset_set'] != 'canonical' for r in rows):
            raise ValueError('Only full canonical nightly candidate runs may be published')
        if len(rows) != run['result_count']:
            raise ValueError(f"Incomplete result snapshot for {run['benchmark_name']}")
        keys = {(r['instance'], r['solver'], r['time_limit_seconds']) for r in rows}
        expected = len({r['instance'] for r in rows}) * len(run['solvers']) * len(run['time_limits_seconds'])
        if len(keys) != len(rows) or len(rows) != expected:
            raise ValueError('Incomplete or duplicated comparison matrix')
        groups = defaultdict(list)
        for row in rows:
            groups[(row['time_limit_seconds'], row['solver'], row['solver_version'])].append(row)
        summaries = []
        for (budget, solver, version), group in sorted(groups.items()):
            feasible = [r for r in group if r['hard_feasible'] is True]
            ratios = [r['quality_ratio'] for r in feasible if r['quality_ratio'] is not None]
            costs = [r['cost'] for r in feasible if r['cost'] is not None]
            times = [r['actual_time_seconds'] for r in group if r['actual_time_seconds'] is not None]
            summaries.append(dict(
                budget=budget, solver=solver, version=version, total=len(group),
                feasible=len(feasible), quality_samples=len(ratios), cost_samples=len(costs),
                gap_percent=100 * (sum(ratios) / len(ratios) - 1) if ratios else None,
                mean_cost=sum(costs) / len(costs) if costs else None,
                mean_seconds=sum(times) / len(times) if times else None,
                errors=sum(r['error'] is True for r in group),
                over_budget=sum(r['wall_time_over_limit'] is True for r in group),
            ))
        name = run['benchmark_name']
        title, description = LABELS.get(name, (name.replace('-', ' ').capitalize(), 'Lower validated cost is better; feasibility comes first.'))
        problems.append(dict(
            **run, title=title, description=description,
            instances=len({r['instance'] for r in rows}),
            datasets=sorted({r['dataset'] for r in rows}),
            dataset_sets=sorted({r['dataset_set'] for r in rows}),
            summaries=summaries,
        ))
    if sum(p['result_count'] for p in problems) != len(results):
        raise ValueError('Unexpected rows outside selected runs')
    return dict(source=snapshot['source'], selection=snapshot['selection'], problems=problems,
                unavailable=[dict(id=name, title=details[0]) for name, details in LABELS.items()
                             if name not in {p['benchmark_name'] for p in problems}])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database-url', default=os.environ.get('BENCH_DATABASE_URL', 'postgresql://postgres@localhost/solverforge_bench'))
    args = parser.parse_args()
    response = subprocess.run(
        ['psql', args.database_url, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'],
        input=QUERY, text=True, capture_output=True, check=True,
    )
    snapshot = json.loads(response.stdout)
    summary = summarize(snapshot)
    for path, data in [(ROOT / 'src/_data/benchmarks.json', summary), (ROOT / 'src/benchmarks/results.json', snapshot)]:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')
    print(f"Imported {len(summary['problems'])} problems, {len(snapshot['results'])} existing results. No benchmarks executed.")


if __name__ == '__main__':
    main()
