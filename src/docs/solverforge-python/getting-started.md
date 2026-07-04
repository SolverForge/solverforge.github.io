---
title: "Python Getting Started"
description: >
  Install SolverForge Python, define a minimal planning model, solve it, and
  pass runtime config.
---

# Python Getting Started

This guide installs SolverForge Python, defines a small shift-assignment model,
solves it, and shows the equivalent config forms.

## Prerequisites

- CPython 3.14
- Rust 1.95.0 only if pip needs to build from source

The current public PyPI package is `solverforge 0.4.0`. The 0.5.0 APIs in this
guide are available from the tagged source line until the reviewed PyPI publish
gate completes.

Install the documented 0.5.0 line from source:

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.5.0
make develop
. .venv/bin/activate
python - <<'PY'
import solverforge
print(solverforge.__version__)
PY
```

The version printed for the current release line should be `0.5.0`.

After the 0.5.0 PyPI publish approval completes, the equivalent package install
is:

```bash
python3.14 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install "solverforge==0.5.0"
```

## A Minimal Model

The model below assigns nurses to required shifts. It uses one scalar planning
variable, one hard constraint, and the built-in `HardSoftScore` family.

```python
from solverforge import (
    ConstraintFactory,
    HardSoftScore,
    Solver,
    constraint_provider,
    planning_entity,
    planning_solution,
    planning_variable,
)


@planning_entity
class Shift:
    nurse = planning_variable(
        value_range_provider="nurses",
        allows_unassigned=True,
    )

    def __init__(self, required: bool = True, nurse: int | None = None) -> None:
        self.required = required
        self.nurse = nurse


@constraint_provider
def constraints(factory: ConstraintFactory):
    return [
        factory.for_each(Shift)
        .filter(lambda shift: shift.required and shift.nurse is None)
        .penalize(HardSoftScore.ONE_HARD)
        .named("required shift is unassigned")
    ]


@planning_solution(score=HardSoftScore, constraints=constraints)
class Schedule:
    shifts: list[Shift]

    def __init__(self, shifts: list[Shift], nurses: list[int]) -> None:
        self.shifts = shifts
        self.nurses = nurses
        self.score = None


schedule = Schedule([Shift(), Shift()], [0, 1])
solved = Solver.solve(schedule)

print(solved.score)
print([shift.nurse for shift in solved.shifts])
```

`Solver.solve(...)` reads the Python object graph, runs SolverForge, then writes
the solved variables and score back to a Python solution object.

## Analyze A Solution

Use `Solver.analyze(...)` when you want to calculate the score for an existing
solution without running a search.

```python
schedule = Schedule([Shift(nurse=None)], [0])
analyzed = Solver.analyze(schedule)
print(analyzed.score)
```

## Pass Runtime Config

You can pass config as a `SolverConfig`, as a dictionary, or through a
`solver.toml` file in the current directory.

```python
from solverforge import SolverConfig

config = SolverConfig(seconds_spent_limit=2, random_seed=7)
solved = Solver.solve(schedule, config=config)
```

The equivalent dictionary shape is:

```python
solved = Solver.solve(
    schedule,
    config={
        "random_seed": 7,
        "termination": {"seconds_spent_limit": 2},
    },
)
```

The equivalent `solver.toml` is:

```toml
random_seed = 7

[termination]
seconds_spent_limit = 2
```

When the `config` argument is `None`, `Solver.solve(...)` and `SolverManager`
load `solver.toml` from the current directory if it exists.

## Next Steps

- Use [Modeling](/docs/solverforge-python/modeling/) for decorators, scalar
  variables, list variables, and score family selection.
- Use [Constraints](/docs/solverforge-python/constraints/) for joins, grouping,
  balance scoring, and callback weights.
- Use [Solving & Runtime](/docs/solverforge-python/solving-and-runtime/) for
  retained jobs and dynamic selector configuration.
- Use [Hospital Example](/docs/solverforge-python/hospital-example/) for the
  larger FastAPI demo.
- Use [Deliveries Example](/docs/solverforge-python/deliveries-example/) for a
  route-owning planning-list demo with CVRP route hooks and recommendations.
