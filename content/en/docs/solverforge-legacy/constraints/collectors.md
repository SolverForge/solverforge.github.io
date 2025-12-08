---
title: "Collectors"
linkTitle: "Collectors"
weight: 30
tags: [reference, python]
description: >
  Aggregate data in constraint streams using collectors.
---

**Collectors** aggregate data when grouping entities. They're used with `group_by()` to compute counts, sums, lists, and other aggregations.

## Basic Usage

```python
from solverforge_legacy.solver.score import ConstraintCollectors

factory.for_each(Shift)
.group_by(
    lambda shift: shift.employee,       # Group key
    ConstraintCollectors.count()        # Collector
)
# Result: BiStream of (employee, count)
```

## Available Collectors

### count()

Count items in each group:

```python
factory.for_each(Shift)
.group_by(
    lambda shift: shift.employee,
    ConstraintCollectors.count()
)
# (Employee, int)
```

### count_distinct()

Count unique values:

```python
factory.for_each(Lesson)
.group_by(
    lambda lesson: lesson.teacher,
    ConstraintCollectors.count_distinct(lambda l: l.room)
)
# (Teacher, number of distinct rooms)
```

### sum()

Sum numeric values:

```python
factory.for_each(Visit)
.group_by(
    lambda visit: visit.vehicle,
    ConstraintCollectors.sum(lambda v: v.demand)
)
# (Vehicle, total demand)
```

### min() / max()

Find minimum or maximum:

```python
factory.for_each(Shift)
.group_by(
    lambda shift: shift.employee,
    ConstraintCollectors.min(lambda s: s.start_time)
)
# (Employee, earliest start time)
```

With comparator:

```python
ConstraintCollectors.max(
    lambda shift: shift,
    key=lambda s: s.priority
)
# Returns the shift with highest priority
```

### average()

Calculate average:

```python
factory.for_each(Task)
.group_by(
    lambda task: task.worker,
    ConstraintCollectors.average(lambda t: t.duration)
)
# (Worker, average task duration)
```

### to_list()

Collect into a list:

```python
factory.for_each(Visit)
.group_by(
    lambda visit: visit.vehicle,
    ConstraintCollectors.to_list(lambda v: v)
)
# (Vehicle, list of visits)
```

### to_set()

Collect into a set (unique values):

```python
factory.for_each(Lesson)
.group_by(
    lambda lesson: lesson.teacher,
    ConstraintCollectors.to_set(lambda l: l.room)
)
# (Teacher, set of rooms)
```

### to_sorted_set()

Collect into a sorted set:

```python
factory.for_each(Shift)
.group_by(
    lambda shift: shift.employee,
    ConstraintCollectors.to_sorted_set(lambda s: s.start_time)
)
# (Employee, sorted set of start times)
```

### compose()

Combine multiple collectors:

```python
ConstraintCollectors.compose(
    ConstraintCollectors.count(),
    ConstraintCollectors.sum(lambda s: s.hours),
    lambda count, total_hours: (count, total_hours)
)
# Returns (count, sum) tuple
```

### conditional()

Collect only matching items:

```python
ConstraintCollectors.conditional(
    lambda shift: shift.is_night,
    ConstraintCollectors.count()
)
# Count only night shifts
```

## Multiple Collectors

Use multiple collectors in one group_by:

```python
factory.for_each(Shift)
.group_by(
    lambda shift: shift.employee,
    ConstraintCollectors.count(),
    ConstraintCollectors.sum(lambda s: s.hours),
    ConstraintCollectors.min(lambda s: s.start_time),
)
# QuadStream: (Employee, count, total_hours, earliest_start)
```

## Grouping Patterns

### Count Per Category

```python
def balance_shift_count(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Shift)
        .group_by(
            lambda shift: shift.employee,
            ConstraintCollectors.count()
        )
        .filter(lambda employee, count: count > 5)
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda employee, count: (count - 5) ** 2
        )
        .as_constraint("Balance shift count")
    )
```

### Sum with Threshold

```python
def vehicle_capacity(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Visit)
        .group_by(
            lambda visit: visit.vehicle,
            ConstraintCollectors.sum(lambda v: v.demand)
        )
        .filter(lambda vehicle, total: total > vehicle.capacity)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda vehicle, total: total - vehicle.capacity
        )
        .as_constraint("Vehicle capacity")
    )
```

### Load Distribution

```python
def fair_distribution(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Task)
        .group_by(
            lambda task: task.worker,
            ConstraintCollectors.count()
        )
        .group_by(
            ConstraintCollectors.min(lambda worker, count: count),
            ConstraintCollectors.max(lambda worker, count: count),
        )
        .filter(lambda min_count, max_count: max_count - min_count > 2)
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda min_count, max_count: max_count - min_count
        )
        .as_constraint("Fair task distribution")
    )
```

### Consecutive Detection

```python
def consecutive_shifts(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Shift)
        .group_by(
            lambda shift: shift.employee,
            ConstraintCollectors.to_sorted_set(lambda s: s.date)
        )
        .filter(lambda employee, dates: has_consecutive_days(dates, 6))
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Max consecutive days")
    )

def has_consecutive_days(dates: set, max_consecutive: int) -> bool:
    sorted_dates = sorted(dates)
    consecutive = 1
    for i in range(1, len(sorted_dates)):
        if (sorted_dates[i] - sorted_dates[i-1]).days == 1:
            consecutive += 1
            if consecutive > max_consecutive:
                return True
        else:
            consecutive = 1
    return False
```

## Performance Tips

### Prefer count() over to_list()

```python
# Good: Efficient counting
ConstraintCollectors.count()

# Avoid: Creates list just to count
ConstraintCollectors.to_list(lambda x: x).map(len)
```

### Use conditional() for Filtered Counts

```python
# Good: Single pass
ConstraintCollectors.conditional(
    lambda s: s.is_weekend,
    ConstraintCollectors.count()
)

# Avoid: Filter then count
factory.for_each(Shift)
.filter(lambda s: s.is_weekend)
.group_by(...)
```

### Minimize Data in Collectors

```python
# Good: Collect only needed data
ConstraintCollectors.to_list(lambda s: s.start_time)

# Avoid: Collect entire objects
ConstraintCollectors.to_list(lambda s: s)
```

## Next Steps

- [Score Types](score-types.md) - Scoring with constraints
- [Performance](performance.md) - Optimize constraint evaluation
