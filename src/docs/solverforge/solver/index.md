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

The current release resolves one `RuntimeModel` per planning model and compiles
it into one immutable graph before solving. Native, dynamic, scalar-only,
list-only, and mixed models share that graph compiler. Generic construction,
configured selector trees, provider registries, stable list sources, and
model-aware defaults are validated once; there is no parallel descriptor phase
builder or fallback runtime path.

Local search uses capability-matched streaming defaults when `move_selector` is
omitted. Scalar candidate limits, assignment-backed grouped scalar selectors,
conflict repair, list permutation and precedence repair, per-leaf ordering,
weighted unions, seeded score ties, candidate tracing, and score-level simulated
annealing are expressed in `solver.toml`.

The facade exports the configuration surface directly from
`solverforge`, including `SolverConfig`, `PhaseConfig`, `MoveSelectorConfig`,
`AcceptorConfig`, `ForagerConfig`, `SolverConfigOverride`, and related enums.
Application code no longer needs a separate `solverforge-config` dependency for
normal configuration construction or parsing.

Assignment-backed grouped scalar construction is available for required
nullable scalar slots through named `ScalarGroup::assignment(...)`
declarations. Pair it with `grouped_scalar_move_selector` when local search
should prioritize uncovered required slots, capacity conflicts, bounded
reassignments, same-sequence run-gap repairs, value-window swaps, optional
occupant releases, block reassignments, or value rotations from the same group.

`SolverManager` now exposes a retained job lifecycle rather than a fire-and-forget
channel. In addition to `Progress` and `BestSolution`, you can observe
`PauseRequested`, `Paused`, `Resumed`, `Completed`, `Cancelled`, and `Failed`,
inspect `SolverStatus`, and fetch or analyze retained snapshots by
`snapshot_revision`.

Retained telemetry carries exact generated, evaluated, accepted, not-doable,
acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
construction-slot, and active-phase counters plus generation and evaluation
durations. The runtime also carries per-move-label telemetry and a bounded
applied-move trace with selected candidate index, per-step candidate counts,
score delta, and hard-feasibility before/after. Opt-in candidate-pull traces add
canonical plan, policy, input, identity, and disposition provenance and are read
through `get_telemetry_detail(...)`. User-facing rates such as `moves/s` remain
display-only derived values.

## Sections

- **[Configuration](/docs/solverforge/solver/configuration/)** — `SolverConfig`, selector policy, candidate tracing, `solver.toml`, and YAML parsing
- **[Construction](/docs/solverforge/solver/construction/)** — construction heuristics, nullable obligations, grouped scalar construction, and stable list sources
- **[Local Search](/docs/solverforge/solver/local-search/)** — acceptors, foragers, selector ordering, union weighting, and score-level annealing
- **[Phases](/docs/solverforge/solver/phases/)** — Construction heuristic, local search, VND, typed exact search, and partitioned search
- **[Moves](/docs/solverforge/solver/moves/)** — selector-family guide with scalar, list, and composite subsections
- **[Termination](/docs/solverforge/solver/termination/)** — When to stop solving
- **[SolverManager](/docs/solverforge/solver/solver-manager/)** — Running and managing solver instances
