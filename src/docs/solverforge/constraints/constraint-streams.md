---
title: 'Constraint Streams'
linkTitle: 'Constraint Streams'
weight: 10
description: >
  Declarative constraint definition using the stream API.
---

Constraint streams are the primary way to define constraints in SolverForge.
They provide a pipeline-style API where you select entities, transform the
stream, and terminate with a scoring impact.

## Defining Constraints

Constraints are defined as a function that returns a tuple of constraint
objects. The `#[planning_solution]` macro wires this up automatically.

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};
use ScheduleConstraintStreams;

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

    (
        factory.shifts()
            .filter(|shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),
    )
}
```

Each constraint builder chain produces an `IncrementalUniConstraint` (or
similar) via `.named()`. Return them as a tuple — SolverForge implements
`ConstraintSet` for tuples of up to 16 constraints.

## Source Operations

### `for_each`

Selects all items from a collection in the solution, using a closure extractor.

```rust
factory.shifts()
```

## Intermediate Operations

### `filter`

Keeps only elements that match a predicate.

```rust
factory.shifts()
    .filter(|shift| shift.employee_idx.is_none())
```

### `join`

Combines elements from the same or different collections. The join target
determines the behavior:

**Self-join** — pairs from the same collection, using an `equal` joiner:

```rust
factory.shifts()
    .join(equal(|shift: &Shift| shift.employee_idx))
```

**Cross-join** — pairs from two different collections, using an `equal_bi`
joiner:

```rust
factory.shifts()
    .join((
        |s: &Schedule| s.unavailability.as_slice(),
        equal_bi(|shift: &Shift| shift.employee_idx, |u: &Unavailability| u.employee_idx),
    ))
```

See [Joiners](../joiners/) for all available joiner types.

### `flatten_last`

Flattens a collection in the last element into individual elements. Takes three
arguments: a slice extractor, a key function for the flattened items, and a
lookup function for matching.

```rust
factory.for_each(|s: &Schedule| s.employees.as_slice())
    .join((
        |s: &Schedule| s.shifts.as_slice(),
        equal_bi(|e: &Employee| e.id, |s: &Shift| s.employee_idx),
    ))
    .flatten_last(
        |e: &Employee| e.available_days.as_slice(),  // slice extractor
        |d| *d,                                       // key for flattened item
        |s: &Shift| s.date(),                         // lookup from A
    )
```

### `group_by`

Groups elements and applies a [collector](../collectors/) to aggregate.

```rust
factory.shifts()
    .group_by(
        |shift: &Shift| shift.employee_idx,   // grouping key
        count(),                              // collector
    )
```

### `balance`

Calculates load imbalance across a grouping key. The key function returns
`Option<K>` — `None` values are skipped (useful for unassigned entities).

```rust
factory.shifts()
    .balance(|shift: &Shift| shift.employee_idx)
```

### `if_exists` / `if_not_exists`

Filters based on the existence (or absence) of matching entities in another
collection.

```rust
factory.clone()
    .shifts()
    .if_exists((
        factory.unavailability(),
        equal_bi(|shift: &Shift| shift.employee_idx, |u: &Unavailability| u.employee_idx),
    ))
```

## Terminal Operations

### `penalize` / `reward`

Apply a fixed score impact per match, then finalize with `.named()`.

```rust
.penalize(HardSoftScore::ONE_HARD)
    .named("Constraint name")

.reward(HardSoftScore::ONE_SOFT)
    .named("Preference bonus")
```

### `penalize_hard` / `penalize_soft` / `reward_hard` / `reward_soft`

Convenience methods that use the score type's unit hard or soft value.

```rust
.penalize_hard()
    .named("Hard violation")

.penalize_soft()
    .named("Soft preference")
```

### `penalize_hard_with` / `penalize_soft_with` / `reward_hard_with`

Apply a dynamic score impact based on the matched element.

```rust
.penalize_hard_with(|shift: &Shift| HardSoftScore::of_hard(shift.overtime_hours() as i64))
    .named("Overtime")
```

### `penalize_with` / `reward_with`

Apply a fully custom score impact.

```rust
.penalize_with(|shift: &Shift| HardSoftScore::of_soft(shift.preference_penalty()))
    .named("Preference")
```

## Full Example

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};
use ScheduleConstraintStreams;

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

    (
        // Hard: every shift must be assigned
        factory.clone().shifts()
            .filter(|shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),

        // Hard: no employee works two overlapping shifts
        factory.clone().shifts()
            .join(equal(|shift: &Shift| shift.employee_idx))
            .filter(|a: &Shift, b: &Shift| a.employee_idx.is_some() && a.overlaps(b))
            .penalize(HardSoftScore::ONE_HARD)
            .named("Overlap"),

        // Soft: prefer assigning employees to their preferred shifts
        factory.shifts()
            .filter(|shift| shift.is_preferred_by_employee())
            .reward(HardSoftScore::ONE_SOFT)
            .named("Preference"),
    )
}
```

## See Also

- [Joiners](../joiners/) — Controlling how streams are joined
- [Collectors](../collectors/) — Aggregation functions for `group_by`
- [Score Types](../score-types/) — Available score types
