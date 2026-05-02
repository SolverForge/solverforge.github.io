---
title: "SolverForge"
linkTitle: "SolverForge"
icon: fa-brands fa-rust
weight: 10
description: >
  Native Rust constraint solver.
---

SolverForge is a native Rust constraint solver for planning and scheduling
problems. It uses derive macros for domain modeling, constraint streams for
declarative rule definition, and metaheuristic algorithms for optimization.

## Installation

```bash
cargo add solverforge
```

These pages track the `solverforge` `0.10.0` core-library codebase. At the time
of this docs update, crates.io still reports `solverforge 0.9.1`; use a git/path
dependency for unreleased 0.10.0 work and check crate metadata before assuming a
published package is available. Generated CLI projects can intentionally target
an older runtime until the next CLI target refresh, so check `solverforge
--version` when starting from a scaffold.

For end-to-end app scaffolding, prefer the standalone
[`solverforge-cli`](https://github.com/solverforge/solverforge-cli) workflow:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

The 0.10.0 workspace declares Rust `1.95`.

The generated runtime now builds one `ModelContext` for each planning model.
Scalar metadata is resolved by descriptor index and variable name, not by Rust
module declaration order. Generic `FirstFit` and `CheapestInsertion` use the
canonical construction engine whenever matching list work is present, while pure
scalar matches reuse the descriptor-scalar path. Optional scalar variables keep
`None` when it is the best legal baseline instead of forcing an eager assignment.

Startup telemetry is shape-aware in the current release: scalar solves report
average `candidates`, list solves report element counts, and console output
labels those solve shapes as `candidates` or `elements`.

The 0.10.0 codebase also tightens several public contracts:

- projected scoring rows use `Projection` / `ProjectionSink`, declare
  `MAX_EMITS`, and keep self-join ordering coordinate-stable by source slot,
  entity index, and emission index
- scalar construction order is model-owned through
  `construction_entity_order_key` and `construction_value_order_key`; those
  hooks are evaluated against the live working solution at each construction
  step and do not reorder local-search candidates
- nearby scalar neighborhoods are bounded model capabilities through
  `nearby_value_candidates` and `nearby_entity_candidates`; distance meters rank
  or filter those candidates, but do not discover them
- default local-search neighborhoods are explicit streaming defaults: scalar
  change plus swap, list nearby-change plus nearby-swap plus reverse, and mixed
  models concatenate list defaults before scalar defaults
- retained telemetry preserves exact generated, evaluated, and accepted counts
  plus generation and evaluation durations; `moves/s` is only a display metric

## Minimal Example

```rust
use solverforge::prelude::*;
use solverforge::{SolverEvent, SolverManager};
use solverforge::stream::ConstraintFactory;

#[problem_fact]
pub struct Worker {
    #[planning_id]
    pub id: usize,
    pub name: String,
}

#[planning_entity]
pub struct Task {
    #[planning_id]
    pub id: usize,

    #[planning_variable(value_range = "workers", allows_unassigned = true)]
    pub worker: Option<usize>,
}

#[planning_solution(constraints = "define_constraints")]
pub struct Plan {
    #[problem_fact_collection]
    pub workers: Vec<Worker>,

    #[planning_entity_collection]
    pub tasks: Vec<Task>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}

fn define_constraints() -> impl ConstraintSet<Plan, HardSoftScore> {
    use PlanConstraintStreams;
    use TaskUnassignedFilter;

    (
        ConstraintFactory::<Plan, HardSoftScore>::new()
            .tasks()
            .unassigned()
            .penalize_hard()
            .named("Unassigned task"),
    )
}

static MANAGER: SolverManager<Plan> = SolverManager::new();

fn main() {
    let problem = Plan {
        workers: vec![],
        tasks: vec![],
        score: None,
    };

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

    let snapshot = MANAGER
        .get_snapshot(job_id, None)
        .expect("latest snapshot should exist");
    println!("latest snapshot revision {}", snapshot.snapshot_revision);

    MANAGER.delete(job_id).expect("delete retained job");
}
```

## API Reference

Full API documentation is available on
[docs.rs/solverforge](https://docs.rs/solverforge).

## Sections

- **[Domain Modeling](modeling/)** — Derive macros for solutions, entities, and
  problem facts
- **[Constraints](constraints/)** — Constraint streams, joiners, collectors, and
  score types
- **[Solver](solver/)** — Configuration, phases, moves, termination, and
  SolverManager
