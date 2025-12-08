---
title: "Pinning"
linkTitle: "Pinning"
weight: 50
tags: [concepts, python]
description: >
  Lock specific assignments to prevent the solver from changing them.
---

**Pinning** locks certain assignments so the solver cannot change them. This is useful for:

- Preserving manual decisions
- Locking in-progress or completed work
- Incremental planning with fixed history

## PlanningPin Annotation

Mark an entity as pinned using the `PlanningPin` annotation:

```python
from dataclasses import dataclass, field
from typing import Annotated
from solverforge_legacy.solver.domain import (
    planning_entity,
    PlanningId,
    PlanningVariable,
    PlanningPin,
)

@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    teacher: str
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)
    # When True, solver won't change this lesson's assignments
    pinned: Annotated[bool, PlanningPin] = field(default=False)
```

When `pinned=True`, the solver will not modify `timeslot` or `room` for this lesson.

## Setting Pinned State

### At Problem Creation

```python
lessons = [
    Lesson("1", "Math", "A. Turing", timeslot=monday_8am, room=room_a, pinned=True),  # Fixed
    Lesson("2", "Physics", "M. Curie", pinned=False),  # Solver will assign
]
```

### Based on Time

Pin lessons that are already in progress or past:

```python
from datetime import datetime

def create_problem(lessons: list[Lesson], current_time: datetime) -> Timetable:
    for lesson in lessons:
        if lesson.timeslot and lesson.timeslot.start_time <= current_time:
            lesson.pinned = True
    return Timetable(...)
```

### Based on User Decisions

```python
def pin_manual_assignments(lesson: Lesson, is_manual: bool):
    lesson.pinned = is_manual
```

## PlanningPinToIndex for List Variables

For list variables (routing), you can pin elements up to a certain index:

```python
from solverforge_legacy.solver.domain import PlanningPinToIndex

@planning_entity
@dataclass
class Vehicle:
    id: Annotated[str, PlanningId]
    visits: Annotated[list[Visit], PlanningListVariable] = field(default_factory=list)
    # Elements at index 0, 1, ..., (pinned_index-1) are pinned
    pinned_index: Annotated[int, PlanningPinToIndex] = field(default=0)
```

Example:
- `pinned_index=0` - No visits are pinned (all can be reordered)
- `pinned_index=3` - First 3 visits are locked in place
- `pinned_index=len(visits)` - All visits are pinned

### Updating Pinned Index

```python
def update_pinned_for_in_progress(vehicle: Vehicle, current_time: datetime):
    """Pin visits that have already started."""
    pinned_count = 0
    for visit in vehicle.visits:
        if visit.arrival_time and visit.arrival_time <= current_time:
            pinned_count += 1
        else:
            break  # Stop at first unstarted visit
    vehicle.pinned_index = pinned_count
```

## Use Cases

### Continuous Planning

In continuous planning, pin the past and near future:

```python
def prepare_for_replanning(solution: Schedule, current_time: datetime, buffer: timedelta):
    """
    Pin assignments that:
    - Have already started (in the past)
    - Are starting soon (within buffer time)
    """
    publish_deadline = current_time + buffer

    for shift in solution.shifts:
        if shift.start_time < publish_deadline:
            shift.pinned = True
        else:
            shift.pinned = False
```

### Respecting User Decisions

```python
def load_schedule_with_pins(raw_data) -> Schedule:
    shifts = []
    for data in raw_data:
        shift = Shift(
            id=data["id"],
            employee=find_employee(data["employee_id"]),
            pinned=data.get("manually_assigned", False)
        )
        shifts.append(shift)
    return Schedule(shifts=shifts)
```

### Incremental Solving

Pin everything except new entities:

```python
def add_new_lessons(solution: Timetable, new_lessons: list[Lesson]) -> Timetable:
    # Pin all existing lessons
    for lesson in solution.lessons:
        lesson.pinned = True

    # Add new lessons (unpinned)
    for lesson in new_lessons:
        lesson.pinned = False
        solution.lessons.append(lesson)

    return solution
```

## Behavior Notes

### Pinned Entities Still Affect Score

Pinned entities participate in constraint evaluation:

```python
# This constraint still fires if a pinned lesson conflicts with an unpinned one
def room_conflict(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each_unique_pair(Lesson, ...)
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Room conflict")
    )
```

### Initialization

Pinned entities must have their planning variables already assigned:

```python
# Correct: pinned entity has assigned values
Lesson("1", "Math", "Teacher", timeslot=slot, room=room, pinned=True)

# Incorrect: pinned entity without assignment (will cause issues)
Lesson("2", "Physics", "Teacher", timeslot=None, room=None, pinned=True)
```

## Constraints with Pinning

You might want different constraint behavior for pinned vs unpinned:

```python
def prefer_unpinned_over_pinned(factory: ConstraintFactory) -> Constraint:
    """If there's a conflict, prefer to move the unpinned lesson."""
    return (
        factory.for_each(Lesson)
        .filter(lambda lesson: lesson.pinned)
        .join(
            Lesson,
            Joiners.equal(lambda l: l.timeslot),
            Joiners.equal(lambda l: l.room),
            Joiners.filtering(lambda pinned, other: not other.pinned)
        )
        # Penalize the unpinned lesson in conflict
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Conflict with pinned lesson")
    )
```

## Best Practices

### Do

- Pin entities that represent completed or in-progress work
- Use `PlanningPinToIndex` for routing problems
- Ensure pinned entities have valid assignments

### Don't

- Pin too many entities (solver has less freedom)
- Forget to unpin entities when requirements change
- Create infeasible problems by pinning conflicting entities

## Next Steps

- [Real-Time Planning](../patterns/real-time-planning.md) - Handle changes during solving
- [Continuous Planning](../patterns/continuous-planning.md) - Rolling horizon patterns
