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

static MANAGER: SolverManager<Schedule> = SolverManager::new();

let config = SolverConfig::from_toml_str(r#"
    [termination]
    seconds_spent_limit = 30
"#).unwrap();

let (job_id, rx) = MANAGER.solve(problem);

// Receive improving solutions via channel
for (solution, score) in rx {
    println!("New best score: {:?}", score);
}
```

## Sections

- **[Configuration](configuration/)** — TOML-based solver configuration
- **[Phases](phases/)** — Construction heuristic, local search, exhaustive search
- **[Moves](moves/)** — Move types and selectors
- **[Termination](termination/)** — When to stop solving
- **[SolverManager](solver-manager/)** — Running and managing solver instances
