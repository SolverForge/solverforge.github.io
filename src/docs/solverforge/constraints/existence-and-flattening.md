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
exists, or only if no matching row exists, in another collection. The examples
on this page use the
[example model](/docs/solverforge/constraints/#example-model).

A shift is a conflict when its employee has an unavailability row on the
shift's date. Key both sides on `(employee, date)`. An unassigned shift's key is
`None`; every unavailability row has a `Some` key, so an unassigned shift never
matches:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .if_exists((
        Streams::new().for_each(Schedule::unavailability()),
        equal_bi(
            |shift: &Shift| shift.employee_idx.map(|employee| (employee, shift.date)),
            |u: &Unavailability| Some((u.employee_idx, u.date)),
        ),
    ))
    .penalize(HardSoftScore::ONE_HARD)
    .named("Unavailable employee")
```

`if_exists` asks "does this item have at least one matching record over there?"
`if_not_exists` asks the inverse. Multiple right-side matches do not multiply
the left row's score: an existence filter publishes only accepted left rows.

Keep `None` out of the key when a missing value must not match. Two `None`
keys are equal, so keying an `Option` field that both sides can leave empty
pairs every unassigned left row with every right row that has no value.

This program scores three shifts on day 2: one for an employee with two
unavailability rows that day, one for an available employee, and one
unassigned. It adds `src/main.rs` to the example model:

<!-- rust: crate=existence extends=schedule file=src/main.rs -->
```rust
mod constraints;
mod domain;

use domain::{Employee, Schedule, Shift, Unavailability};
use solverforge::prelude::*;
use solverforge::stream::joiner::*;
use solverforge::IncrementalConstraint;

type Streams = ConstraintFactory<Schedule, HardSoftScore>;

fn employee(index: usize, name: &str) -> Employee {
    Employee {
        index,
        name: name.into(),
        skills: vec![],
        available_days: vec![],
        max_hours: 40,
    }
}

fn shift(id: usize, employee_idx: Option<usize>) -> Shift {
    Shift {
        id,
        date: 2,
        start: 8,
        end: 16,
        required_skill: "nurse".into(),
        preferred_employee: None,
        employee_idx,
    }
}

fn main() {
    let schedule = Schedule {
        employees: vec![employee(0, "Amina"), employee(1, "Bruno")],
        unavailability: vec![
            Unavailability { id: 0, employee_idx: 0, date: 2 },
            Unavailability { id: 1, employee_idx: 0, date: 2 },
            Unavailability { id: 2, employee_idx: 1, date: 3 },
        ],
        shifts: vec![shift(0, Some(0)), shift(1, Some(1)), shift(2, None)],
        score: None,
    };

    let unavailable = Streams::new()
        .for_each(Schedule::shifts())
        .if_exists((
            Streams::new().for_each(Schedule::unavailability()),
            equal_bi(
                |shift: &Shift| shift.employee_idx.map(|employee| (employee, shift.date)),
                |u: &Unavailability| Some((u.employee_idx, u.date)),
            ),
        ))
        .penalize(HardSoftScore::ONE_HARD)
        .named("Unavailable employee");

    println!("matches: {}", unavailable.match_count(&schedule));
    println!("score: {}", unavailable.evaluate(&schedule));
}
```

`cargo run` prints one match, for shift 0, scored once although two rows match
it:

<!-- rust: crate=existence output -->
```text
matches: 1
score: -1hard/0soft
```

## Relational Execution

Both operations use `stream::relational::operator::ExistenceNode`,
a semi/anti join over concrete row producers, and finalize onto
`constraint::relational::OperatorTerminal`, not a separate existence scoring
engine. Key choice does not select an engine: the node dispatches its key
storage internally — dense tables for `usize` planning-id
keys, hash tables otherwise — so choose `usize`, optional, string, or compound
keys for the relationship you need.

The node answers membership from per-key occurrence counts instead of materializing child rows or pair links. It retains one occurrence
count per right-side key, each right row's stored key contribution, and one
bucket of left rows per key; a key whose count crosses the alive/dead
threshold publishes or retracts every left row carrying it in one idempotent
pass per event. Right-side children never become rows and never receive
handles — when the right stream is flattened, a `ParentChildKeys` adapter
reads each parent's children straight from the solution, and a grouped right
stream keys off its aggregated result. Left rows are re-keyed from the live
solution on insert, so a changed key moves the row between key domains, and
only left rows are published, never scored pair rows.

The node retains only what membership needs: stored key contributions are
recycled, and every event reuses its notification and key scratch buffers.

Dense `usize` count updates keep that bookkeeping inline: `DenseKeys::add`
and `take` check the table length before calling `grow`, then mark a key's
first touch directly. A key enters the touched list at most once per event,
even when several right-side contributions change its count.
Growth is still possible when a key exceeds the current table length; this is
not an allocation-free update guarantee. Hash-key storage and the public
existence methods are unchanged. See the
[tagged count-state implementation](https://github.com/SolverForge/solverforge/blob/v0.26.1/crates/solverforge-scoring/src/stream/relational/count_state.rs).

These are internal representation and allocation changes, not a change to
membership: semi/anti joins still publish left rows according to whether any
matching key is present. The per-event membership pass is idempotent, so a key
removed and re-added inside one event settles on its final state; retained
right-row key contributions remove exactly the old keys after a value changes;
generational handles prevent a reused storage slot from reviving an old
relationship; and reset clears retained keys, counts, contributions, and
scratch before reinitialization. Relationships that need residual predicates
beyond an equality key still run the compiled per-pair path: there
`JoinerExistenceNode` retains matching pair links and evaluates the residual
predicate, and complement defaults restore through the plan's retained
equality keys.

## `flatten_last`

Use `flatten_last` after a join when the last joined item owns a collection and
the constraint needs to score individual child elements.

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
    .flatten_last(
        |employee: &Employee| employee.available_days.as_slice(),
        |day: &u32| *day,
        |shift: &Shift| shift.date,
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

The fluent builder creates a `FlattenNode` over the parent source
and joins it to the left collection using the compound `(parent key, child
key)` relationship. It finalizes onto `OperatorTerminal`; there is no separate
flattened-bi retained scoring engine. The three-argument `flatten_last` API
remains the keyed `Bi` operation shown above, not a general promise that every
arbitrary-depth `Chain` supports flattening.

The node recycles retired parent-to-child handle vectors and
reserves space for replacement children. It still retracts every old child and
creates fresh generational child handles when the parent refreshes. Reusing a
vector allocation does not retain a stale child, change the compound-key
relationship, or introduce a new fluent flattening API.

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
