---
title: "Constraint Streams"
linkTitle: "Constraint Streams"
weight: 10
description: >
  Build constraints using the fluent Constraint Streams API.
---

The **Constraint Streams API** is a fluent, declarative way to define constraints. It's inspired by Java Streams and SQL, allowing you to express complex scoring logic concisely.

## Basic Structure

Every constraint follows this pattern:

```python
from solverforge_legacy.solver.score import (
    constraint_provider, ConstraintFactory, Constraint, HardSoftScore
)

@constraint_provider
def define_constraints(factory: ConstraintFactory) -> list[Constraint]:
    return [
        my_constraint(factory),
    ]

def my_constraint(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(MyEntity)        # 1. Select entities
        .filter(lambda e: e.is_active)    # 2. Filter matches
        .penalize(HardSoftScore.ONE_HARD) # 3. Apply score impact
        .as_constraint("My constraint")   # 4. Name the constraint
    )
```

## Stream Types

Streams are typed by the number of entities they carry:

| Stream Type | Entities | Example Use |
|-------------|----------|-------------|
| `UniConstraintStream` | 1 | Single entity constraints |
| `BiConstraintStream` | 2 | Pair constraints |
| `TriConstraintStream` | 3 | Triple constraints |
| `QuadConstraintStream` | 4 | Quad constraints |

## Starting a Stream

### for_each()

Start with all instances of an entity class:

```python
factory.for_each(Lesson)
# Stream of: Lesson1, Lesson2, Lesson3, ...
```

### for_each_unique_pair()

Get all unique pairs (no duplicates, no self-pairs):

```python
factory.for_each_unique_pair(Lesson)
# Stream of: (L1,L2), (L1,L3), (L2,L3), ...
# NOT: (L1,L1), (L2,L1), ...
```

With joiners for efficient filtering:

```python
factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.timeslot),
    Joiners.equal(lambda l: l.room),
)
# Only pairs with same timeslot AND same room
```

### for_each_including_unassigned()

Include entities with unassigned planning variables:

```python
factory.for_each_including_unassigned(Lesson)
# Includes lessons where timeslot=None or room=None
```

## Filtering

### filter()

Remove non-matching items:

```python
factory.for_each(Lesson)
.filter(lambda lesson: lesson.teacher == "A. Turing")
```

For bi-streams:

```python
factory.for_each_unique_pair(Lesson)
.filter(lambda l1, l2: l1.room != l2.room)
```

## Joining

### join()

Combine streams:

```python
factory.for_each(Lesson)
.join(Room)
# BiStream of (Lesson, Room) for all combinations
```

With joiners:

```python
factory.for_each(Lesson)
.join(
    Room,
    Joiners.equal(lambda lesson: lesson.room, lambda room: room)
)
# BiStream of (Lesson, Room) where lesson.room == room
```

See [Joiners](joiners.md) for available joiner types.

### if_exists() / if_not_exists()

Check for existence without creating pairs:

```python
# Lessons that have at least one other lesson in the same room
factory.for_each(Lesson)
.if_exists(
    Lesson,
    Joiners.equal(lambda l: l.room),
    Joiners.filtering(lambda l1, l2: l1.id != l2.id)
)
```

```python
# Employees not assigned to any shift
factory.for_each(Employee)
.if_not_exists(
    Shift,
    Joiners.equal(lambda emp: emp, lambda shift: shift.employee)
)
```

## Grouping

### group_by()

Aggregate entities:

```python
from solverforge_legacy.solver.score import ConstraintCollectors

# Count lessons per teacher
factory.for_each(Lesson)
.group_by(
    lambda lesson: lesson.teacher,
    ConstraintCollectors.count()
)
# BiStream of (teacher, count)
```

Multiple collectors:

```python
# Get count and list of lessons per teacher
factory.for_each(Lesson)
.group_by(
    lambda lesson: lesson.teacher,
    ConstraintCollectors.count(),
    ConstraintCollectors.to_list(lambda l: l)
)
# TriStream of (teacher, count, lesson_list)
```

See [Collectors](collectors.md) for available collector types.

## Mapping

### map()

Transform stream elements:

```python
factory.for_each(Lesson)
.map(lambda lesson: lesson.teacher)
# UniStream of teachers (with duplicates)
```

### expand()

Add derived values:

```python
factory.for_each(Lesson)
.expand(lambda lesson: lesson.duration_minutes)
# BiStream of (Lesson, duration)
```

### distinct()

Remove duplicates:

```python
factory.for_each(Lesson)
.map(lambda lesson: lesson.teacher)
.distinct()
# UniStream of unique teachers
```

## Scoring

### penalize()

Apply negative score for matches:

```python
# Hard constraint
.penalize(HardSoftScore.ONE_HARD)

# Soft constraint
.penalize(HardSoftScore.ONE_SOFT)

# Dynamic weight
.penalize(HardSoftScore.ONE_SOFT, lambda lesson: lesson.priority)
```

### reward()

Apply positive score for matches:

```python
# Reward preferred assignments
.reward(HardSoftScore.ONE_SOFT, lambda lesson: lesson.preference_score)
```

### impact()

Apply positive or negative score based on value:

```python
# Positive values reward, negative values penalize
.impact(HardSoftScore.ONE_SOFT, lambda l: l.score_impact)
```

## Finalizing

### as_constraint()

Name the constraint (required):

```python
.as_constraint("Room conflict")
```

### justify_with()

Add custom justification for score explanation:

```python
.penalize(HardSoftScore.ONE_HARD)
.justify_with(lambda l1, l2, score: RoomConflictJustification(l1, l2, score))
.as_constraint("Room conflict")
```

### indict_with()

Specify which entities to blame:

```python
.penalize(HardSoftScore.ONE_HARD)
.indict_with(lambda l1, l2: [l1, l2])
.as_constraint("Room conflict")
```

## Complete Examples

### Room Conflict (Hard)

```python
def room_conflict(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda l: l.timeslot),
            Joiners.equal(lambda l: l.room),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Room conflict")
    )
```

### Teacher Room Stability (Soft)

```python
def teacher_room_stability(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda l: l.teacher)
        )
        .filter(lambda l1, l2: l1.room != l2.room)
        .penalize(HardSoftScore.ONE_SOFT)
        .as_constraint("Teacher room stability")
    )
```

### Balance Workload (Soft)

```python
def balance_workload(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Shift)
        .group_by(
            lambda shift: shift.employee,
            ConstraintCollectors.count()
        )
        .filter(lambda employee, count: count > 5)
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda employee, count: count - 5  # Penalize excess shifts
        )
        .as_constraint("Balance workload")
    )
```

## Best Practices

### Do

- Use joiners in `for_each_unique_pair()` for efficiency
- Name constraints descriptively
- Break complex constraints into helper functions

### Don't

- Use `filter()` when a joiner would work (less efficient)
- Create overly complex single constraints (split them)
- Forget to call `as_constraint()`

## Next Steps

- [Joiners](joiners.md) - Efficient filtering operations
- [Collectors](collectors.md) - Aggregation operations
- [Score Types](score-types.md) - Hard, soft, and multi-level scoring
