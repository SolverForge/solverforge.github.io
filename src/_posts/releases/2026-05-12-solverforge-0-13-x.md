---
title: "SolverForge 0.13.x: Streaming Defaults, Typed Search, and Explicit Scoring"
date: 2026-05-12
draft: false
description: >
  SolverForge 0.13.x publishes streaming model-aware search defaults, typed
  custom search registration, match-shape collectors, direct cross-join
  grouping, and the explicit scoring terminal surface.
---

**SolverForge 0.13.x** was the previous core runtime line. It starts with
[0.13.0](https://crates.io/crates/solverforge/0.13.0), published on
2026-05-12, with API docs on
[docs.rs](https://docs.rs/solverforge/0.13.0). The 0.13.x patch is
[0.13.1](https://crates.io/crates/solverforge/0.13.1), published on
2026-05-14, with API docs at [docs.rs](https://docs.rs/solverforge/0.13.1).

The release was not a CLI scaffold refresh. `solverforge-cli 2.0.4` still
scaffolds `solverforge 0.11.1`, `solverforge-ui 0.6.5`, and
`solverforge-maps 2.1.4`. Direct Cargo projects and deliberately upgraded
generated apps can target the published `solverforge 0.13.1` crate.

## What Changed

### Scoring terminals are explicit

Constraint streams no longer expose the older helper family such as
`penalize_hard`, `penalize_with`, `reward_soft`, or `reward_hard_with`. Use
`penalize(score)`, `reward(score)`, or a typed dynamic closure:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_none())
    .penalize(HardSoftScore::ONE_HARD)
    .named("Unassigned shift");

Streams::new()
    .for_each(Schedule::shifts())
    .penalize(|shift: &Shift| HardSoftScore::of_soft(shift.preference_penalty()))
    .named("Preference penalty");
```

Dynamic closure weights are non-hard metadata by default. Wrap a fixed or
dynamic weight with `hard_weight(...)` when analysis metadata and
conflict-repair matching should classify the constraint as hard:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .penalize(hard_weight(|shift: &Shift| {
        HardSoftScore::of_hard(shift.overtime_hours() as i64)
    }))
    .named("Overtime");
```

### Collectors own grouped payloads

`collect_vec(...)` is now part of the public collector surface. It retains
mapped values once and exposes them as `CollectedVec<T>`, so grouped payloads do
not need `Copy`, `Clone`, or `PartialEq` just to be collected.

`indexed_presence(...)` adds a stock ordinal-presence collector for rules that
need covered and missing ranges. It pairs with the existing `count`, `sum`,
`load_balance`, and `consecutive_runs` collectors.

In `0.13.1`, collectors are generic over the stream match shape. The public
collector trait is `Collector<Input>`, so the same stock collector protocol
works for unary rows, projected rows, and joined pairs. Direct cross joins can
now group joined pairs without materializing projected rows first:

```rust
type Streams = ConstraintFactory<Plan, HardSoftScore>;

Streams::new()
    .for_each(Plan::assignments())
    .join((
        Streams::new().for_each(Plan::capacities()),
        equal_bi(
            |assignment: &Assignment| assignment.capacity_id,
            |capacity: &Capacity| Some(capacity.id),
        ),
    ))
    .group_by(
        |assignment: &Assignment, capacity: &Capacity| (assignment.id, capacity.id),
        sum(|(assignment, capacity): (&Assignment, &Capacity)| {
            capacity.amount - assignment.demand
        }),
    )
    .penalize(hard_weight(|_key: &(usize, usize), shortage: &i64| {
        HardSoftScore::of_hard((-*shortage).max(0))
    }))
    .named("Capacity shortage");
```

Projected grouped streams can also continue into `complement(...)` or
`complement_with_key(...)`, so supply/demand rules can group retained scoring
rows and still produce explicit rows for missing keys.

### Joined filters use source indexes

`0.13.1` fixes the last placeholder index path in joined filters. Low-level
Bi/Tri/Quad/Penta filter traits now receive semantic source indexes for the
rows being tested. Same-source joins use entity indexes, cross joins use left
and right source indexes, flattened rows use the left source index and owning
right-side source index, and projected self-joins use each projected row's
primary owner entity index.

Normal fluent `.filter(|a, b| ...)` predicates remain entity-oriented. This
matters when you implement low-level scoring extensions, inspect retained match
identity, or depend on localized incremental updates across direct cross,
projected, flattened, and higher-arity joins.

### Default search is streaming-first

When full `phases` are omitted, the runtime builds model-aware construction and
then one streaming local-search phase. When an explicit `acceptor_forager`
local-search phase omits `move_selector`, SolverForge now resolves typed
defaults from declared model capabilities:

- nearby scalar change/swap selectors when nearby hooks are present
- plain scalar change/swap fallbacks for non-assignment-owned scalar slots
- grouped scalar selectors for declared scalar groups
- conflict-repair selectors only when repair providers are registered
- nearby list change/swap, sublist change/swap, and reverse selectors for list
  variables, with k-opt and list ruin only when their hooks exist

Assignment-owned scalar variables stay on the grouped scalar path. Generic
scalar selectors and default conflict-repair selectors exclude those slots.

### VND is a local-search type

Variable Neighborhood Descent remains available, but it is configured as a
`local_search_type` on a local-search phase:

```toml
[[phases]]
type = "local_search"
local_search_type = "variable_neighborhood_descent"

[[phases.neighborhoods]]
type = "change_move_selector"
variable_name = "employee_idx"

[[phases.neighborhoods]]
type = "swap_move_selector"
variable_name = "employee_idx"
```

The old standalone `type = "vnd"` phase shape is not the current config
surface.

### Accepted-count is a real horizon

The accepted-count forager now means "collect this many accepted candidates in
the current step, then choose the best among them." Use `best_score` when the
search policy should scan the whole neighborhood.

### Typed custom search replaces class-name loading

Solutions can compile in custom search code with
`#[planning_solution(search = "...")]`. The search function receives a
`SearchContext`, registers typed phase names, and `solver.toml` orders those
names:

```toml
[[phases]]
type = "custom"
name = "weekend_repair"
```

SolverForge does not load arbitrary `custom_phase_class` strings or use an
erased plugin registry.

### Partitioned and exact search are typed surfaces

`partitioned_search` requires a named typed `SolutionPartitioner`; it does not
infer safe partitions from a count. Exact tree search is exposed through typed
runtime APIs such as `ExhaustiveSearchPhase`, `ExhaustiveSearchConfig`,
`ExplorationType`, and `SimpleDecider`, and should be registered as custom
search when an application owns the concrete decider.

## Install And Scaffold Status

For direct Cargo projects:

```toml
solverforge = { version = "0.13.1", features = ["serde", "console"] }
```

If you write custom incremental constraints that need lower-level identities,
the companion workspace crates are also published at the same 0.13.x patch:

```toml
solverforge-core = "0.13.1"
```

For generated apps, confirm the installed CLI target:

```bash
solverforge --version
```

`solverforge-cli 2.0.4` still reports:

```text
CLI version: 2.0.4
Scaffold runtime target: SolverForge crate target 0.11.1
Scaffold UI target: solverforge-ui 0.6.5
Scaffold maps target: solverforge-maps 2.1.4
Runtime source: crates.io: solverforge 0.11.1
UI source: crates.io: solverforge-ui 0.6.5
Maps source: crates.io: solverforge-maps 2.1.4
```

Generated apps created with that CLI start on `solverforge 0.11.1`. Move a
generated app to `solverforge 0.13.x` only when you are deliberately upgrading
that app's runtime dependency and validating the generated code against the
newer core crate.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.13.1` | 2026-05-14 | Generalizes collectors to `Collector<Input>`, adds direct cross-join grouping, allows projected grouped complements, and preserves semantic source indexes for joined filters. |
| `0.13.0` | 2026-05-12 | Adds `collect_vec` and `indexed_presence`, exposes explicit weight wrappers, restores generated constraint-stream convenience traits, moves VND under local search, adds typed custom search registration, and makes default search streaming-first. |

## Documentation Changes

At publication, the docs tree was updated for the 0.13.x runtime surface:

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
  shows the current `penalize(...)` / `reward(...)` terminal API, direct
  cross-join grouping, and the index-aware joined filter contract.
- [Collectors](/docs/solverforge/constraints/collectors/) documents
  `collect_vec(...)`, `indexed_presence(...)`, and the generic
  `Collector<Input>` match-shape contract beside the existing collectors.
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  covers projected grouped complements.
- [Configuration](/docs/solverforge/solver/configuration/) covers VND as
  `local_search_type`, typed `custom` phase names, and named partitioners.
- [Local Search](/docs/solverforge/solver/local-search/) explains the
  accepted-count horizon and fair union selector ordering.
- [Status & Roadmap](/docs/status-and-roadmap/) separates the published
  `solverforge 0.13.1` runtime from the `solverforge-cli 2.0.4` scaffold
  target that was current at publication time.
