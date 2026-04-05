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

let (job_id, mut rx) = MANAGER.solve(problem);

while let Some(event) = rx.blocking_recv() {
    match event {
        SolverEvent::Progress { best_score, .. } => {
            println!("best so far: {:?}", best_score);
        }
        SolverEvent::BestSolution { score, .. } => {
            println!("new best: {score}");
        }
        SolverEvent::Finished { score, .. } => {
            println!("finished: {score}");
            break;
        }
    }
}

MANAGER.free_slot(job_id);
```

The stock generated solve path loads `solver.toml` automatically from the
current working directory. `solverforge-config` also exposes parsing APIs when
you want to inspect or construct configs directly.

## Sections

- **[Configuration](configuration/)** — `SolverConfig`, `solver.toml`, and YAML parsing
- **[Phases](phases/)** — Construction heuristic, local search, exhaustive search, and VND
- **[Moves](moves/)** — Move types and selectors
- **[Termination](termination/)** — When to stop solving
- **[SolverManager](solver-manager/)** — Running and managing solver instances
