---
title: "SolverForge Python"
linkTitle: "Python"
icon: fa-solid fa-code
weight: 10
description: >
  Build SolverForge planning models in Python and solve them with the native
  SolverForge engine.
---

<h1>SolverForge Python</h1>

<%= render Ui::Callout.new do %>
Install SolverForge Python with `python3.14 -m pip install solverforge`.
The current package is `solverforge 0.4.0` and requires CPython 3.14.
<% end %>

SolverForge Python lets Python users define planning models with ordinary
classes, decorators, functions, and lambdas. Decorators mark planning entities,
variables, and solutions. Constraint providers return Python callback-based
rules. The solve still runs through the native SolverForge engine.

## Installation

```bash
python3.14 -m pip install solverforge
```

## Basic Workflow

1. Define facts and planning entities as Python classes.
2. Mark scalar or list planning variables on entity classes.
3. Add a `@planning_solution(...)` class that owns the collections.
4. Write constraint callbacks with `ConstraintFactory`.
5. Call `Solver.solve(...)` for a direct solve or `SolverManager` for retained
   jobs, snapshots, pause, resume, and cancel.

## API Surface

| Use | API |
| --- | --- |
| Model classes | `@planning_solution`, `@planning_entity`, `@problem_fact` |
| Planning fields | `planning_id`, `planning_variable`, `planning_list_variable` |
| Constraints | `@constraint_provider`, `ConstraintFactory`, `joiner` |
| Scores | `SoftScore`, `HardSoftScore`, `HardSoftDecimalScore`, `HardMediumSoftScore` |
| Direct solve | `Solver.solve(...)`, `Solver.analyze(...)` |
| Retained jobs | `SolverManager` |
| Runtime config | `SolverConfig`, dictionaries, or `solver.toml` |

## Package Details

| Surface | Current state |
| ------- | ------------- |
| Package name | `solverforge` |
| Version | `0.4.0` |
| Python requirement | `>=3.14` |
| Repository | [SolverForge/solverforge-py](https://github.com/SolverForge/solverforge-py) |

## Sections

- **[Getting Started](/docs/solverforge-python/getting-started/)** - install
  the package, write a minimal model, solve it, and pass config
- **[Modeling](/docs/solverforge-python/modeling/)** - classes, decorators,
  scalar variables, list variables, score families, and schema inference
- **[Constraints](/docs/solverforge-python/constraints/)** - callback stream
  shapes, joins, grouping, balance scoring, and unsupported top-level methods
- **[Solving & Runtime](/docs/solverforge-python/solving-and-runtime/)** -
  synchronous solves, score analysis, solver config, retained jobs, and dynamic
  move support
- **[Hospital Example](/docs/solverforge-python/hospital-example/)** - the
  FastAPI example, retained lifecycle endpoints, and public dataset shape

## Links

- [PyPI package](https://pypi.org/project/solverforge/)
- [Python repository](https://github.com/SolverForge/solverforge-py)
