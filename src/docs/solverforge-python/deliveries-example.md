---
title: "Python Deliveries Example"
description: >
  FastAPI deliveries routing example, planning-list route ownership, CVRP route
  hooks, route snapshots, and insertion recommendations.
---

# Python Deliveries Example

The Python repository includes a FastAPI deliveries demo at
`examples/solverforge_deliveries`. It ports the deliveries use case to Python
model classes backed by SolverForge planning-list variables, route callbacks,
shadow updates, retained jobs, API routes, and static UI assets.

Clone the repository when you want to run the full demo app.

## What It Demonstrates

- `Delivery` problem facts with demand, coordinates, service duration, and time
  windows
- `Vehicle` planning entities with `Vehicle.delivery_order` as a route-owning
  planning list variable over `delivery_indices`
- CVRP-style route callbacks for depot lookup, metric class, travel time, and
  route feasibility
- Route shadow metrics for demand, capacity overage, travel time, and
  time-window violations
- `ConstraintFactory.for_each_unassigned_element(...)` scoring for missing
  deliveries
- List cheapest-insertion construction, list k-opt construction polish, and
  late-acceptance list local search
- Retained `SolverManager` jobs, live events, exact snapshots, route snapshots,
  analysis, pause, resume, cancel, terminal-job delete, and
  delivery-insertion recommendations
- Shared `/sf/*` frontend assets served from the native `solverforge-ui` bridge

## Dataset Shape

The seeded demo data includes:

- `PHILADELPHIA`
- `HARTFORD`
- `FIRENZE`

Each fixture builds delivery facts, vehicle route owners, travel data, initial
route assignments, and route metrics used by the solver and browser API.

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
git checkout v0.5.0
make develop
make deliveries-run PORT=7861
```

Then open `http://127.0.0.1:7861`.

For a terminal solve:

```bash
make deliveries-solve
```
