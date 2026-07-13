---
title: "Python Modeling"
description: >
  Model SolverForge planning problems with Python classes, explicit scalar and
  list metadata, candidate metrics, assignment groups, and score families.
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
| `@candidate_metric(name)` | a named numeric ranking callback for sorted or probabilistic selector order |
| `shadow_variable_updates(...)` | post-update listeners for refreshed list-derived fields |

`@planning_solution(...)` accepts:

```python
@planning_solution(
    score=HardSoftScore,
    constraints=constraints,
    scalar_groups=[repair_employee_assignments],
    conflict_repairs=[repair_missing_skill],
    candidate_metrics=[rank_candidate],
    shadow_updates=shadow_variable_updates(
        list_owner="vehicles",
        post_update_listener=refresh_vehicle_route_shadows,
    ),
)
class Schedule:
    ...
```

`constraints`, `scalar_groups`, `conflict_repairs`, `candidate_metrics`, and
`shadow_updates` are optional unless the model or solver config selects a
feature that requires them.

The decorator data is not late-bound search behavior. SolverForge Python
validates it into one immutable runtime plan containing the schema, solution
descriptor, and SolverForge 0.18 runtime model. Direct solves, retained jobs,
snapshots, and resumes reuse that plan; instance rows, callback views, seeds,
and moves remain specific to each solve.

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
the selected phase needs them. Nearby candidate and distance metadata accepts
either a callback or a row field name. Each property has exactly one source;
declaring both is rejected during schema compilation.

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

`required_entity_field`, `capacity_key_field`, `position_key_field`, and
`sequence_key_field` are field-backed alternatives to their callback forms.
Required metadata is a row boolean, position and sequence metadata are row
integers, and capacity metadata is a row list indexed by candidate value. A
field source and callback source for the same property are mutually exclusive.

An assignment-owned variable has one mutation path: its declared group handles
grouped construction and `grouped_scalar_move_selector`. Raw scalar, nearby,
ruin, and conflict-repair selectors targeting that variable are rejected rather
than creating a second ownership path.

## Candidate Metrics

Use `@candidate_metric("name")` when a leaf selector uses `selection_order =
"sorted"` or `"probabilistic"`. Register the decorated function on the
solution:

```python
from solverforge import candidate_metric


@candidate_metric("dispatch_cost")
def dispatch_cost(solution: object, candidate: dict[str, object]) -> float:
    return calculate_dispatch_cost(solution, candidate)


@planning_solution(
    score=HardSoftScore,
    constraints=constraints,
    candidate_metrics=[dispatch_cost],
)
class DispatchPlan:
    ...
```

The callback receives a read-only solution view and the core candidate's
canonical operation or composite identity. It must return a finite number;
probabilistic metrics must also be non-negative. Metrics rank candidates already
generated by the core and do not build or execute a Python-side selector.

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
from solverforge import (
    ListRouteHooks,
    ListSavingsHooks,
    RowField,
    SolutionCallback,
    planning_entity,
    planning_list_variable,
)


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

List variables expose owner, precedence, route, savings, and nearby-distance
metadata to the native solver through explicit sources:

```python
@planning_entity
class Vehicle:
    delivery_order = planning_list_variable(
        element_collection="delivery_indices",
        route=ListRouteHooks(
            depot=RowField("depot"),
            distance=RowField("distance_matrix"),
            feasible=SolutionCallback(route_feasible),
        ),
        savings=ListSavingsHooks(
            depot=RowField("depot"),
            metric_class=RowField("metric_class"),
            distance=RowField("distance_matrix"),
            feasible=SolutionCallback(route_feasible),
        ),
    )
```

Use `element_owner`, `construction_element_order_key`,
`precedence_duration`, and `precedence_successors` for owner-aware queues and
precedence-list scoring. Each accepts either a Python callback or a
solution-level sequence field indexed by element ID. Declared sequences are
validated before state import; missing or malformed owner, order, duration, or
successor data never becomes an unrestricted default.

For nested list metadata:

- `RowField("name")` reads only a field on the route-owning entity.
- `SolutionField("name")` reads only immutable solution-root data.
- `EntityCallback(fn)` calls a function scoped to the owning entity.
- `SolutionCallback(fn)` calls a function scoped to the solution.
- `CapacityRouteFeasibility(capacity=..., demand=...)` declares independently
  scoped capacity and demand fields.

`ListRouteHooks` and `ListSavingsHooks` are complete, independent bundles. A
route bundle does not implicitly enable Clarke-Wright savings. Nearby list
selectors use their own `cross_position_distance` and
`intra_position_distance` sources; neither is inferred from route distance.

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
- Scope nested list metadata explicitly with row, solution, entity-callback, or
  solution-callback wrappers.
- Register every configured candidate metric on the solution and return finite
  values from it.
- Initialize `score` to `None`.
- Validate and normalize input data before calling the solver.
