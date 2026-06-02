---
title: "SolverForge Python 0.4.x: Python Models on the Native SolverForge Engine"
date: 2026-06-02
draft: false
description: >
  SolverForge Python 0.4.0 publishes the solverforge PyPI package for
  CPython 3.14, with Python model decorators, callback constraints, direct
  solves, retained jobs, and the hospital FastAPI example.
---

**SolverForge Python 0.4.0** is available on
[PyPI](https://pypi.org/project/solverforge/0.4.0/) as `solverforge` and
targets CPython 3.14.

```bash
python3.14 -m pip install solverforge
```

Python users can now define planning models with ordinary classes, decorators,
functions, and callbacks, then run those models through SolverForge's native
solver engine.

## What Changed

### Python models use ordinary classes

The public modeling API is built around decorators and field descriptors:

```python
from solverforge import planning_entity, planning_solution, planning_variable


@planning_entity
class Shift:
    nurse = planning_variable(value_range_provider="nurses", allows_unassigned=True)

    def __init__(self, required: bool = True, nurse: int | None = None) -> None:
        self.required = required
        self.nurse = nurse


@planning_solution()
class Schedule:
    shifts: list[Shift]

    def __init__(self, shifts: list[Shift], nurses: list[int]) -> None:
        self.shifts = shifts
        self.nurses = nurses
        self.score = None
```

The package supports `@planning_solution`, `@planning_entity`,
`@problem_fact`, `planning_id`, `planning_variable`, and
`planning_list_variable`. Entity and fact collections are inferred from type
hints where available and from instance collections at solve time.

### Constraints are callback-authored

Constraint providers receive a `ConstraintFactory` and return named rules:

```python
from solverforge import ConstraintFactory, HardSoftScore, constraint_provider


@constraint_provider
def constraints(factory: ConstraintFactory):
    return [
        factory.for_each(Shift)
        .filter(lambda shift: shift.required and shift.nurse is None)
        .penalize(HardSoftScore.ONE_HARD)
        .named("required shift is unassigned")
    ]
```

The current Python stream surface includes:

- unary `for_each(...).filter(...)`
- stream-level `join(...)`
- grouped counts with `group_by(...)`
- balance scoring with `balance(...)`
- fixed or callback-computed weights
- `joiner.equal(...)` and `joiner.equal_bi(...)`

Supported score families are `SoftScore`, `HardSoftScore`,
`HardSoftDecimalScore`, and `HardMediumSoftScore`.

### Direct solves and retained jobs are both available

Use `Solver.solve(...)` for one-shot solves:

```python
from solverforge import Solver

solution = Solver.solve(Schedule([Shift(), Shift()], [0, 1]))
print(solution.score)
```

Use `Solver.analyze(...)` to score an existing solution, and use
`SolverManager` when an application needs retained lifecycle state:

```python
from solverforge import SolverManager

manager = SolverManager(config={"termination": {"seconds_spent_limit": 10}})
handle = manager.solve(schedule)
status = manager.wait(handle.job_id, timeout_seconds=15)
snapshot = manager.snapshot(handle.job_id)
```

`SolverManager` exposes status reads, event drains, snapshots, pause, resume,
cancel, and delete.

### Solver config uses Python objects, dictionaries, or `solver.toml`

Runtime config can be passed as a `SolverConfig`, as a dictionary, or loaded
from `solver.toml` when the solve or manager is created without an explicit
config argument.

```toml
random_seed = 7

[termination]
seconds_spent_limit = 5

[[phases]]
phase_type = "construction_heuristic"

[[phases]]
phase_type = "local_search"
move_selector = { type = "change_move_selector" }
```

Termination supports `seconds_spent_limit`, `minutes_spent_limit`,
`best_score_limit`, `step_count_limit`, `unimproved_step_count_limit`, and
`unimproved_seconds_spent_limit`.

### Scalar and list search are wired through the Python path

Python dynamic models can use scalar selectors such as change, swap, nearby
change/swap, pillar change/swap, ruin-recreate, grouped scalar, conflict
repair, and compound conflict repair.

List-variable models can use list change/swap, nearby list change/swap,
sublist change/swap, list reverse, k-opt, and list ruin selectors. Selector
composition supports limited neighborhoods, union selectors, and two-child
cartesian products.

## Hospital FastAPI Example

The repository includes a Python hospital scheduling example at
`examples/solverforge_hospital`. It demonstrates:

- `HardSoftDecimalScore` hospital scheduling constraints
- unary, joined, grouped, and balance rules
- retained jobs
- status, event, snapshot, and analysis endpoints
- pause, resume, cancel, and delete controls
- schedule views by location and by employee

The canonical `LARGE` dataset has 50 employees and 688 shifts.

Run the demo from a source checkout:

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
python3.14 -m venv .venv-examples
. .venv-examples/bin/activate
python -m pip install "solverforge[examples]==0.4.0"
python -m examples.solverforge_hospital
```

Then open `http://127.0.0.1:7860`.

## Package Artifacts

The `0.4.0` release publishes:

- macOS arm64 CPython 3.14 wheel
- manylinux x86_64 CPython 3.14 wheel
- Windows x86_64 CPython 3.14 wheel
- source distribution

The package declares `requires-python = ">=3.14"`.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.4.0` | 2026-06-02 | Publishes the `solverforge` PyPI package with Python model decorators, callback constraints, direct solve and analysis APIs, retained `SolverManager` jobs, scalar/list dynamic search support, and the hospital FastAPI example. |

## Where to read next

Use the [SolverForge Python docs](/docs/solverforge-python/) for installation,
modeling, constraints, solving, and the hospital example. The package lives in
the [SolverForge Python repository](https://github.com/SolverForge/solverforge-py).
