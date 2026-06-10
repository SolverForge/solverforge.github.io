---
title: "Joiners"
linkTitle: "Joiners"
weight: 20
description: >
  Control which tuples are created when joining constraint streams.
---

Joiners define the matching criteria when two streams are joined. Without
joiners, a join produces every possible pair; joiners filter this down to only
relevant combinations.

## Available Joiners

### `equal`

For symmetric self-joins, takes a single key extractor:

```rust
equal(|shift: &Shift| shift.employee_idx)
```

### `equal_bi`

For cross-joins or directed projected self-joins, takes separate left and right
key extractors:

```rust
equal_bi(|shift: &Shift| shift.employee_idx, |u: &Unavailability| u.employee_idx)
```

### `less_than`

Matches when the left value is less than the right. Takes two extractors.

```rust
less_than(|a: &Shift| a.id, |b: &Shift| b.id)
```

### `greater_than`

Matches when the left value is greater than the right. Takes two extractors.

```rust
greater_than(|a: &Shift| a.priority, |b: &Shift| b.priority)
```

### `overlapping`

Matches when two ranges overlap. Takes four extractors: start and end for each side.

```rust
overlapping(
    |a: &Shift| a.start_time, |a: &Shift| a.end_time,
    |b: &Shift| b.start_time, |b: &Shift| b.end_time,
)
```

### `filtering`

A general-purpose joiner that uses a predicate over both elements.

```rust
filtering(|a: &Shift, b: &Shift| a.location.distance_to(&b.location) < 50.0)
```

## Using Joiners with `join`

**Self-join** - join the same generated source on the right side:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::shifts()),
        equal_bi(
            |left: &Shift| left.employee_idx,
            |right: &Shift| right.employee_idx,
        ),
    ))
```

**Cross-join** - pass a tuple of (stream, joiner):

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::unavailability()),
        equal_bi(|shift: &Shift| shift.date, |u: &Unavailability| u.date),
    ))
```

After a cross join, the stream can score pairs directly, group the joined pairs
with `.group_by(|left, right| key, collector)`, or project each pair into a
retained scoring row with `.project(|left, right| row)`.

After a projected stream, `join(equal(|row| key))` creates a symmetric
projected self-join. `join(equal_bi(left_key, right_key))` creates a directed
projected self-join where row orientation is part of the rule.

## Performance Note

Indexed joiners (`equal`, `equal_bi`, `less_than`, `greater_than`, `overlapping`) are much faster than `filtering` because they use index lookups instead of iterating all pairs. Prefer indexed joiners where possible and only use `filtering` for conditions that can't be expressed with indexed joiners.

Low-level joined filters receive semantic source indexes in the current runtime.
The fluent `filtering(|left, right| ...)` and `.filter(|left, right| ...)`
closures remain value-oriented.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - The core stream API
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - Generated collection sources
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - Directed projected self-joins
- [docs.rs/solverforge](https://docs.rs/solverforge) - Full joiner API reference
