---
title: "SolverForge (Legacy)"
linkTitle: "Python Solver"
icon: fa-brands fa-python
weight: 100
tags: [python]
description: >
  Technical documentation for SolverForge Legacy — the pure Python constraint solver using the Timefold backend.
---

Every organization faces planning problems: providing products or services with a limited set of *constrained* resources (employees, assets, time, and money). SolverForge's [Planning AI](concepts/what-is-planning.md) optimizes these problems to do more business with fewer resources using Constraint Satisfaction Programming.

SolverForge is a lightweight, embeddable constraint satisfaction engine which optimizes planning problems. Example use cases include:

- **Vehicle Routing** - Optimize delivery routes for fleets of vehicles
- **Employee Scheduling** - Assign shifts to employees based on skills and availability
- **School Timetabling** - Schedule lessons to timeslots and rooms
- **Meeting Scheduling** - Find optimal times and rooms for meetings
- **Bin Packing** - Efficiently pack items into containers
- **Task Assignment** - Assign tasks to resources optimally

![Use Case Overview](images/useCaseOverview.png)

## Python-First Design

SolverForge provides a Pythonic API using:

- **Decorators** for domain modeling (`@planning_entity`, `@planning_solution`)
- **Type annotations** with `Annotated` for constraint and property marking
- **Dataclasses** for clean, readable domain models
- **Fluent constraint stream API** for intuitive constraint definition

```python
from dataclasses import dataclass, field
from typing import Annotated
from solverforge_legacy.solver.domain import (
    planning_entity, planning_solution,
    PlanningId, PlanningVariable, PlanningEntityCollectionProperty,
    ProblemFactCollectionProperty, ValueRangeProvider, PlanningScore
)
from solverforge_legacy.solver.score import HardSoftScore

@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    teacher: str
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)

@planning_solution
@dataclass
class Timetable:
    timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]
    rooms: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
    lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
    score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```

## Requirements

- **Python 3.10+** (3.11 or 3.12 recommended)
- **JDK 17+** (for the optimization engine backend)

## Next Steps

- Follow the [Getting Started guides](/docs/getting-started/) to solve your first planning problem
- Learn about [Planning AI concepts](concepts/what-is-planning.md)
