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
documentation tracks the `solverforge 0.19.0` tag and calls out
published crates.io, docs.rs, CLI scaffold targets, UI assets, maps, and Python
bindings separately. The `v0.19.0` tag, workspace, and crates.io package are the
current core runtime line. The GitHub Release and all nine workspace crates
were published on 2026-07-17, and docs.rs serves the 0.19.0 API.
The independently published `solverforge-cli 2.2.2` package still scaffolds
generated apps on `solverforge 0.15.2`, `solverforge-ui 0.6.5`, and
`solverforge-maps 2.1.4`. The worked-use-case bundle still ships
`solverforge-hospital@2.0.4`, `solverforge-lessons@2.0.4`,
`solverforge-deliveries@2.0.4`, and `solverforge-fsr@2.0.5`, all on
`solverforge 0.18.0`; bundle CI and the four
Space sync workflows pass at the tagged commit. SolverForge Python has a tagged
`solverforge-py 0.6.2` source line for CPython 3.14, compiled onto the
`solverforge 0.19.0` runtime with embedded `solverforge-ui 0.7.0` assets. The
automatic release workflow completed and PyPI serves `solverforge 0.6.2`;
GitHub CI and the final-tag release workflow both pass.
<% end %>

## Current Status

| Component     | Status              | Description |
| ------------- | ------------------- | ----------- |
| **Rust Core** | Published | Native Rust constraint solver published as `solverforge 0.19.0` |
| **CLI Scaffold** | Published | `solverforge-cli 2.2.2` scaffolds `solverforge 0.15.2`, `solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4` |
| **Python** | Published; CI and release passed | `solverforge-py 0.6.2` compiles dynamic CPython 3.14 models into the `solverforge 0.19.0` runtime; PyPI publishes `solverforge 0.6.2` |
| **Worked Use Cases** | Released, CI passed | `solverforge-hospital@2.0.4`, `solverforge-lessons@2.0.4`, `solverforge-deliveries@2.0.4`, and `solverforge-fsr@2.0.5`; all target `solverforge 0.18.0` and `solverforge-ui 0.6.5` |
| **UI** | Published | `solverforge-ui 0.7.0` exposes framework-neutral embedded assets; CLI scaffolds still pin `solverforge-ui 0.6.5` |
| **Maps** | Published | `solverforge-maps 2.1.4` carries matrix route-distance access |

## Try It Today

- Start with [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
  for the generic app shell.
- Use [SolverForge Python](/docs/solverforge-python/) when you want to define
  models with Python classes, decorators, and callbacks while using the native
  SolverForge engine.
- Continue with the worked use-case bundle:
  [Hospital](/docs/getting-started/solverforge-hospital-use-case/),
  [Lessons](/docs/getting-started/solverforge-lessons-use-case/),
  [Deliveries](/docs/getting-started/solverforge-deliveries-use-case/), or
  [FSR](/docs/getting-started/solverforge-fsr-use-case/). Those guides now
  document the released Hospital, Lessons, and Deliveries 2.0.4 and FSR 2.0.5
  contracts on `solverforge 0.18.0`, while keeping their recorded
  scaffold provenance separate from the published `solverforge-cli 2.2.2`
  scaffold target.
- Use [Constraint Node Sharing](/docs/solverforge/constraints/node-sharing/)
  when a constraint function reuses the same grouped stream across several
  named terminal constraints.
- Use [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  when scoring needs retained rows derived from source entities, joined pairs,
  or oriented relationships between projected rows.

## Completed Runtime Surface

- **Constraint Streams API**: source-aware generated source methods, `for_each`,
  `filter`, unified `join(...)`, direct cross-join `group_by(...)`,
  direct cross-join grouped complements, `flatten_last`, `project(...)`,
  projected grouped complements, `balance`, `complement(...)`,
  `if_exists(...)`, `if_not_exists(...)`,
  `collect_vec(...)`, `indexed_presence(...)`, explicit score weighting, and
  `.named(...)`
- **Projected Scoring Rows**: bounded single-source rows, joined-pair projected
  rows, symmetric projected self-joins through `equal(...)`, and directed
  projected self-joins through `equal_bi(left_key, right_key)`
- **Constraint Compiler Node Sharing**: `#[solverforge_constraints]` can share
  grouped, projected grouped, direct cross grouped, and complemented grouped
  stream nodes across repeated terminal constraints while preserving terminal
  names, order, metadata, and score explanation
- **Score Types**: SoftScore, HardSoftScore, HardMediumSoftScore,
  HardSoftDecimalScore, BendableScore
- **Score Analysis**: facade-level `ScoreAnalysis` and `ConstraintAnalysis`,
  plus lower-level detailed match/explanation APIs in `solverforge-scoring`
- **SERIO Engine**: retained incremental scoring for real-time optimization
- **Solver Phases**: scalar/list construction heuristics, assignment-backed
  grouped scalar construction, streaming local search, VND as a local-search
  type, precedence-list neighborhoods, and typed custom, exact, or partitioned
  search extensions
- **Move System**: scalar, list, grouped scalar, assignment repair,
  conflict repair, cartesian, and composite move families
- **Runtime Compiler**: one immutable resolved graph for native and dynamic
  construction, selector trees, providers, stable list sources, defaults, and
  execution errors
- **SolverManager API**: retained job lifecycle with progress, best-solution,
  pause/resume, completion, cancellation, failure, snapshots, and
  snapshot-bound analysis, active-phase telemetry, and explicit candidate-trace
  detail retrieval
- **Configuration**: stock `solver.toml`, TOML/YAML parsing helpers, bounded
  scalar candidates, grouped scalar selectors, per-leaf ordering and metrics,
  weighted unions, seeded score ties, candidate tracing, level-aware simulated
  annealing, and per-solution config overlays

## Python Package

- **Install**: `python3.14 -m pip install "solverforge==0.6.2"`; use the
  matching `solverforge-py` `v0.6.2` tag for source and example development.
- **Modeling**: Python classes, decorators, scalar variables, list variables,
  explicit assignment metadata, scoped route/savings bundles, named candidate
  metrics, and callback constraints.
- **Runtime entry points**: `Solver.solve(...)`, `Solver.analyze(...)`, and
  `SolverManager(config=None)` over one compiled SolverForge 0.19.0 runtime graph.
- **Constraint surface**: callback-authored unary streams, binary stream-level
  joins, grouped counts, balance scoring, fixed or callback-computed weights,
  unassigned-list scoring, list precedence/makespan scoring, indexed-presence
  grouped collectors, and `joiner.equal(...)` / `joiner.equal_bi(...)`.
- **Dynamic move parity**: supported scalar and list local-search selectors,
  including grouped scalar, conflict repair, compound conflict repair, k-opt,
  list precedence, list permute, list ruin, union, limited neighborhood, and
  two-child cartesian composition.
- **Retained diagnostics**: phase telemetry, bounded format-3 candidate traces,
  atomic `telemetry_detail(...)`, and optional immutable
  `QualifiedCandidateTraceProvenance` supplied per managed job.
- **Compiled scoring boundary**: proven fixed-weight unary, unassigned-list,
  precedence, and stable string-key equality plans can evaluate natively while
  callback-dependent shapes preserve the Python path.
- **Examples**: hospital scheduling with row-filtered scalar candidates and
  nearby metadata, plus deliveries routing with unassigned seed routes and
  explicit route/savings bundles; both expose retained jobs, exact snapshots,
  phase telemetry, analysis, and shared `solverforge-ui` assets from the native
  bridge.

## Runtime Notes

- **0.19.0 runtime line**: `v0.19.0` and the crates.io `solverforge 0.19.0`
  package are current, and the Rust toolchain floor remains `1.95`. The
  published `solverforge-cli 2.2.2` package targets `solverforge 0.15.2`;
  generated app manifests should move to `solverforge 0.19.0` only when that app
  is deliberately upgraded and validated.
- **One sequence model**: planning list variables are the canonical model for
  routes and ordered assignments. They own the sequence directly and retain
  inverse, index, previous, next, custom, cascading, and piggyback shadows.
  Scalar variables remain direct single-slot assignments; the former
  predecessor-chain surface and its chain-only anchor shadow are no longer
  part of the public runtime.
- **One compiled runtime graph**: native Rust and dynamic bridge models resolve
  construction stages, recursive selector trees, providers, stable list-source
  identities, defaults, and termination into one immutable graph before
  solving. Declaration, compilation, preparation, and execution errors are
  explicit; there is no parallel configured-search fallback.
- **Resolved selector policy**: leaf selectors can use original, seeded random,
  shuffled, sorted, or probabilistic order; sorted/probabilistic leaves require
  a registered candidate metric. Unions support sequential, round-robin,
  rotating-round-robin, random, and default stratified-random scheduling with
  equal, fixed, or candidate-count weighting. Equal best scores use seeded
  random tie-breaking by default.
- **Cursor-owned candidate execution**: shared scalar/list kernels expose stable
  candidate IDs, let foragers short-circuit without draining a neighborhood,
  and transfer only the selected winner by value. Generated counts represent
  actual cursor yields rather than an unrequested logical tail.
- **Qualified candidate traces**: `[candidate_trace]` retains a bounded ordered
  prefix with canonical config, resolved plan, execution policy, input,
  operation identity, and disposition provenance. Detailed traces are fetched
  atomically through `SolverManager::get_telemetry_detail(...)`; routine events
  and snapshots keep only compact telemetry.
- **Dynamic capability contracts**: bridge models declare scalar legality and
  nearby sources, list mutation operations, immutable list metadata bundles,
  and scalar-assignment metadata explicitly. Host compound providers and
  optional candidate metrics are frozen per solve instead of discovered through
  mutable schema or thread-local state in cursor execution.
- **Lifecycle settlement**: pause and cancellation are polled around phases and
  terminal hooks as well as inside long candidate work. Paused time is excluded
  from active phase telemetry, and pending control cannot be overwritten by
  ordinary completion.
- **0.17.2 construction surface**: advanced solver integrations can import
  dynamic construction primitives such as `GroupedScalarCursor`,
  `GroupedScalarSelector`, `ScalarAssignmentMoveCursor`,
  `ScalarAssignmentMoveOptions`, and
  `ScalarAssignmentRequiredStreamingCursor`. Required assignment construction
  now streams state instead of relying only on a closed internal batch path.
- **0.17.1 route safety fixes**: stock CVRP helpers reject unreachable
  travel-time legs during strict feasibility checks, convert unreachable or
  malformed distance entries into a large finite cost for construction/search,
  and clamp route-distance arithmetic used by Clarke-Wright and k-opt.
- **CVRP list profile**: stock CVRP list variables can declare
  `domain = "cvrp"`. The profile supplies the CVRP solution trait, distance
  meters, strict route-local hooks, relaxed Clarke-Wright savings hooks, and
  savings metric class.
- **Route and savings hooks**: custom routing list variables can still split
  route-local behavior from Clarke-Wright construction explicitly.
  `route_hooks` exports `get`, `set`, `depot`, `distance`, and `feasible`;
  `savings_hooks` exports `depot`, `distance`, and `feasible`;
  `savings_metric_class_fn` is the optional construction sharing hook.
- **Strict K-opt route feasibility**: stock CVRP route hooks reject capacity and
  time-window violations before k-opt commits a route. The stock savings hooks
  stay relaxed enough for Clarke-Wright construction to assign scoreable
  capacity or time-window violations when that is better than leaving work
  unassigned.
- **Clarke-Wright completion**: `ListClarkeWright` completes unmatched
  route elements instead of dropping work when no saving merge can place them.
- **Dynamic bridge crate**: `solverforge-bridge` carries host-language binding
  contracts for logical entity/fact/variable IDs, dynamic score families, and
  descriptor-resolved scalar/list slots. Python remains the first published
  binding, but the bridge contract is a Rust workspace crate.
- **Constraint node sharing**: annotate reusable constraint factory functions
  with `#[solverforge_constraints]`. Reused same-binding grouped streams and
  syntax-proved identical grouped chains share retained incremental node work;
  separate terminal constraints keep their own names, impact direction,
  metadata, and explanation rows.
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
- **Directed projected self-joins**: projected rows can use
  `.join(equal_bi(left_key, right_key))` when the left and right side of a
  same-row-type relationship are semantically different, such as parent-child
  projected rows.
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
- **CVRP profile and custom hook split**: stock CVRP routes should use
  `domain = "cvrp"`; custom route domains can wire `route_hooks`,
  `savings_hooks`, and optional `savings_metric_class_fn` explicitly.
  Construction savings can share a metric class without collapsing route-local
  assignment semantics.
- **Assignment value-pattern neighborhoods**: assignment-backed grouped scalar
  local search includes bounded value-window swaps, longer value-window swaps,
  same-sequence run-gap swaps, block reassignments, optional run releases, and
  three-value rotations. Required assignment construction still has a hard-first
  fill path for required slots, with public streaming state available for
  advanced construction integrations.
- **Borrowed constraint identity**: scoring metadata preserves full
  `ConstraintRef` identity borrowed from the owning constraint.
- **Model-owned scalar hooks**: `candidate_values`,
  `nearby_value_candidates`, `nearby_entity_candidates`,
  `construction_entity_order_key`, and `construction_value_order_key` declare
  bounded scalar neighborhoods and construction ordering on the model.
- **Model-aware defaults**: omitted runtime config builds construction plus one
  streaming local-search phase. Capability-matched leaves use seeded random
  order, multi-family unions use stratified-random scheduling, and
  assignment-owned scalar slots remain exclusively on their grouped path.
- **Exact retained telemetry**: generated, evaluated, accepted, not-doable,
  acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
  construction-slot, active-phase, move-label, and bounded applied-move counters
  are retained as authoritative counters; bounded candidate-pull detail is
  retained separately on explicit request.

## Roadmap

### Native Solver Complete

The Rust-native constraint solver, derive macros, SERIO scoring engine,
retained runtime lifecycle, and stock configuration surface are in place.

### Rust API Refinement

Current work focuses on tightening public API contracts, making scoring and
runtime paths easier to explain, and keeping source, docs, examples, and CLI
scaffolds aligned as releases move.

### Python Package

`solverforge-py 0.6.2` is the current tagged SolverForge Python source line for
CPython 3.14. It compiles explicit Python model metadata into the
`solverforge 0.19.0` runtime, removes the wrapper-owned search path, specializes
safe native constraint plans, adds qualified retained candidate diagnostics,
and keeps shared `solverforge-ui 0.7.0` assets. The automatic release workflow
published the 0.6.2 source distribution and CPython 3.14 wheels to PyPI. This
patch aligns the exact Rust crate set with SolverForge 0.19.0 without changing
the public Python API. Its source archive contains only the package metadata
and Python/Rust build inputs; repository tests, examples, guidance, and tooling
remain source-checkout assets.

### Additional Language Bindings

Other language bindings remain future-facing. The Rust core remains the source
of truth for solver behavior, while Python is the first published dynamic
binding.

## How You Can Help

- [Follow the getting started guides](/docs/getting-started/) and share
  feedback.
- [Open an issue](https://github.com/solverforge/solverforge/issues) for bugs
  or unclear docs.
- Star the [GitHub repo](https://github.com/solverforge/solverforge) and share
  real planning use cases.
