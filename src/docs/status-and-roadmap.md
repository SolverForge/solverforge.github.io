---
title: "Status & Roadmap"
description:
  Current SolverForge release, published package status, completed runtime
  surface, and roadmap.
weight: 2
---

# Status & Roadmap

<%= render Ui::Callout.new do %>
SolverForge is a **production-ready constraint solver** written in Rust. This
documentation tracks the published `solverforge 0.11.1` crate and calls out
published crates.io and CLI scaffold targets separately. The public
`solverforge 0.11.1` package is now available on crates.io; the published
`solverforge-cli 2.0.4` package scaffolds generated apps on the
`solverforge 0.11.1` runtime target.
<% end %>

## Current Status

| Component     | Status              | Description |
| ------------- | ------------------- | ----------- |
| **Rust Core** | Published | Native Rust constraint solver published as `solverforge 0.11.1` |
| **CLI Scaffold** | Published | `solverforge-cli 2.0.4` scaffolds `solverforge 0.11.1`, `solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4` |
| **UI** | Published | `solverforge-ui 0.6.5` is the current UI patch line |
| **Maps** | Published | `solverforge-maps 2.1.4` carries matrix route-distance access |

## Try It Today

- Start with [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
  for the generic app shell.
- Continue with the
  [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
  or the
  [SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/).
- Use [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  when scoring needs retained rows derived from source entities or joined pairs.

## Completed Runtime Surface

- **Constraint Streams API**: source-aware generated accessors, `for_each`,
  `filter`, unified `join(...)`, `flatten_last`, `project(...)`, `group_by`,
  `balance`, `if_exists(...)`, `if_not_exists(...)`, terminal scoring methods,
  and `.named(...)`
- **Score Types**: SoftScore, HardSoftScore, HardMediumSoftScore,
  HardSoftDecimalScore, BendableScore
- **Score Analysis**: facade-level `ScoreAnalysis` and `ConstraintAnalysis`,
  plus lower-level detailed match/explanation APIs in `solverforge-scoring`
- **SERIO Engine**: retained incremental scoring for real-time optimization
- **Solver Phases**: construction heuristics, local search, exhaustive search,
  partitioned search, and VND
- **Move System**: scalar, list, grouped scalar, conflict repair, cartesian, and
  composite move families
- **SolverManager API**: retained job lifecycle with progress, best-solution,
  pause/resume, completion, cancellation, failure, snapshots, and
  snapshot-bound analysis
- **Configuration**: stock `solver.toml`, TOML/YAML parsing helpers, bounded
  scalar candidates, grouped scalar selectors, level-aware simulated annealing,
  and per-solution config overlays

## Runtime Notes

- **0.11.1 published baseline**: the core crate version is `0.11.1` and the
  Rust toolchain floor remains `1.95`.
- **Facade configuration exports**: app code can import `SolverConfig`,
  `PhaseConfig`, `MoveSelectorConfig`, `AcceptorConfig`, `ForagerConfig`,
  `SolverConfigOverride`, and related enums directly from `solverforge`.
- **Facade recording director export**: extension code that needs trial-move
  rollback can import `RecordingDirector` from the facade beside `Director` and
  `ScoreDirector`.
- **Joined-pair projected rows**: cross joins can use
  `.project(|left, right| row)` to retain one scoring row per joined pair.
- **Clone-free projected paths**: projected outputs, projected self-join keys,
  and grouped collector values no longer need `Clone` in the `0.11.x` release
  line.
- **Borrowed constraint identity**: scoring metadata preserves full
  `ConstraintRef` identity borrowed from the owning constraint.
- **Model-owned scalar hooks**: `candidate_values`,
  `nearby_value_candidates`, `nearby_entity_candidates`,
  `construction_entity_order_key`, and `construction_value_order_key` declare
  bounded scalar neighborhoods and construction ordering on the model.
- **Exact retained telemetry**: generated, evaluated, accepted, not-doable,
  acceptor-rejected, forager-ignored, hard-delta, conflict-repair, and
  construction-slot counters are retained as authoritative counters.

## Roadmap

### Native Solver Complete

The Rust-native constraint solver, derive macros, SERIO scoring engine,
retained runtime lifecycle, and stock configuration surface are in place.

### Rust API Refinement

Current work focuses on tightening public API contracts, making scoring and
runtime paths easier to explain, and keeping source, docs, examples, and CLI
scaffolds aligned as releases move.

### Language Bindings

Python and other language bindings remain future-facing. The Rust core remains
the source of truth for solver behavior and docs.

## How You Can Help

- [Follow the getting started guides](/docs/getting-started/) and share
  feedback.
- [Open an issue](https://github.com/solverforge/solverforge/issues) for bugs
  or unclear docs.
- Star the [GitHub repo](https://github.com/solverforge/solverforge) and share
  real planning use cases.
