---
title: "Python Solving & Runtime"
description: >
  Run synchronous solves, score analysis, compiled solver.toml config, retained
  jobs, candidate diagnostics, snapshots, and dynamic move selectors.
---

# Python Solving & Runtime

SolverForge Python has two runtime entry points:

- `Solver` for synchronous solve and score-analysis calls
- `SolverManager` for retained jobs, lifecycle events, snapshots, pause,
  resume, cancel, and delete

Both paths compile the authored Python schema into one immutable SolverForge
0.19.0 runtime graph. The binding supplies dynamic state, callbacks, slot
capabilities, assignment groups, providers, and candidate metrics; the core owns
phase construction, cursor execution, foraging, lifecycle control, and
telemetry. There is no wrapper-owned fallback runner.

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
| `telemetry_detail(job_id)` | atomically read detailed telemetry and an optional candidate trace |
| `events(job_id)` | drain retained lifecycle events |
| `wait(job_id, timeout_seconds=...)` | block until completed, cancelled, or failed |
| `snapshot(job_id, snapshot_revision=None)` | export a deep-copied Python solution snapshot |
| `pause(job_id)` | request pause |
| `resume(job_id)` | resume a paused job |
| `cancel(job_id)` | request cancellation |
| `delete(job_id)` | remove retained job state |

Treat snapshots as point-in-time Python objects. Status telemetry includes the
active phase type, phase index, phase-local counters, and generation/evaluation
time when a phase is active.

## Candidate Tracing

Candidate tracing is opt-in, bounded, and available only for retained manager
jobs:

```python
manager = SolverManager(
    {
        "termination": {"seconds_spent_limit": 10},
        "candidate_trace": {"max_entries": 256},
    }
)
handle = manager.solve(schedule)
manager.wait(handle.job_id, timeout_seconds=15)

detail = manager.telemetry_detail(handle.job_id)
trace = detail["candidate_trace"]
```

`max_entries` must be greater than zero. The format-3 trace reports canonical
configured input, execution policy, resolved phase-plan provenance, candidate
identities and dispositions, prefix digests, explicit completeness state, and
truncation. The total pull count continues after the bounded identity prefix is
full.

Ordinary `get_status(...)`, `events(...)`, and `snapshot(...)` payloads do not
clone the trace. `Solver.solve(...)` rejects `candidate_trace` because the
synchronous API has no retained detail channel.

Use `QualifiedCandidateTraceProvenance` when an external harness has already
attested the schema, instance, initial state, core tree, and loaded build:

```python
from solverforge import QualifiedCandidateTraceProvenance

provenance = QualifiedCandidateTraceProvenance(
    schema_sha256="01" * 32,
    instance_sha256="02" * 32,
    initial_state_sha256="03" * 32,
    core_tree_sha256="04" * 32,
    build_sha256="05" * 32,
    producer="solverforge-bench",
)

handle = manager.solve(
    schedule,
    qualified_candidate_trace_provenance=provenance,
)
```

The digests are keyword-only lowercase SHA-256 strings and `producer` must be
non-blank. Qualified provenance is accepted per job only when the manager has
candidate tracing enabled. It is never inferred from a solution or accepted as
ordinary serializable solver config.

## Dynamic Move Support

Construction phases available to Python dynamic models include ordinary scalar
first-fit and cheapest insertion. Assignment groups additionally support
first-fit decreasing, weakest-fit, weakest-fit decreasing, strongest-fit, and
strongest-fit decreasing; decreasing variants require entity order and
weakest/strongest variants require value order. Dynamic list construction
supports list round robin, cheapest insertion, regret insertion,
Clarke-Wright, and k-opt polish when the model supplies the metadata bundle each
phase requires.

An explicit assignment `group_name` obeys its configured obligation and
termination. Required-only completion belongs to upstream omitted defaults.
Default local search is assembled only when the top-level termination has an
effective finite limit, so an empty or invalid termination cannot create an
unbounded solve.

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

Assignment-owned variables are excluded from raw scalar, nearby, ruin, and
conflict-repair selectors. Their declared group is the only construction and
local-search ownership path. Multiple declarative assignment groups can still
compose through selector combinators.

Dynamic neighborhoods are resumable cursor trees. Union children, limits,
Cartesian branches, pillar windows, and k-opt reconnections advance only when
the solver requests another candidate. Nearby Python callbacks may return any
iterable; the binding consumes it once into an exact bounded top-k. Losing
candidates are released when the forager no longer needs them, and only the
winner crosses the ownership boundary.

## Candidate Ordering

Leaf selectors can use `original`, seeded `random`, `shuffled`, `sorted`, or
`probabilistic` order. Sorted and probabilistic leaves name a candidate metric
registered through `@candidate_metric` and
`@planning_solution(candidate_metrics=[...])`:

```toml
[[phases]]
type = "local_search"

[phases.move_selector]
type = "change_move_selector"
entity_class = "Shift"
variable_name = "employee_idx"
selection_order = "sorted"
selection_metric = "dispatch_cost"
```

Sorted metrics are ascending. Metric results must be finite; probabilistic
weights must also be non-negative, and zero-weight candidates are omitted.

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

The native working solution stores scalar, list, and candidate values by
compiled descriptor index and shares immutable metadata across clones. Callback
views project entity and fact collections from that Rust-owned state, so working,
preview, and best-solution clones do not share mutable Python row objects. After
the first full callback-view sync, only changed rows are synchronized.

Callback exceptions surface as SolverForge Python exceptions with Python
traceback context.
