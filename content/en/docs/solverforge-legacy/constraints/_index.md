---
title: "Constraints"
linkTitle: "Constraints"
weight: 40
description: >
  Define constraints using the fluent Constraint Streams API.
---

Constraints define the rules that make a solution valid and optimal. SolverForge uses a fluent Constraint Streams API that lets you express constraints declaratively.

## Topics

- **[Constraint Streams](constraint-streams.md)** - The core API for building constraints
- **[Joiners](joiners.md)** - Efficiently filter and match entities
- **[Collectors](collectors.md)** - Aggregate data for scoring
- **[Score Types](score-types.md)** - Hard, soft, and multi-level scoring
- **[Score Analysis](score-analysis.md)** - Understand why a solution has its score
- **[Performance](performance.md)** - Optimize constraint evaluation
- **[Testing](testing.md)** - Test your constraints in isolation

## Constraint Types

| Type | Purpose | Example |
|------|---------|---------|
| **Hard** | Must be satisfied for feasibility | No two lessons in the same room at the same time |
| **Soft** | Preferences to optimize | Teachers prefer consecutive lessons |
| **Medium** | Between hard and soft (optional) | Important but not mandatory constraints |

## Example

```python
from solverforge_legacy.solver.score import (
    constraint_provider, ConstraintFactory, Constraint, Joiners, HardSoftScore
)

@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory) -> list[Constraint]:
    return [
        room_conflict(constraint_factory),
        teacher_conflict(constraint_factory),
        teacher_room_stability(constraint_factory),
    ]

def room_conflict(constraint_factory: ConstraintFactory) -> Constraint:
    # Hard constraint: No two lessons in the same room at the same time
    return (
        constraint_factory
        .for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.timeslot),
            Joiners.equal(lambda lesson: lesson.room),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Room conflict")
    )

def teacher_room_stability(constraint_factory: ConstraintFactory) -> Constraint:
    # Soft constraint: Teachers prefer teaching in the same room
    return (
        constraint_factory
        .for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.teacher),
        )
        .filter(lambda lesson1, lesson2: lesson1.room != lesson2.room)
        .penalize(HardSoftScore.ONE_SOFT)
        .as_constraint("Teacher room stability")
    )
```
