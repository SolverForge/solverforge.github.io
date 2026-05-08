---
title: "Collectors"
linkTitle: "Collectors"
weight: 30
description: >
  Aggregation functions for group_by operations in constraint streams.
---

Collectors aggregate values within groups created by `group_by(...)`. They
transform a stream of individual matches into grouped summaries. For simple
fairness rules, prefer `balance(...)`; use collectors when you need explicit
counts, totals, or custom imbalance data.

## Using Collectors

Pass a collector as the second argument to `group_by`:

```rust
factory.for_each(Schedule::shifts())
    .group_by(
        |shift: &Shift| shift.employee_idx,   // grouping key
        count(),                              // collector
    )
    // Result: grouped stream of (key, usize)
```

## Available Collectors

### `count()`

Counts the number of matches in each group. Returns `usize`.

```rust
.group_by(|s: &Shift| s.employee_idx, count())
// → (key, usize)
```

### `sum(mapper)`

Sums numeric values in each group. The mapper extracts the value to sum.

```rust
.group_by(|s: &Shift| s.employee_idx, sum(|s: &Shift| s.hours))
// → (key, i64)
```

### `load_balance(key_fn, metric_fn)`

Measures load imbalance across a grouping key. Returns a `LoadBalance<K>` with unfairness metric.

```rust
.group_by(
    |s: &Shift| s.department_idx,
    load_balance(|s: &Shift| s.employee_idx, |s: &Shift| 1i64),
)
```

### `consecutive_runs(index_fn)`

Groups integer points into consecutive runs. Duplicate points increase
`item_count()` for the run but still count as one unique point for
`point_count()`.

```rust
factory.for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(
        |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
        consecutive_runs(|shift: &Shift| shift.date as i64),
    )
    .penalize_with(|_employee_idx: &usize, runs: &Runs| {
        let excess_days = runs
            .runs()
            .iter()
            .map(|run| run.point_count().saturating_sub(5) as i64)
            .sum();
        HardSoftScore::of_soft(excess_days)
    })
    .named("Long work streaks")
```

`Run` exposes `start()`, `end()`, `point_count()`, and `item_count()`. `Runs`
exposes `runs()`, `point_count()`, `item_count()`, `len()`, and `is_empty()`.

## Complemented Groups

Use `complement(...)` after `group_by(...)` when a grouped rule needs rows for
keys that have no source matches. For example, workload fairness often needs a
zero-count row for employees with no assigned shifts:

```rust
factory.for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(
        |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
        count::<Shift>(),
    )
    .complement(Schedule::employees(), |employee: &Employee| employee.index, |_employee| 0usize)
    .penalize_with(|_employee_idx: &usize, count: &usize| {
        HardSoftScore::of_soft((*count as i64 - 4).abs())
    })
    .named("Balanced workload")
```

## Balance Stream Operation

For simple load balancing without `group_by`, use the `balance` stream operation directly:

```rust
factory.for_each(Schedule::shifts())
    .balance(|shift: &Shift| shift.employee_idx)
    .penalize_soft()
    .named("Fair distribution")
```

The key function returns `Option<K>` — `None` values (unassigned entities) are skipped.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - The `group_by` operation
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - Generated collection sources
- [docs.rs/solverforge](https://docs.rs/solverforge) - Full collector API reference
