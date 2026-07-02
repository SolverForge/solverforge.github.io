---
title: "SolverForge 0.17.x: CVRP Domain Profile"
date: 2026-06-15
draft: false
description: >
  SolverForge 0.17.x adds the stock CVRP list-variable domain profile, hardens
  route-distance handling, and exposes dynamic construction primitives.
---

**SolverForge 0.17.x** started with
[v0.17.0](https://github.com/SolverForge/solverforge/releases/tag/v0.17.0)
on 2026-06-15. The current core patch is
[v0.17.2](https://github.com/SolverForge/solverforge/releases/tag/v0.17.2),
published on crates.io on 2026-07-02. The 0.17 line keeps the Rust `1.95`
floor, publishes the workspace crates on one version line, makes stock CVRP
route lists much easier to declare, and exposes more construction internals for
advanced integrations.

The runtime release line is separate from CLI scaffold publishing. The current
published `solverforge-cli 2.2.2` package scaffolds generated apps on
`solverforge 0.15.2`, `solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4`.
Direct Cargo projects and deliberately upgraded generated apps can depend on
the current `solverforge 0.17.2` runtime.

## What Changed

### CVRP route lists have a stock domain profile

Stock CVRP route-list models no longer need to repeat the standard CVRP
solution trait, distance meters, route hook bundle, savings hook bundle, and
savings metric class on every route list:

```rust
#[planning_list_variable(
    element_collection = "deliveries",
    domain = "cvrp"
)]
pub visits: Vec<usize>,
```

The profile expands to the same public CVRP helpers that were already available
in 0.16.0:

- `solverforge::cvrp::VrpSolution`
- `MatrixDistanceMeter`
- `MatrixIntraDistanceMeter`
- `route_hooks`
- `savings_hooks`
- `savings_metric_class`

Explicit `route_hooks`, `savings_hooks`, and `savings_metric_class_fn` are still
the advanced path for custom route semantics or different construction pruning
policies. The stock `domain = "cvrp"` profile is the default path when the model
uses SolverForge's CVRP `ProblemData` and `VrpSolution` contract.

### K-opt keeps strict route-local feasibility

Stock CVRP route-local feasibility now remains the hard gate for route-polishing
phases. K-opt uses `route_hooks::feasible`, and that hook rejects malformed
routes, capacity violations, and time-window violations before committing a
candidate reversal.

Clarke-Wright construction stays separate. It uses `savings_hooks::feasible`,
which rejects malformed owners, backing data, or visit IDs but admits scoreable
capacity and time-window violations. That lets construction compare "assigned
but imperfect" routes against leaving work unassigned, while K-opt still refuses
to polish a route into an invalid state.

### Route distance handling is panic-safe

0.17.1 hardens the stock CVRP route helpers for real-world matrices. Strict
route feasibility rejects unreachable travel-time legs and overflowing time
arithmetic. Distance hooks convert unreachable or malformed distance entries
into a large finite cost so construction and local search can score the
candidate without panicking.

The same patch line clamps route-distance arithmetic in Clarke-Wright and
k-opt, so extreme matrix values stay inside the solver's scoring domain.

### Dynamic construction primitives are public

0.17.2 exposes construction pieces used by dynamic and advanced integration
paths. The public solver surface now includes `GroupedScalarCursor`,
`GroupedScalarSelector`, `ScalarAssignmentMoveCursor`,
`ScalarAssignmentMoveOptions`, and
`ScalarAssignmentRequiredStreamingCursor`.

Required assignment construction now streams the state it needs for required
slot completion. The stock grouped scalar path still owns required assignment
construction for normal app models; the new exports are for integrations that
intentionally assemble or inspect construction streams directly.

## Install And Scaffold Status

For direct Cargo projects:

```toml
solverforge = { version = "0.17.2", features = ["serde", "console"] }
```

The companion workspace crates are published on the same `0.17.2` line:

```toml
solverforge-core = "0.17.2"
solverforge-scoring = "0.17.2"
solverforge-solver = "0.17.2"
solverforge-bridge = "0.17.2"
solverforge-cvrp = "0.17.2"
solverforge-console = "0.17.2"
solverforge-config = "0.17.2"
solverforge-macros = "0.17.2"
```

For generated apps, confirm the installed CLI target:

```bash
solverforge --version
```

The current published CLI reports:

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
| `0.17.2` | 2026-07-02 | Exposes dynamic construction primitives and streams required assignment construction state for advanced grouped-scalar construction integrations. |
| `0.17.1` | 2026-06-15 | Handles unreachable CVRP legs safely and clamps route-distance arithmetic in construction and k-opt paths. |
| `0.17.0` | 2026-06-15 | Adds the stock `domain = "cvrp"` list-variable profile and keeps K-opt on strict route-local CVRP feasibility while Clarke-Wright uses relaxed savings admissibility. |

## Documentation Changes

The docs tree now tracks the `solverforge 0.17.2` runtime surface:

- [SolverForge runtime docs](/docs/solverforge/) state the 0.17.2 runtime line
  and the separate `solverforge-cli 2.2.2` scaffold target.
- [List Variables](/docs/solverforge/modeling/list-variables/) documents the
  stock `domain = "cvrp"` profile and the custom explicit-hook escape hatch.
- [Construction](/docs/solverforge/solver/construction/) explains that
  Clarke-Wright consumes savings hooks supplied by the CVRP profile or by
  custom route models, and records the public construction cursor/options
  surface exposed in 0.17.2.
- [List Move Selectors](/docs/solverforge/solver/list-move-selectors/) explains
  that K-opt uses strict route-local CVRP feasibility and inherits clamped
  route-distance arithmetic.
- [Crate & Runtime Map](/reference/crate-map/) records the 0.17.2 workspace
  crate line, CVRP profile helpers, and dynamic construction exports.
- The worked use-case docs now record their app-owned `solverforge 0.17.1`
  runtime target while keeping the published CLI scaffold target separate.
