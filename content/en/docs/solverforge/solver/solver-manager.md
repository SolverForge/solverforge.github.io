---
title: "SolverManager"
linkTitle: "SolverManager"
weight: 50
description: >
  Run and manage solver instances with channel-based streaming.
---

`SolverManager` is the main entry point for running the solver. It manages solver lifecycle, provides status updates, and supports early termination.

## Basic Usage

```rust
use solverforge::prelude::*;

let config = SolverConfig::from_toml_str(r#"
    [solver]
    termination.seconds_spent_limit = 30
"#).unwrap();

let manager = SolverManager::new(config);
let solution = manager.solve(problem).unwrap();

println!("Score: {:?}", solution.score);
```

## Channel-Based Streaming

For real-time updates during solving, use the channel-based pattern:

```rust
let (tx, rx) = std::sync::mpsc::channel();

let manager = SolverManager::new(config);
manager.solve_with_updates(problem, move |update| {
    tx.send(update.best_solution().clone()).ok();
});

// Receive updates in another thread
for solution in rx {
    println!("New best score: {:?}", solution.score);
}
```

## Solver Status

Check the current state of the solver:

```rust
let status = manager.get_status();
match status {
    SolverStatus::NotStarted => println!("Not started"),
    SolverStatus::Solving => println!("Currently solving"),
    SolverStatus::Terminated => println!("Done"),
}
```

## Early Termination

Stop the solver before the configured termination condition:

```rust
manager.terminate_early();
```

The solver finishes its current step and returns the best solution found so far.

## The `Solvable` Trait

Your planning solution must implement the `Solvable` trait (derived automatically by the `#[planning_solution]` macro) to be used with `SolverManager`.

## See Also

- [Configuration](../configuration/) — Solver configuration
- [Termination](../termination/) — Termination conditions
