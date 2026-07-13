---
title: "Python Deliveries Example"
description: >
  FastAPI deliveries routing example, planning-list route ownership, CVRP route
  and savings metadata, route snapshots, and insertion recommendations.
---

# Python Deliveries Example

The Python repository includes a FastAPI deliveries demo at
`examples/solverforge_deliveries`. It ports the deliveries use case to Python
model classes backed by SolverForge planning-list variables, declarative route
and savings metadata, shadow updates, retained jobs, API routes, and static UI
assets.

Clone the repository when you want to run the full demo app.

## What It Demonstrates

- `Delivery` problem facts with demand, coordinates, service duration, and time
  windows
- `Vehicle` planning entities with `Vehicle.delivery_order` as a route-owning
  planning list variable over `delivery_indices`
- Independent `ListRouteHooks` and `ListSavingsHooks` bundles with explicit
  `RowField` depot, metric-class, and distance-matrix sources plus
  solution-scoped feasibility
- Route shadow metrics for demand, capacity overage, travel time, and
  time-window violations
- `ConstraintFactory.for_each_unassigned_element(...)` scoring for missing
  deliveries
- List cheapest-insertion construction, list k-opt construction polish, and
  late-acceptance list local search
- Reproducible seed-42 search with three-second and one-second-unimproved
  limits, `k = 2` construction polish, a 100-step local-search limit, a
  late-acceptance history size of 100, and accepted-count foraging at four
- Retained `SolverManager` jobs, live events, exact snapshots, route snapshots,
  phase telemetry, analysis, pause, resume, cancel, terminal-job delete, and
  delivery-insertion recommendations
- Shared `/sf/*` frontend assets served from the native `solverforge-ui` bridge

## Dataset Shape

The seeded demo data includes:

- `PHILADELPHIA`
- `HARTFORD`
- `FIRENZE`

Each fixture builds delivery facts, vehicle route owners, travel data, and route
metrics used by the solver and browser API. Routes start unassigned and the
configured SolverForge construction phases build the initial assignment.

## Solver Policy

The checked-in `solver.toml` uses `environment_mode = "reproducible"` and seed
`42`. List cheapest insertion builds routes, list k-opt with `k = 2` polishes
them, and late-acceptance list change, swap, and reverse moves continue search
with a history size of 100. The local-search phase stops at 100 steps and its
accepted-count forager stops each step after four accepted candidates. The
whole solve stops after three seconds or one second without improvement.

## API Surface

The FastAPI app exposes:

| Endpoint | Purpose |
| -------- | ------- |
| `GET /health` | process health |
| `GET /info` | app metadata |
| `GET /demo-data` | available demo datasets |
| `GET /demo-data/{id}` | selected fixture payload |
| `POST /jobs` | start a retained solve |
| `GET /jobs/{id}` | job summary |
| `GET /jobs/{id}/status` | lifecycle state |
| `GET /jobs/{id}/snapshot` | latest retained snapshot |
| `GET /jobs/{id}/analysis` | score analysis for a snapshot |
| `GET /jobs/{id}/routes` | route snapshot payload |
| `GET /jobs/{id}/events` | retained job event stream |
| `POST /jobs/{id}/pause` | request pause |
| `POST /jobs/{id}/resume` | resume a paused job |
| `POST /jobs/{id}/cancel` | request cancellation |
| `DELETE /jobs/{id}` | delete terminal retained job state |
| `POST /recommendations/delivery-insertions` | rank insertion options for an unassigned delivery |

## Run The Demo

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.6.0
make develop
make deliveries-run PORT=7861
```

Then open `http://127.0.0.1:7861`.

For a terminal solve:

```bash
make deliveries-solve
```

The Rust reference application is documented separately in the
[SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/).
