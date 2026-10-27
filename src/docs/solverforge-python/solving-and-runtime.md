---
title: "Python Solving & Runtime"
description: >
  Run synchronous solves, score analysis, compiled solver.toml config, retained
  jobs, parallel move evaluation, per-phase telemetry, candidate diagnostics,
  snapshots, and dynamic move selectors.
---

# Python Solving & Runtime

SolverForge Python has two runtime entry points:

- `Solver` for synchronous solve and score-analysis calls
- `SolverManager` for retained jobs, lifecycle events, snapshots, pause,
  resume, cancel, and delete

Both paths compile the authored Python schema into one immutable SolverForge
0.23.0 runtime graph. The binding supplies dynamic state, callbacks, slot
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
score = Solver.analyze(schedule)
print(score)
```

`Solver.analyze(...)` returns the calculated score and writes it to
`schedule.score`. It evaluates the named constraints for the current solution
state. Eligible
rules, including list precedence/makespan, use their native evaluators; rules
that need Python callbacks keep that path. Analysis does not run search or
change the planning assignments. See
[Compiled Evaluation Boundary](/docs/solverforge-python/constraints/#compiled-evaluation-boundary).

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
type = "construction_heuristic"

[[phases]]
type = "local_search"
move_selector = { type = "change_move_selector" }
```

## Parallel Move Evaluation

Acceptor-forager local search, including default local search, can evaluate
candidate moves concurrently within one solve. Candidate generation and
acceptance decisions remain ordered on one coordinator; workers score trials
on separate working-state replicas. Each evaluator constructs its own constraint
set from the same compiled schema and callbacks.

| `move_thread_count` | Behavior |
| --- | --- |
| `"auto"` | default; currently sequential |
| `"none"` | disable parallel move evaluation |
| `{"count": 4}` | request four evaluators, including the main director |

The effective count is bounded by the solve's Rayon thread count and the
32-candidate evaluation-window ceiling. Counts of zero or one stay sequential.
Construction and variable neighborhood descent remain sequential. The binding
passes this config to the core; it does not create a Python thread pool.

With the `Schedule` class from [Getting Started](/docs/solverforge-python/getting-started/#a-minimal-model),
run a fixed-step solve as follows:

```python
from solverforge import Solver, SolverConfig

config = SolverConfig.from_dict({
    "random_seed": 7,
    "move_thread_count": {"count": 4},
    "phases": [
        {"type": "construction_heuristic"},
        {"type": "local_search", "termination": {"step_count_limit": 60}},
    ],
})
solved = Solver.solve(Schedule([Shift() for _ in range(30)], [0, 1, 2]), config)
assert solved.score["family"] == "hard_soft"
assert solved.score["levels"][0] == 0
assert all(shift.nurse in (0, 1, 2) for shift in solved.shifts)
```

`move_thread_count` is not a direct `SolverConfig(...)` constructor keyword.
Use `from_dict`, `from_toml`, or `extra={"move_thread_count": {"count": 4}}`.
The equivalent TOML, loadable with `SolverConfig.from_toml(text)` or from
`solver.toml`, is:

```toml
random_seed = 7
move_thread_count = { count = 4 }

[[phases]]
type = "construction_heuristic"

[[phases]]
type = "local_search"
termination = { step_count_limit = 60 }
```

### Reproducibility Limits

Use the same seed, input, configuration, and fixed work budget when comparing
runs. Deterministic stateless neighborhoods can preserve assignments and score
across evaluator counts. This is not a universal cross-count guarantee:
stateful ruin/recreate selectors and custom candidate providers can advance
differently when a parallel window pulls candidates ahead of the decision
point. For those paths, parity is only at a fixed evaluator count. Keep that
count unchanged when reproducing a result. Time limits can stop at different
points regardless of the seed or environment mode.

`Solver.solve(...)` releases the GIL for the native solve so evaluator workers
can attach to Python. A GIL-enabled CPython build still serializes Python
callbacks; use free-threaded CPython 3.14 for concurrent callback execution.
Parallel execution is not a promise of faster solves: replica upkeep, callback
cost, and discarded speculative work affect throughput.

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

Treat snapshots as point-in-time Python objects. Status and event telemetry
contain run totals and a `phases` list, with one record per phase started so
far in execution order. Before a phase starts the list can be empty. Each entry
includes `phase_index`, `phase_type`, `elapsed_ms`, step/move/score counters,
`moves_speculative`, `generation_ms`, and `evaluation_ms`. In a progress event,
the last entry is the running phase; after termination it is the last phase
that started, not an assertion that the job is still running.

Read per-phase state from `phases`, not a singular `phase` dictionary:

```python
telemetry = status["telemetry"]
phases = telemetry["phases"]
last_phase = phases[-1] if phases else None
for phase in phases:
    print(phase["phase_index"], phase["phase_type"], phase["moves_speculative"])
print("discarded look-ahead trials:", telemetry["moves_speculative"])
```

`moves_evaluated` counts trials consumed by the decision loop.
`moves_speculative` separately counts evaluated look-ahead trials discarded
after an early decision or interruption; it is not accepted or applied work.
Both run totals and phase records expose it. Sequential phases report zero.

Construction and local search publish the same engine-owned phase lifecycle and
progress telemetry. The first observed construction work is reported promptly,
and long-running phases continue at roughly one-second intervals when verbose
logging is enabled. The Python layer does not synthesize construction counters.

## Mandatory Completion And Limits

Configured solver and phase limits remain binding during construction. A best
or completed solution is published only after every planning-list element,
required assignment row, and non-optional scalar variable is assigned.

If a limit is reached first, `Solver.solve(...)` raises a runtime error. A
retained job enters `FAILED` without a latest snapshot revision, and
`snapshot(...)` remains unavailable instead of returning an incomplete plan. A
pause requested before mandatory construction completes preserves resumable
internal state, but it does not expose a partial snapshot.

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

Discarded look-ahead window suffixes carry the `discarded_speculative`
disposition. An interrupted decision-point candidate can instead carry
`interrupted_before_evaluation` even if its speculative trial already ran.
Do not classify this work as acceptor rejections or applied moves.
Pull counts and trace prefixes can differ across evaluator
counts even when the final plan agrees. Compare global `ordinal` plus
`identity`; `candidate_index_scope` is `source_local_only`, so a leaf-local
`candidate_index` is not a cross-runtime identity.

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
termination. Omitted construction resolves required and optional stages in the
core, but mandatory work never bypasses a configured limit. Default local
search is assembled only when the top-level termination has an effective finite
limit, so an empty or invalid termination cannot create an unbounded solve.

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

Every scalar selector also respects the entity row's imported
`candidate_values` set as a hard domain. Change, swap, grouped-scalar, and
construction moves cannot assign a solution-level value that the row candidate
source excluded.

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
extension may invoke callbacks repeatedly during scoring and search, including
from Rayon evaluator workers. Filters, join keys, grouped collectors, weights,
and metadata callbacks must not depend on invocation order or mutate shared
Python state. Keep solution-level lookup context immutable throughout a solve.
On free-threaded CPython 3.14, callback code and third-party extension modules
used inside callbacks need to be safe for concurrent execution. Releasing the
GIL in the calling thread does not make an unsafe callback safe.

The native working solution stores scalar, list, and candidate values by
compiled descriptor index and shares immutable metadata across clones. Callback
views project entity and fact collections from that Rust-owned state, so working,
preview, and best-solution clones do not share mutable Python row objects. After
the first full callback-view sync, only changed rows are synchronized.

Synchronous solve and analysis re-raise the original Python callback exception
with its traceback, including failures originating in parallel evaluation.
Retained jobs enter `FAILED` and expose the formatted Python callback traceback
in the failed event's `error` field.
