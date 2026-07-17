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
This section documents the tagged `solverforge-py 0.6.2` source line for
CPython 3.14. The automatic release workflow completed and the public PyPI
package is `solverforge 0.6.2`. The source compiles Python models into the
`solverforge 0.19.0` Rust runtime and embeds `solverforge-ui 0.7.0` assets for
Python-hosted examples. GitHub CI and the final-tag release workflow completed
successfully.
<% end %>

SolverForge Python lets Python users define planning models with ordinary
classes, decorators, functions, and lambdas. Decorators mark planning entities,
variables, and solutions. Constraint providers return Python callback-based
rules. The binding compiles that authored schema into the same immutable runtime
graph used by native SolverForge models; it does not maintain a second Python
selector or move engine.

## Installation

Install the current public PyPI package:

```bash
python3.14 -m pip install "solverforge==0.6.2"
```

Use the tagged source checkout when developing the repository examples or
inspecting the complete source:

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.6.2
make develop
. .venv/bin/activate
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
| Candidate ordering | `@candidate_metric`, `selection_order`, `selection_metric` |
| List metadata | `ListRouteHooks`, `ListSavingsHooks`, `RowField`, `SolutionField`, `EntityCallback`, `SolutionCallback` |
| Scores | `SoftScore`, `HardSoftScore`, `HardSoftDecimalScore`, `HardMediumSoftScore` |
| Direct solve | `Solver.solve(...)`, `Solver.analyze(...)` |
| Retained jobs | `SolverManager`, `telemetry_detail(...)`, `QualifiedCandidateTraceProvenance` |
| Runtime config | `SolverConfig`, dictionaries, or `solver.toml` |
| Embedded UI assets | `solverforge.ui.asset(...)`, `solverforge.ui.asset_paths()` |

## Package Details

| Surface | Current state |
| ------- | ------------- |
| Package name | `solverforge` |
| Documented source line | `0.6.2` |
| Published PyPI version | `0.6.2` |
| Python requirement | `>=3.14` |
| Runtime base | `solverforge 0.19.0` |
| Embedded UI base | `solverforge-ui 0.7.0` |
| Repository | [SolverForge/solverforge-py](https://github.com/SolverForge/solverforge-py) |

## Sections

- **[Getting Started](/docs/solverforge-python/getting-started/)** - install
  the package, write a minimal model, solve it, and pass config
- **[Modeling](/docs/solverforge-python/modeling/)** - classes, decorators,
  scalar variables, assignment groups, scoped list metadata, candidate metrics,
  score families, and schema compilation
- **[Constraints](/docs/solverforge-python/constraints/)** - callback stream
  shapes, joins, grouping, balance scoring, and unsupported top-level methods
- **[Solving & Runtime](/docs/solverforge-python/solving-and-runtime/)** -
  synchronous solves, score analysis, compiled runtime config, retained jobs,
  candidate traces, qualified provenance, and dynamic move support
- **[Hospital Example](/docs/solverforge-python/hospital-example/)** - the
  FastAPI example, retained lifecycle endpoints, and public dataset shape
- **[Deliveries Example](/docs/solverforge-python/deliveries-example/)** -
  the route-owning list-variable example, explicit CVRP route/savings metadata,
  route snapshots, and insertion recommendations

## Links

- [SolverForge Python 0.6.x release notes](/blog/releases/2026/07/13/solverforge-python-0-6-x/)
- [PyPI package 0.6.2](https://pypi.org/project/solverforge/0.6.2/)
- [Python v0.6.2 source](https://github.com/SolverForge/solverforge-py/tree/v0.6.2)
