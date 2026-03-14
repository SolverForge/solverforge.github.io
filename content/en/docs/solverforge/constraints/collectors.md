---
title: "Collectors"
linkTitle: "Collectors"
weight: 30
description: >
  Aggregation functions for group_by operations in constraint streams.
---

Collectors aggregate values within groups created by `group_by`. They transform a stream of individual matches into grouped summaries.

## Using Collectors

Pass a collector as the second argument to `group_by`:

```rust
factory.for_each::<Shift>()
    .group_by(
        |shift| shift.employee.clone(),  // grouping key
        count(),                          // collector
    )
    // Result: BiConstraintStream<Employee, i64>
```

## Available Collectors

### `count()`

Counts the number of matches in each group.

```rust
.group_by(|s| s.employee.clone(), count())
// → (Employee, i64)
```

### `count_distinct()`

Counts distinct values in each group.

```rust
.group_by(|s| s.department.clone(), count_distinct(|s| s.employee.clone()))
// → (Department, i64)
```

### `sum()`

Sums numeric values in each group.

```rust
.group_by(|s| s.employee.clone(), sum(|s| s.hours))
// → (Employee, i64)
```

### `min()`

Finds the minimum value in each group.

```rust
.group_by(|s| s.employee.clone(), min(|s| s.start_time))
// → (Employee, Option<Time>)
```

### `max()`

Finds the maximum value in each group.

```rust
.group_by(|s| s.employee.clone(), max(|s| s.end_time))
// → (Employee, Option<Time>)
```

### `to_list()`

Collects all matches into a `Vec`.

```rust
.group_by(|s| s.employee.clone(), to_list())
// → (Employee, Vec<Shift>)
```

### `to_set()`

Collects unique matches into a set.

```rust
.group_by(|s| s.employee.clone(), to_set(|s| s.skill.clone()))
// → (Employee, HashSet<String>)
```

## Balance Collector

The `balance` collector measures load imbalance across a grouping key. It's useful for ensuring fair distribution of work.

```rust
// Penalize uneven shift distribution across employees
factory.for_each::<Shift>()
    .balance(|s| s.employee.clone())
    .penalize_soft_with("Fair distribution", |imbalance| imbalance)
    .as_constraint()
```

The balance collector calculates how far the distribution is from perfectly even, returning a penalty value proportional to the imbalance.

## Multiple Collectors

You can use multiple collectors in a single `group_by`:

```rust
.group_by(
    |s| s.employee.clone(),
    count(),
    sum(|s| s.hours),
)
// → TriConstraintStream<Employee, i64, i64>
```

## See Also

- [Constraint Streams](../constraint-streams/) — The `group_by` operation
- [docs.rs/solverforge](https://docs.rs/solverforge) — Full collector API reference
