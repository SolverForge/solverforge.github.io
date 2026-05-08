---
title: Architecture
description:
  Crate responsibilities, zero-erasure design, SERIO scoring, and retained
  runtime pieces.
weight: 3
---

# Architecture

SolverForge is a native Rust constraint solver. It keeps the public facade
small while preserving concrete types through the solver pipeline.

## Workspace Shape

```text
solverforge
├── solverforge          facade and public re-exports
├── solverforge-core     score types, descriptors, domain traits
├── solverforge-macros   planning derive macros and planning_model!
├── solverforge-scoring  constraint streams and SERIO scoring
├── solverforge-config   TOML/YAML config model and builders
├── solverforge-solver   phases, moves, selectors, runtime, manager
├── solverforge-console  tracing-driven console output
└── solverforge-cvrp     route-centric helpers and distance meters
```

For most app code, depend on `solverforge` and stay on the facade. Reach for
lower-level crates only when extending SolverForge itself or building a custom
runtime path.

## Zero-Erasure Runtime

SolverForge preserves concrete types through scoring, moves, phases, and
runtime assembly:

- no `Box<dyn Iterator>` in hot move selectors
- no hidden allocation for ordinary moves
- move payloads stored inline or in arena-owned candidate storage
- score directors and stream constraints monomorphized by solution and score
  type
- deterministic selector order for reproducible local search

The descriptor boundary remains explicit for generated scalar/list model
metadata, but app code should not need to construct descriptor-level runtime
pieces directly.

## SERIO Scoring

SERIO, the Scoring Engine for Real-time Incremental Optimization, evaluates
constraints incrementally as moves are explored. Constraint streams compile to
typed scoring structures, and generated collection source methods carry source
metadata so localized updates hit the right planning-entity collection.

Projected scoring rows are retained inside this layer. They are useful when a
constraint needs a scoring-only row from one source entity or one joined pair
without materializing a problem fact.

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
snapshot while the job is active or terminal.

## Configuration Boundary

`solver.toml` selects declared capabilities; it does not invent model hooks.
Nearby scalar selectors require nearby candidate hooks on the model. Grouped
scalar selectors require named scalar groups. Conflict repair selectors require
constraint-aware repair providers.

That boundary keeps the runtime honest: the model declares what it can produce,
and config chooses which declared search paths to run.

## See Also

- [Crate & Runtime Map](/reference/crate-map/) - practical ownership map
- [Solver Configuration](/docs/solverforge/solver/configuration/) - runtime config surface
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - retained scoring rows
