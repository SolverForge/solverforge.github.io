---
title: "SolverForge Python"
linkTitle: "Python"
icon: fa-solid fa-code
weight: 10
description: >
  Dynamic Python bindings for SolverForge, published as the solverforge package
  on PyPI.
---

<h1>SolverForge Python</h1>

<%= render Ui::Callout.new do %>
This section tracks the published `solverforge 0.4.0` Python package. It
targets CPython 3.14, ships a PyO3 native extension backed by the Rust
SolverForge engine, and is published on PyPI as three CPython 3.14 wheels plus
one source distribution.
<% end %>

SolverForge Python lets Python users define planning models with ordinary
classes, decorators, functions, and lambdas. The package does not generate Rust,
does not use a string-parsed constraint language, and does not require a Java
service. Python owns model authoring; Rust owns the working solver state,
search, scoring, snapshots, and retained job lifecycle.

## Installation

```bash
python3.14 -m pip install solverforge
```

The current wheel contains the public `solverforge` package, the native
`solverforge._native` extension, type stubs, and package metadata. Source
checkout examples, including the hospital FastAPI app, are maintained in the
repository and source distribution rather than installed into the runtime wheel.

If pip builds from source, the build uses Rust 1.95.0 and `maturin`.

## What It Provides

- Python decorators for `@planning_solution`, `@planning_entity`,
  `@problem_fact`, `@constraint_provider`, `@scalar_group`, and
  `@conflict_repair`
- Planning fields for `planning_id`, `planning_variable`, and
  `planning_list_variable`
- Score families for `SoftScore`, `HardSoftScore`,
  `HardSoftDecimalScore`, and `HardMediumSoftScore`
- Callback-authored constraints through `ConstraintFactory`
- Synchronous solving with `Solver.solve(...)`
- Score evaluation with `Solver.analyze(...)`
- Retained jobs with `SolverManager`, including status, events, snapshots,
  pause, resume, cancel, and delete
- Config loading from explicit `SolverConfig`, dictionaries, or a local
  `solver.toml`

## Mental Model

| Layer | Python owns | Rust owns |
| ----- | ----------- | --------- |
| Domain model | classes, collections, field declarations, type hints | schema import into dynamic state |
| Constraints | Python callbacks and stream plans | native evaluation, score conversion, localized state |
| Solving | solution objects and optional config | construction, local search, move application, telemetry |
| Retained lifecycle | manager calls and exported snapshots | job state, events, pause/resume/cancel, retained clones |

The Rust macro-generated API remains the performance ceiling. The Python path
is the dynamic binding path for teams that need Python authoring while keeping
the solver engine and mutable working state in Rust.

## Current Package Status

| Surface | Current state |
| ------- | ------------- |
| Package name | `solverforge` |
| Version | `0.4.0` |
| Python requirement | `>=3.14` |
| Wheel targets | macOS arm64, manylinux x86_64, Windows x86_64 |
| Source distribution | Published |
| Repository | [SolverForge/solverforge-py](https://github.com/SolverForge/solverforge-py) |

`0.4.0` is the first release from the current dynamic binding architecture. It
intentionally supersedes older incompatible `0.2.x` and `0.3.0` artifacts in
the same PyPI namespace. Those older artifacts exposed APIs such as
`SolverFactory`, `PlanningVariable`, and Java-backed service requirements that
are not part of the current package.

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
  source-checkout FastAPI example, retained lifecycle endpoints, dataset shape,
  and UI boundary

## External References

- [PyPI package](https://pypi.org/project/solverforge/)
- [Python repository](https://github.com/SolverForge/solverforge-py)
- [PyPI release run](https://github.com/SolverForge/solverforge-py/actions/runs/26798126888)
- [TestPyPI release run](https://github.com/SolverForge/solverforge-py/actions/runs/26798017478)
