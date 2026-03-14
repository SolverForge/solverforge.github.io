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

## Programmatic Termination

Use `SolverManager::terminate_early(job_id)` to stop a job from code:

```rust
static MANAGER: SolverManager<Schedule> = SolverManager::new();

let (job_id, rx) = MANAGER.solve(problem);

// Later...
MANAGER.terminate_early(job_id);
```

## See Also

- [Configuration](../configuration/) — TOML configuration format
- [SolverManager](../solver-manager/) — Programmatic solver control
