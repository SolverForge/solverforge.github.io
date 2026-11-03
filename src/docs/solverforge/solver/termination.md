---
title: "Termination"
linkTitle: "Termination"
weight: 40
description: >
  Control when the solver stops — time limits, step counts, score targets, and composites.
---

Termination conditions tell the solver when to stop searching. You can set termination globally or per-phase.

## Omitted Phases Require an Effective Limit

With `phases` omitted, state-aware construction runs first. Default local
search is eligible only if top-level termination contains a time, work,
unimproved, or score limit. Missing termination or an empty `[termination]`
table does not enable it: those solves are construction-only. An explicit
local-search phase and its omitted selector defaults are a separate
configuration choice. A score target enables the default phase, but does not
guarantee that the target can be reached.

## Termination Types

### Time-Based

```toml
[termination]
seconds_spent_limit = 300           # Stop after 5 minutes
```

`minutes_spent_limit` sets the same budget in minutes. The two keys add up:
`minutes_spent_limit = 1` with `seconds_spent_limit = 30` is a 90-second limit.

### Step-Based

```toml
[termination]
step_count_limit = 100000           # Stop after 100k steps
```

### Unimproved Time/Steps

Stop when no improvement has been found for a number of steps:

```toml
[termination]
unimproved_step_count_limit = 10000        # No improvement for 10k steps
```

or for a duration:

```toml
[termination]
unimproved_seconds_spent_limit = 60        # No improvement for 60s
```

### Fallback Time Guard

A step, unimproved, or score criterion without `seconds_spent_limit` or
`minutes_spent_limit` still runs under a time guard: 30 seconds for a model
with only scalar variables, 60 seconds for a model with a list variable.
`step_count_limit = 100000` alone therefore stops after 100000 steps or 30
seconds on a scalar model, whichever comes first. Set a time limit to choose
the guard yourself.

### Score-Based

Stop when a target score is reached:

```toml
[termination]
best_score_limit = "0hard/-100soft"    # Stop when feasible with soft ≥ -100
```

## Composite Termination

The configured parser combines a time limit with one selected score/work
criterion. It chooses the first criterion present in this order:
`best_score_limit`, `step_count_limit`, `unimproved_step_count_limit`, then
`unimproved_seconds_spent_limit`. It does not OR every populated field
together. The time guard and selected criterion stop the solver when **either**
is met:

```toml
[termination]
seconds_spent_limit = 300
best_score_limit = "0hard/0soft"
# Stops after 5 minutes OR when a perfect score is found
```

A `best_score_limit` must parse as the model's score type. One that does not
fails the job before any phase runs, naming the key:

<!-- sf-toml: expect="solve-error" message="termination.best_score_limit" -->
```toml
[termination]
seconds_spent_limit = 300
best_score_limit = "0hard/-5sotf"
```

## Per-Phase Termination

Each phase can have its own termination:

```toml
[[phases]]
type = "construction_heuristic"
# Runs until construction decisions finish; optional values may stay unassigned

[[phases]]
type = "local_search"
[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[phases.termination]
unimproved_step_count_limit = 10000
```

An explicit phase's termination counters start at that top-level phase boundary
and are removed before the next phase begins. Score and unimproved limits observe
committed step scores at the same boundary. Mandatory omitted construction does
not install a phase-local overlay, so required completion remains governed by
the retained lifecycle rather than an accidental internal cutoff.

## Parallel Evaluation Budgets

In compiled acceptor-forager local search, move-count and score-calculation
limits count candidates consumed in canonical order. Parallel windows are
capped by the remaining in-phase evaluation budget. Trials evaluated ahead of
the decision point and discarded are reported as `moves_speculative`, not
added to `moves_evaluated` or `score_calculations`. A fixed work budget therefore
does not measure all physical speculative scoring work. See
[Local Search](/docs/solverforge/solver/local-search/#parallel-candidate-evaluation).

## Programmatic Termination

Use `SolverManager::cancel(job_id)` to stop a retained job from code:

```rust
use solverforge::SolverManager;

static MANAGER: SolverManager<Schedule> = SolverManager::new();

let (job_id, rx) = MANAGER.solve(problem).expect("solver job should start");

// Later...
MANAGER.cancel(job_id).expect("cancel should be accepted");
```

The job's event stream then ends with `SolverEvent::Cancelled`.

Configured limits remain binding during mandatory scalar and list construction.
Their terminal result depends on whether the solution is structurally complete:

- after every mandatory list element, required assignment row, and non-optional
  scalar slot is assigned, the terminal event is `SolverEvent::Completed` and
  the terminal reason is `SolverTerminalReason::TerminatedByConfig`
- if a limit fires first, the terminal event is `SolverEvent::Failed`; no
  `BestSolution`, completed snapshot, or partial construction state is published

Local search cannot start until the mandatory completion gate passes. The gate
is checked again before final publication, so a later phase cannot expose a
solution that has become structurally incomplete.

Pause, cancellation, and config termination are polled inside large candidate
work and around phase and terminal hooks. Paused time is removed from the active
solve and phase timers, so resuming continues the remaining configured budget
instead of charging the paused interval.

## Extension State and Polling

Unimproved terminations own mutable observation state. Repeated checks on the
same step do not count as extra unimproved steps.

Control and wall-clock checks are batched within candidate loops and are also
performed at step, phase, and terminal boundaries. The local-search loop polls
control every 64 candidate iterations, with evaluation checks on a 64-evaluation
schedule. Construction also batches scans/pulls and polls around placements.
These limits are cooperative stopping conditions, not hard real-time deadlines:
a callback or one expensive candidate can run past the requested time before
control settles. Phase limits with only step/score criteria use counters
without reading the wall clock on each control poll.

## See Also

- [Configuration](/docs/solverforge/solver/configuration/) — TOML configuration format
- [SolverManager](/docs/solverforge/solver/solver-manager/) — Programmatic solver control
