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
cargo add solverforge@=0.25.0
```

These pages track `solverforge 0.25.0`, and every Rust example on them
compiles against that release. The workspace declares Rust `1.95`.

For end-to-end app scaffolding, prefer the standalone
[`solverforge-cli`](https://github.com/solverforge/solverforge-cli) workflow.
The `solverforge-cli 3.9` line scaffolds `solverforge 0.25.0`; an app
scaffolded by an earlier CLI pins an older core, so read the `solverforge`
version in its `Cargo.toml`.

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

## How It Fits Together

A model is a set of Rust structs marked with derive macros and registered by a
`planning_model!` manifest; see [Domain Modeling](/docs/solverforge/modeling/).
Constraints are typed streams returned as a constraint set; see
[Constraints](/docs/solverforge/constraints/). At solve time the generated
runtime resolves one `RuntimeModel` for the planning model and compiles
construction, selectors, providers, and defaults into one immutable search
graph before the first phase runs, so an invalid declaration fails before any
candidate work. [`SolverManager`](/docs/solverforge/solver/solver-manager/)
runs solves as retained jobs and streams their events.

Solver configuration comes from `#[planning_solution(solver_toml = "...")]`,
which embeds the file at compile time, or from a `SolverConfig` passed at
solve time. A model with neither uses the defaults: construction runs, and a
local-search phase is added only when termination is configured. See
[Solver Configuration](/docs/solverforge/solver/configuration/).

## Minimal Example

A binary crate with `cargo add solverforge@=0.25.0` and three files.
`src/domain/mod.rs` registers the model:

<!-- rust: crate=minimal file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod plan;

    pub use plan::{Plan, Task, Worker};
}
```

`src/domain/plan.rs` holds the model and its constraints:

<!-- rust: crate=minimal file=src/domain/plan.rs -->
```rust
use solverforge::prelude::*;

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

    #[planning_variable(value_range_provider = "workers", allows_unassigned = true)]
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

#[solverforge_constraints]
fn define_constraints() -> impl ConstraintSet<Plan, HardSoftScore> {
    (
        ConstraintFactory::<Plan, HardSoftScore>::new()
            .for_each(Plan::tasks())
            .unassigned()
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned task"),
    )
}
```

`src/main.rs` solves a plan with two workers and three tasks:

<!-- rust: crate=minimal file=src/main.rs -->
```rust
mod domain;

use domain::{Plan, Task, Worker};
use solverforge::{SolverEvent, SolverManager};

static MANAGER: SolverManager<Plan> = SolverManager::new();

fn main() {
    let problem = Plan {
        workers: vec![
            Worker { id: 0, name: "Amina".into() },
            Worker { id: 1, name: "Bruno".into() },
        ],
        tasks: (0..3).map(|id| Task { id, worker: None }).collect(),
        score: None,
    };

    let (job_id, mut rx) = MANAGER.solve(problem).expect("solver job should start");

    while let Some(event) = rx.blocking_recv() {
        match event {
            SolverEvent::Progress { .. } | SolverEvent::BestSolution { .. } => {}
            SolverEvent::Completed { metadata, solution } => {
                println!("finished with reason {:?}", metadata.terminal_reason);
                println!("score {:?}", solution.score);
                let assigned = solution.tasks.iter().filter(|task| task.worker.is_some()).count();
                println!("{assigned} of {} tasks assigned", solution.tasks.len());
                break;
            }
            SolverEvent::Failed { error, .. } => panic!("solve failed: {error}"),
            SolverEvent::Cancelled { .. } => break,
            SolverEvent::PauseRequested { .. } | SolverEvent::Paused { .. } | SolverEvent::Resumed { .. } => {}
        }
    }

    MANAGER.delete(job_id).expect("delete retained job");
}
```

`cargo run` prints:

<!-- rust: crate=minimal output -->
```text
finished with reason Some(Completed)
score Some(HardSoftScore(0, 0))
3 of 3 tasks assigned
```

## API Reference

Consult the [`v0.25.0` implementation](https://github.com/SolverForge/solverforge/tree/v0.25.0)
and the repository `crates/*/WIREFRAME.md` API maps for this source line.
[docs.rs/solverforge](https://docs.rs/solverforge/) serves published crate APIs;
select the version matching your dependency.

## Sections

- **[Domain Modeling](/docs/solverforge/modeling/)** — Derive macros for solutions, entities, and
  problem facts
- **[Constraints](/docs/solverforge/constraints/)** — Constraint streams,
  projected scoring rows, existence, joiners, collectors, and score types
- **[Solver](/docs/solverforge/solver/)** — Configuration, construction, local
  search, moves, termination, and SolverManager
