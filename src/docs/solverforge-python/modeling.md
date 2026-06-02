---
title: "Python Modeling"
description: >
  Model SolverForge planning problems with Python classes, decorators, scalar
  variables, list variables, and score families.
---

# Python Modeling

SolverForge Python models are normal Python object graphs. Decorators and field
descriptors mark the parts SolverForge should solve; constructors still own the
data you pass in.

## Decorators

| Decorator | Use it for |
| --------- | ---------- |
| `@planning_solution(...)` | the root object passed to `Solver.solve(...)` |
| `@planning_entity` | objects whose planning variables the solver may change |
| `@problem_fact` | immutable or solver-external facts used by constraints |
| `@constraint_provider` | a function that returns constraint plans |
| `@scalar_group(name)` | grouped scalar repair candidates used by config |
| `@conflict_repair(*constraint_names)` | conflict-repair candidates for named hard constraints |

`@planning_solution(...)` accepts:

```python
@planning_solution(
    score=HardSoftScore,
    constraints=constraints,
    scalar_groups=[repair_employee_assignments],
    conflict_repairs=[repair_missing_skill],
)
class Schedule:
    ...
```

`constraints`, `scalar_groups`, and `conflict_repairs` are optional unless your
solver config selects features that require them.

## Planning Fields

| Field | Meaning |
| ----- | ------- |
| `planning_id()` | stable identity field |
| `planning_variable(value_range_provider=...)` | scalar value chosen from a solution collection |
| `planning_list_variable(element_collection=...)` | ordered list variable whose elements come from a solution collection |

Scalar variables can allow `None` with `allows_unassigned=True`. They can also
be declared pinned with `pinning=True` when a model needs fixed assignments.

```python
@planning_entity
class Shift:
    id = planning_id()
    employee_idx = planning_variable(
        value_range_provider="employees",
        allows_unassigned=True,
    )

    def __init__(self, shift_id: str, employee_idx: int | None = None) -> None:
        self.id = shift_id
        self.employee_idx = employee_idx
```

The `value_range_provider` name must match a collection on the solution object.
In this example, `Schedule.employees` provides candidate values.

## Collections And Type Hints

Entity and fact collections are inferred from type hints where available, then
from instance lists. Keep the solution class explicit:

```python
@planning_solution(score=HardSoftScore, constraints=constraints)
class Schedule:
    shifts: list[Shift]

    def __init__(self, shifts: list[Shift], employees: list[int]) -> None:
        self.shifts = shifts
        self.employees = employees
        self.score = None
```

Initialize `score` to `None`. SolverForge writes the calculated score back after
`Solver.solve(...)` or `Solver.analyze(...)`.

## Score Families

Supported score families:

- `SoftScore`
- `HardSoftScore`
- `HardSoftDecimalScore`
- `HardMediumSoftScore`

Choose the family on `@planning_solution(score=...)`. Constraint weights should
use the same family when a constraint contributes hard, medium, soft, or scaled
decimal levels.

```python
@planning_solution(score=HardSoftDecimalScore, constraints=constraints)
class HospitalPlan:
    ...
```

## List Variables

List variables represent ordered routes, tours, or queues. The list stores
element identifiers, and `element_collection` names the solution collection that
contains the assignable values.

```python
@planning_entity
class Vehicle:
    visits = planning_list_variable(element_collection="visit_values")

    def __init__(self, vehicle_id: int) -> None:
        self.vehicle_id = vehicle_id
        self.visits: list[int] = []


@planning_solution()
class DispatchPlan:
    vehicles: list[Vehicle]

    def __init__(self) -> None:
        self.vehicles = [Vehicle(0), Vehicle(1)]
        self.visit_values = [0, 1, 2, 3]
        self.score = None
```

List construction and list local-search selectors work with the same
`Solver.solve(...)` and `SolverManager` entry points as scalar models.

## Before Solving

- Match each scalar variable's `value_range_provider` to a collection on the
  solution object.
- Match each list variable's `element_collection` to a collection on the
  solution object.
- Initialize `score` to `None`.
- Validate and normalize input data before calling the solver.
