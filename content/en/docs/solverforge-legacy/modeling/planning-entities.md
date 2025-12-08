---
title: "Planning Entities"
linkTitle: "Planning Entities"
weight: 10
description: >
  Define planning entities that the solver will optimize.
---

A **planning entity** is a class whose instances the solver can change during optimization. Planning entities contain planning variables that get assigned values.

## The @planning_entity Decorator

Mark a class as a planning entity with `@planning_entity`:

```python
from dataclasses import dataclass, field
from typing import Annotated
from solverforge_legacy.solver.domain import planning_entity, PlanningId, PlanningVariable

@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    teacher: str
    student_group: str
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)
```

## Planning ID

Every planning entity must have a unique identifier marked with `PlanningId`:

```python
id: Annotated[str, PlanningId]
```

The ID is used for:
- Tracking entities during solving
- Cloning solutions
- Score explanation

The ID type can be `str`, `int`, or any hashable type.

## Genuine vs Shadow Entities

There are two types of planning entities:

### Genuine Entities

A **genuine** planning entity has at least one genuine planning variable that the solver directly assigns:

```python
@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    # Genuine variable - solver assigns this
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
```

### Shadow-Only Entities

A **shadow-only** entity has only shadow variables (calculated from other entities):

```python
@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    location: Location
    # Shadow variable - calculated from vehicle's visit list
    vehicle: Annotated[Vehicle | None, InverseRelationShadowVariable(...)] = field(default=None)
```

## Entity Properties

### Immutable Properties

Properties without `PlanningVariable` annotations are immutable during solving:

```python
@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str          # Immutable
    teacher: str          # Immutable
    student_group: str    # Immutable
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)  # Mutable
```

The solver never changes `subject`, `teacher`, or `student_group`.

### Default Values

Planning variables should have default values (typically `None`) for uninitialized state:

```python
timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
```

## Multiple Planning Variables

An entity can have multiple planning variables:

```python
@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    teacher: str
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)
```

Each variable is assigned independently by the solver.

## Entity Collections in Solution

Planning entities are collected in the planning solution:

```python
@planning_solution
@dataclass
class Timetable:
    lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
```

The solver iterates over this collection to find entities to optimize.

## Nullable Variables

By default, planning variables must be assigned. For nullable variables (when some entities might be unassigned), see [Planning Variables](planning-variables.md).

## Best Practices

### Do

- Use `@dataclass` for clean, simple entity definitions
- Give each entity a unique, stable ID
- Initialize planning variables to `None`
- Keep entities focused on a single concept

### Don't

- Put business logic in entities (use constraints instead)
- Make planning variables required in `__init__`
- Use mutable default arguments (use `field(default_factory=...)` instead)

## Example: Shift Assignment

```python
@planning_entity
@dataclass
class Shift:
    id: Annotated[str, PlanningId]
    start_time: datetime
    end_time: datetime
    required_skill: str
    # Assigned by solver
    employee: Annotated[Employee | None, PlanningVariable] = field(default=None)
```

## Example: Vehicle Routing

```python
@planning_entity
@dataclass
class Vehicle:
    id: Annotated[str, PlanningId]
    capacity: int
    home_location: Location
    # List of visits assigned to this vehicle
    visits: Annotated[list[Visit], PlanningListVariable] = field(default_factory=list)
```

## Next Steps

- [Planning Variables](planning-variables.md) - Learn about variable types
- [Planning Solutions](planning-solutions.md) - Container for entities and facts
