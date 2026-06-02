---
title: "Python Hospital Example"
description: >
  Source-checkout FastAPI hospital scheduling example, retained job lifecycle,
  public dataset shape, and UI/API boundaries.
---

# Python Hospital Example

`examples/solverforge_hospital` in
[SolverForge/solverforge-py](https://github.com/SolverForge/solverforge-py)
is the larger Python example. It mirrors the public hospital scheduling use
case with Python model classes, callback constraints, retained jobs, FastAPI
routes, and static UI assets.

The example is source-checkout material. It is included in the source
distribution for reproducible builds and development, but it is not installed
into the runtime wheel.

## What It Demonstrates

- Python domain modules for employees, shifts, availability, and skills
- `HardSoftDecimalScore` constraints
- Unary, joined, grouped, and balance constraints
- A `SolverManager` backed retained lifecycle
- Snapshot and analysis endpoints
- Pause, resume, cancel, and delete controls
- A static app that renders schedules by location and by employee
- A generated `ui-model.json` and `sf-config.json` for the example UI

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

The browser reads authoritative retained lifecycle state from the backend. It
does not infer solver status locally.

## Run From A Source Checkout

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

Use the repository's own `README.md`, `WIREFRAME.md`, and `docs/` files for
maintainer-level details. The published website keeps this page focused on the
public example surface and integration boundary.
