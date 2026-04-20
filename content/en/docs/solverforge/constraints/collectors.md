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
factory.for_each(|s: &Schedule| s.shifts.as_slice())
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

## Balance Stream Operation

For simple load balancing without `group_by`, use the `balance` stream operation directly:

```rust
factory.for_each(|s: &Schedule| s.shifts.as_slice())
    .balance(|shift: &Shift| shift.employee_idx)
    .penalize_soft()
    .named("Fair distribution")
```

The key function returns `Option<K>` — `None` values (unassigned entities) are skipped.

## See Also

- [Constraint Streams](../constraint-streams/) — The `group_by` operation
- [docs.rs/solverforge](https://docs.rs/solverforge) — Full collector API reference
