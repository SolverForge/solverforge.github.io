---
title: Architecture
description:
  Crate responsibilities, zero-erasure design, SERIO scoring, and retained
  runtime pieces.
weight: 3
---

# Architecture

SolverForge is a native Rust constraint solver. It keeps the public facade
small, compiles one immutable search graph before execution, and preserves
concrete types through the native solver pipeline.

## Workspace Shape

```text
solverforge
├── solverforge          facade and public re-exports
├── solverforge-core     score types, descriptors, domain traits
├── solverforge-macros   planning derive macros, planning_model!, and constraint compiler
├── solverforge-scoring  constraint streams and SERIO scoring
├── solverforge-config   TOML/YAML config model and builders
├── solverforge-solver   phases, moves, selectors, runtime, manager
├── solverforge-bridge   dynamic host-language binding contracts
├── solverforge-console  tracing-driven console output
└── solverforge-cvrp     route-centric helpers and distance meters
```

For most app code, depend on `solverforge` and stay on the facade. Reach for
lower-level crates only when extending SolverForge itself or building a custom
runtime path.

## Compiled Zero-Erasure Runtime

Every macro-generated Rust model and dynamic bridge model enters the same
runtime compiler. SolverForge resolves scalar/list slots, stable list-source
identities, construction stages, recursive selector trees, native or host
providers, candidate metrics, defaults, and termination policy before the first
phase runs. The resulting graph is immutable for that solve; declaration,
compilation, preparation, and execution failures are reported explicitly
instead of falling through to a second phase-builder path.

The native hot path keeps concrete types through scoring, moves, selectors, and
phases:

- GAT-based cursors expose stable candidate IDs without `Box<dyn Iterator>` in
  selector hot loops
- cursor-owned candidate storage releases losing moves and transfers the chosen
  move by value exactly once
- score directors, move carriers, selector carriers, and stream constraints are
  monomorphized by solution and score type
- deterministic canonical enumeration plus seeded ordering keeps reproducible
  search reproducible
- object-safe dispatch is confined to documented dynamic/host integration,
  descriptor access, scorer-agnostic callbacks, real-time problem changes,
  analysis, and cold panic-preservation boundaries

Descriptor scalar selectors remain an explicit standalone API. They do not
form an alternate construction or configured-search engine for generated
models.

The 0.19 model boundary is equally explicit: scalar slots are direct
single-value assignments, while list slots own ordered membership. Inverse,
index, previous, next, custom, cascading, and piggyback shadows are derived
views of that list; there is no second predecessor-chain topology in the
runtime.

## SERIO Scoring

SERIO, the Scoring Engine for Real-time Incremental Optimization, evaluates
constraints incrementally as moves are explored. Constraint streams compile to
typed scoring structures, and generated collection source methods carry source
metadata so localized updates hit the right planning-entity collection.

Projected scoring rows are retained inside this layer. They are useful when a
constraint needs a scoring-only row from one source entity or one joined pair
without materializing a problem fact. The current projected stream surface
distinguishes symmetric self-joins from directed same-row-type joins so
parent-child, predecessor-successor, and similar oriented scoring rows keep
their left/right semantics.

## Dynamic Bridge

`solverforge-bridge` owns the Rust contracts used by host-language bindings:
stable logical entity, fact, and variable IDs; dynamic score-family values;
descriptor-resolved scalar/list slots; dynamic scalar-assignment metadata; and
explicit list access and metadata capability bundles. Binding layers can build
dynamic models without depending on Rust `TypeId` as their public identity
model. The runtime resolves those logical IDs, validates legal-value and
operation capabilities, freezes host providers and optional candidate metrics,
and then executes the same compiled graph as native models.

## Constraint Compiler

`#[solverforge_constraints]` is the constraint-function compiler boundary. It
keeps the public fluent stream syntax but lets SolverForge share repeated
grouped nodes inside one annotated function. Same-binding grouped terminals and
syntax-proved identical grouped chains can share grouped, projected grouped,
direct cross grouped, and complemented grouped retained state.

The shared node owns extraction, join indexes, collector accumulators,
retraction tokens, dirty-key tracking, and localized update work once. Terminal
scorers remain separate, so names, impact direction, hard metadata, authored
order, and score explanation do not collapse into one constraint.

## Runtime Lifecycle

`SolverManager` exposes retained jobs instead of one-shot fire-and-forget
solves. A running job can emit:

- `Progress`
- `BestSolution`
- `PauseRequested`
- `Paused`
- `Resumed`
- `Completed`
- `Cancelled`
- `Failed`

Snapshots are retained by revision, and score analysis can target a retained
snapshot while the job is active or terminal. Pause and cancel requests are
settled at phase and terminal-hook boundaries as well as inside long-running
candidate work. Paused time is excluded from active phase telemetry, and a
pending control command cannot be overwritten by ordinary completion.

Compact events and status carry aggregate and active-phase telemetry. Opt-in
bounded candidate-pull traces are retained separately and fetched through
`SolverManager::get_telemetry_detail(...)`, so control-plane events do not clone
large diagnostic prefixes.

## Configuration Boundary

`solver.toml` selects declared capabilities; it does not invent model hooks.
Nearby scalar selectors require nearby candidate hooks on the model. Grouped
scalar selectors require named scalar groups. Conflict repair selectors require
constraint-aware repair providers. Sorted or probabilistic leaf ordering
requires a registered named candidate metric.

That boundary keeps the runtime honest: the model declares what it can produce,
and config chooses which declared search paths to run. The compiler freezes the
resolved selection order, union weighting, score tie policy, construction
obligations, and candidate-trace plan before solving.

## See Also

- [Crate & Runtime Map](/reference/crate-map/) - practical ownership map
- [Constraint Node Sharing](/docs/solverforge/constraints/node-sharing/) - compiler-backed grouped node sharing
- [Solver Configuration](/docs/solverforge/solver/configuration/) - runtime config surface
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - retained scoring rows
