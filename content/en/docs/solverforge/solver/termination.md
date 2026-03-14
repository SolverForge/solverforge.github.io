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
[solver.termination]
seconds_spent_limit = 300           # Stop after 5 minutes
minutes_spent_limit = 10            # Stop after 10 minutes
milliseconds_spent_limit = 5000     # Stop after 5 seconds
```

### Step-Based

```toml
[solver.termination]
step_count_limit = 100000           # Stop after 100k steps
```

### Unimproved Time/Steps

Stop when no improvement has been found for a duration:

```toml
[solver.termination]
unimproved_seconds_spent_limit = 60        # No improvement for 60s
unimproved_step_count_limit = 10000        # No improvement for 10k steps
```

### Score-Based

Stop when a target score is reached:

```toml
[solver.termination]
best_score_limit = "0hard/-100soft"    # Stop when feasible with soft ≥ -100
best_score_feasible = true             # Stop when any feasible solution is found
```

## Composite Termination

Combine multiple conditions with `and` or `or`:

### OrTermination (default)

Stop when **any** condition is met:

```toml
[solver.termination]
seconds_spent_limit = 300
best_score_limit = "0hard/0soft"
# Stops after 5 minutes OR when a perfect score is found
```

### AndTermination

Stop only when **all** conditions are met:

```toml
[solver.termination]
type = "and"
seconds_spent_limit = 60
best_score_feasible = true
# Stops only after 60s AND a feasible solution is found
```

## Per-Phase Termination

Each phase can have its own termination:

```toml
[[solver.phases]]
type = "construction_heuristic"
# No termination needed — runs until all variables are assigned

[[solver.phases]]
type = "local_search"
acceptor = "late_acceptance"

[solver.phases.termination]
unimproved_step_count_limit = 10000
```

## Programmatic Termination

Use `SolverManager::terminate_early()` to stop the solver from code:

```rust
let manager = SolverManager::new(config);
let handle = manager.solve_async(problem);

// Later...
manager.terminate_early();
```

## See Also

- [Configuration](../configuration/) — TOML configuration format
- [SolverManager](../solver-manager/) — Programmatic solver control
