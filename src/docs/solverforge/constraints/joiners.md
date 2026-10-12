---
title: "Joiners"
linkTitle: "Joiners"
weight: 20
description: >
  Control which tuples are created when joining constraint streams.
---

Joiners define the matching criteria when sources are joined. Fluent cross
joins take a target plus a condition or predicate; structural joiners narrow
the candidate pairs, while a general predicate scans retained opposite rows.
Use an indexed condition when the relationship can be expressed with keys,
comparisons, or intervals.

## Available Joiners

### `equal`

For symmetric self-joins, takes a single key extractor:

```rust
equal(|shift: &Shift| shift.employee_idx)
```

### `equal_bi`

For the first unary cross-join or a directed projected self-join, takes separate
left and right entity/output key extractors. It is not the entity-key API for
later joins in a chain:

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
use borrowed row views too. At every second or later join, `equal_bi` with
plain entity closures fails to typecheck (`E0631`): the left input is the whole
prior row, not one ambiguous entity binding. Use `equal_on` and select the
intended binding explicitly, including when an earlier join repeats a type.

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

**Same-collection keyed cross-join** — pass the same generated source on the
right. The tuple form uses keyed cross-join dispatch, not the same-source
unique-combination dispatch of `.join(equal(|row| key))`:

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
`Pair<Pair<Leaf<A>, Leaf<B>>, Leaf<C>>`. `stream::cross::Penta::join` continues at six sources
as `Chain`, which accepts further `.join((target, condition))` calls without a
fixed depth ceiling. `Chain` filters and weights take the solution and the
borrowed nested row; the named arity adapters retain separate entity arguments
for filters and weights. See [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
for these terminal and lifetime boundaries.

The key-shape rule applies separately at every continuation:

| Method | Left key input | Right key input |
| --- | --- | --- |
| First unary `.join(...)` | `&A` with `equal_bi` | `&B` with `equal_bi` |
| `Bi::join` (third source) | `&Pair<Leaf<A>, Leaf<B>>` | `&Leaf<C>` |
| `Tri::join` (fourth source) | `&Pair<Pair<Leaf<A>, Leaf<B>>, Leaf<C>>` | `&Leaf<D>` |
| `Quad::join` (fifth source) | Borrowed nested `(A, B, C, D)` row | `&Leaf<E>` |
| `Penta::join` (sixth source) | Borrowed nested `(A, B, C, D, E)` row | `&Leaf<G>` |
| `Chain::join` (each further source) | `&O::View<'_>` for the whole existing tree | `&Leaf<NewEntity>` |

The table abbreviates `Leaf<'_, T>` as `Leaf<T>`. All continuation equality
keys use `equal_on`; select earlier bindings via nested `.left` / `.right`
and read entity fields via `.entity`. Each relationship compiles fresh and may
use its own key type. `0.19.14` adds these clarifications to the tagged fluent
source documentation; it does not change the method signatures.

After a cross join, the stream can score pairs directly, group the joined pairs
with `.group_by(|left, right| key, collector)`, or project each pair into a
retained scoring row with `.project(|left, right| row)`.

After a projected stream, `join(equal(|row| key))` creates a symmetric
projected self-join. `join(equal_bi(left_key, right_key))` creates a directed
projected self-join where row orientation is part of the rule.

## Source Filters and Target Boundaries

For the first unary keyed equality cross-join, apply nullable-row filters on
both unary inputs before `join((target, equal_bi(...)))`. Left unary membership
is checked before key extraction and pair creation; a filtered unary right
target preserves its own membership. Original indexes and incremental change
metadata are retained. A post-join filter only filters joined rows and does not
prevent key extraction. This left-source pushdown is not implemented for
comparison, overlap, composed-condition (`.and(...)`), predicate, or same-source
self-join dispatch.

Fluent right-hand targets implement `CollectionExtract`, including filtered
unary streams. Compatible arbitrary derived producers belong at the low-level
`JoinNode` input boundary, not as interchangeable fluent targets.

`stream::cross::Penta::join` drops the authored penta filter; apply the row filter on the returned `Chain`.
filter the returned `Chain` instead. Same-source `PentaConstraintStream` is
terminal. These are distinct APIs despite sharing the five-source name.

## Performance Note

Equality conditions compile to hash-indexed plans; comparison conditions use
ordered scans, and overlap conditions use interval narrowing. A bare
`filtering` predicate uses a scan. Prefer a structural condition that narrows
candidates before applying an arbitrary predicate. Compose conditions with
`.and(...)`; the compiled plan still checks the complete condition. These
strategies are shared across the relational operator tree rather than selected
by a separate retained engine for each tuple arity.

The relational `ViewEqualPlan` treats membership in the exact equality-key
bucket as proof of that equality: candidate validation does not repeat the
same key extractors for every candidate. Keys are still extracted when
indexing and probing. Composed plans still evaluate residual conditions, and
ordinary unindexed `matches(...)` still compares the keys.

Occupied hash buckets are updated in place on retraction; only an empty bucket
is removed and its vector recycled. Retained old keys still remove
the exact prior entry after a value changes, duplicate insertion of the same
live handle does not multiply matches, and generational identities still
protect slot reuse. This reduces internal work without changing join
results or providing a public bucket-order guarantee.

Existence relationships do not scan derived candidate rows:
`ExistenceNode` keeps no child rows and no pair links, so a semi/anti stream's
incremental path reads only relationship keys and the touched keys' left rows.
The compiled per-pair path remains where a relationship needs it —
`JoinerExistenceNode` for residual-predicate existence, and the complement node
for scored defaults — together with the `JoinNode`, `SelfJoinNode`, and grouped
families, which retain their pair-row engines. Dense `usize`
count updates check table length before growth and inline touched-key marking;
the per-event membership pass still processes each changed key once from its
final count. This is internal bookkeeping, not a new indexing API or a
measured performance guarantee.

Low-level joined filters receive semantic source indexes in the current runtime.
The fluent `filtering(|left, right| ...)` and `.filter(|left, right| ...)`
closures remain value-oriented.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - The core stream API
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - Generated collection sources
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - Directed projected self-joins
- [docs.rs/solverforge](https://docs.rs/solverforge) - Full joiner API reference
