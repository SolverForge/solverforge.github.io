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

Call `.solve()` with your planning solution. It returns a `(job_id, Receiver)`
tuple:

```rust
let (job_id, rx) = MANAGER.solve(solution);
```

The receiver yields `SolverEvent<S>` values, not raw `(solution, score)` tuples.
Consume them in a loop:

```rust
use solverforge::SolverEvent;

let (job_id, mut rx) = MANAGER.solve(solution);

while let Some(event) = rx.blocking_recv() {
    match event {
        SolverEvent::Progress {
            current_score,
            best_score,
            ..
        } => {
            println!("current: {:?}, best: {:?}", current_score, best_score);
        }
        SolverEvent::BestSolution { solution, score, .. } => {
            println!("new best: {:?}", score);
            drop(solution);
        }
        SolverEvent::Finished { solution, score, .. } => {
            println!("finished: {:?}", score);
            drop(solution);
            break;
        }
    }
}
```

The event variants are:

- `Progress` — telemetry plus current and best scores
- `BestSolution` — an owned improving solution
- `Finished` — the final owned best solution

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

Your planning solution must implement `Solvable` to be used with
`SolverManager`. This is generated automatically when `#[planning_solution]`
includes a `constraints = "..."` path.

## See Also

- [Configuration](../configuration/) — Solver configuration
- [Termination](../termination/) — Termination conditions
