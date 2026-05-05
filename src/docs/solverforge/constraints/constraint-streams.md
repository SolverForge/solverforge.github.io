---
title: "Constraint Streams"
linkTitle: "Constraint Streams"
weight: 10
description: >
  Declarative constraint definition using the stream API.
---

Constraint streams are the primary way to define constraints in SolverForge.
They provide a pipeline-style API where you select entities or facts, transform
the stream, and terminate with a scoring impact.

## Defining Constraints

Constraints are defined as a function that returns a tuple of constraint
objects. The `#[planning_solution]` macro wires this up automatically.

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

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

Each constraint builder chain produces an `IncrementalUniConstraint`,
`IncrementalBiConstraint`, or related constraint object through `.named()`.
Return them as a tuple; SolverForge implements `ConstraintSet` for tuples of up
to 16 constraints.

## Source Operations

### Generated Accessors

Generated `{Name}ConstraintStreams` accessors select all items from a solution
collection and carry hidden source metadata for localized incremental scoring.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new().shifts()
Streams::new().employees()
```

These should be the default entry points for planning entity and problem fact
collections. See [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/)
for the generated method contract.

### `for_each`

`for_each` selects items from a solution collection using a closure extractor.
Use generated accessors when they exist; use `for_each` for lower-level or
custom collection surfaces.

```rust
use solverforge::stream::vec;

factory.for_each(vec(|solution: &Schedule| &solution.custom_rows))
```

## Intermediate Operations

| Operation | Purpose |
| --------- | ------- |
| `filter` | Keep only matches that satisfy a predicate |
| `join` | Combine rows from the same stream or a second stream |
| `project` | Create retained scoring-only rows |
| `flatten_last` | Expand a collection carried by the last joined item |
| `group_by` | Group rows and apply a collector |
| `balance` | Score load balance without manual grouped unfairness logic |
| `if_exists` / `if_not_exists` | Keep rows based on matching rows in another collection |

### `filter`

```rust
factory.shifts()
    .filter(|shift| shift.employee_idx.is_none())
```

### `join`

`join` dispatches on the target shape.

Self-join with an `equal` joiner:

```rust
factory.shifts()
    .join(equal(|shift: &Shift| shift.employee_idx))
```

Cross-join with a generated accessor plus `equal_bi`:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .shifts()
    .join((
        Streams::new().unavailability(),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |u: &Unavailability| u.employee_idx,
        ),
    ))
```

See [Joiners](/docs/solverforge/constraints/joiners/) for joiner types and
composition.

### `group_by`

```rust
factory.shifts()
    .group_by(
        |shift: &Shift| shift.employee_idx,
        count(),
    )
```

See [Collectors](/docs/solverforge/constraints/collectors/) for `count`, `sum`,
and `load_balance`.

### `balance`

`balance` calculates load imbalance across a grouping key. The key function
returns `Option<K>`; `None` values are skipped, which is useful for unassigned
entities.

```rust
factory.shifts()
    .balance(|shift: &Shift| shift.employee_idx)
```

## Terminal Operations

### `penalize` / `reward`

Apply a fixed score impact per match, then finalize with `.named()`.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let hard = Streams::new()
    .shifts()
    .penalize(HardSoftScore::ONE_HARD)
    .named("Constraint name");

let soft = Streams::new()
    .shifts()
    .reward(HardSoftScore::ONE_SOFT)
    .named("Preference bonus");
```

### Score Convenience Methods

Use convenience methods when the constraint applies one hard or soft unit:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let hard = Streams::new()
    .shifts()
    .penalize_hard()
    .named("Hard violation");

let soft = Streams::new()
    .shifts()
    .reward_soft()
    .named("Soft preference");
```

Use dynamic methods when the score depends on the match:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let overtime = Streams::new()
    .shifts()
    .penalize_hard_with(|shift: &Shift| HardSoftScore::of_hard(shift.overtime_hours() as i64))
    .named("Overtime");

let preference = Streams::new()
    .shifts()
    .penalize_with(|shift: &Shift| HardSoftScore::of_soft(shift.preference_penalty()))
    .named("Preference");
```

## Full Example

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    (
        Streams::new()
            .shifts()
            .filter(|shift| shift.employee_idx.is_none())
            .penalize_hard()
            .named("Unassigned shift"),

        Streams::new()
            .shifts()
            .join(equal(|shift: &Shift| shift.employee_idx))
            .filter(|a: &Shift, b: &Shift| {
                a.employee_idx.is_some() && a.overlaps(b)
            })
            .penalize_hard()
            .named("Overlap"),

        Streams::new()
            .shifts()
            .filter(|shift| shift.is_preferred_by_employee())
            .reward_soft()
            .named("Preference"),
    )
}
```

## See Also

- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - scoring-only derived rows
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - generated collection accessors and `for_each`
- [Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/) - `if_exists`, `if_not_exists`, and `flatten_last`
- [Score Analysis](/docs/solverforge/constraints/score-analysis/) - inspecting score contributions
