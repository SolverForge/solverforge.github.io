---
title: "Python Solving & Runtime"
description: >
  Run synchronous solves, score analysis, solver.toml config, retained jobs,
  snapshots, and dynamic move selectors from SolverForge Python.
---

# Python Solving & Runtime

SolverForge Python has two runtime entry points:

- `Solver` for synchronous solve and score-analysis calls
- `SolverManager` for retained jobs, lifecycle events, snapshots, pause,
  resume, cancel, and delete

Both paths run the native SolverForge engine.

## Synchronous Solve

```python
solved = Solver.solve(schedule)
```

`Solver.solve(...)` reads the Python model, runs the solver, then returns a
solution object with updated planning variables and score.

Pass config explicitly when the solve needs a seed, termination budget, or
custom phase list:

```python
solved = Solver.solve(
    schedule,
    config={
        "random_seed": 7,
        "termination": {"seconds_spent_limit": 5},
    },
)
```

## Score Analysis

```python
analyzed = Solver.analyze(schedule)
print(analyzed.score)
```

`Solver.analyze(...)` evaluates callback constraints for the current solution
state and writes the calculated score back to the Python solution.

## Config Loading

Config can be:

- `None`
- a `SolverConfig`
- a `dict[str, object]`
- a `solver.toml` file in the current directory when the argument is `None`

Supported termination fields are:

- `seconds_spent_limit`
- `minutes_spent_limit`
- `best_score_limit`
- `step_count_limit`
- `unimproved_step_count_limit`
- `unimproved_seconds_spent_limit`

Termination fields can be set at the top level or under `termination`, but not
with conflicting values in both places.

```toml
random_seed = 7

[termination]
seconds_spent_limit = 5

[[phases]]
phase_type = "construction_heuristic"

[[phases]]
phase_type = "local_search"
move_selector = { type = "change_move_selector" }
```

## Retained Jobs

Use `SolverManager` when the application needs lifecycle state, progress,
snapshots, or cancellation.

```python
from solverforge import SolverManager

manager = SolverManager(config={"termination": {"seconds_spent_limit": 10}})
handle = manager.solve(schedule)

status = manager.wait(handle.job_id, timeout_seconds=15)
snapshot = manager.snapshot(handle.job_id)

print(status["lifecycle_state"])
print(snapshot.score)
```

The manager exposes:

| Method | Purpose |
| ------ | ------- |
| `solve(solution)` | start a retained job and return a `JobHandle` |
| `get_status(job_id)` | read lifecycle state and current job metadata |
| `events(job_id)` | drain retained lifecycle events |
| `wait(job_id, timeout_seconds=...)` | block until completed, cancelled, or failed |
| `snapshot(job_id, snapshot_revision=None)` | export a deep-copied Python solution snapshot |
| `pause(job_id)` | request pause |
| `resume(job_id)` | resume a paused job |
| `cancel(job_id)` | request cancellation |
| `delete(job_id)` | remove retained job state |

Treat snapshots as point-in-time Python objects.

## Dynamic Move Support

Construction phases available to Python dynamic models include scalar
first-fit and cheapest insertion, assignment-group first-fit and cheapest
insertion, list cheapest insertion, list regret insertion, list Clarke-Wright,
and list k-opt construction polish when the model supplies the hooks that the
phase needs.

Scalar selectors available to Python dynamic models:

- `change_move_selector`
- `swap_move_selector`
- `nearby_change_move_selector`
- `nearby_swap_move_selector`
- `pillar_change_move_selector`
- `pillar_swap_move_selector`
- `ruin_recreate_move_selector`
- `grouped_scalar_move_selector`
- `conflict_repair_move_selector`
- `compound_conflict_repair_move_selector`

List selectors available to Python dynamic models:

- `list_change_move_selector`
- `nearby_list_change_move_selector`
- `list_swap_move_selector`
- `nearby_list_swap_move_selector`
- `sublist_change_move_selector`
- `sublist_swap_move_selector`
- `list_reverse_move_selector`
- `list_permute_move_selector`
- `list_precedence_move_selector`
- `k_opt_move_selector`
- `list_ruin_move_selector`

Selector combinators available to Python dynamic models:

- `limited_neighborhood`
- `union_move_selector`
- two-child `cartesian_product_move_selector`

Grouped scalar and conflict-repair selectors require Python callbacks declared
on the solution with `@scalar_group(...)` and `@conflict_repair(...)`.
Assignment-aware grouped scalar construction and grouped local search consume
`scalar_assignment_group(...)` metadata from the solution.

## Embedded UI Assets

The wheel embeds shared `solverforge-ui` assets through the native bridge.
Python HTTP hosts can serve those files without copying the UI bundle into each
example:

```python
from solverforge import ui

asset = ui.asset("sf.js")
for path in ui.asset_paths():
    print(path)
```

The hospital and deliveries examples use this bridge for `/sf/*` assets and
keep only app-specific browser modules under their own `static/` directories.

## Callback Threading

Python callbacks must be deterministic for the same solution state. The native
extension may invoke callbacks repeatedly during scoring and search. On
free-threaded CPython 3.14, callback code and third-party extension modules used
inside callbacks need to be safe for the concurrency they participate in.

Callback exceptions surface as SolverForge Python exceptions with Python
traceback context.
