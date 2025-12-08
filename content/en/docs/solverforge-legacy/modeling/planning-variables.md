---
title: "Planning Variables"
linkTitle: "Planning Variables"
weight: 20
description: >
  Define what the solver assigns: simple variables and list variables.
---

A **planning variable** is a property of a planning entity that the solver assigns values to during optimization.

## Simple Planning Variable

The most common type assigns a single value from a value range:

```python
from dataclasses import dataclass, field
from typing import Annotated
from solverforge_legacy.solver.domain import planning_entity, PlanningId, PlanningVariable

@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    # Simple planning variable
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)
```

### How It Works

1. The solver sees `timeslot` needs a value
2. It looks for a `ValueRangeProvider` for `Timeslot` in the solution
3. It tries different values and evaluates the score
4. It assigns the best value found within the time limit

## Planning List Variable

For routing problems where order matters, use `PlanningListVariable`:

```python
from solverforge_legacy.solver.domain import PlanningListVariable

@planning_entity
@dataclass
class Vehicle:
    id: Annotated[str, PlanningId]
    capacity: int
    home_location: Location
    # List variable - ordered sequence of visits
    visits: Annotated[list[Visit], PlanningListVariable] = field(default_factory=list)
```

### How It Works

The solver:
- Assigns visits to vehicles
- Determines the order of visits within each vehicle's route
- Uses moves like insert, swap, and 2-opt for optimization

### When to Use List Variables

Use `PlanningListVariable` when:
- Order matters (routing, sequencing)
- Entities belong to groups (visits per vehicle, tasks per worker)
- Chain relationships exist (predecessor/successor patterns)

## Nullable Variables

By default, all planning variables must be assigned. For optional assignments:

```python
@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    location: Location
    # This visit might not be assigned to any vehicle
    vehicle: Annotated[Vehicle | None, PlanningVariable(allows_unassigned=True)] = field(default=None)
```

> **Note:** When using nullable variables, add medium constraints to penalize unassigned entities.

## Value Range Providers

Planning variables need a source of possible values. This is configured in the planning solution:

```python
@planning_solution
@dataclass
class Timetable:
    # This list provides values for 'timeslot' variables
    timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]
    # This list provides values for 'room' variables
    rooms: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
    lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
    score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```

The solver matches variables to value ranges by type:
- `timeslot: Annotated[Timeslot | None, PlanningVariable]` uses `list[Timeslot]`
- `room: Annotated[Room | None, PlanningVariable]` uses `list[Room]`

## Variable Configuration Options

### Strength Comparator

For construction heuristics, you can specify how to order values:

```python
# Stronger values tried first during construction
timeslot: Annotated[
    Timeslot | None,
    PlanningVariable(value_range_provider_refs=["timeslots"])
] = field(default=None)
```

## Multiple Variables on One Entity

Entities can have multiple independent variables:

```python
@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    # Two independent variables
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)
```

Each variable is optimized independently—assigning `timeslot` doesn't affect `room`.

## Chained Variables (Alternative to List)

For simpler routing without list variables, you can use chained planning variables. However, `PlanningListVariable` is generally easier and more efficient.

## Variable Listener Pattern

When one variable affects another, use shadow variables:

```python
@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    location: Location
    # Calculated from vehicle's visit list
    vehicle: Annotated[Vehicle | None, InverseRelationShadowVariable(source_variable_name="visits")] = field(default=None)
    # Calculated from previous visit
    arrival_time: Annotated[datetime | None, CascadingUpdateShadowVariable(target_method_name="update_arrival_time")] = field(default=None)
```

See [Shadow Variables](shadow-variables.md) for details.

## Best Practices

### Do

- Initialize variables to `None` or empty list
- Use type hints with `| None` for nullable types
- Match value range types exactly

### Don't

- Mix list variables with simple variables for the same concept
- Use complex types as planning variables (use references instead)
- Forget to provide a value range

## Common Patterns

### Scheduling

```python
timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
```

### Assignment

```python
employee: Annotated[Employee | None, PlanningVariable] = field(default=None)
```

### Routing

```python
visits: Annotated[list[Visit], PlanningListVariable] = field(default_factory=list)
```

## Next Steps

- [Planning Solutions](planning-solutions.md) - Define value ranges
- [Shadow Variables](shadow-variables.md) - Calculated variables
