---
title: "Planning Solutions"
linkTitle: "Planning Solutions"
weight: 30
tags: [concepts, python]
description: >
  Define the container for problem data and solution score.
---

A **planning solution** is the container class that holds all problem data, planning entities, and the solution score.

## The @planning_solution Decorator

```python
from dataclasses import dataclass, field
from typing import Annotated
from solverforge_legacy.solver.domain import (
    planning_solution,
    ProblemFactCollectionProperty,
    ProblemFactProperty,
    PlanningEntityCollectionProperty,
    ValueRangeProvider,
    PlanningScore,
)
from solverforge_legacy.solver.score import HardSoftScore

@planning_solution
@dataclass
class Timetable:
    id: str
    timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]
    rooms: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
    lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
    score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```

## Solution Components

A planning solution contains:

1. **Problem Facts** - Immutable input data
2. **Planning Entities** - Mutable entities with planning variables
3. **Score** - Quality measure of the solution

## Problem Facts

Problem facts are immutable data that define the problem:

### Collection Property

For lists of facts:

```python
timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty]
rooms: Annotated[list[Room], ProblemFactCollectionProperty]
employees: Annotated[list[Employee], ProblemFactCollectionProperty]
```

### Single Property

For single facts:

```python
config: Annotated[ScheduleConfig, ProblemFactProperty]
start_date: Annotated[date, ProblemFactProperty]
```

## Value Range Providers

Value ranges provide possible values for planning variables. Combine with problem fact annotations:

```python
# This list provides values for Timeslot planning variables
timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]

# This list provides values for Room planning variables
rooms: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
```

The solver automatically matches variables to value ranges by type:
- `PlanningVariable` of type `Timeslot` uses `list[Timeslot]`
- `PlanningVariable` of type `Room` uses `list[Room]`

### Multiple Ranges for Same Type

If you have multiple value ranges of the same type, use explicit references:

```python
@planning_solution
@dataclass
class Schedule:
    preferred_timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]
    backup_timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]
```

## Planning Entities

Collect planning entities in the solution:

```python
lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
```

For a single entity:

```python
main_vehicle: Annotated[Vehicle, PlanningEntityProperty]
```

## Score

Every solution needs a score field:

```python
score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```

Common score types:
- `SimpleScore` - Single level
- `HardSoftScore` - Feasibility + optimization
- `HardMediumSoftScore` - Three levels
- `BendableScore` - Custom levels

The solver calculates and updates this field automatically.

## Solution Identity

Include an identifier for tracking:

```python
@planning_solution
@dataclass
class Timetable:
    id: str  # For tracking in SolverManager
    ...
```

## Complete Example

```python
from dataclasses import dataclass, field
from typing import Annotated
from datetime import date

from solverforge_legacy.solver.domain import (
    planning_solution,
    ProblemFactCollectionProperty,
    ProblemFactProperty,
    PlanningEntityCollectionProperty,
    ValueRangeProvider,
    PlanningScore,
)
from solverforge_legacy.solver.score import HardSoftScore


@planning_solution
@dataclass
class EmployeeSchedule:
    # Identity
    id: str

    # Problem facts
    schedule_start: Annotated[date, ProblemFactProperty]
    employees: Annotated[list[Employee], ProblemFactCollectionProperty, ValueRangeProvider]
    skills: Annotated[list[Skill], ProblemFactCollectionProperty]

    # Planning entities
    shifts: Annotated[list[Shift], PlanningEntityCollectionProperty]

    # Score
    score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```

## Creating Problem Instances

Load or generate problem data:

```python
def load_problem() -> Timetable:
    timeslots = [
        Timeslot("MONDAY", time(8, 30), time(9, 30)),
        Timeslot("MONDAY", time(9, 30), time(10, 30)),
        # ...
    ]

    rooms = [
        Room("Room A"),
        Room("Room B"),
    ]

    lessons = [
        Lesson("1", "Math", "A. Turing", "9th grade"),
        Lesson("2", "Physics", "M. Curie", "9th grade"),
        # ...
    ]

    return Timetable(
        id="problem-001",
        timeslots=timeslots,
        rooms=rooms,
        lessons=lessons,
        score=None,  # Solver will calculate this
    )
```

## Accessing the Solved Solution

After solving, the solution contains assigned variables and score:

```python
solution = solver.solve(problem)

print(f"Score: {solution.score}")
print(f"Is feasible: {solution.score.is_feasible}")

for lesson in solution.lessons:
    print(f"{lesson.subject}: {lesson.timeslot} in {lesson.room}")
```

## Solution Cloning

The solver internally clones solutions to track the best solution. This happens automatically with `@dataclass` entities.

For custom classes, ensure proper cloning behavior or use `@deep_planning_clone`:

```python
from solverforge_legacy.solver.domain import deep_planning_clone

@deep_planning_clone
class CustomClass:
    # This class will be deeply cloned during solving
    pass
```

## Best Practices

### Do

- Use `@dataclass` for solutions
- Initialize score to `None`
- Include all data needed for constraint evaluation
- Use descriptive field names

### Don't

- Include data not used in constraints (performance impact)
- Modify problem facts during solving
- Forget value range providers for planning variables

## Next Steps

- [Shadow Variables](shadow-variables.md) - Calculated variables
- [Constraints](../constraints/) - Define scoring rules
