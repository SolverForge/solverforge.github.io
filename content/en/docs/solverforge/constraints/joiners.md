---
title: "Joiners"
linkTitle: "Joiners"
weight: 20
description: >
  Control which tuples are created when joining constraint streams.
---

Joiners define the matching criteria when two streams are joined. Without joiners, a join produces every possible pair — joiners filter this down to only relevant combinations.

## Available Joiners

### `joiner::equal`

Matches when two values are equal.

```rust
joiner::equal(|shift| &shift.employee, |other| &other.employee)
```

For self-joins (same type on both sides):

```rust
joiner::equal(|shift| &shift.employee)
```

### `joiner::equal_bi`

Matches when a value from one stream equals a value from a bi-stream.

```rust
joiner::equal_bi(|shift| &shift.date, |(a, b)| &a.date)
```

### `joiner::less_than`

Matches when the left value is less than the right. Useful for avoiding duplicate pairs in self-joins.

```rust
joiner::less_than(|shift| shift.id)
```

### `joiner::greater_than`

Matches when the left value is greater than the right.

```rust
joiner::greater_than(|shift| shift.priority)
```

### `joiner::overlapping`

Matches when two ranges overlap. Takes a start and end extractor.

```rust
joiner::overlapping(
    |shift| shift.start_time, |shift| shift.end_time,
    |other| other.start_time, |other| other.end_time,
)
```

### `joiner::filtering`

A general-purpose joiner that uses a predicate.

```rust
joiner::filtering(|shift, other| shift.location.distance_to(&other.location) < 50.0)
```

## Combining Joiners

Use `.and()` to combine multiple joiners:

```rust
factory.for_each::<Shift>()
    .join(
        factory.for_each::<Shift>(),
        joiner::equal(|s| &s.employee)
            .and(joiner::less_than(|s| s.id)),
    )
```

## Performance Note

Indexed joiners (`equal`, `less_than`, `greater_than`, `overlapping`) are much faster than `filtering` because they use index lookups instead of iterating all pairs. Prefer indexed joiners where possible and only use `filtering` for conditions that can't be expressed with indexed joiners.

## See Also

- [Constraint Streams](../constraint-streams/) — The core stream API
- [docs.rs/solverforge](https://docs.rs/solverforge) — Full joiner API reference
