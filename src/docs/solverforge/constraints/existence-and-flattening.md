---
title: "Existence & Flattening"
linkTitle: "Existence & Flattening"
weight: 14
description: >
  Matching against related collections with if_exists, if_not_exists, and
  flatten_last.
---

`if_exists`, `if_not_exists`, and `flatten_last` cover common relationship
shapes without forcing the model to materialize extra facts.

## `if_exists` / `if_not_exists`

Use existence filters when the left row should survive only if a matching row
exists, or only if no matching row exists, in another collection.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .if_exists((
        Streams::new().for_each(Schedule::unavailability()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |u: &Unavailability| u.employee_idx,
        ),
    ))
    .penalize(HardSoftScore::ONE_HARD)
    .named("Unavailable employee");
```

`if_exists` asks "does this item have at least one matching record over there?"
`if_not_exists` asks the inverse. The public API stays simple while the runtime
chooses faster internal bookkeeping for key shapes it can index directly.

## Indexed `usize` Keys

Direct and flattened existence constraints with exact `usize` keys use dense
indexed storage internally. Other key shapes, including `Option<usize>`,
newtype keys, strings, and compound keys, keep hashed storage.

That storage decision does not change the stream API. Choose keys for modeling
clarity first; the runtime uses the exact-key fast path when it is available.

## `flatten_last`

Use `flatten_last` after a join when the last joined item owns a collection and
the constraint needs to score individual child elements.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.id),
        ),
    ))
    .flatten_last(
        |employee: &Employee| employee.available_days.as_slice(),
        |day| *day,
        |shift: &Shift| shift.date(),
    )
```

The three arguments are:

| Argument | Purpose |
| -------- | ------- |
| slice extractor | returns the nested collection from the joined item |
| flattened key | extracts a key from each nested element |
| lookup key | extracts the matching key from the left-side row |

## When To Use Which

| Need | Use |
| ---- | --- |
| Keep a row if a related record exists | `if_exists` |
| Keep a row if a related record is missing | `if_not_exists` |
| Score individual values inside a joined collection | `flatten_last` |
| Emit a retained scoring row with a custom shape | [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) |

## See Also

- [Joiners](/docs/solverforge/constraints/joiners/) - equality, comparison, overlap, and filtering joiners
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - the main stream pipeline
