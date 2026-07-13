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

These pages track the `solverforge 0.18.0` crate and current release
workspace. Generated CLI projects can intentionally target an older scaffold
runtime; the published `solverforge-cli 2.2.2` package scaffolds
`solverforge 0.15.2`, so check `solverforge --version` when starting from a
scaffold.

For end-to-end app scaffolding, prefer the standalone
[`solverforge-cli`](https://github.com/solverforge/solverforge-cli) workflow:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

The `0.18.0` workspace declares Rust `1.95`.

The generated runtime resolves one value-owned `RuntimeModel` for each planning
model, then compiles construction stages, selector trees, providers, stable
list-source identities, and defaults into one immutable search graph. Native
Rust models and dynamic bridge models use that same compile-and-execute
lifecycle. Scalar metadata is resolved by descriptor index and variable name,
not Rust module declaration order; invalid declarations fail before candidate
work rather than falling through to a parallel builder path.

Generic `FirstFit` and `CheapestInsertion` use the compiled graph's
descriptor-placement schedule for scalar-only targets and its declaration-order
global scan for matching mixed/list work. Assignment-backed grouped scalar
construction covers required nullable scalar slots through
`ScalarGroup::assignment(...)`, and optional scalar variables keep `None` when
it is the best legal baseline unless configuration asks construction to assign
whenever a candidate exists.

Startup telemetry is shape-aware: scalar solves report average `candidates`,
list solves report element counts, and console output labels those solve shapes
as `candidates` or `elements`. Retained telemetry also identifies the active
phase and keeps its local elapsed/work counters separate from whole-solve totals.

The current release tightens several public contracts:

- macro-generated and dynamic solves both enter the same runtime compiler;
  public build failures distinguish declaration, compilation, phase
  preparation, and phase execution without exposing private graph types
- runtime variable slots, list element sources, native/host compound providers,
  and optional candidate metrics are resolved once and frozen for the solve.
  Specialized list construction uses stable source keys rather than payload
  equality or hash recovery
- local-search config now models leaf `selection_order`, registered
  `selection_metric` values for sorted/probabilistic ordering, weighted union
  scheduling, and seeded score tie-breaking. Omitted multi-family unions use
  `stratified_random`; omitted leaf order uses seeded `random`
- dynamic bridges declare scalar-assignment metadata plus list mutation and
  metadata capabilities explicitly. Missing required operations, descriptor
  bindings, legal values, or route/precedence bundles fail during binding or
  graph compilation
- `[candidate_trace]` enables a bounded ordered prefix of candidates actually
  pulled by the engine, including the canonical config, resolved phase plan,
  execution policy, logical operation identity, and disposition transitions.
  Detailed traces are fetched explicitly with
  `SolverManager::get_telemetry_detail(...)`
- pause and cancellation settle at phase and terminal-hook boundaries as well
  as inside long-running work; paused time does not consume active phase timing,
  and pending control cannot be overwritten by default completion
- `#[solverforge_constraints]` is the canonical constraint-function attribute
  when a function reuses grouped streams. Reused same-binding grouped streams
  and syntax-proved identical grouped chains share one retained node while each
  `.named(...)` terminal keeps its own identity, ordering, metadata, and score
  explanation
- generated collection sources are solution-associated methods such as
  `Schedule::shifts()`, and stream roots use
  `ConstraintFactory::for_each(Schedule::shifts())`
- assignment-backed grouped scalar construction and repair are public runtime
  policy through `ScalarGroup::assignment(...)`, grouped construction
  `group_name`, and `grouped_scalar_move_selector`
- solver construction internals that advanced integrations use directly now
  expose `GroupedScalarCursor`, `GroupedScalarSelector`,
  `ScalarAssignmentMoveCursor`, `ScalarAssignmentMoveOptions`, and
  `ScalarAssignmentRequiredStreamingCursor` from the public solver surface
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
- `solverforge::bridge` re-exports host-language binding contracts for logical
  entity/fact/variable IDs, dynamic score families, descriptor-resolved dynamic
  scalar/list slots, explicit list access/metadata capabilities, and dynamic
  scalar-assignment metadata
- projected scoring rows use `Projection` / `ProjectionSink` for bounded
  single-source rows, and cross joins can either group joined pairs directly
  with `.group_by(|left, right| key, collector)` or retain one scoring row per
  joined pair with `.project(|left, right| row)`
- projected streams support symmetric self-joins with `equal(|row| key)` and
  directed same-output joins with `equal_bi(left_key, right_key)` when pair
  orientation is part of the rule
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
- default local-search neighborhoods are capability-matched streaming defaults:
  nearby scalar selectors before plain change/swap fallbacks for
  non-assignment-owned slots; precedence plus permutation for fully capable list
  slots; nearby list change/swap when a cross-position metric exists and plain
  change/swap otherwise; capability-gated sublist, reverse, and k-opt; list ruin
  for bound list slots; and grouped-scalar or conflict-repair selectors only
  when the model declares them
- assignment-backed grouped scalar search includes bounded value-window swaps,
  longer window swaps, same-sequence run-gap swaps, block reassignments,
  optional run releases, and value rotations without weakening the assignment
  hard constraints
- stock CVRP route lists can now declare
  `#[planning_list_variable(element_collection = "...", domain = "cvrp")]`.
  The profile expands to `solverforge::cvrp::VrpSolution`, the stock CVRP
  distance meters, route hooks, savings hooks, and savings metric class.
  Route-local phases such as k-opt use strict stock CVRP feasibility, while
  Clarke-Wright construction uses relaxed savings admissibility so capacity and
  time-window violations can still be compared by the score model
- stock CVRP distance hooks reject unreachable travel-time legs in strict route
  feasibility and convert unreachable or malformed distance entries into a
  large finite construction/search cost instead of panicking or overflowing
- route-distance arithmetic used by Clarke-Wright and k-opt is clamped, so
  unreachable or extreme matrix values stay in the solver's scoring domain
- custom routing domains can still omit `domain = "cvrp"` and wire
  `route_hooks`, `savings_hooks`, and optional `savings_metric_class_fn`
  explicitly when they need non-CVRP semantics or different construction
  pruning policies
- `ListClarkeWright` construction completes unmatched route elements instead
  of dropping them when no saving merge can place them
- list variables can declare fixed element ownership, construction element
  ordering, and fixed precedence hooks; the stock runtime exposes
  `ListPrecedenceMakespanConstraint`, `list_permute_move_selector`, and
  `list_precedence_move_selector` for generic precedence-list models.
  Cheapest-insertion list construction uses precedence duration/successor hooks
  to dispatch downstream-critical unassigned elements earlier when the hooks
  are present
- typed custom search is compiled into the solution with
  `#[planning_solution(search = "...")]`; config names registered phases
  instead of loading arbitrary runtime classes
- retained telemetry preserves exact generated, evaluated, accepted,
  not-doable, acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
  construction-slot, active-phase, move-label, and bounded applied-move counters
  plus generation and evaluation durations. `moves_generated` counts candidates
  actually yielded, not an unrequested logical tail; `moves/s` is only a display
  metric

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
[docs.rs/solverforge](https://docs.rs/solverforge). docs.rs can briefly lag the
crate registry after a release; the `0.18.0` crate is the package source of
truth now that crates.io has accepted it. Source-line API maps for the local
workspace live in the repository `crates/*/WIREFRAME.md` files.

## Sections

- **[Domain Modeling](/docs/solverforge/modeling/)** — Derive macros for solutions, entities, and
  problem facts
- **[Constraints](/docs/solverforge/constraints/)** — Constraint streams,
  projected scoring rows, existence, joiners, collectors, and score types
- **[Solver](/docs/solverforge/solver/)** — Configuration, construction, local
  search, moves, termination, and SolverManager
