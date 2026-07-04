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
| `shadow_variable_updates(...)` | post-update listeners for refreshed list-derived fields |

`@planning_solution(...)` accepts:

```python
@planning_solution(
    score=HardSoftScore,
    constraints=constraints,
    scalar_groups=[repair_employee_assignments],
    conflict_repairs=[repair_missing_skill],
    shadow_updates=shadow_variable_updates(
        list_owner="vehicles",
        post_update_listener=refresh_vehicle_route_shadows,
    ),
)
class Schedule:
    ...
```

`constraints`, `scalar_groups`, `conflict_repairs`, and `shadow_updates` are
optional unless your solver config or list-variable model selects features that
require them.

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

Scalar variables can also declare bounded candidate and nearby callbacks:
`candidate_values`, `nearby_value_candidates`, `nearby_entity_candidates`,
`nearby_value_distance_meter`, and `nearby_entity_distance_meter`. Dynamic
scalar construction and nearby scalar local search consume those callbacks when
the selected phase needs them.

Assignment-aware grouped scalar construction and local search use
`scalar_assignment_group(...)` metadata passed to the solution decorator:

```python
from solverforge import ScalarGroupLimits, scalar_assignment_group

assignment_group = scalar_assignment_group(
    "employee_assignments",
    entity_class="Shift",
    variable_name="employee_idx",
    required_entity=lambda solution, entity_index: solution.shifts[entity_index].required,
    capacity_key=lambda solution, entity_index, employee_index: solution.team_by_employee[employee_index],
    limits=ScalarGroupLimits(value_candidate_limit=8),
)

@planning_solution(score=HardSoftScore, constraints=constraints, scalar_groups=[assignment_group])
class Schedule:
    ...
```

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

List variables can expose owner, precedence, route, and field-backed route data
to the native solver:

```python
@planning_entity
class Vehicle:
    delivery_order = planning_list_variable(
        element_collection="delivery_indices",
        route_depot=route_depot,
        route_metric_class=route_metric_class,
        route_distance=route_distance,
        route_feasible=route_feasible,
    )
```

Use `element_owner`, `construction_element_order_key`,
`precedence_duration`, and `precedence_successors` for owner-aware queues and
precedence-list scoring. Use `route_depot`, `route_metric_class`,
`route_distance`, and `route_feasible` for solution/entity-index route
callbacks, or the `*_entity` variants when the callback should receive the
route-owning entity object. Immutable route data can avoid per-query Python
callbacks with `route_depot_field`, `route_metric_class_field`,
`route_distance_matrix_field`, `route_capacity_field`, and
`route_demand_field`.

Shadow updates refresh fields derived from an ordered list after solve/analyze
changes:

```python
@planning_solution(
    constraints=constraints,
    shadow_updates=shadow_variable_updates(
        list_owner="vehicles",
        post_update_listener=refresh_vehicle_route_shadows,
    ),
)
class DeliveryPlan:
    ...
```

## Before Solving

- Match each scalar variable's `value_range_provider` to a collection on the
  solution object.
- Match each list variable's `element_collection` to a collection on the
  solution object.
- Match route, precedence, shadow-update, and scalar-group callback names to
  real functions that are deterministic for the same solution state.
- Initialize `score` to `None`.
- Validate and normalize input data before calling the solver.
