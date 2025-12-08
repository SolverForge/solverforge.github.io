---
title: "Constraint Performance"
linkTitle: "Performance"
weight: 60
description: >
  Optimize constraint evaluation for faster solving.
---

Efficient constraint evaluation is critical for solver performance. Most solving time is spent calculating scores, so optimizing constraints has a direct impact on solution quality.

## Performance Principles

### 1. Use Joiners Instead of Filters

Joiners use indexes for O(1) lookups. Filters check every item.

```python
# Good: Uses index
factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.timeslot)
)

# Bad: Checks all pairs
factory.for_each_unique_pair(Lesson)
.filter(lambda l1, l2: l1.timeslot == l2.timeslot)
```

### 2. Put Selective Joiners First

More selective joiners reduce the search space faster:

```python
# Good: timeslot has few values, filters early
factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.timeslot),  # Few timeslots
    Joiners.equal(lambda l: l.teacher),    # More teachers
)

# Less efficient: teacher might have many values
factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.teacher),    # Many teachers
    Joiners.equal(lambda l: l.timeslot),   # Then timeslot
)
```

### 3. Avoid Expensive Lambda Operations

```python
# Good: Simple property access
Joiners.equal(lambda l: l.timeslot)

# Bad: Complex calculation in joiner
Joiners.equal(lambda l: calculate_complex_hash(l))
```

### 4. Use Cached Properties

```python
@planning_entity
@dataclass
class Lesson:
    # Pre-calculate expensive values
    @cached_property
    def combined_key(self):
        return (self.timeslot, self.room)

# Use cached property in constraint
Joiners.equal(lambda l: l.combined_key)
```

## Common Optimizations

### Replace for_each + filter with for_each_unique_pair

```python
# Before: Inefficient
factory.for_each(Lesson)
.join(Lesson)
.filter(lambda l1, l2: l1.id != l2.id and l1.timeslot == l2.timeslot)

# After: Efficient
factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.timeslot)
)
```

### Use if_exists() Instead of Join + group_by

```python
# Before: Creates pairs then groups
factory.for_each(Employee)
.join(Shift, Joiners.equal(lambda e: e, lambda s: s.employee))
.group_by(lambda e, s: e, ConstraintCollectors.count())
.filter(lambda e, count: count > 0)

# After: Just checks existence
factory.for_each(Employee)
.if_exists(Shift, Joiners.equal(lambda e: e, lambda s: s.employee))
```

### Avoid Redundant Constraints

```python
# Redundant: Two constraints that overlap
def constraint1(factory):
    # Penalizes A and B in same room
    ...

def constraint2(factory):
    # Penalizes A and B in same room and same timeslot
    ...  # This overlaps with constraint1!

# Better: One specific constraint
def room_conflict(factory):
    # Only penalizes same room AND same timeslot
    factory.for_each_unique_pair(
        Lesson,
        Joiners.equal(lambda l: l.timeslot),
        Joiners.equal(lambda l: l.room),
    )
```

### Limit Collection Sizes in Collectors

```python
# Bad: Collects everything
ConstraintCollectors.to_list(lambda s: s)

# Better: Collect only what's needed
ConstraintCollectors.to_list(lambda s: s.start_time)

# Best: Use aggregate if possible
ConstraintCollectors.count()
```

## Incremental Score Calculation

SolverForge uses incremental score calculation—only recalculating affected constraints when a move is made. Help this work efficiently:

### Keep Constraints Independent

```python
# Good: Constraints don't share state
def room_conflict(factory):
    return factory.for_each_unique_pair(...)

def teacher_conflict(factory):
    return factory.for_each_unique_pair(...)

# Bad: Shared calculation affects both
shared_data = calculate_once()  # Recalculated on every change!
```

### Avoid Global State

```python
# Bad: References external data
external_config = load_config()

def my_constraint(factory):
    return factory.for_each(Lesson)
    .filter(lambda l: l.priority > external_config.threshold)  # External ref
```

## Benchmarking Constraints

### Enable Debug Logging

```python
import logging
logging.getLogger("ai.timefold").setLevel(logging.DEBUG)
```

### Time Individual Constraints

```python
import time

def timed_constraint(factory):
    start = time.time()
    result = actual_constraint(factory)
    print(f"Constraint built in {time.time() - start:.3f}s")
    return result
```

### Use the Benchmarker

For systematic comparison, use the Benchmarker (see [Benchmarking](../solver/benchmarking.md)).

## Score Corruption Detection

Enable environment mode for debugging:

```python
from solverforge_legacy.solver.config import EnvironmentMode

SolverConfig(
    environment_mode=EnvironmentMode.FULL_ASSERT,  # Detects score corruption
    ...
)
```

Modes:
- `NON_REPRODUCIBLE` - Fastest, no checks
- `REPRODUCIBLE` - Deterministic but no validation
- `FAST_ASSERT` - Quick validation checks
- `FULL_ASSERT` - Complete validation (slowest)

Use `FULL_ASSERT` during development, `REPRODUCIBLE` or `NON_REPRODUCIBLE` in production.

## Common Performance Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Very slow start | Complex constraint building | Simplify or cache |
| Slow throughout | Filter instead of joiner | Use joiners |
| Memory issues | Large collections | Use aggregates |
| Score corruption | Incorrect incremental calc | Enable FULL_ASSERT |

## Next Steps

- [Testing](testing.md) - Test constraints in isolation
- [Benchmarking](../solver/benchmarking.md) - Compare configurations
