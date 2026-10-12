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

These pages track the `solverforge 0.19.14` crate and current release
workspace. Generated CLI projects can intentionally target an older scaffold
runtime; the `solverforge-cli 3.3.3` line scaffolds `solverforge 0.19.7`, while
apps scaffolded by earlier lines pin `solverforge 0.19.5` (3.1.0) or
`solverforge 0.19.4` (3.0.0), so check `solverforge --version` when starting
from a scaffold.

For end-to-end app scaffolding, prefer the standalone
[`solverforge-cli`](https://github.com/solverforge/solverforge-cli) workflow:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

The `0.19.14` workspace declares Rust `1.95`.

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
`ScalarGroup::assignment(...)`. Its default required pass commits the dense
hard-first batch with direct independent assignments, then leaves bounded
augmenting rematches to the following required cursor where multi-entity edits
can be retained. Optional scalar variables keep `None` when it is the best legal
baseline unless configuration asks construction to assign whenever a candidate
exists. For assignment-backed groups, keeping an optional row unassigned
completes its exact group-slot decision without ending the optional pass.
Completed optional roots are skipped before candidate-domain reads or move
generation, preserving later rows' candidate budget; assigned occupants remain
available for required augmenting rematches.

When `phases` are omitted, state-aware construction runs first. One streaming
default local-search phase is eligible only when top-level termination contains
an effective parsed limit; absent termination, an empty object, or invalid
score-only termination stays construction-only. VND is never added implicitly.

Startup telemetry is shape-aware: scalar solves report average `candidates`,
list solves report element counts, and console output labels those solve shapes
as `candidates` or `elements`. Retained telemetry also identifies the active
phase and keeps its local elapsed/work counters separate from whole-solve totals.
Generic and specialized construction now publish the same engine-owned
lifecycle and progress events as local search: the first observed work is
reported promptly and long-running phases continue at roughly one-second
intervals when verbose logging is enabled.

The current release tightens several public contracts:

- ordered assignments and routes use planning list variables as their single
  canonical representation. List owners store the sequence directly, and
  inverse, index, previous, next, custom, cascading, and piggyback shadows stay
  derived from that list. Scalar variables retain direct single-slot mutation;
  they no longer carry predecessor-chain semantics
- macro-generated and dynamic solves both enter the same runtime compiler;
  public build failures distinguish declaration, compilation, phase
  preparation, and phase execution without exposing private graph types
- configured solver and phase limits remain binding during mandatory
  construction. Best-solution publication opens only after every list element,
  required assignment row, and non-optional scalar slot is assigned; reaching
  a limit first ends the retained job as `Failed` without exposing an
  incomplete solution or snapshot
- generic and specialized construction share one phase lifecycle, telemetry,
  and control-polling contract. Candidate counters and route telemetry commit
  atomically, expensive cursor generation can observe pause/cancel/deadline
  control, and consumers do not synthesize construction progress
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
  and pending control cannot be overwritten by default completion. A pause
  before mandatory construction completes remains resumable in-process but has
  no public solution snapshot. Resume and cancellation clear the pause request
  and notify the worker under the same pause gate used by its wait, preventing
  a lost wakeup between the worker's predicate check and sleep
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
- solver construction internals used by grouped-scalar assignment stay
  runtime-internal. The public policy is `ScalarGroup::assignment(...)`,
  grouped construction `group_name`, and `grouped_scalar_move_selector`; the
  grouped construction cursors are not part of the public crate surface
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
- fluent cross joins build one concrete relational operator tree and finalize
  into `constraint::relational::OperatorTerminal`. Named `Bi`, `Tri`, `Quad`,
  and `Penta` adapters use that tree; cross `Penta::join` continues into the
  arity-free `stream::chain::Chain`, whose joins have no fixed binding-count
  ceiling. Every second or later join uses view keys: `equal_on` receives the
  whole prior borrowed row on the left and `Leaf<NewEntity>` on the right;
  read entity fields through `.entity`. `equal_bi` with plain entity closures
  belongs to the first join, not a continuation. Each relationship can
  use a different key type. Since v0.19.12 that cross-Penta
  continuation drops the authored penta filter; apply the row filter on the
  returned `Chain`. Same-source `PentaConstraintStream` is terminal
- same-collection unique combinations use the arity-generic `SelfJoinNode`
  with filtered rows and the same generic terminal, rather than per-arity
  incremental scorers. The former cross-bi/cross-tri incremental engines are
  removed; this does not mean every specialized fluent family has migrated
- low-level relational operators compose filtered, merged, projected, grouped,
  existence, flattened, and complemented row producers, including derived
  inputs on either side of a join. Owned derived values remain with their
  evaluation or retained-state owner; views borrow them, and provenance keeps
  upstream bindings. Since `v0.19.13`, incremental notifications emit into
  caller-owned `Vec<RowHandle>` buffers (the former `RowChanges` return type is
  gone). These low-level capabilities are not all exposed through
  every fluent stream family
- direct cross-join grouped streams can call `complement(...)` against a
  generated fact or entity source, so missing target keys produce explicit
  default rows without a projected-row detour
- on the first unary keyed equality cross-join, unary source membership excludes
  rows before key extraction and pair creation while retaining original indexes
  and incremental metadata. Post-join filters remain row filters. This left-source
  pushdown does not apply to comparison, overlap, composed-condition, predicate,
  or same-source self-join dispatch. Filtered right targets, flattened keyed
  targets, projected joined rows, and complement sources retain their contracts
- fluent right-hand join targets implement `CollectionExtract`, including
  filtered unary streams; arbitrary compatible derived producers belong at
  low-level `JoinNode` inputs, not interchangeable fluent targets
- assignment limits separate value/group candidate bounds, per-step moves,
  augmenting depth, and rematch size. Model-owned `ScalarGroup::with_limits`
  sets depth and rematch bounds; defaults are 3 and 4 respectively, with rematch
  size clamped to at least 2
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

## Changes in 0.19.14

Released on October 12, 2026, `0.19.14` simplifies dense existence bookkeeping
and clarifies the existing chained-join key contract:

- `DenseKeys::add` and `take` check table length before growing and inline
  first-touch marking, removing the separate `touch` helper and its redundant
  growth check. Each key still enters the touched list only once per event;
  semi/anti membership settles from the final count. Hash-key storage and
  public existence authoring are unchanged. See
  [Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/).
- every continuation (`Bi::join`, `Tri::join`, `Quad::join`, `Penta::join`,
  and `Chain::join`) takes keys over borrowed row views, not plain entities.
  Use `equal_on(left_row_key, right_leaf_key)`; entity-closure `equal_bi`
  produces a type mismatch (`E0631`) at those boundaries. The first join
  continues to use entity keys with `equal_bi`. This documents the existing
  API, rather than changing the join signatures. See
  [Joiners](/docs/solverforge/constraints/joiners/).

The [0.19.13…0.19.14 source comparison](https://github.com/SolverForge/solverforge/compare/v0.19.13...v0.19.14)
and [exact released source](https://github.com/SolverForge/solverforge/tree/075aa6285ea266fe192b82949e65f43a6e69e777)
define this update. CLI scaffold, Python binding, app, and recorded benchmark
versions are independent; this patch does not change them or add measurements.

## Changes in 0.19.11–0.19.13

The earlier `0.19.13` release includes the `0.19.11` construction and scoring
fixes, the `0.19.12` retained-bookkeeping refinement, and the `0.19.13`
count-backed existence rewrite:

- interrupted Clarke-Wright merge work can commit a complete buffered route set
  using already verified owner-feasibility evidence, without another feasibility
  scan or candidate budget. Savings-generation interruption keeps the previously
  committed complete assignment. See [Construction](/docs/solverforge/solver/construction/).
- relational existence scratch, link lists, flattened child-handle vectors, and
  empty hash-bucket vectors are reused across incremental updates. Internal
  index maps use deterministic fast hashing; ordered and interval reverse
  side-tables use generation-checked handles. This is not a public ordering or
  allocation-free scoring guarantee.
- exact indexed view-equality candidates no longer repeat the same equality key
  extractors. Composed conditions still check residual predicates. See
  [Joiners](/docs/solverforge/constraints/joiners/).
- `0.19.12` keeps occupied hash buckets and surviving existence match lists in
  place. Old-key retraction, stale-generation rejection, duplicate-notification
  handling, semi/anti membership, and flattening relationships remain intact.
- since `0.19.13`, `ExistenceNode` answers semi and anti membership from
  per-key occurrence counts — dense tables keyed by `usize` planning ids, hash
  tables otherwise — without materializing right-side child rows or pair links;
  a threshold-crossing key publishes or retracts its left rows idempotently per
  event. `JoinerExistenceNode` remains the compiled-plan engine for existence
  with residual predicates, and complement defaults restore through the plan's
  retained equality keys. `Operator::retract`/`insert` emit into caller-owned
  buffers instead of returning the removed `RowChanges` value. See
  [Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/)
  and [Joiners](/docs/solverforge/constraints/joiners/).

These are runtime implementation changes, not a new CLI scaffold, Python binding,
app release, or benchmark measurement. Their independently pinned versions above
remain unchanged. The [0.19.10…0.19.13 source comparison](https://github.com/SolverForge/solverforge/compare/v0.19.10...v0.19.13)
and [final tagged source](https://github.com/SolverForge/solverforge/tree/d2eb5fb6f4b821ffaef9e69295667365343c8406)
are the evidence for this update.

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

    if let Ok(snapshot) = MANAGER.get_snapshot(job_id, None) {
        println!("latest snapshot revision {}", snapshot.snapshot_revision);
    }

    MANAGER.delete(job_id).expect("delete retained job");
}
```

## API Reference

Full published API documentation is available on
[docs.rs/solverforge 0.19.14](https://docs.rs/solverforge/0.19.14/solverforge/).
The `0.19.14` crate is the registry source of truth. Consult the
[`v0.19.14` implementation](https://github.com/SolverForge/solverforge/tree/v0.19.14)
alongside the repository `crates/*/WIREFRAME.md` API maps.

## Sections

- **[Domain Modeling](/docs/solverforge/modeling/)** — Derive macros for solutions, entities, and
  problem facts
- **[Constraints](/docs/solverforge/constraints/)** — Constraint streams,
  projected scoring rows, existence, joiners, collectors, and score types
- **[Solver](/docs/solverforge/solver/)** — Configuration, construction, local
  search, moves, termination, and SolverManager
