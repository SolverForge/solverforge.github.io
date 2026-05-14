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
        factory.for_each(Schedule::shifts())
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

### Generated Source Methods

Generated solution source methods select all items from a solution collection
and carry hidden source metadata for localized incremental scoring.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new().for_each(Schedule::shifts())
Streams::new().for_each(Schedule::employees())
```

These should be the default source arguments for planning entity and problem fact
collections. See [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/)
for the generated method contract.

### `for_each`

`for_each` starts a stream from any collection extractor. Use generated source
methods such as `Schedule::shifts()` for ordinary model collections. Use
`solverforge::stream::vec(...)` for lower-level custom collection surfaces.

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
| `group_by` | Group unary rows, projected rows, or cross-join pairs and apply a collector |
| `balance` | Score load balance without manual grouped unfairness logic |
| `complement` | Fill missing grouped keys from a generated fact or entity source |
| `if_exists` / `if_not_exists` | Keep rows based on matching rows in another collection |

### `filter`

```rust
factory.for_each(Schedule::shifts())
    .filter(|shift| shift.employee_idx.is_none())
```

### `join`

`join` dispatches on the target shape.

Self-join by joining the same generated source on the right side:

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

Cross-join with a generated accessor plus `equal_bi`:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::unavailability()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |u: &Unavailability| u.employee_idx,
        ),
    ))
```

See [Joiners](/docs/solverforge/constraints/joiners/) for joiner types and
composition.

After a cross join, choose the operation that matches the rule:

- score the joined pair directly with `penalize(...)` or `reward(...)`
- group joined pairs directly with `.group_by(|left, right| key, collector)`
- emit one retained scoring row per pair with `.project(|left, right| row)`

### `group_by`

```rust
factory.for_each(Schedule::shifts())
    .group_by(
        |shift: &Shift| shift.employee_idx,
        count(),
    )
```

See [Collectors](/docs/solverforge/constraints/collectors/) for `count`, `sum`,
`load_balance`, `consecutive_runs`, `collect_vec`, and `indexed_presence`.

Cross-join streams can group pairs without a projection step. The key function
receives the joined values as separate arguments, while the collector receives
the stream match shape as one tuple:

```rust
type Streams = ConstraintFactory<Plan, HardSoftScore>;

Streams::new()
    .for_each(Plan::assignments())
    .join((
        Streams::new().for_each(Plan::capacities()),
        equal_bi(
            |assignment: &Assignment| assignment.capacity_id,
            |capacity: &Capacity| Some(capacity.id),
        ),
    ))
    .group_by(
        |assignment: &Assignment, capacity: &Capacity| (assignment.id, capacity.id),
        count(),
    )
```

### `balance`

`balance` calculates load imbalance across a grouping key. The key function
returns `Option<K>`; `None` values are skipped, which is useful for unassigned
entities.

```rust
factory.for_each(Schedule::shifts())
    .balance(|shift: &Shift| shift.employee_idx)
```

## Terminal Operations

### `penalize` / `reward`

Apply a fixed score impact per match, then finalize with `.named()`.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let hard = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(HardSoftScore::ONE_HARD)
    .named("Constraint name");

let soft = Streams::new()
    .for_each(Schedule::shifts())
    .reward(HardSoftScore::ONE_SOFT)
    .named("Preference bonus");
```

Use fixed score values when the constraint applies one hard or soft unit:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let hard = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(HardSoftScore::ONE_HARD)
    .named("Hard violation");

let soft = Streams::new()
    .for_each(Schedule::shifts())
    .reward(HardSoftScore::ONE_SOFT)
    .named("Soft preference");
```

Use a typed dynamic closure when the score depends on the match. Dynamic
closure weights are non-hard metadata by default; wrap the closure in
`hard_weight(...)` when score analysis and conflict repair should classify the
constraint as hard.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let overtime = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(hard_weight(|shift: &Shift| {
        HardSoftScore::of_hard(shift.overtime_hours() as i64)
    }))
    .named("Overtime");

let preference = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(|shift: &Shift| HardSoftScore::of_soft(shift.preference_penalty()))
    .named("Preference");
```

## Joined Filter Indexes

Normal `.filter(...)` predicates stay value-oriented. The lower-level retained
filter contract also receives semantic source indexes so localized incremental
scoring can retract and re-evaluate the correct joined rows:

- same-source joins pass canonical entity indexes
- cross joins pass the left and right source indexes
- flattened rows pass the left source index and the owning right-side source
  index
- projected self-joins pass each projected row's primary owner entity index

This matters for advanced scoring extensions and retained match inspection; it
does not change ordinary fluent `.filter(|a, b| ...)` application code.

## Full Example

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    (
        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),

        Streams::new()
            .for_each(Schedule::shifts())
            .join((
                Streams::new().for_each(Schedule::shifts()),
                equal_bi(
                    |left: &Shift| left.employee_idx,
                    |right: &Shift| right.employee_idx,
                ),
            ))
            .filter(|a: &Shift, b: &Shift| {
                a.id < b.id && a.employee_idx.is_some() && a.overlaps(b)
            })
            .penalize(HardSoftScore::ONE_HARD)
            .named("Overlap"),

        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift| shift.is_preferred_by_employee())
            .reward(HardSoftScore::ONE_SOFT)
            .named("Preference"),
    )
}
```

## See Also

- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - scoring-only derived rows
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - generated collection sources and `for_each`
- [Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/) - `if_exists`, `if_not_exists`, and `flatten_last`
- [Score Analysis](/docs/solverforge/constraints/score-analysis/) - inspecting score contributions
