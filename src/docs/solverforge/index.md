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

These pages track the published `solverforge 0.14.0` crate and current source
workspace. Generated CLI projects can intentionally target an older scaffold
runtime until the next CLI runtime-target refresh, so check
`solverforge --version` when starting from a scaffold.

For end-to-end app scaffolding, prefer the standalone
[`solverforge-cli`](https://github.com/solverforge/solverforge-cli) workflow:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

The `0.14.0` crate declares Rust `1.95`.

The generated runtime now builds one `RuntimeModel` for each planning model.
Scalar metadata is resolved by descriptor index and variable name, not by Rust
module declaration order. Generic `FirstFit` and `CheapestInsertion` use the
canonical construction engine whenever matching list work is present, while pure
scalar matches reuse the descriptor boundary. Assignment-backed grouped scalar
construction can cover required nullable scalar slots through
`ScalarGroup::assignment(...)`, and optional scalar variables keep `None` when
it is the best legal baseline unless configuration asks construction to assign
whenever a candidate exists.

Startup telemetry is shape-aware in the current release: scalar solves report
average `candidates`, list solves report element counts, and console output
labels those solve shapes as `candidates` or `elements`.

The current release tightens several public contracts:

- generated collection sources are solution-associated methods such as
  `Schedule::shifts()`, and stream roots use
  `ConstraintFactory::for_each(Schedule::shifts())`
- assignment-backed grouped scalar construction and repair are public runtime
  policy through `ScalarGroup::assignment(...)`, grouped construction
  `group_name`, and `grouped_scalar_move_selector`
- `collect_vec(...)`, `consecutive_runs(...)`, `indexed_presence(...)`,
  `CollectedVec`, `IndexedPresence`, `Run`, and `Runs` are available from the
  prelude for grouped collection, streak, and ordinal-presence rules; their
  shared `Collector<Input>` contract covers unary rows, projected rows, and
  joined cross-join pairs
- scoring terminals use `penalize(score)`, `reward(score)`, typed dynamic
  closures, `fixed_weight(...)`, and `hard_weight(...)`; the former
  `penalize_hard`, `penalize_with`, and `reward_soft` helper family is no
  longer part of the current stream API
- solver configuration controls such as `SolverConfig`, `PhaseConfig`,
  `MoveSelectorConfig`, `AcceptorConfig`, `ForagerConfig`,
  `SolverConfigOverride`, and related enums are available directly from
  `solverforge`
- projected scoring rows use `Projection` / `ProjectionSink` for bounded
  single-source rows, and cross joins can either group joined pairs directly
  with `.group_by(|left, right| key, collector)` or retain one scoring row per
  joined pair with `.project(|left, right| row)`
- direct cross-join grouped streams can call `complement(...)` against a
  generated fact or entity source, so missing target keys produce explicit
  default rows without a projected-row detour
- filtered keyed joins preserve the filter contract on both joined sources,
  flattened keyed targets, projected joined rows, and complement sources
- projected outputs, projected self-join keys, and grouped collector values no
  longer require `Clone`
- projected self-join ordering is coordinate-stable by source ownership and
  emission index, with low-level joined filters receiving primary owner entity
  indexes rather than retained storage row IDs
- scalar construction order is model-owned through
  `construction_entity_order_key` and `construction_value_order_key`; those
  hooks are evaluated against the live working solution at each construction
  step and do not reorder local-search candidates
- nearby scalar neighborhoods are bounded model capabilities through
  `nearby_value_candidates` and `nearby_entity_candidates`; distance meters rank
  or filter those candidates, but do not discover them
- default local-search neighborhoods are explicit streaming defaults: nearby
  scalar selectors when hooks exist, scalar change/swap fallbacks for
  non-assignment-owned slots, list nearby-change, nearby-swap, sublist,
  reverse, optional k-opt/list-ruin when hooks exist, and grouped-scalar or
  conflict-repair selectors only when the model declares them
- list construction shares owner-aware route hooks across Clarke-Wright and
  k-opt: `route_get_fn`, `route_set_fn`, `route_depot_fn`,
  `route_distance_fn`, and `route_feasible_fn`
- typed custom search is compiled into the solution with
  `#[planning_solution(search = "...")]`; config names registered phases
  instead of loading arbitrary runtime classes
- retained telemetry preserves exact generated, evaluated, accepted,
  not-doable, acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
  and construction-slot counters plus generation and evaluation durations;
  `moves/s` is only a display metric

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

fn define_constraints() -> impl ConstraintSet<Plan, HardSoftScore> {
    (
        ConstraintFactory::<Plan, HardSoftScore>::new()
            .for_each(Plan::tasks())
            .unassigned()
            .penalize(HardSoftScore::ONE_HARD)
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

Full published API documentation is available on
[docs.rs/solverforge](https://docs.rs/solverforge). Source-line API maps for
the local workspace live in the repository `crates/*/WIREFRAME.md` files.

## Sections

- **[Domain Modeling](/docs/solverforge/modeling/)** — Derive macros for solutions, entities, and
  problem facts
- **[Constraints](/docs/solverforge/constraints/)** — Constraint streams,
  projected scoring rows, existence, joiners, collectors, and score types
- **[Solver](/docs/solverforge/solver/)** — Configuration, construction, local
  search, moves, termination, and SolverManager
