---
title: "Crate & Runtime Map"
description: "A practical map of the SolverForge workspace and the companion repos around it."
---

# Crate & Runtime Map

Use this page when you need to decide which crate or companion repository should
own a piece of work.

## Default starting point

For most application code, depend on `solverforge` and stay on the facade until
you have a concrete reason to go lower-level.

This map is aligned with the published `solverforge 0.23.0` crate and current
release workspace.

The facade re-exports the normal modeling, scoring, projection, configuration,
custom-search, and retained runtime surface, including
`solverforge_constraints`, `Projection`, `ProjectionSink`, `SolverConfig`,
`PhaseConfig`, `MoveSelectorConfig`, `SearchContext`, `CustomSearchPhase`,
`ScalarGroup`, `ScalarAssignmentRule`, `ScalarGroupLimits`,
`SharedNodeDiagnostics`, `SharedNodeId`, `SharedNodeOperation`, direct
cross-join `.group_by(|left, right| key, collector)`, cross-join
`.project(|left, right| row)` projected scoring, row-aware chained cross joins
through `Bi`, `Tri`, `Quad`, `Penta`, and an arity-free `Chain`, direct cross-join grouped
complements, symmetric and directed projected self-joins, projected grouped
complements, score weight helpers such as `fixed_weight` and `hard_weight`,
collector helpers such as `count`, `sum`, `load_balance`, `consecutive_runs`,
`collect_vec`, and `indexed_presence`, plus advanced grouped-scalar assignment,
conflict-repair extension types, phase and move-label telemetry, bounded
applied-move and candidate-pull traces, candidate-trace provenance types, and
CVRP profile helpers such as `domain = "cvrp"`, `route_hooks`,
`savings_hooks`, `savings_metric_class`, `route_distance`, `route_feasible`, and
`savings_feasible`. The grouped-scalar construction cursors, runtime model,
provider, and candidate-metric registries are solver-internal; applications
reach grouped construction through `ScalarGroup::assignment(...)`,
`group_name`, and `grouped_scalar_move_selector` rather than by importing those
types. That keeps app code on `solverforge` unless it needs to implement
lower-level solver internals directly.

## Workspace crates

| Crate                 | Owns                                                                     | Reach for it when...                                                           |
| --------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `solverforge`         | the public facade and re-exports                                         | you are building an app and want the normal public API                         |
| `solverforge-core`    | score types, descriptors, domain traits, and dynamic capability contracts | you are extending lower-level abstractions or implementing core-facing helpers |
| `solverforge-macros`  | `#[planning_solution]`, `#[planning_entity]`, `#[problem_fact]`, `#[solverforge_constraints]` | you need derive behavior, model glue, or constraint-function compilation |
| `solverforge-scoring` | constraint streams, typed relational operators and terminals, incremental scoring, and shared grouped node state | you are working directly on scoring internals or advanced scoring extensions |
| `solverforge-config`  | TOML/YAML parsing, resolved selector policy, candidate-trace config, acceptors, and builders | you need direct config construction or parsing outside the stock solve path    |
| `solverforge-solver`  | runtime compiler, phases, cursor selectors, retained lifecycle, and telemetry | you are building custom runtime behavior beyond facade-level use               |
| `solverforge-bridge`  | dynamic binding contracts, logical IDs, scores, explicit slot capabilities, and the compiled runner | you are implementing or maintaining a binding layer |
| `solverforge-console` | tracing-driven console output                                            | you want the standard terminal UX or progress formatting                       |
| `solverforge-cvrp`    | CVRP-specific helpers and distance utilities                             | your problem is route-centric and the domain benefits from these helpers       |

## Relational scoring internals

Fluent cross joins and same-collection unique combinations score through
`constraint::relational::OperatorTerminal`. Cross joins nest `JoinNode`s;
same-collection combinations use `SelfJoinNode` with an identity-preserving
filter. The old `cross_bi_incremental`, `cross_tri_incremental`, and per-arity
self-join incremental constraint modules are no longer the implementation.
Every grouped stream — unary, cross-join, projected, and complemented — lowers
onto the one `stream::relational::operator::GroupNode` accumulator; chained
terminals over a shared group share that operator owner through
`constraint::relational::shared_terminal`, scored and explained per terminal.

Named cross `Bi`/`Tri`/`Quad`/`Penta` streams adapt the common tree. Cross
`Penta::join` returns `stream::chain::Chain`; subsequent `Chain::join` calls
extend it without a fixed arity ceiling. Each chained condition compiles
independently, receives the whole prior borrowed row, and can use a key domain
different from earlier relationships. Chain filters and weights receive the
typed row rather than a new positional closure signature for every arity.
Every continuation — `Bi::join`, `Tri::join`, `Quad::join`, `Penta::join`,
and `Chain::join` — uses `equal_on` with the whole prior borrowed row on the
left and `&Leaf<'_, NewEntity>` on the right. Select bindings through nested
`.left` / `.right` and read fields through `.entity`. `equal_bi` with plain
entity closures belongs to the first unary join and fails at a continuation
(`E0631`). The cross-Penta continuation drops its authored penta filter;
apply the row filter on the returned `Chain`. Same-source
`PentaConstraintStream` is terminal.

Fluent right-hand targets implement `CollectionExtract`, including filtered
unary streams. Arbitrary compatible derived producers can feed either low-level
`JoinNode` input, but are not interchangeable fluent collection targets.
For the first unary keyed equality cross-join, the left unary filter becomes
source membership before key extraction and pair creation. Original source
indexes and incremental metadata are preserved; post-join filters remain joined
row filters. This left-source pushdown does not apply to comparison, overlap,
composed-condition, predicate, or same-source self-join dispatch.

Low-level `stream::relational::operator` types compose collection, filter,
merge, project, group, join, self-join, existence, flatten, and complement
producers. Derived payloads belong to evaluation or retained-state owners;
borrowed views and generational row identities preserve lineage without
retaining solution references. Group and membership changes can replace rows
during either retraction or insertion, so consumers process both removed and
inserted handles from each notification.

`Operator::retract` and `Operator::insert` emit into caller-owned
`&mut Vec<RowHandle>` buffers. Nodes pass their reused scratch
pairs through their children rather than allocating a returned change object
per hop; buffers can still grow when more handles are needed. Relational
operators reuse retired link, flattened
child-handle, and hash-bucket vectors, and internal index maps use the private
`stream/relational/hash.rs` deterministic fast hasher while ordered and interval
side-tables use generation-checked `HandleMap`s; `v0.19.12` kept occupied hash
buckets and surviving existence match lists in place during unlinking, and
`v0.19.13` replaced the linked existence engine with per-key occurrence counts
(dense tables for `usize` planning-id keys, hash tables otherwise), leaving
`JoinerExistenceNode` as the compiled-plan semi/anti engine for residual
predicates and moving complement default restoration to retained plan keys
(`KeyOf`). Buffer reuse does not bypass old-key removal, generational checks,
residual predicates, or duplicate-notification handling, and does not promise
public iteration order or allocation-free updates. Exact `ViewEqualPlan`
candidates rely on their equality bucket rather than re-extracting both keys;
composed plans still evaluate residual conditions. See
[Joiners](/docs/solverforge/constraints/joiners/) and
[Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/).

Dense existence count updates mark a touched key at most once per event; the
touched list stays unique and membership settles from final counts. Hash-key
storage, residual-predicate dispatch, and public authoring methods are
unchanged. Grouped-scalar default local search forages with
`AcceptedCount(256)` — the list-model policy — so a step sweeps until the
limit is accepted and applies the best.

Specialized unary and projected pair families remain, while grouped shapes —
including direct cross and projected grouped complements — run on the shared
kernel above. Existence and keyed
flattened terminals, and unary complemented groups, use the shared
`OperatorTerminal`. Reusable grouped-node sharing remains distinct from
compiler-owned sharing of arbitrary derived consumers. Check the
[tagged scoring implementation](https://github.com/SolverForge/solverforge/tree/v0.23.0/crates/solverforge-scoring/src)
when extending internals.

## Parallel Evaluation and Dynamic Scores

The compiled runtime evaluates acceptor-forager local-search windows on the
main score director plus persistent replicas when `move_thread_count` requests
at least two evaluators. The count is capped by the solve's Rayon pool and by
32; `auto` remains sequential. The scoring crate exports `DirectorDescriptor`
and `ReplicaDescriptor` for a borrowed descriptor plus `fn(&S) -> C`
constraint-set constructor. `ScoreDirector<S, C, Desc = SolutionDescriptor>`
forks initialized evaluators through `Director::fork_replica()` only when using
that replica descriptor. Configured native and bridge entry points accept the
constructor and share the same runtime path. See
[Extend the Solver](/reference/extend-solver/#evaluator-replicas-and-solve-entry-points).

`solverforge-bridge::DynamicScore` is a plain `{ hard, medium, soft }` value.
Equality, ordering, hashing, zero, and arithmetic depend only on those three
levels. Unused levels stay zero; decimal hard/soft levels use a scale of
100,000. `DynamicScore::of`, `soft`, and `hard_soft` construct values;
`family_levels(family)` chooses a host-facing level vector. Family is not a
score field or constructor argument. `scoped_dynamic_score_family` and
`active_dynamic_score_family` govern thread-local display and parsing only,
including whole-number scaling under `HardSoftDecimal`; worker scoring needs
no family scope. Bindings that hold a host global lock must release it on the
calling thread during a parallel solve so worker callbacks can acquire it.
The Python binding releases the GIL with `py.detach`, builds an independent
constraint set per evaluator, and exposes run/per-phase `moves_speculative`
with ordered `phases` records. GIL-enabled Python serializes callbacks;
free-threaded callbacks must not mutate shared state.

## Companion repositories

| Repo               | Owns                                                              | Use it when...                                              |
| ------------------ | ----------------------------------------------------------------- | ----------------------------------------------------------- |
| `solverforge-cli`  | scaffolding and code generation                                   | you are starting a new app or extending a generated shell   |
| `solverforge-py`   | the tagged `v0.7.0` Python source line, compiled-model PyO3 binding, retained diagnostics, native row-domain enforcement, and embedded UI asset bridge | you want Python model authoring backed by the Rust solver engine |
| `solverforge-ui`   | retained-job frontend controls and scheduling-facing components   | you need a web UI around a retained solve lifecycle         |
| `solverforge-maps` | road networks, routing, matrices, and map-backed planning helpers | you need route costs, geometry, or spatial planning support |

## Practical dependency rules

- Start with `solverforge-cli` to scaffold the app shell.
- Start with the PyPI `solverforge` package when the application surface is
  Python and you do not need a generated Rust web/API/CLI shell. PyPI publishes
  `solverforge 0.7.0`; use the matching `solverforge-py v0.7.0` tag for source
  and example development on SolverForge 0.23.0.
- Keep application code on the `solverforge` facade unless a lower-level crate
  unlocks something you actually need.
- Keep scalar/list model declarations in the `planning_model!` manifest and
  variable attributes; solver config consumes declared hooks rather than
  inferring nearby or construction-order behavior.
- Use scalar variables for direct assignments and list variables for ordered
  membership; there is no separate chained-scalar sequence model.
- Keep reusable grouped constraint work inside a
  `#[solverforge_constraints]` function; do not add app-level caches or public
  sharing helpers.
- Add `solverforge-ui` only if the product needs retained-job UI flows.
- Add `solverforge-maps` only if routing or map-backed costs are part of the
  planning model.
- Use `solverforge-py` for Python classes, decorators, explicit scalar/list
  metadata, callbacks, candidate metrics, retained jobs and diagnostics, and
  embedded UI assets over the native Rust engine.
- Reach into `solverforge-solver` directly only when configuration and the
  public facade stop being enough.
- Reach into `solverforge-scoring` module-scoped names such as
  `stream::projected::DirectedBi` or `constraint::projected::DirectedBi` only
  when you are extending scoring internals; application constraints should use
  the fluent `join(equal_bi(...))` surface.

## Typical stacks

| Scenario                           | Typical stack                                          |
| ---------------------------------- | ------------------------------------------------------ |
| service or CLI planner             | `solverforge-cli` scaffold + `solverforge`             |
| Python-authored planner            | PyPI `solverforge` package or the `solverforge-py v0.7.0` source tag |
| web app with retained lifecycle UI | `solverforge-cli` + `solverforge` + `solverforge-ui`   |
| routing or fleet optimization      | `solverforge-cli` + `solverforge` + `solverforge-maps` |
| research or advanced runtime work  | `solverforge` plus selected lower-level crates         |

## What not to do

- Do not start on the lowest-level crates unless the public API is clearly
  insufficient.
- Do not push app-specific business rules into SolverForge crates just because
  the extension point exists.
- Do not treat `solverforge-ui` or `solverforge-maps` as part of this
  repository's workspace; they are companion repos with their own release lines.
## See also

- [SolverForge docs](/docs/solverforge/)
- [SolverForge Python docs](/docs/solverforge-python/)
- [Integration Boundaries](/reference/integration-surfaces/)
- [Modeling Cheat Sheet](/reference/modeling-cheat-sheet/)
