---
title: "Joiners"
linkTitle: "Joiners"
weight: 20
description: >
  Control which tuples are created when joining constraint streams.
---

Joiners define the matching criteria when two streams are joined. Without joiners, a join produces every possible pair — joiners filter this down to only relevant combinations.

## Available Joiners

### `equal`

For self-joins (pairing items from the same collection), takes a single key extractor:

```rust
equal(|shift: &Shift| shift.employee_idx)
```

### `equal_bi`

For cross-joins (pairing items from two different collections), takes two key extractors:

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

**Self-join** — pass a single `equal` joiner directly:

```rust
factory.for_each(|s: &Schedule| s.shifts.as_slice())
    .join(equal(|shift: &Shift| shift.employee_idx))
```

**Cross-join** — pass a tuple of (extractor, joiner):

```rust
factory.for_each(|s: &Schedule| s.shifts.as_slice())
    .join((
        |s: &Schedule| s.unavailability.as_slice(),
        equal_bi(|shift: &Shift| shift.date, |u: &Unavailability| u.date),
    ))
```

## Performance Note

Indexed joiners (`equal`, `equal_bi`, `less_than`, `greater_than`, `overlapping`) are much faster than `filtering` because they use index lookups instead of iterating all pairs. Prefer indexed joiners where possible and only use `filtering` for conditions that can't be expressed with indexed joiners.

## See Also

- [Constraint Streams](../constraint-streams/) — The core stream API
- [docs.rs/solverforge](https://docs.rs/solverforge) — Full joiner API reference
