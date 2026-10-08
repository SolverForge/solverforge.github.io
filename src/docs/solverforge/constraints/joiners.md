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

### `equal_on`

For chained joins, takes keys over the whole borrowed left row and the new
right leaf. It does not inherit the first join's key domain:

```rust
use solverforge::stream::relational::{operator::Pair, Leaf};

equal_on(
    |row: &Pair<Leaf<'_, Shift>, Leaf<'_, Employee>>| {
        (row.left.entity.employee_idx, row.left.entity.date)
    },
    |u: &Leaf<'_, Unavailability>| (u.entity.employee_idx, u.entity.date),
)
```

The right key receives `Leaf<Unavailability>`, not `&Unavailability`.
Use `.entity` to read its value. The left key can inspect either existing
binding or combine them. Comparison joiners also provide row-aware variants
such as `less_than_on` and `greater_than_on`; their left and right arguments
use borrowed row views too.

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

**Third source with an independent relationship** - pass the new collection
extractor and a row-aware joiner to `.join((target, equal_on(...)))`:

```rust
use solverforge::stream::relational::{operator::Pair, Leaf};

type Streams = ConstraintFactory<Schedule, SoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
    .join((
        Schedule::unavailability(),
        equal_on(
            |row: &Pair<Leaf<'_, Shift>, Leaf<'_, Employee>>| {
                (row.left.entity.employee_idx, row.left.entity.date)
            },
            |u: &Leaf<'_, Unavailability>| (u.entity.employee_idx, u.entity.date),
        ),
    ))
```

The first join matches the employee index; the second matches employee index
and date. Each relationship compiles its own condition and indexes. The
retained rows satisfy both relationships, not one equality across all sources.

The fluent adapters continue through `Bi`, `Tri`, `Quad`, and `Penta`.
Each added source nests the row view: the next left row after a triple is
`Pair<Pair<Leaf<A>, Leaf<B>>, Leaf<C>>`. `Penta::join` continues at six sources
as `Chain`, which accepts further `.join((target, condition))` calls without a
fixed depth ceiling. `Chain` filters and weights take the solution and the
borrowed nested row; the named arity adapters retain separate entity arguments
for filters and weights. See [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
for these terminal and lifetime boundaries.

After a cross join, the stream can score pairs directly, group the joined pairs
with `.group_by(|left, right| key, collector)`, or project each pair into a
retained scoring row with `.project(|left, right| row)`.

After a projected stream, `join(equal(|row| key))` creates a symmetric
projected self-join. `join(equal_bi(left_key, right_key))` creates a directed
projected self-join where row orientation is part of the rule.

## Performance Note

Equality conditions compile to hash-indexed plans; comparison conditions use
ordered scans, and overlap conditions use interval narrowing. A bare
`filtering` predicate uses a scan. Prefer a structural condition that narrows
candidates before applying an arbitrary predicate. Compose conditions with
`.and(...)`; the compiled plan still checks the complete condition. These
strategies are shared across the relational operator tree rather than selected
by a separate retained engine for each tuple arity.

Low-level joined filters receive semantic source indexes in the current runtime.
The fluent `filtering(|left, right| ...)` and `.filter(|left, right| ...)`
closures remain value-oriented.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - The core stream API
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - Generated collection sources
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - Directed projected self-joins
- [docs.rs/solverforge](https://docs.rs/solverforge) - Full joiner API reference
