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

- CPython 3.14 (`python3.14` on `PATH`)
- Rust 1.95.0 when pip has no wheel for your platform, and for every source
  checkout build

The published `solverforge 0.7.2` package ships wheels for three platforms:

| Platform | Wheel tag |
| -------- | --------- |
| Linux x86_64 (glibc 2.17+) | `cp314-cp314-manylinux_2_17_x86_64` |
| macOS on Apple silicon | `cp314-cp314-macosx_11_0_arm64` |
| Windows x86_64 | `cp314-cp314-win_amd64` |

On any other platform (Linux on ARM, musl, Intel macOS) pip downloads the
source distribution and compiles the native extension, which needs Rust 1.95.0
and a C toolchain.

`Solver.solve(...)` releases the GIL while the native solver runs. On a normal
GIL-enabled interpreter, Python callbacks still serialize when they attach to
Python. Concurrent Python callback execution requires free-threaded CPython 3.14.
The published wheels use the GIL-enabled `cp314` ABI, not `cp314t`; a
free-threaded installation needs a source build with its matching interpreter.

## Install

Create a virtual environment, install the published package, and print its
version:

```bash
python3.14 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install "solverforge==0.7.2"
python -c "import solverforge; print(solverforge.__version__)"
```

The last command prints:

```text
0.7.2
```

### From The Tagged Source

Use the matching tagged source checkout when developing the repository examples
or inspecting the binding implementation. `make develop` creates `.venv`, then
compiles the native extension with Rust 1.95.0:

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.7.2
make develop
. .venv/bin/activate
python -c "import solverforge; print(solverforge.__version__)"
```

This also prints `0.7.2`.

## A Minimal Model

The model below assigns nurses to required shifts. It uses one scalar planning
variable, one hard constraint, and the built-in `HardSoftScore` family.

Save this as `schedule.py`:

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

Run it:

```bash
python schedule.py
```

```text
{'family': 'hard_soft', 'levels': [0, 0]}
[0, 0]
```

A score is a dictionary: `family` names the score type and `levels` lists the
hard and soft values. Both shifts are assigned, so the hard level is `0`. The
model has no preference between nurses, so both shifts keep the first one.

`Solver.solve(...)` reads the Python object graph, runs SolverForge, then writes
the solved variables and score back to a Python solution object. The schema is
compiled into the SolverForge 0.23.0 runtime graph; Python-authored models do not
use a separate search engine.

## Analyze A Solution

Use `Solver.analyze(...)` when you want to calculate the score for an existing
solution without running a search. The return value is the score itself, also
written to `schedule.score`, not a solution or an analysis wrapper.

Add this to the end of `schedule.py`:

```python
schedule = Schedule([Shift(nurse=None)], [0])
score = Solver.analyze(schedule)
print(score)
```

```bash
python schedule.py
```

```text
{'family': 'hard_soft', 'levels': [0, 0]}
[0, 0]
{'family': 'hard_soft', 'levels': [-1, 0]}
```

The unassigned required shift costs one hard point.

## Pass Runtime Config

You can pass config as a `SolverConfig`, as a dictionary, or through a
`solver.toml` file in the current directory.

The next block solves the analyzed schedule with a fixed seed and a two-second
limit. Add it to the end of `schedule.py`:

```python
from solverforge import SolverConfig

config = SolverConfig(seconds_spent_limit=2, random_seed=7)
solved = Solver.solve(schedule, config=config)
print(solved.score)
```

The dictionary form is equivalent. Add it to the end of `schedule.py`:

```python
solved = Solver.solve(
    schedule,
    config={
        "random_seed": 7,
        "termination": {"seconds_spent_limit": 2},
    },
)
print(solved.score)
```

Run the script again. Each config solve assigns the shift:

```bash
python schedule.py
```

```text
{'family': 'hard_soft', 'levels': [0, 0]}
[0, 0]
{'family': 'hard_soft', 'levels': [-1, 0]}
{'family': 'hard_soft', 'levels': [0, 0]}
{'family': 'hard_soft', 'levels': [0, 0]}
```

The equivalent `solver.toml` is:

```toml
random_seed = 7

[termination]
seconds_spent_limit = 2
```

When the `config` argument is `None`, `Solver.solve(...)` and `SolverManager`
load `solver.toml` from the current directory if it exists.

To enable parallel candidate evaluation, pass `"move_thread_count": {"count": 4}`
in the dictionary or set `move_thread_count = { count = 4 }` at the top level of
the TOML. The default `"auto"` stays sequential. See
[Parallel Move Evaluation](/docs/solverforge-python/solving-and-runtime/#parallel-move-evaluation)
for a fixed-step example, callback safety, and reproducibility limits.

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
  route-owning planning-list demo with explicit CVRP route/savings metadata and
  recommendations.
