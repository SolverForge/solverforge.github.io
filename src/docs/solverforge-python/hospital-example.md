---
title: "Python Hospital Example"
description: >
  FastAPI hospital scheduling example, retained job lifecycle, public dataset
  shape, and UI/API surface.
---

# Python Hospital Example

The Python repository includes a FastAPI hospital scheduling demo at
`examples/solverforge_hospital`. It uses Python model classes, callback
constraints, retained jobs, API routes, and static UI assets.

Clone the repository when you want to run the full demo app.

## What It Demonstrates

- Python domain modules for employees, shifts, availability, and skills
- `HardSoftDecimalScore` constraints
- Unary, joined, grouped, and balance constraints
- 688 initially unassigned shifts in the canonical `LARGE` fixture
- A row candidate callback that removes employees without the required skill or
  with overlapping unavailability before construction
- Row-backed employee/shift candidate and distance metadata for bounded nearby
  change and swap search
- Seed-1 search in reproducible environment mode with 30-second and
  5-second-unimproved limits,
  `assign_when_candidate_exists` cheapest insertion, and a
  `first_best_score_improving` forager
- A `SolverManager` backed retained lifecycle
- Snapshot, analysis, and phase-telemetry payloads
- Pause, resume, cancel, and delete controls
- Schedule views by location and by employee
- Shared `/sf/*` frontend assets served from the native `solverforge-ui` bridge

## Dataset Shape

The canonical `LARGE` dataset has:

- 50 employees
- 688 initially unassigned shifts
- public demo-data endpoints
- a terminal solve configured with a 30-second limit; feasibility depends on
  the input and search result

## API Surface

The FastAPI app exposes:

| Endpoint | Purpose |
| -------- | ------- |
| `GET /health` | process health |
| `GET /info` | app metadata |
| `GET /demo-data` | available demo datasets |
| `GET /demo-data/LARGE` | canonical large dataset |
| `GET /solve-summary` | terminal solve summary |
| `POST /jobs` | start a retained solve |
| `GET /jobs/{id}` | job summary |
| `GET /jobs/{id}/status` | lifecycle state |
| `GET /jobs/{id}/snapshot` | latest retained snapshot |
| `GET /jobs/{id}/analysis` | score analysis for a snapshot |
| `GET /jobs/{id}/events` | retained job event stream |
| `POST /jobs/{id}/pause` | request pause |
| `POST /jobs/{id}/resume` | resume a paused job |
| `POST /jobs/{id}/cancel` | request cancellation |
| `DELETE /jobs/{id}` | delete retained job state |

The browser reads retained lifecycle state from the backend for status,
snapshots, analysis, and job controls.

### Telemetry DTOs

The native manager exposes snake-case run totals and an ordered `phases` list.
The example's API/SSE DTO maps these to camel case: `moves_speculative` becomes
`movesSpeculative` at both run and phase level, and `phase_index`/`phase_type`
become `phaseIndex`/`phaseType`. `phases` is an empty list before any phase
starts; it is not a nullable singular `phase` object. During progress the last
entry describes the running phase. Check lifecycle state before treating the
last entry as active after completion.

For example, in code run from the source checkout:

```python
from examples.solverforge_hospital.src.api.dto import telemetry

payload = telemetry({
    "moves_speculative": 4,
    "phases": [{
        "phase_index": 1,
        "phase_type": "Local Search",
        "moves_speculative": 4,
    }],
})
assert payload["movesSpeculative"] == 4
assert payload["phases"][-1]["phaseType"] == "Local Search"
assert payload["phases"][-1]["movesSpeculative"] == 4
assert telemetry(None)["phases"] == []
```

## Solver Policy

The checked-in `solver.toml` uses `environment_mode = "reproducible"` and seed
`1`. Construction assigns only when the filtered row callback exposes an
eligible employee. Local search then uses max-10 nearby change and swap
selectors, late acceptance, and `first_best_score_improving`. The solve stops
after 30 seconds or 5 seconds without improvement.

The config does not opt into parallel evaluation: the default
`move_thread_count = "auto"` stays sequential. Set `move_thread_count = { count = 4 }`
at the top level to request parallel local-search trials; construction remains
sequential. Wall-clock limits do not guarantee identical results across runs or
evaluator counts. See
[Parallel Move Evaluation](/docs/solverforge-python/solving-and-runtime/#parallel-move-evaluation).

## Run The Demo

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.7.0
make develop
make hospital-run
```

For a terminal solve:

```bash
make hospital-solve
```

To run the tagged example against the published package instead of an editable
binding, keep the source checkout for the app and install the examples extra:

```bash
python3.14 -m venv .venv-examples
. .venv-examples/bin/activate
python -m pip install "solverforge[examples]==0.7.0"
python -m examples.solverforge_hospital
```

The wheel includes the binding and shared UI assets, not the repository's
`examples` package.

The Rust reference application is documented separately in the
[SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/).
