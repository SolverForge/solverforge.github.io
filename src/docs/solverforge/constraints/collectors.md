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

The examples on this page use the
[example model](/docs/solverforge/constraints/#example-model) and compile in
its `src/examples.rs`.

The collector trait is `Collector<Input>`. `Input` is
the borrowed stream match shape: unary and projected grouping pass `&A` or
`&Out`, while direct cross-join grouping passes `(&A, &B)`. Stock collectors
such as `count`, `sum`, `collect_vec`, `consecutive_runs`, and
`indexed_presence` use the same protocol across those shapes.

## Using Collectors

Pass a collector as the second argument to `group_by`:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .group_by(
        |shift: &Shift| shift.employee_idx, // grouping key
        count(),                            // collector
    )
// Result: grouped stream of (Option<usize>, usize)
```

## Available Collectors

### `count()`

Counts the number of matches in each group. Returns `usize`.

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .group_by(|s: &Shift| s.employee_idx, count())
// → (key, usize)
```

### `sum(mapper)`

Sums numeric values in each group. The mapper extracts the value to sum.

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .group_by(|s: &Shift| s.employee_idx, sum(|s: &Shift| s.hours()))
// → (key, i64)
```

For direct cross-join grouping, the mapper receives the joined pair as a tuple:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
    .group_by(
        |_shift: &Shift, employee: &Employee| employee.index,
        sum(|(shift, _employee): (&Shift, &Employee)| shift.hours()),
    )
```

### `load_balance(key_fn, metric_fn)`

Measures load imbalance across a grouping key. Returns a `LoadBalance<K>` with
an unfairness metric. Here the group is a day and the balanced key is the
employee:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .group_by(
        |s: &Shift| s.date,
        load_balance(|s: &Shift| s.employee_idx, |_s: &Shift| 1i64),
    )
```

### `consecutive_runs(index_fn)`

Groups integer points into consecutive runs. Duplicate points increase
`item_count()` for the run but still count as one unique point for
`point_count()`.

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(
        |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
        consecutive_runs(|shift: &Shift| shift.date as i64),
    )
    .penalize(|_employee_idx: &usize, runs: &Runs| {
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

### `collect_vec(mapper)`

Collects mapped values for each group and returns a `CollectedVec<T>`.
The collector owns values once and can retract them exactly during incremental
updates, so `T` does not need `Copy`, `Clone`, or `PartialEq` just to
participate in grouped scoring.

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(
        |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
        collect_vec(|shift: &Shift| shift.required_skill.clone()),
    )
    .penalize(|_employee_idx: &usize, skills: &CollectedVec<String>| {
        HardSoftScore::of_soft(skills.len().saturating_sub(5) as i64)
    })
    .named("Too many shifts")
```

### `indexed_presence(index_fn)`

Tracks active ordinal positions and exposes both presence and complement runs.
Use it when a rule needs to know which slots are covered and which slots are
missing.

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(
        |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
        indexed_presence(|shift: &Shift| shift.date as i64),
    )
    .penalize(|_employee_idx: &usize, presence: &IndexedPresence| {
        HardSoftScore::of_soft(presence.complement_runs(0..7).len() as i64)
    })
    .named("Gaps in the week")
```

## Complemented Groups

Use `complement(...)` after `group_by(...)` when a grouped rule needs rows for
keys that have no source matches. For example, workload fairness often needs a
zero-count row for employees with no assigned shifts:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(
        |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
        count(),
    )
    .complement(Schedule::employees(), |employee: &Employee| employee.index, |_employee: &Employee| 0usize)
    .penalize(|_employee_idx: &usize, count: &usize| {
        HardSoftScore::of_soft((*count as i64 - 4).abs())
    })
    .named("Balanced workload")
```

Unary complemented groups use a relational `ComplementNode` and the
shared `OperatorTerminal`, rather than a separate complemented scoring engine.
The node relates the target domain to grouped results and owns default values
for targets with no matching result; its default restoration reads the plan's
retained equality keys, so a target whose last result row is
retracted regains its default even after the target retracted and re-inserted
earlier in the same event. The public `complement(source, key,
default)` authoring shape is unchanged. Every complemented group — unary,
direct cross-join, or projected — finalizes into the relational
`ComplementNode` under the shared `OperatorTerminal`; there is one grouping
execution path and no per-shape grouped terminal families.

Projected grouped streams can also use `complement(...)` after grouping when
the source rows were created by `project(...)`.

Direct cross-join grouped streams can also use `complement(...)` after grouping.
This is useful when the group key comes from a joined target and the rule needs
default rows for targets that have no matching left-side rows, such as the
hours each employee works, with 0 for an employee who has no shift:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
    .group_by(
        |_shift: &Shift, employee: &Employee| employee.index,
        sum(|(shift, _employee): (&Shift, &Employee)| shift.hours()),
    )
    .complement(
        Schedule::employees(),
        |employee: &Employee| employee.index,
        |_employee: &Employee| 0i64,
    )
```

## Balance Stream Operation

For simple load balancing without `group_by`, use the `balance` stream operation directly:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .balance(|shift: &Shift| shift.employee_idx)
    .penalize(HardSoftScore::ONE_SOFT)
    .named("Fair distribution")
```

The key function returns `Option<K>` — `None` values (unassigned entities) are skipped.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - The `group_by` operation
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - Generated collection sources
- [Shift-Group Uniformity](/docs/solverforge/constraints/shift-group-uniformity/) - A worked example that
  collects shift-group values per block and penalizes mixed groups
- [docs.rs/solverforge](https://docs.rs/solverforge) - Full collector API reference
