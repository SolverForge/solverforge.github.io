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
documentation tracks the published `solverforge 0.14.0` crate and calls out
published crates.io and CLI scaffold targets separately. The public
`solverforge 0.14.0` package is available on crates.io; the published
`solverforge-cli 2.0.4` package scaffolds generated apps on the
`solverforge 0.11.1` runtime target.
<% end %>

## Current Status

| Component     | Status              | Description |
| ------------- | ------------------- | ----------- |
| **Rust Core** | Published | Native Rust constraint solver published as `solverforge 0.14.0` |
| **CLI Scaffold** | Published | `solverforge-cli 2.0.4` scaffolds `solverforge 0.11.1`, `solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4`; generated apps can be manually upgraded to the published `0.14.0` runtime |
| **UI** | Published | `solverforge-ui 0.6.5` is the current UI patch line |
| **Maps** | Published | `solverforge-maps 2.1.4` carries matrix route-distance access |

## Try It Today

- Start with [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
  for the generic app shell.
- Continue with the worked use-case bundle:
  [Hospital](/docs/getting-started/solverforge-hospital-use-case/),
  [Lessons](/docs/getting-started/solverforge-lessons-use-case/),
  [Deliveries](/docs/getting-started/solverforge-deliveries-use-case/), or
  [FSR](/docs/getting-started/solverforge-fsr-use-case/).
- Use [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  when scoring needs retained rows derived from source entities or joined pairs.

## Completed Runtime Surface

- **Constraint Streams API**: source-aware generated source methods, `for_each`,
  `filter`, unified `join(...)`, direct cross-join `group_by(...)`,
  direct cross-join grouped complements, `flatten_last`, `project(...)`,
  projected grouped complements, `balance`, `complement(...)`,
  `if_exists(...)`, `if_not_exists(...)`,
  `collect_vec(...)`, `indexed_presence(...)`, explicit score weighting, and
  `.named(...)`
- **Score Types**: SoftScore, HardSoftScore, HardMediumSoftScore,
  HardSoftDecimalScore, BendableScore
- **Score Analysis**: facade-level `ScoreAnalysis` and `ConstraintAnalysis`,
  plus lower-level detailed match/explanation APIs in `solverforge-scoring`
- **SERIO Engine**: retained incremental scoring for real-time optimization
- **Solver Phases**: scalar/list construction heuristics, assignment-backed
  grouped scalar construction, streaming local search, VND as a local-search
  type, and typed custom, exact, or partitioned search extensions
- **Move System**: scalar, list, grouped scalar, assignment repair,
  conflict repair, cartesian, and composite move families
- **SolverManager API**: retained job lifecycle with progress, best-solution,
  pause/resume, completion, cancellation, failure, snapshots, and
  snapshot-bound analysis
- **Configuration**: stock `solver.toml`, TOML/YAML parsing helpers, bounded
  scalar candidates, grouped scalar selectors, level-aware simulated annealing,
  and per-solution config overlays

## Runtime Notes

- **0.14.0 published baseline**: the core crate version is `0.14.0` and the
  Rust toolchain floor remains `1.95`.
- **Generated source methods**: `#[planning_solution]` now exposes collection
  sources as solution-associated functions such as `Schedule::shifts()`.
  Constraint streams use those generated methods through
  `ConstraintFactory::for_each(...)`.
- **Assignment-backed scalar groups**: `ScalarGroup::assignment(...)` declares
  required nullable scalar slots, capacity keys, sequence/position hooks, and
  construction ordering; grouped construction and `grouped_scalar_move_selector`
  consume the same `group_name` from `solver.toml`.
- **Collectors**: `consecutive_runs(...)`, `collect_vec(...)`, and
  `indexed_presence(...)` cover streaks, owned grouped payloads, and ordinal
  presence/complement checks. The underlying `Collector<Input>` contract is
  generic over the stream match shape, so unary rows, projected rows, and direct
  cross-join pairs use the same collector protocol.
- **Scoring terminals**: the current stream surface uses `penalize(score)`,
  `reward(score)`, typed dynamic closures, `fixed_weight(...)`, and
  `hard_weight(...)`; the older `penalize_hard`, `penalize_with`, and
  `reward_soft` helper family is historical.
- **Public runtime names**: direct runtime assembly APIs use `RuntimeModel`,
  `VariableSlot`, `ScalarVariableSlot`, `ListVariableSlot`, `ScalarGroup`,
  `ScalarAssignmentRule`, `ConflictRepair`, `RepairCandidate`, and
  `RepairLimits`.
- **Facade configuration exports**: app code can import `SolverConfig`,
  `PhaseConfig`, `MoveSelectorConfig`, `AcceptorConfig`, `ForagerConfig`,
  `SolverConfigOverride`, and related enums directly from `solverforge`.
- **Typed custom search**: solutions can compile in search code with
  `#[planning_solution(search = "...")]`, register named phases through
  `SearchContext`, and order those names from `solver.toml`.
- **Joined-pair projected rows**: cross joins can use
  `.project(|left, right| row)` to retain one scoring row per joined pair.
- **Direct cross-join grouping**: cross joins can group joined pairs with
  `.group_by(|left, right| key, collector)` without projecting first.
- **Projected grouped complements**: projected grouped streams can continue into
  `complement(...)` or `complement_with_key(...)` for missing-key scoring rows.
- **Direct cross-join grouped complements**: direct cross joins can group joined
  pairs and then call `complement(...)` against a generated fact or entity
  source for zero-match target rows.
- **Filtered keyed joins**: filtered right-hand join sources, flattened keyed
  targets, custom keyed extractors, and filtered complement sources retain only
  rows that still satisfy their source filters.
- **Clone-free projected paths**: projected outputs, projected self-join keys,
  and grouped collector values no longer need `Clone` in the `0.11.x` release
  line.
- **Joined filter indexes**: low-level joined filters receive semantic source
  indexes for direct, grouped, projected, flattened, and higher-arity joins.
- **Owner-aware route hooks**: list construction uses shared route hooks
  `route_get_fn`, `route_set_fn`, `route_depot_fn`, `route_distance_fn`, and
  `route_feasible_fn` for Clarke-Wright and k-opt, and Clarke-Wright keeps
  merged routes bound to the owner whose route context scored them.
- **Borrowed constraint identity**: scoring metadata preserves full
  `ConstraintRef` identity borrowed from the owning constraint.
- **Model-owned scalar hooks**: `candidate_values`,
  `nearby_value_candidates`, `nearby_entity_candidates`,
  `construction_entity_order_key`, and `construction_value_order_key` declare
  bounded scalar neighborhoods and construction ordering on the model.
- **Model-aware defaults**: omitted runtime config builds construction plus one
  streaming local-search phase; omitted `move_selector` values use typed
  scalar/list/grouped defaults rather than prebuilding broad neighborhoods.
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
