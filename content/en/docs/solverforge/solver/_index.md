---
title: "Solver"
linkTitle: "Solver"
weight: 50
description: >
  Configure and run the solver — phases, moves, termination, and SolverManager.
---

The solver takes your domain model and constraints, then searches for the best solution using metaheuristic algorithms. Configuration controls which algorithms run, how long to search, and how moves are selected.

## Quick Start

```rust
use solverforge::prelude::*;
use solverforge::{SolverEvent, SolverManager};

static MANAGER: SolverManager<Schedule> = SolverManager::new();

let (job_id, mut rx) = MANAGER.solve(problem).expect("solver job should start");

while let Some(event) = rx.blocking_recv() {
    match event {
        SolverEvent::Progress { metadata } => {
            println!("best so far: {:?}", metadata.best_score);
        }
        SolverEvent::BestSolution { metadata, .. } => {
            println!("new best at snapshot {:?}", metadata.snapshot_revision);
        }
        SolverEvent::Completed { metadata, .. } => {
            println!("finished with reason {:?}", metadata.terminal_reason);
            break;
        }
        SolverEvent::Cancelled { .. } | SolverEvent::Failed { .. } => break,
        SolverEvent::PauseRequested { .. } | SolverEvent::Paused { .. } | SolverEvent::Resumed { .. } => {}
    }
}

MANAGER.delete(job_id).expect("delete retained job");
```

The stock generated solve path loads `solver.toml` automatically from the
current working directory. `solverforge-config` also exposes parsing APIs when
you want to inspect or construct configs directly.

`SolverManager` now exposes a retained job lifecycle rather than a fire-and-forget
channel. In addition to `Progress` and `BestSolution`, you can observe
`PauseRequested`, `Paused`, `Resumed`, `Completed`, `Cancelled`, and `Failed`,
inspect `SolverStatus`, and fetch or analyze retained snapshots by
`snapshot_revision`.

## Sections

- **[Configuration](configuration/)** — `SolverConfig`, `solver.toml`, and YAML parsing
- **[Phases](phases/)** — Construction heuristic, local search, exhaustive search, and VND
- **[Moves](moves/)** — Move types and selectors
- **[Termination](termination/)** — When to stop solving
- **[SolverManager](solver-manager/)** — Running and managing solver instances
