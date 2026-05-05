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

The `0.11.x` release line uses one `ModelContext` per planning model. Generic
construction heuristics share that context for mixed/list-bearing work, while
pure scalar construction uses the descriptor-scalar boundary. Local search uses
explicit streaming defaults when `move_selector` is omitted, and scalar
candidate limits, grouped scalar selectors, and score-level simulated annealing
are expressed in `solver.toml`.

The `0.11.1` facade also exports the configuration surface directly from
`solverforge`, including `SolverConfig`, `PhaseConfig`, `MoveSelectorConfig`,
`AcceptorConfig`, `ForagerConfig`, `SolverConfigOverride`, and related enums.
Application code no longer needs a separate `solverforge-config` dependency for
normal configuration construction or parsing.

`SolverManager` now exposes a retained job lifecycle rather than a fire-and-forget
channel. In addition to `Progress` and `BestSolution`, you can observe
`PauseRequested`, `Paused`, `Resumed`, `Completed`, `Cancelled`, and `Failed`,
inspect `SolverStatus`, and fetch or analyze retained snapshots by
`snapshot_revision`.

Retained telemetry carries exact generated, evaluated, accepted, not-doable,
acceptor-rejected, forager-ignored, hard-delta, conflict-repair, and
construction-slot counters plus generation and evaluation durations.
User-facing rates such as `moves/s` are display-only derived values.

## Sections

- **[Configuration](/docs/solverforge/solver/configuration/)** — `SolverConfig`, `solver.toml`, and YAML parsing
- **[Construction](/docs/solverforge/solver/construction/)** — construction heuristics, nullable obligations, and grouped scalar construction
- **[Local Search](/docs/solverforge/solver/local-search/)** — acceptors, foragers, selectors, and score-level annealing
- **[Phases](/docs/solverforge/solver/phases/)** — Construction heuristic, local search, exhaustive search, and VND
- **[Moves](/docs/solverforge/solver/moves/)** — selector-family guide with scalar, list, and composite subsections
- **[Termination](/docs/solverforge/solver/termination/)** — When to stop solving
- **[SolverManager](/docs/solverforge/solver/solver-manager/)** — Running and managing solver instances
