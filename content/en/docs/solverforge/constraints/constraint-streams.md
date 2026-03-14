---
title: "Constraint Streams"
linkTitle: "Constraint Streams"
weight: 10
description: >
  Declarative constraint definition using the stream API.
---

Constraint streams are the primary way to define constraints in SolverForge. They provide a pipeline-style API where you select entities, transform the stream, and terminate with a scoring impact.

## Creating a Constraint Factory

```rust
use solverforge::prelude::*;

fn define_constraints(factory: &ConstraintFactory<Schedule>) -> Vec<Constraint<Schedule>> {
    vec![
        // constraints go here
    ]
}
```

## Source Operations

### `for_each`

Selects all instances of a type from the solution.

```rust
factory.for_each::<Shift>()   // UniConstraintStream<Shift>
```

### `for_each_unique_pair`

Selects all unique pairs of a type, avoiding duplicate combinations.

```rust
factory.for_each_unique_pair::<Shift>()   // BiConstraintStream<Shift, Shift>
```

## Stream Types

Streams are typed by how many elements they carry:

| Stream Type | Elements | Created By |
|---|---|---|
| `UniConstraintStream<A>` | 1 | `for_each` |
| `BiConstraintStream<A, B>` | 2 | `join`, `for_each_unique_pair` |
| `TriConstraintStream<A, B, C>` | 3 | `join` on Bi |
| `QuadConstraintStream<A, B, C, D>` | 4 | `join` on Tri |
| `PentaConstraintStream<A, B, C, D, E>` | 5 | `join` on Quad |

## Intermediate Operations

### `filter`

Keeps only tuples that match a predicate.

```rust
factory.for_each::<Shift>()
    .filter(|shift| shift.employee.is_none())
```

### `join`

Combines two streams. Use [joiners](../joiners/) to control which pairs are created.

```rust
factory.for_each::<Shift>()
    .join(
        factory.for_each::<Shift>(),
        joiner::equal(|s| &s.employee),
        joiner::less_than(|s| s.id),  // avoid duplicate pairs
    )
```

### `flatten_last`

Flattens a collection in the last element of the tuple into individual elements.

```rust
factory.for_each::<Employee>()
    .flatten_last(|e| &e.skills)   // Employee → (Employee, Skill)
```

### `group_by`

Groups tuples and applies [collectors](../collectors/) to aggregate.

```rust
factory.for_each::<Shift>()
    .group_by(|s| s.employee.clone(), count())
    // BiConstraintStream<Employee, i64>
```

### `balance`

Calculates load balance across a grouping key using the [balance collector](../collectors/).

```rust
factory.for_each::<Shift>()
    .balance(|s| s.employee.clone())
```

### `if_exists` / `if_not_exists`

Filters based on the existence (or absence) of matching entities.

```rust
factory.for_each::<Shift>()
    .if_exists(
        factory.for_each::<Unavailability>(),
        joiner::equal(|s| &s.employee, |u| &u.employee),
        joiner::equal(|s| &s.date, |u| &u.date),
    )
```

## Terminal Operations

### `penalize` / `reward`

Apply a fixed score impact per match.

```rust
.penalize("Constraint name", HardSoftScore::ONE_HARD)
.reward("Constraint name", HardSoftScore::ONE_SOFT)
```

### `penalize_hard_with` / `penalize_soft_with` / `reward_soft`

Apply a dynamic score impact based on the matched elements.

```rust
.penalize_hard_with("Overtime", |shift| shift.overtime_hours())
.penalize_soft_with("Preference", |shift| shift.preference_penalty())
.reward_soft("Bonus", |shift| shift.skill_match_score())
```

### `as_constraint`

Finalizes the stream into a `Constraint<S>`.

```rust
factory.for_each::<Shift>()
    .filter(|s| s.employee.is_none())
    .penalize("Unassigned", HardSoftScore::ONE_HARD)
    .as_constraint()
```

## Full Example

```rust
fn define_constraints(factory: &ConstraintFactory<Schedule>) -> Vec<Constraint<Schedule>> {
    vec![
        // Hard: every shift must be assigned
        factory.for_each::<Shift>()
            .filter(|s| s.employee.is_none())
            .penalize("Unassigned shift", HardSoftScore::ONE_HARD)
            .as_constraint(),

        // Hard: no employee works two overlapping shifts
        factory.for_each_unique_pair::<Shift>()
            .filter(|(a, b)| a.overlaps(b) && a.employee == b.employee)
            .penalize("Overlap", HardSoftScore::ONE_HARD)
            .as_constraint(),

        // Soft: prefer assigning employees to their preferred shifts
        factory.for_each::<Shift>()
            .filter(|s| s.is_preferred_by_employee())
            .reward("Preference", HardSoftScore::ONE_SOFT)
            .as_constraint(),
    ]
}
```

## See Also

- [Joiners](../joiners/) — Controlling how streams are joined
- [Collectors](../collectors/) — Aggregation functions for `group_by`
- [Score Types](../score-types/) — Available score types
