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
- Reproducible seed-1 search with 30-second and 5-second-unimproved limits,
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
- a 30-second hard-feasible terminal solve when run with the release native
  extension

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

## Solver Policy

The checked-in `solver.toml` uses `environment_mode = "reproducible"` and seed
`1`. Construction assigns only when the filtered row callback exposes an
eligible employee. Local search then uses max-10 nearby change and swap
selectors, late acceptance, and `first_best_score_improving`. The solve stops
after 30 seconds or 5 seconds without improvement.

## Run The Demo

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.6.0
make develop
make hospital-run
```

For a terminal solve:

```bash
make hospital-solve
```

The Rust reference application is documented separately in the
[SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/).
