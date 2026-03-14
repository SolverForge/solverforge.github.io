---
title: "SolverManager"
linkTitle: "SolverManager"
weight: 50
description: >
  Run and manage solver instances with channel-based streaming.
---

`SolverManager` is the main entry point for running the solver. It manages solver lifecycle, provides streaming updates via channels, and supports early termination.

## Creating a SolverManager

`SolverManager::new()` is a `const fn` that takes no arguments. It's designed to be used as a static:

```rust
use solverforge::prelude::*;

static MANAGER: SolverManager<Schedule> = SolverManager::new();
```

## Solving

Call `.solve()` with your planning solution. It returns a `(job_id, Receiver)` tuple:

```rust
let (job_id, rx) = MANAGER.solve(solution);
```

The receiver yields `(S, S::Score)` tuples — each is an improving solution found during solving. Consume them in a loop or spawn a thread:

```rust
let (job_id, rx) = MANAGER.solve(solution);

for (best_solution, score) in rx {
    println!("New best score: {:?}", score);
    // Update UI, save to database, etc.
}
```

## Solver Status

Check the current state of a job:

```rust
let status = MANAGER.get_status(job_id);
match status {
    SolverStatus::NotSolving => println!("Not solving"),
    SolverStatus::Solving => println!("Currently solving"),
}
```

The two variants are:
- `SolverStatus::NotSolving` — the job is idle or finished
- `SolverStatus::Solving` — the job is actively running

## Early Termination

Stop a job before its configured termination condition:

```rust
let terminated = MANAGER.terminate_early(job_id);
// Returns true if the job was found and was currently solving
```

The solver finishes its current step and sends the best solution found so far through the channel.

## Freeing Slots

After a job completes and you've consumed the results, free the slot:

```rust
MANAGER.free_slot(job_id);
```

## Active Jobs

Check how many jobs are currently running:

```rust
let count = MANAGER.active_job_count();
```

## The `Solvable` Trait

Your planning solution must implement the `Solvable` trait (derived automatically by the `#[planning_solution]` macro) to be used with `SolverManager`.

## See Also

- [Configuration](../configuration/) — Solver configuration
- [Termination](../termination/) — Termination conditions
