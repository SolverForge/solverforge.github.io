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
This section documents the tagged `solverforge-py 0.5.0` source line for
CPython 3.14. The public PyPI package remains `solverforge 0.4.0` until the
`v0.5.0` release workflow clears the reviewed PyPI publish environment. The
0.5.0 line is backed by the `solverforge 0.17.2` Rust runtime and embeds
`solverforge-ui 0.7.0` assets for Python-hosted examples.
<% end %>

SolverForge Python lets Python users define planning models with ordinary
classes, decorators, functions, and lambdas. Decorators mark planning entities,
variables, and solutions. Constraint providers return Python callback-based
rules. The solve still runs through the native SolverForge engine.

## Installation

Install the current public PyPI package:

```bash
python3.14 -m pip install "solverforge==0.4.0"
```

Use the tagged source line for the 0.5.0 APIs documented here until PyPI
publishing completes:

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.5.0
make develop
. .venv/bin/activate
```

After the 0.5.0 PyPI publish approval completes, install the same line with:

```bash
python3.14 -m pip install "solverforge==0.5.0"
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
| Grouped scalar repair | `scalar_assignment_group`, `ScalarGroupLimits`, `@scalar_group`, `@conflict_repair` |
| List route hooks | `element_owner`, precedence hooks, route callbacks, route data fields, `shadow_variable_updates(...)` |
| Scores | `SoftScore`, `HardSoftScore`, `HardSoftDecimalScore`, `HardMediumSoftScore` |
| Direct solve | `Solver.solve(...)`, `Solver.analyze(...)` |
| Retained jobs | `SolverManager` |
| Runtime config | `SolverConfig`, dictionaries, or `solver.toml` |
| Embedded UI assets | `solverforge.ui.asset(...)`, `solverforge.ui.asset_paths()` |

## Package Details

| Surface | Current state |
| ------- | ------------- |
| Package name | `solverforge` |
| Documented source line | `0.5.0` |
| Published PyPI version | `0.4.0` until the `v0.5.0` publish gate completes |
| Python requirement | `>=3.14` |
| Runtime base | `solverforge 0.17.2` |
| Embedded UI base | `solverforge-ui 0.7.0` |
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
- **[Deliveries Example](/docs/solverforge-python/deliveries-example/)** -
  the route-owning list-variable example, CVRP hooks, route snapshots, and
  insertion recommendations

## Links

- [PyPI package](https://pypi.org/project/solverforge/)
- [Python repository](https://github.com/SolverForge/solverforge-py)
