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
- Seed-42 search in reproducible environment mode with three-second and
  one-second-unimproved limits, `k = 2` construction polish, a 100-step local-search limit, a
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

The default `move_thread_count = "auto"` remains sequential. To request parallel
local-search trials, set `move_thread_count = { count = 4 }` at the top level;
list construction and k-opt construction polish remain sequential. The seed and
environment mode do not make wall-clock termination reproducible across runs
or evaluator counts. See
[Parallel Move Evaluation](/docs/solverforge-python/solving-and-runtime/#parallel-move-evaluation)
for fixed-work limits and stateful-provider caveats.

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

### Telemetry DTOs

Native manager status/events contain snake-case run totals and a `phases` list
in execution order. The API/SSE DTO preserves that list and maps each phase to
camel-case fields such as `phaseIndex`, `phaseType`, `movesEvaluated`, and
`movesSpeculative`. Run-level `moves_speculative` also maps to
`movesSpeculative`. With no phase started, `phases` is `[]`, not a nullable
singular `phase` dictionary. In a progress event the last entry is the running
phase; completed jobs retain their earlier phase records.

For example, in code run from the source checkout:

```python
from examples.solverforge_deliveries.src.api.dto import telemetry

payload = telemetry({
    "moves_speculative": 4,
    "phases": [{
        "phase_index": 2,
        "phase_type": "Local Search",
        "moves_speculative": 4,
    }],
})
assert payload["movesSpeculative"] == 4
assert payload["phases"][-1]["phaseIndex"] == 2
assert payload["phases"][-1]["movesSpeculative"] == 4
assert telemetry(None)["phases"] == []
```

Speculative trials were scored ahead of the decision point and discarded; they
are not accepted or applied moves. The native retained diagnostic trace names
these with the `discarded_speculative` disposition; ordinary progress DTOs do
not include the full trace.

## Run The Demo

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.7.2
make develop
make deliveries-run PORT=7861
```

Then open `http://127.0.0.1:7861`.

For a terminal solve:

```bash
make deliveries-solve
```

To use the published binding with the tagged source-checkout app:

```bash
python3.14 -m venv .venv-examples
. .venv-examples/bin/activate
python -m pip install "solverforge[examples]==0.7.2"
python -m examples.solverforge_deliveries
```

The wheel supplies the binding and shared UI assets; the `examples` package
still comes from the source checkout.

The Rust reference application is documented separately in the
[SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/).
