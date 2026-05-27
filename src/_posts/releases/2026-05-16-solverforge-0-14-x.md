---
title: "SolverForge 0.14.x: Complemented Cross-Join Groups and Metric-Class Routes"
date: 2026-05-16
draft: false
description: >
  SolverForge 0.14.x publishes direct complemented cross-join grouping, fixes
  filtered keyed join retention, unifies owner-aware route hooks, and adds
  route metric classes for Clarke-Wright construction.
---

**SolverForge 0.14.x** was the previous core runtime line. It starts with
[v0.14.0](https://github.com/SolverForge/solverforge/releases/tag/v0.14.0),
tagged at `27329bd` and published on 2026-05-16. The final patch is
[v0.14.1](https://github.com/SolverForge/solverforge/releases/tag/v0.14.1),
tagged at `446b35e` and published on 2026-05-16. The final 0.14.x crate is available
as [solverforge 0.14.1](https://crates.io/crates/solverforge/0.14.1) on
crates.io, with API docs at [docs.rs](https://docs.rs/solverforge/0.14.1).

The release is a core runtime release, not a CLI scaffold refresh.
`solverforge-cli 2.0.4` still scaffolds `solverforge 0.11.1`,
`solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4`. Direct Cargo projects
and deliberately upgraded generated apps can target the published
`solverforge 0.14.1` crate.

## What Changed

### Direct cross-join groups can be complemented

`0.13.1` made direct cross-join grouping public. `0.14.0` completes that path by
letting grouped cross joins continue into `complement(...)`, so a rule can
aggregate joined pairs and still emit default rows for keys with no matches.

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
        |_assignment: &Assignment, capacity: &Capacity| capacity.id,
        sum(|(assignment, _capacity): (&Assignment, &Capacity)| assignment.demand),
    )
    .complement(
        Plan::capacities(),
        |capacity: &Capacity| capacity.id,
        |_capacity: &Capacity| 0i64,
    )
    .penalize(hard_weight(|_capacity_id: &usize, used: &i64| {
        HardSoftScore::of_hard((*used - 40).max(0))
    }))
    .named("Capacity overuse");
```

Use this shape when the business rule is naturally "facts joined to entities,
grouped by a target key, with explicit zero rows for uncovered targets." It
avoids the extra projected-row step when the joined pair does not need to be a
named retained scoring row.

### Filtered keyed joins retain the right sources

The scoring layer now honors filters on both sides of keyed joins and on
complement sources. That fixes retained state for these paths:

- filtered streams used as the right side of a keyed cross join
- custom keyed join extractors after a filtered source
- flattened keyed join targets after filtering
- projected joined rows whose left or right source is filtered

Normal `.filter(|left, right| ...)` application code does not change. The fix
matters because incremental scoring now builds, retracts, and re-inserts only
the rows that still pass their source filters.

### Route hooks are unified and owner-aware

List construction no longer has separate Clarke-Wright and k-opt hook names.
Both route constructors consume the same owner-aware route hooks from
`#[planning_list_variable]`:

```rust
#[planning_list_variable(
    element_collection = "deliveries",
    solution_trait = "solverforge::cvrp::VrpSolution",
    distance_meter = "solverforge::cvrp::MatrixDistanceMeter",
    intra_distance_meter = "solverforge::cvrp::MatrixIntraDistanceMeter",
    route_get_fn = "solverforge::cvrp::get_route",
    route_set_fn = "solverforge::cvrp::replace_route",
    route_depot_fn = "solverforge::cvrp::depot_for_entity",
    route_metric_class_fn = "solverforge::cvrp::route_metric_class",
    route_distance_fn = "solverforge::cvrp::route_distance",
    route_feasible_fn = "solverforge::cvrp::route_feasible"
)]
pub delivery_order: Vec<usize>;
```

The facade now re-exports the matching CVRP helpers from
`solverforge::cvrp`: `get_route`, `replace_route`, `depot_for_entity`,
`route_metric_class`, `route_distance`, and `route_feasible`.

Clarke-Wright savings are evaluated for the owner that supplies the distance
and feasibility context, and merged routes remain bound to that scored owner
through final assignment. That prevents a route scored under one vehicle's
depot, distance, capacity, or time-window context from being assigned to a
different owner just because the route values look feasible elsewhere.

`0.14.1` adds `route_metric_class_fn` for route owners that share depot and
distance behavior. Owners in the same metric class compute Clarke-Wright savings
once per class, but feasibility remains owner-specific through
`route_feasible_fn`. The stock CVRP helper `route_metric_class(...)` groups
owners by their backing `ProblemData` pointer, which fits homogeneous fleets
sharing one matrix while still allowing each owner to reject routes that violate
capacity, time windows, or other route-local rules.

## Install And Scaffold Status

For direct Cargo projects:

```toml
solverforge = { version = "0.14.1", features = ["serde", "console"] }
```

If you write custom incremental constraints that need lower-level identities,
the companion workspace crates are also published at the same `0.14.1` line:

```toml
solverforge-core = "0.14.1"
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
generated app to `solverforge 0.14.1` only when you are deliberately upgrading
that app's runtime dependency and validating the generated code against the
newer core crate.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.14.1` | 2026-05-16 | Adds `route_metric_class_fn`, re-exports `solverforge::cvrp::route_metric_class`, groups Clarke-Wright savings by shared route metric class, and preserves owner-specific feasibility within each class. |
| `0.14.0` | 2026-05-16 | Adds complemented direct cross-join groups, preserves filters through keyed and flattened joins, unifies route hooks for Clarke-Wright and k-opt, and binds Clarke-Wright merges to the scored owner. |

## Documentation Changes

At publication, the docs tree was updated for the 0.14.1 runtime surface:

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
  shows complemented direct cross-join groups and the filtered joined-source
  retention contract.
- [Collectors](/docs/solverforge/constraints/collectors/) documents
  `complement(...)` after direct cross-join `group_by(...)`.
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  separates projected grouped complements from direct cross-join grouped
  complements.
- [List Variables](/docs/solverforge/modeling/list-variables/) and
  [List Move Selectors](/docs/solverforge/solver/list-move-selectors/) document
  the unified owner-aware route hooks and optional route metric classes.
- [Status & Roadmap](/docs/status-and-roadmap/) separates the published
  `solverforge 0.14.1` runtime from the then-current
  `solverforge-cli 2.0.4` scaffold target.
