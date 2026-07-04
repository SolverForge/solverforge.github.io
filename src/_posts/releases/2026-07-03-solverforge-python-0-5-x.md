---
title: "SolverForge Python 0.5.x: Dynamic Lists, Route Hooks, and Embedded UI Assets"
date: 2026-07-03
draft: false
description: >
  SolverForge Python 0.5.0 moves the source line onto the SolverForge 0.17.2
  runtime line, adds route-aware planning-list support, expands grouped scalar
  construction, embeds shared UI assets, and adds the deliveries FastAPI demo.
---

**SolverForge Python 0.5.0** is the tagged source line for the `solverforge`
Python package. It targets CPython 3.14, carries the Rust dependency base
forward to `solverforge 0.17.2`, and embeds `solverforge-ui 0.7.0` assets
through the native extension. The `v0.5.0` tag is cut and the source line has
passed CI; public PyPI still resolves `solverforge` to `0.4.0` until the
reviewed 0.5.0 publish gate completes.

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.5.0
make develop
```

## What Changed

### Dynamic list models can carry route semantics

`planning_list_variable(...)` now carries the hooks needed by owner-aware list
construction, precedence/makespan scoring, and CVRP-style route construction:

- `element_owner`
- `construction_element_order_key`
- `precedence_duration`
- `precedence_successors`
- `route_depot`, `route_metric_class`, `route_distance`, `route_feasible`
- entity-scoped route callback variants
- field-backed route data for depot, metric class, distance matrix, capacity,
  and demand

Those hooks let Python models use native list cheapest insertion, list regret
insertion, list Clarke-Wright, list k-opt construction polish, and list local
search while keeping model-specific route data in Python.

### Shadow updates refresh route-derived fields

`shadow_variable_updates(...)` registers post-update listeners for ordered list
variables. The native solver owns the working state during solve/analyze, then
exports refreshed fields back to Python objects so constraints and APIs can read
route metrics such as total demand, travel time, or time-window violations.

### Scalar groups cover assignment-aware construction

`scalar_assignment_group(...)` declares assignment-aware scalar groups with
required-entity, capacity, assignment, ordering, and limit callbacks. Grouped
scalar local search and assignment-group construction consume the same group
metadata from `solver.toml`.

### Python constraints grew list and presence helpers

The callback-authored stream surface now includes:

- `ConstraintFactory.for_each_unassigned_element(...)`
- `ConstraintFactory.list_precedence_makespan(...)`
- `indexed_presence(...)` grouped collectors
- stream-level joins, grouped counts, balance scoring, and callback weights

### Shared UI assets ship inside the wheel

The native extension embeds shared `solverforge-ui` assets and exposes them
through `solverforge.ui.asset(...)` and `solverforge.ui.asset_paths()`. Python
HTTP hosts can serve `/sf/*` files from the installed package while keeping
app-specific browser modules inside their own example directories.

## Deliveries FastAPI Example

The repository now includes `examples/solverforge_deliveries`, a Python port of
the deliveries use case. It demonstrates:

- deliveries as problem facts
- route-owning vehicles with a planning-list variable
- CVRP route callbacks and route shadow metrics
- unassigned-delivery scoring
- retained jobs, snapshots, route snapshots, analysis, pause/resume/cancel, and
  terminal-job deletion
- delivery-insertion recommendations
- shared `/sf/*` assets served from the native UI bridge

Run it from the tagged source checkout:

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.5.0
make develop
make deliveries-run PORT=7861
```

Then open `http://127.0.0.1:7861`.

The hospital example remains available at
`examples/solverforge_hospital` and now also serves shared UI assets through the
native bridge.

After the 0.5.0 PyPI publish approval completes, package consumers can install
the same line with:

```bash
python3.14 -m pip install "solverforge==0.5.0"
```

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.5.0` | 2026-07-03 | Tags the source line on `solverforge 0.17.2`, adds route-aware dynamic list hooks, field-backed CVRP route data, shadow updates, assignment-aware grouped scalar construction, embedded `solverforge-ui 0.7.0` assets, and the deliveries FastAPI example. |

## Where to read next

Use the [SolverForge Python docs](/docs/solverforge-python/) for installation,
modeling, constraints, solving, hospital scheduling, and deliveries routing.
The package lives in the
[SolverForge Python repository](https://github.com/SolverForge/solverforge-py).
