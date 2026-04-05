---
title: 'SolverForge'
linkTitle: 'SolverForge'
icon: fa-brands fa-rust
weight: 10
description: >
  Native Rust constraint solver — aligned with the 0.7.1 runtime surface.
---

SolverForge is a native Rust constraint solver for planning and scheduling
problems. It uses derive macros for domain modeling, constraint streams for
declarative rule definition, and metaheuristic algorithms for optimization.

## Installation

```bash
cargo add solverforge
```

For end-to-end app scaffolding, prefer the standalone
[`solverforge-cli`](https://github.com/solverforge/solverforge-cli) workflow:

```bash
cargo install solverforge-cli
solverforge new my-scheduler --standard
cd my-scheduler
solverforge server
```

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
