---
title: "solverforge-bench"
linkTitle: "solverforge-bench"
icon: fa-solid fa-chart-line
weight: 22
description: >
  Reproducible benchmark framework for SolverForge evidence across
  routing and scalar-assignment problems.
---

<h1>solverforge-bench</h1>

<%= render Ui::Callout.new do %>
`solverforge-bench` is a benchmark repository, not a runtime dependency. Use it
when you need reproducible evidence for SolverForge releases, candidate
changes, or runtime tuning.
<% end %>

`solverforge-bench` is the official SolverForge benchmark surface. It groups
benchmarks by SolverForge solve shape and runs them through one shared Python
harness so timing, watchdog handling, result rows, logging, CSV output, and
optional PostgreSQL persistence stay comparable across problem families.

Problem packages are adapters. They load cases, build solver callables,
validate returned solutions, compute benchmark-specific fields, and hand the
result back to the shared framework.

## What It Provides

- **List-variable CVRP benchmarks** under `list-variable/cvrp/`, exercising
  SolverForge route-list solving on vehicle-routing instances
- **Scalar-variable employee scheduling benchmarks** under
  `scalar-variable/employee-scheduling/`, using the bundled INRC-II nurse
  rostering corpus
- **One shared harness** for solver registration, run matrices, wall-clock
  timing, overshoot calculation, watchdog containment, result rows, CSV files,
  run logs, and solver stdout/stderr capture
- **TOML configuration** for benchmark selection, solvers, time limits, run
  kind, logging, watchdog settings, and PostgreSQL persistence
- **PostgreSQL warehouse output** for cron-driven and release-tagged runs,
  backed by checked-in SQL migrations and latest-run views

## Setup

The repository currently targets Python 3.14:

```bash
python3.14 -m venv .venv
. .venv/bin/activate
pip install -e .
```

The root Makefile uses the same `.venv` for CVRP, employee scheduling,
normalization, and nightly runs. Use `make install-python-deps` to create or
refresh it through the repository workflow.

## Benchmark Families

| Family | Path | Scope |
| ------ | ---- | ----- |
| CVRP | `list-variable/cvrp/` | List-variable route planning |
| Employee scheduling | `scalar-variable/employee-scheduling/` | Scalar-variable shift assignment |

CVRP is the canonical list-variable benchmark. Employee scheduling is the
canonical scalar-variable benchmark and uses INRC-II nurse-to-shift assignment
instances.

## Common Commands

Validate adapters and reference data before treating a benchmark run as
evidence:

```bash
make validate-cvrp
make validate-employee-scheduling
make validate-employee-model-parity
```

Run quick smoke benchmarks:

```bash
make bench-cvrp-quick
make bench-cvrp-solverforge-quick
make bench-employee-scheduling-quick
make bench-employee-scheduling-solverforge-quick
```

Run canonical benchmark sets:

```bash
make bench-cvrp
make bench-employee-scheduling
```

The quick CVRP target runs three instances at `1` and `10` seconds. The quick
employee-scheduling target runs `n005w4` at `1` and `10` seconds. The canonical
employee-scheduling target uses the `canonical` group from the bundled INRC-II
manifest and the `1`, `10`, and `60` second budgets.

## Unified Harness

The Make targets call the same root benchmark entrypoint:

```bash
PYTHONPATH=src:list-variable/cvrp/src:scalar-variable/employee-scheduling/src \
  .venv/bin/python3 scripts/run_benchmark.py cvrp \
  --run-kind quick \
  --num-instances 3 \
  --time-limits 1 10

PYTHONPATH=src:list-variable/cvrp/src:scalar-variable/employee-scheduling/src \
  .venv/bin/python3 scripts/run_benchmark.py employee-scheduling \
  --run-kind quick \
  --datasets n005w4 \
  --time-limits 1 10
```

Shared options include:

```text
--config CONFIG
--solver SOLVER
--time-limits SECONDS...
--run-kind quick|candidate|tag
--nightly | --no-nightly
--release-tag TAG
--save-postgres | --no-save-postgres
--postgres-url URL
--log-level LEVEL
--show-solver-output | --no-show-solver-output
--capture-solver-output | --no-capture-solver-output
```

`cvrp` adds `--num-instances`. `employee-scheduling` adds `--dataset-set` and
`--datasets`.

## Timing Contract

The requested time limit is passed to the solver and measured with wall-clock
timing around the solver call. The watchdog is separate: it exists to contain
runaway invocations, not to discard every solution that returns slightly after
the nominal budget.

The harness records:

```text
overshoot_seconds = max(0, actual_time_seconds - time_limit_seconds)
overshoot_ratio = overshoot_seconds / time_limit_seconds
wall_time_over_limit = actual_time_seconds > time_limit_seconds * 1.1
```

Only watchdog-killed invocations lose the returned solution, because the child
process was forcibly terminated.

## TOML Configuration

Use a TOML file when a run needs to be repeatable outside a Make target:

```toml
benchmark = "cvrp"
solver = ["solverforge"]
time_limits = [1]
run_kind = "quick"
nightly = false

[postgres]
save = false
url = "postgresql://postgres@localhost/solverforge_bench"

[logging]
level = "INFO"
show_solver_output = true
capture_solver_output = true

[benchmarks.cvrp]
num_instances = 3

[benchmarks.employee-scheduling]
dataset_set = "quick"
datasets = ["n005w4"]
```

Command-line options override TOML values. Make targets accept the same file
through `BENCH_CONFIG`:

```bash
make bench-cvrp-quick BENCH_CONFIG=benchmark.example.toml
```

Use `benchmark.nightly.example.toml` as the cron-oriented template for the
combined nightly job.

## PostgreSQL Results

Normal benchmark targets write CSV evidence artifacts. The `-db` targets apply
migrations and save the same run to PostgreSQL:

```bash
make db-check
make db-create
make db-migrate

make bench-cvrp-quick-db
make bench-employee-scheduling-quick-db
make bench-nightly-db
```

`make bench-nightly-db` is the cron entrypoint. It builds both benchmark stacks,
applies migrations once, then runs full CVRP and canonical employee scheduling
as one PostgreSQL-saving nightly job.

PostgreSQL stores run catalog data, solver versions, and per-result rows.
Display consumers should read `benchmark_result_facts`,
`latest_benchmark_runs`, or `latest_benchmark_result_facts` instead of
reconstructing the run/result join.

## Result Columns

Generated CSV rows use one global snake_case schema. Core columns include:

```text
run_id, benchmark_name, benchmark_category, dataset, dataset_set, instance,
instance_size, solver, solver_version, time_limit_seconds,
actual_time_seconds, overshoot_seconds, overshoot_ratio,
wall_time_over_limit, watchdog_limit_seconds, watchdog_killed, run_error,
solver_stdout_path, solver_stderr_path, hard_feasible, cost, reported_cost,
fresh_cost, reference_cost, quality_ratio, validation_error,
solution_artifact
```

Benchmark-specific fields such as `nurses`, `weeks`,
`validator_model_delta`, and `score_drift` are preserved as optional native
columns.

## External References

- [GitHub repository](https://github.com/SolverForge/solverforge-bench)
- [Benchmark methodology](/blog/technical/2026/05/14/how-we-benchmark-solverforge/)
