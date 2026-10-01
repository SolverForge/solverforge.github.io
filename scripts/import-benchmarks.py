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
    ) public_result),
  'references', (SELECT json_agg(row_to_json(reference_catalog) ORDER BY benchmark_name, instance)
    FROM (
      SELECT c.benchmark_name, c.dataset, c.instance, c.reference_cost, c.reference_kind,
             c.source_name, c.source_revision
      FROM benchmark_reference_catalog c
      WHERE c.benchmark_name IN (SELECT benchmark_name FROM selected)
    ) reference_catalog)
);
COMMIT;
"""
LABELS = {
    'cvrp': ('Capacitated vehicle routing', 'Assign customers to vehicle routes while respecting capacity. Lower route cost is better.'),
    'employee-scheduling': ('Employee scheduling', 'Assign nurses to shifts while respecting hard rules. Among feasible schedules, lower penalty cost is better.'),
    'job-shop-scheduling': ('Job-shop scheduling', 'Sequence jobs on machines while respecting operation order and machine capacity. Lower makespan is better.'),
}


def rank_solvers(summaries, solver_order, budget=None):
    """Rank one budget by feasibility, measured time, then reference gap.

    The overview uses the longest budget, matching the first visible table.
    Shorter budgets have their own ranking rather than inheriting an aggregate.
    """
    if budget is None:
        budget = max(row['budget'] for row in summaries)
    rows = {row['solver']: row for row in summaries if row['budget'] == budget}

    def key(solver):
        row = rows[solver]
        return (
            row['total'] - row['feasible'],
            row['mean_feasible_seconds'] if row['mean_feasible_seconds'] is not None else float('inf'),
            row['gap_percent'] if row['gap_percent'] is not None else float('inf'),
            solver,
        )

    return sorted(solver_order, key=key)


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
            # Time to a viable solution is the harness's measured wall-clock time
            # over the invocations that returned one. Averaging every invocation
            # would fold in failures that ran to the watchdog, which measures
            # time discipline rather than how quickly a usable answer arrives.
            feasible_times = [r['actual_time_seconds'] for r in feasible
                              if r['actual_time_seconds'] is not None]
            summaries.append(dict(
                budget=budget, solver=solver, version=version, total=len(group),
                feasible=len(feasible), quality_samples=len(ratios), cost_samples=len(costs),
                feasible_time_samples=len(feasible_times),
                gap_percent=100 * (sum(ratios) / len(ratios) - 1) if ratios else None,
                mean_cost=sum(costs) / len(costs) if costs else None,
                mean_seconds=sum(times) / len(times) if times else None,
                mean_feasible_seconds=(sum(feasible_times) / len(feasible_times)
                                       if feasible_times else None),
                errors=sum(r['error'] is True for r in group),
                over_budget=sum(r['wall_time_over_limit'] is True for r in group),
            ))
        name = run['benchmark_name']
        title, description = LABELS.get(name, (name.replace('-', ' ').capitalize(), 'Lower validated cost is better; feasibility comes first.'))
        # Rank the solvers by the priorities the page states, and carry that rank
        # into every rendering of this problem: most instances solved, then
        # fastest to a viable solution, then best quality. Ranking only the
        # columns would present the priorities as a layout while the rows still
        # read in whatever order the run recorded them.
        solvers_ranked = rank_solvers(summaries, solver_order=run['solvers'])
        # Reference provenance travels with the problem: which instances have an
        # official value, how strong those values are, and where they came from.
        # A problem with no reference states that rather than showing a gap that
        # would be measured against nothing.
        problem_references = [r for r in (snapshot.get('references') or [])
                              if r['benchmark_name'] == name]
        kinds = sorted({r['reference_kind'] for r in problem_references})
        sources = sorted({(r['source_name'], r['source_revision']) for r in problem_references})
        # Coverage is stated about the instances this run actually graded, so a
        # problem whose catalog covers instances the run does not select says so
        # instead of implying the gap was measured against a missing value.
        run_instances = {r['instance'] for r in rows}
        covered_run_instances = {r['instance'] for r in problem_references} & run_instances
        problems.append(dict(
            **{k: v for k, v in run.items() if k != 'solvers'},
            title=title, description=description,
            instances=len(run_instances),
            datasets=sorted({r['dataset'] for r in rows}),
            dataset_sets=sorted({r['dataset_set'] for r in rows}),
            summaries=summaries,
            solvers=solvers_ranked,
            solver_orders={str(budget): rank_solvers(summaries, run['solvers'], budget)
                           for budget in run['time_limits_seconds']},
            reference_present=bool(problem_references),
            reference_instances=len({r['instance'] for r in problem_references}),
            reference_covered_run_instances=len(covered_run_instances),
            reference_covers_run=bool(run_instances) and covered_run_instances == run_instances,
            reference_kinds=kinds,
            reference_sources=[dict(name=s[0], revision=s[1]) for s in sources],
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
