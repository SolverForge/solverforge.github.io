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
- A `SolverManager` backed retained lifecycle
- Snapshot and analysis endpoints
- Pause, resume, cancel, and delete controls
- Schedule views by location and by employee

## Dataset Shape

The canonical `LARGE` dataset has:

- 50 employees
- 688 shifts
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

## Run The Demo

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
make develop
make hospital-run
```

For a terminal solve:

```bash
make hospital-solve
```
