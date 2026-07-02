---
title: "SolverForge 0.16.x: Route and Savings Hooks"
date: 2026-06-12
draft: false
description: >
  SolverForge 0.16.0 publishes the route/savings hook split for list variables,
  completes unmatched Clarke-Wright routes, and ships the 0.16 workspace crate
  line on crates.io.
---

**SolverForge 0.16.0** was published on crates.io and tagged as
[v0.16.0](https://github.com/SolverForge/solverforge/releases/tag/v0.16.0).
It kept the Rust `1.95` floor, published the workspace crates on the same
0.16.0 line, and tightened the routing-list hook contract that powers
Clarke-Wright construction and k-opt route improvement.

<%= render Ui::Callout.new(title: "Update, July 2, 2026") do %>
This is a historical 0.16.x release note. It was superseded by
[SolverForge 0.17.x](/blog/releases/2026/06/15/solverforge-0-17-x/), which adds
the stock `domain = "cvrp"` profile, route-distance hardening, and public
dynamic construction primitives. The current core runtime is
`solverforge 0.17.2`.
<% end %>

## What Changed

### Route hooks and savings hooks are separate

List variables now distinguish route-local behavior from Clarke-Wright
construction savings. Use `route_hooks` for route assignment and k-opt:

```rust
#[planning_list_variable(
    element_collection = "visits",
    solution_trait = "solverforge::cvrp::VrpSolution",
    distance_meter = "solverforge::cvrp::MatrixDistanceMeter",
    intra_distance_meter = "solverforge::cvrp::MatrixIntraDistanceMeter",
    route_hooks = "solverforge::cvrp::route_hooks",
    savings_hooks = "solverforge::cvrp::savings_hooks",
    savings_metric_class_fn = "solverforge::cvrp::savings_metric_class"
)]
pub visits: Vec<usize>,
```

`route_hooks` must export `get`, `set`, `depot`, `distance`, and `feasible`.
`savings_hooks` must export `depot`, `distance`, and `feasible`. Use
`savings_metric_class_fn` when route owners share construction depot and
distance behavior, so Clarke-Wright can compute savings rows once for that
metric class while keeping route-local assignment semantics explicit.

### CVRP helpers expose hook bundles

The `solverforge-cvrp` crate now exports:

- `route_hooks`
- `savings_hooks`
- `savings_metric_class`
- `savings_depot_for_entity`
- `savings_distance`
- `savings_feasible`

Those helpers sit beside the existing `VrpSolution`, `ProblemData`,
`MatrixDistanceMeter`, `MatrixIntraDistanceMeter`, `get_route`,
`replace_route`, `depot_for_entity`, `route_distance`, and `route_feasible`
surface.

### Clarke-Wright completes unmatched elements

`ListClarkeWright` now completes unmatched route elements instead of leaving
them behind when no saving merge can place them. That matters for route
construction in real delivery and dispatch apps: a failed saving merge should
not silently drop required work from the initial route set.

## Install And Scaffold Status

For direct Cargo projects that stay on the 0.16 line:

```toml
solverforge = { version = "0.16.0", features = ["serde", "console"] }
```

The companion workspace crates are published at the same `0.16.0` line:

```toml
solverforge-core = "0.16.0"
solverforge-scoring = "0.16.0"
solverforge-solver = "0.16.0"
solverforge-bridge = "0.16.0"
solverforge-cvrp = "0.16.0"
solverforge-console = "0.16.0"
solverforge-config = "0.16.0"
```

For generated apps, confirm the installed CLI target:

```bash
solverforge --version
```

At this release boundary, the published CLI reported:

```text
CLI version: 2.2.2
Scaffold runtime target: SolverForge crate target 0.15.2
Scaffold UI target: solverforge-ui 0.6.5
Scaffold maps target: solverforge-maps 2.1.4
Runtime source: crates.io: solverforge 0.15.2
UI source: crates.io: solverforge-ui 0.6.5
Maps source: crates.io: solverforge-maps 2.1.4
```

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.16.0` | 2026-06-12 | Splits route-local and Clarke-Wright savings hooks on list variables, exposes CVRP route/savings hook bundles, publishes the 0.16 workspace crate line, and completes unmatched Clarke-Wright route elements. |

## Documentation Changes

This post records the documentation changes made for the `solverforge 0.16.0`
runtime surface:

- [SolverForge runtime docs](/docs/solverforge/) stated the 0.16.0 runtime line
  and the separate `solverforge-cli 2.2.2` scaffold target.
- [List Variables](/docs/solverforge/modeling/list-variables/) documents
  `route_hooks`, `savings_hooks`, and `savings_metric_class_fn`.
- [Construction](/docs/solverforge/solver/construction/) explains that
  Clarke-Wright consumes savings hooks while route assignment and k-opt consume
  route hooks.
- [Crate & Runtime Map](/reference/crate-map/) recorded the 0.16.0 workspace
  crate line and `solverforge-cvrp` profile and route/savings helpers.
- [Status & Roadmap](/docs/status-and-roadmap/) recorded the current published
  runtime, CLI, UI, maps, and Python package status separately.
