---
title: "Joiners"
linkTitle: "Joiners"
weight: 20
tags: [reference, python]
description: >
  Efficiently filter and match entities in constraint streams.
---

**Joiners** efficiently filter pairs of entities during joins and unique pair operations. They're more efficient than post-join filtering because they use indexing.

## Basic Usage

```python
from solverforge_legacy.solver.score import Joiners

factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda lesson: lesson.timeslot),
    Joiners.equal(lambda lesson: lesson.room),
)
```

Multiple joiners are combined with AND logic.

## Available Joiners

### equal()

Match when property values are equal:

```python
# Same timeslot
Joiners.equal(lambda lesson: lesson.timeslot)

# In a join, specify both sides
factory.for_each(Lesson).join(
    Room,
    Joiners.equal(lambda lesson: lesson.room, lambda room: room)
)
```

### less_than() / less_than_or_equal()

Match when first value is less than second:

```python
# l1.priority < l2.priority
Joiners.less_than(lambda lesson: lesson.priority)

# l1.start_time <= l2.start_time
Joiners.less_than_or_equal(lambda lesson: lesson.start_time)
```

### greater_than() / greater_than_or_equal()

Match when first value is greater than second:

```python
# l1.priority > l2.priority
Joiners.greater_than(lambda lesson: lesson.priority)

# l1.end_time >= l2.end_time
Joiners.greater_than_or_equal(lambda lesson: lesson.end_time)
```

### overlapping()

Match when ranges overlap:

```python
# Time overlap: [start1, end1) overlaps [start2, end2)
Joiners.overlapping(
    lambda l: l.start_time,   # Start of range 1
    lambda l: l.end_time,     # End of range 1
    lambda l: l.start_time,   # Start of range 2
    lambda l: l.end_time,     # End of range 2
)
```

For a join between different types:

```python
factory.for_each(Meeting).join(
    Availability,
    Joiners.overlapping(
        lambda m: m.start_time,
        lambda m: m.end_time,
        lambda a: a.start_time,
        lambda a: a.end_time,
    )
)
```

### filtering()

Custom filter function (less efficient, use as last resort):

```python
# Custom logic that can't be expressed with other joiners
Joiners.filtering(lambda l1, l2: l1.is_compatible_with(l2))
```

## Combining Joiners

Joiners are combined with AND:

```python
factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.timeslot),    # Same timeslot AND
    Joiners.equal(lambda l: l.room),         # Same room
)
```

## Performance Considerations

### Index-Based Joiners (Preferred)

These joiners use internal indexes for O(1) or O(log n) lookup:

- `equal()` - Hash index
- `less_than()`, `greater_than()` - Tree index
- `overlapping()` - Interval tree

### Filtering Joiner (Slower)

`filtering()` checks every pair, O(n²):

```python
# Avoid when possible - checks all pairs
Joiners.filtering(lambda l1, l2: some_complex_check(l1, l2))
```

### Optimization Tips

**Good:** Index joiners first, filtering last:

```python
factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.timeslot),       # Index first
    Joiners.filtering(lambda l1, l2: custom(l1, l2))  # Filter remaining
)
```

**Bad:** Only filtering (checks all pairs):

```python
factory.for_each_unique_pair(
    Lesson,
    Joiners.filtering(lambda l1, l2: l1.timeslot == l2.timeslot and custom(l1, l2))
)
```

## Examples

### Time Conflict Detection

```python
def time_conflict(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each_unique_pair(
            Shift,
            Joiners.equal(lambda s: s.employee),
            Joiners.overlapping(
                lambda s: s.start_time,
                lambda s: s.end_time,
                lambda s: s.start_time,
                lambda s: s.end_time,
            ),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Employee time conflict")
    )
```

### Same Day Sequential

```python
def same_day_sequential(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Lesson)
        .join(
            Lesson,
            Joiners.equal(lambda l: l.teacher),
            Joiners.equal(lambda l: l.timeslot.day_of_week),
            Joiners.less_than(lambda l: l.timeslot.start_time),
            Joiners.filtering(lambda l1, l2:
                (l2.timeslot.start_time - l1.timeslot.end_time).seconds <= 1800
            ),
        )
        .reward(HardSoftScore.ONE_SOFT)
        .as_constraint("Teacher consecutive lessons")
    )
```

### Resource Assignment

```python
def resource_assignment(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Task)
        .join(
            Resource,
            Joiners.equal(lambda t: t.required_skill, lambda r: r.skill),
            Joiners.greater_than_or_equal(lambda t: t.priority, lambda r: r.min_priority),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Resource skill match")
    )
```

## Joiner vs Filter

| Use Joiner When | Use Filter When |
|-----------------|-----------------|
| Checking equality | Complex logic |
| Comparing values | Multiple conditions with OR |
| Range overlap | Calling methods on entities |
| Performance matters | Simple one-off checks |

## Next Steps

- [Collectors](collectors.md) - Aggregate grouped data
- [Performance](performance.md) - Optimize constraint evaluation
