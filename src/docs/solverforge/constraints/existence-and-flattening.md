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
`if_not_exists` asks the inverse. Multiple right-side matches do not multiply
the left row's score: an existence filter publishes only accepted left rows.

## Relational Execution

In v0.19.10 both operations use `stream::relational::operator::ExistenceNode`,
a semi/anti join over concrete row producers. The compiled condition supplies
the indexes; retained matching links track membership as either source changes.
The terminal is `constraint::relational::OperatorTerminal`, not a separate
existence scoring engine. The old exact-`usize` existence-engine storage
specialization is not the current API contract. Choose `usize`, optional,
string, or compound keys for the relationship you need, not to select a
retired engine.

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

This keyed pair operation emits `(left entity, child element)` matches, not
`(left entity, parent entity, child element)` triples. Score or filter those
matches with two value arguments. Both relationships must hold: the original
join links the left entity to the parent, and the lookup key matches the
child's flattened key.

In v0.19.10 the fluent builder creates a `FlattenNode` over the parent source
and joins it to the left collection using the compound `(parent key, child
key)` relationship. It finalizes onto `OperatorTerminal`; there is no separate
flattened-bi retained scoring engine. The three-argument `flatten_last` API
remains the keyed `Bi` operation shown above, not a general promise that every
arbitrary-depth `Chain` supports flattening.

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
