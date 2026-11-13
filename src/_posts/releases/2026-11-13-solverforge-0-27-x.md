---
title: "solverforge 0.27.x: Pluggable Route Metrics, Bounded Clarke-Wright Savings, and Linear Swap Cursors"
date: 2026-11-13
draft: false
description: >
  The 0.27.x line reads CVRP leg distances through a pluggable RouteMetric,
  with a dense matrix or straight-line legs computed from coordinates, bounds
  Clarke-Wright savings to each stop's nearest neighbours, keeps Clarke-Wright
  owner admission incremental, and opens the scalar swap cursor in linear time.
---

**solverforge 0.27.x** follows `solverforge 0.26.1`; the line was published on
crates.io on 2026-11-13. The current release is
[0.27.0](https://crates.io/crates/solverforge/0.27.0), with a Rust `1.95`
floor. `cargo add solverforge` installs 0.27.0, and docs.rs serves the 0.27.0
API. The one breaking change is in the stock CVRP data: `ProblemData` reads leg
distances and travel times from a `metric` field instead of two matrix fields,
and `VrpSolution` names the metric type. Models that do not use
`solverforge::cvrp` upgrade by moving the pin. `solverforge-cli 4.0.4` still
scaffolds 0.26.1, and the eight worked use cases pin 0.26.1.

## What Changed

### Pluggable route metrics — breaking change

`ProblemData` used to require two dense tables, `distance_matrix` and
`travel_times`: 16 bytes per stop pair, 1.6 GB at 10,000 stops, before any
solving. It is now `ProblemData<M = DenseMatrix>` and holds a `metric: M`
whose `RouteMetric` implementation answers each leg's distance and travel
time. `VrpSolution` gains `type Metric: RouteMetric`, and the stock helpers,
both distance meters, and the route checks read legs only through it, with the
same `UNREACHABLE` and negative-value semantics.

- `DenseMatrix::new(distances, travel_times)` holds the supplied
  `[from][to]` tables unchanged, rows of any length included; existing models
  migrate to it.
- `EuclideanMetric::new(coordinates, speed)` computes legs on demand from
  `(x, y)` coordinates (TSPLIB `EUC_2D`: `sqrt(dx² + dy²)` rounded half away
  from zero; travel time is length / speed, rounded the same way), in memory
  linear in the stops.

The facade re-exports `RouteMetric`, `DenseMatrix`, and `EuclideanMetric`
from `solverforge::cvrp`. On all 100 X instances, Clarke-Wright construction
gives identical routes and scores with both metrics, as does Clarke-Wright
plus 200 local-search steps on X-n101, X-n181, and X-n228
([#258](https://github.com/SolverForge/solverforge/pull/258)). See
[List Variables](/docs/solverforge/modeling/list-variables/#cvrp-route-profile).

### Bounded Clarke-Wright savings

`list_clarke_wright` scores every pair of unassigned elements, so its savings
list holds 32 bytes per pair: 1.6 GB at 10,000 stops and 40 GB at 50,000. A
`list_clarke_wright` phase now accepts `savings_neighbors = K`, which scores a
pair only when one element is among the other's K nearest, about K entries per
element:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "list_clarke_wright"
savings_neighbors = 40
```

The neighbours come from a new optional list-variable hook,
`savings_neighbors_fn`. The `domain = "cvrp"` profile supplies
`solverforge::cvrp::savings_neighbors`, which asks the vehicle's
`RouteMetric::nearest`; `EuclideanMetric` answers from a uniform grid with the
same result as ranking every pair. Each pair is scored once, so a bound of at
least the element count minus one builds the same routes as no bound, and a
phase without the setting behaves as before. A bounded phase on a list
variable without the hook fails before construction starts.

On synthetic stock-profile instances with `EuclideanMetric` and K = 40,
construction at 10,000 stops dropped from 13.2 s and 1.58 GB to 0.30 s and
25 MB, and at 20,000 stops from 56.6 s and 6.29 GB to 1.06 s and 52 MB; 50,000
and 100,000 stops construct in 6.0 s (164 MB) and 22.8 s (389 MB). On the 100 X
instances, K = 40 keeps the score on 90 and improves the hard score on 2; the
soft score changes by -0.10% on average (median 0), in a fifth of the time
([#259](https://github.com/SolverForge/solverforge/pull/259)). See
[Construction](/docs/solverforge/solver/construction/#bounded-clarke-wright-savings).

### Incremental Clarke-Wright owner admission

Each merge attempt used to re-derive the feasible owners of every buffered
route against every owner. The merge loop now keeps its admission state beside
the routes and updates only the merged route, and it resolves each route's
owner restriction once instead of once per candidate owner. The stock CVRP
profile checks savings feasibility once per savings metric class, because its
hook reads only the owner's `ProblemData`; explicit hook paths still ask every
owner. Every accept and reject decision is unchanged. Construction-only runs of all 100 X instances give identical routes
in 2.9 s instead of 17.4 s, and synthetic instances at 8,000 stops construct in
7.8 s instead of 102.1 s
([#257](https://github.com/SolverForge/solverforge/pull/257)).
`ListVariableMetadata` and `ListVariableSlot` gain
`savings_feasible_shared_by_metric_class` and `savings_neighbors_fn` with their
builders.

### Linear-time scalar swap cursor

The scalar swap cursor copied every entity's legal value list when it opened
and tested membership with a linear scan. It now resolves each slot's legality
once: a counted or ranged value source becomes a bounds check and an
entity-slice source a lookup. Opening is linear in the entity count, and every
emitted swap, in the same order, is unchanged. On a 100,000-shift,
10,000-employee hospital model, move generation drops from 555 ms to 5 ms per
step with an identical solution, score, and evaluated-move count
([#256](https://github.com/SolverForge/solverforge/pull/256)).

### Topic guides in the repository

The repository README now keeps the introduction, getting started, and a
documentation map; its reference material moved into topic guides under
`docs/` (modeling, constraints, configuration, running solves, and
performance), each compiled against the release by the README example tests.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.27.0` | Rust `1.95`; `ProblemData` reads legs through a `RouteMetric` (`DenseMatrix`, `EuclideanMetric`); bounded Clarke-Wright savings; incremental owner admission; linear-time scalar swap cursor |
| Previous core runtime | `solverforge 0.26.1` | Late acceptance keeps its history across soft-level improvements; see the [0.26.x release note](/blog/releases/2026/11/10/solverforge-0-26-x/) |
| CLI | `solverforge-cli 4.0.4` | Fresh scaffolds target core `0.26.1`; see the [4.0.x CLI release note](/blog/releases/2026/11/10/solverforge-cli-4-0-x/) |
| Python | `solverforge-py 0.7.2` / PyPI `solverforge 0.7.2` | Compiled onto core `0.23.0`; upgrading the Rust core does not retarget these wheels |
| Worked use cases | November 11 app releases | All eight pin core `0.26.1` and UI `0.9.0`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |
| UI | `solverforge-ui 0.9.1` | Unchanged |
| Maps | `solverforge-maps 2.3.3` | Unchanged |

All nine workspace crates (`solverforge`, `solverforge-core`,
`solverforge-config`, `solverforge-scoring`, `solverforge-solver`,
`solverforge-macros`, `solverforge-bridge`, `solverforge-console`, and
`solverforge-cvrp`) publish `0.27.0`.

The registry records the facade crate's publication at `2026-11-13T11:44:38Z`.
Its artifact SHA-256 is
`c8e84a99102b10b9237712d8742595e5634864c0ad088b7c28279581e253febe`;
`.cargo_vcs_info.json` binds it to
`6ffcacabf117f9a5adf9abd4f4f96c01b9235859`, the `v0.27.0` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.27.0)
was published at `2026-11-13T11:44:53Z`.

On that commit the [CI run](https://github.com/SolverForge/solverforge/actions/runs/43416730323)
passed. The
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/43417890887)
re-ran the CI matrix on Linux, macOS, and Windows with the Miri, MSRV, docs,
and package jobs, verified the release, published to crates.io, and created
the GitHub Release; every job succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.27.0` | 2026-11-13 | `ProblemData` reads legs through a `RouteMetric` (`DenseMatrix`, `EuclideanMetric`) and `VrpSolution` gains `type Metric`; bounded Clarke-Wright savings through `savings_neighbors` and `savings_neighbors_fn`; incremental Clarke-Wright owner admission; linear-time scalar swap cursor. |

## Upgrade Checklist

- Move the `solverforge` pin to `0.27.0`. Models that do not use
  `solverforge::cvrp` need no code changes.
- In a `ProblemData` literal, replace the `distance_matrix` and `travel_times`
  fields with `metric: DenseMatrix::new(distance_matrix, travel_times)`, and
  read the tables back through `data.metric.distances` and
  `data.metric.travel_times`.
- Add `type Metric = DenseMatrix;` to every `impl VrpSolution`. A
  `vehicle_data` returning `Option<&ProblemData>` still compiles, because
  `DenseMatrix` is the default type parameter.
- For models too large for a matrix, hold `EuclideanMetric::new(coordinates,
  speed)` instead (`ProblemData<EuclideanMetric>`,
  `type Metric = EuclideanMetric;`) and set `savings_neighbors` on the
  `list_clarke_wright` phase. A custom list variable that wires its own
  `savings_hooks` needs a `savings_neighbors_fn` before it can use the bound.
- Code that builds `ListVariableMetadata` or `ListVariableSlot` through `new`
  compiles unchanged: the new fields default to off and are set with
  `with_savings_feasible_shared_by_metric_class` and `with_savings_neighbors_fn`.

## Where to read next

Read the [core manual](/docs/solverforge/),
[List Variables](/docs/solverforge/modeling/list-variables/#cvrp-route-profile),
and [Construction](/docs/solverforge/solver/construction/#bounded-clarke-wright-savings).
The [0.27.0 compare](https://github.com/SolverForge/solverforge/compare/v0.26.1...v0.27.0)
covers its 8 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.27.0/CHANGELOG.md)
lists the breaking change.
