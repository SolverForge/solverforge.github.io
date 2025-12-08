---
title: "Domain Modeling"
linkTitle: "Modeling"
weight: 30
description: >
  Model your planning problem with entities, variables, and solutions.
---

Domain modeling is the foundation of any SolverForge application. You define your problem structure using Python dataclasses and type annotations.

## Core Concepts

- **[Planning Entities](planning-entities.md)** - Objects that the solver will modify (e.g., lessons, shifts, visits)
- **[Planning Variables](planning-variables.md)** - Properties that the solver assigns values to
- **[Planning Solutions](planning-solutions.md)** - The container for all problem data and the score
- **[Shadow Variables](shadow-variables.md)** - Derived variables calculated from other variables
- **[Pinning](pinning.md)** - Lock certain assignments to prevent changes

## Model Structure

A typical SolverForge model consists of:

```
Planning Solution
├── Problem Facts (immutable data)
│   ├── Timeslots, Rooms, Employees, etc.
│   └── Value Range Providers
├── Planning Entities (mutable)
│   └── Planning Variables (assigned by solver)
└── Score (calculated from constraints)
```

## Example

```python
@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    teacher: str
    # Planning variables - assigned by the solver
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)

@planning_solution
@dataclass
class Timetable:
    # Problem facts - immutable
    timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]
    rooms: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
    # Planning entities - contain variables to optimize
    lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
    # Score - calculated by constraints
    score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```
