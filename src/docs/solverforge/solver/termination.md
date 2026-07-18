---
title: "Termination"
linkTitle: "Termination"
weight: 40
description: >
  Control when the solver stops — time limits, step counts, score targets, and composites.
---

Termination conditions tell the solver when to stop searching. You can set termination globally or per-phase.

## Termination Types

### Time-Based

```toml
[termination]
seconds_spent_limit = 300           # Stop after 5 minutes
minutes_spent_limit = 10            # Stop after 10 minutes
```

### Step-Based

```toml
[termination]
step_count_limit = 100000           # Stop after 100k steps
```

### Unimproved Time/Steps

Stop when no improvement has been found for a duration:

```toml
[termination]
unimproved_seconds_spent_limit = 60        # No improvement for 60s
unimproved_step_count_limit = 10000        # No improvement for 10k steps
```

### Score-Based

Stop when a target score is reached:

```toml
[termination]
best_score_limit = "0hard/-100soft"    # Stop when feasible with soft ≥ -100
```

## Composite Termination

Combine multiple conditions — by default, the solver stops when **any** condition is met:

```toml
[termination]
seconds_spent_limit = 300
best_score_limit = "0hard/0soft"
# Stops after 5 minutes OR when a perfect score is found
```

## Per-Phase Termination

Each phase can have its own termination:

```toml
[[phases]]
type = "construction_heuristic"
# No termination needed — runs until all variables are assigned

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

## Programmatic Termination

Use `SolverManager::cancel(job_id)` to stop a retained job from code:

```rust
static MANAGER: SolverManager<Schedule> = SolverManager::new();

let (job_id, rx) = MANAGER.solve(problem).expect("solver job should start");

// Later...
MANAGER.cancel(job_id).expect("cancel should be accepted");
```

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

## See Also

- [Configuration](/docs/solverforge/solver/configuration/) — TOML configuration format
- [SolverManager](/docs/solverforge/solver/solver-manager/) — Programmatic solver control
