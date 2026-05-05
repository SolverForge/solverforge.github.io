---
title: "Constraint Factory Methods"
linkTitle: "Constraint Factory Methods"
weight: 12
description: >
  Use ConstraintFactory and generated collection accessors as the typed entry points for constraint streams.
---

`ConstraintFactory<Solution, Score>` is the typed entry point for constraint
streams. In normal application constraints, start each independent stream source
from a fresh zero-state factory and then call the generated collection accessor,
such as `Streams::new().shifts()` or `Streams::new().employees()`.

Use raw `for_each(...)` only for custom collection surfaces that are not
generated from the planning solution. Generated methods carry source ownership
metadata that raw extractor closures do not carry.

## Standard Pattern

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    (
        Streams::new()
            .shifts()
            .unassigned()
            .penalize_hard()
            .named("Unassigned shift"),

        Streams::new()
            .shifts()
            .join((
                Streams::new().employees(),
                equal_bi(
                    |shift: &Shift| shift.employee_idx,
                    |employee: &Employee| Some(employee.index),
                ),
            ))
            .filter(|shift: &Shift, employee: &Employee| {
                !employee.skills.contains(&shift.required_skill)
            })
            .penalize_hard()
            .named("Missing skill"),
    )
}
```

The generated accessor traits live next to the model types emitted by
`#[planning_solution]`. When constraints live in the same module as the model,
the generated traits are already in scope. When constraints live in another
module, import the generated traits from the model module, for example
`use crate::domain::{ScheduleConstraintStreams, ShiftUnassignedFilter};`.

## `ConstraintFactory::new()`

`ConstraintFactory::<Solution, Score>::new()` constructs the zero-state factory
for a concrete planning solution and score type.

```rust
let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();
```

The solution type is the struct annotated with `#[planning_solution]`. The score
type is the same score type used by the `#[planning_score]` field, such as
`SoftScore`, `HardSoftScore`, `HardMediumSoftScore`, `HardSoftDecimalScore`, or
`BendableScore`.

`ConstraintFactory` also implements `Default`, so these are equivalent:

```rust
let explicit = ConstraintFactory::<Schedule, HardSoftScore>::new();
let defaulted = ConstraintFactory::<Schedule, HardSoftScore>::default();
```

Prefer `new()` in documentation and application code because it makes the
solution and score binding obvious at the top of the constraint function.

Generated accessors consume the factory value so stream builder types remain
concrete. `ConstraintFactory` stores no runtime solution data, so construct a
fresh factory for each independent source:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let unassigned = Streams::new()
    .shifts()
    .unassigned()
    .penalize_hard()
    .named("Unassigned shift");

let preference = Streams::new()
    .shifts()
    .filter(|shift| shift.is_preferred())
    .reward_soft()
    .named("Preferred assignment");
```

## Generated Collection Accessors

For every collection field on a `#[planning_solution]`, SolverForge generates a
method with the same name as the field:

```rust
#[planning_solution(constraints = "define_constraints")]
pub struct Schedule {
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

This solution generates:

```rust
Streams::new().shifts()
Streams::new().employees()
```

The generated trait name is `{Solution}ConstraintStreams`, so `Schedule` emits
`ScheduleConstraintStreams<Sc>`. The implementation is provided for
`ConstraintFactory<Schedule, Sc>`.

Each generated method returns a `UniConstraintStream` over the collection item
type. The stream starts with the default true filter and a source-aware
extractor, so it can be used directly as a constraint source or as the
right-hand collection in a keyed cross-join.

Use these methods as the first operation in a stream:

```rust
Streams::new()
    .shifts()
    .filter(|shift| shift.employee_idx.is_none())
    .penalize_hard()
    .named("Unassigned shift")
```

Use generated methods again when joining another solution collection:

```rust
Streams::new()
    .shifts()
    .join((
        Streams::new().employees(),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
```

Do not replace generated methods with custom slice-returning helpers unless you
intentionally need a lower-level custom extractor.

## Source Metadata

Generated factory methods preserve the source of each collection:

| Solution field annotation | Generated source kind | Incremental meaning |
| ------------------------- | --------------------- | ------------------- |
| `#[planning_entity_collection]` | Descriptor source | The stream owns localized updates for that entity descriptor |
| `#[problem_fact_collection]` | Static source | The stream reads immutable facts and does not react to entity moves |

That metadata matters for localized incremental scoring. Entity-source streams
can react only to the descriptor that changed; fact-source streams remain
stable. This is important for generated accessors used with operations such as
`join`, `if_exists`, `if_not_exists`, `project`, `flatten_last`, `balance`, and
`unassigned`.

Custom extractors passed to `for_each(...)` do not have this source metadata.
They are still supported, but they are a lower-level API.

## `for_each(...)`

`for_each(...)` starts a stream from any extractor that implements
`CollectionExtract<Solution>`.

```rust
use solverforge::stream::vec;

Streams::new().for_each(vec(|solution: &Schedule| &solution.custom_rows))
```

Use it when:

- the collection is not a generated planning entity or problem fact collection
- you are intentionally exposing a custom view of solution data
- you are writing low-level scoring or runtime tests

For `Vec<T>` fields, use the `vec(...)` wrapper from the stream API:

```rust
use solverforge::stream::vec;

Streams::new().for_each(vec(|solution: &Schedule| &solution.custom_rows))
```

For normal application constraints over generated solution fields, prefer the
generated accessor:

```rust
Streams::new().shifts()
```

instead of:

```rust
Streams::new().for_each(vec(|solution: &Schedule| &solution.shifts))
```

## Generated `unassigned()`

`unassigned()` is not a `ConstraintFactory` method, but it is generated for
streams of planning entities that have exactly one `Option<_>` planning
variable.

```rust
Streams::new()
    .shifts()
    .unassigned()
    .penalize_hard()
    .named("Unassigned shift")
```

The generated trait name is `{Entity}UnassignedFilter`, so `Shift` emits
`ShiftUnassignedFilter`. Bring that trait into scope where you call
`.unassigned()`.

## Projected Rows

Generated accessors are the preferred source for projected scoring rows because
the projection can keep the same localized source ownership.

```rust
Streams::new()
    .shifts()
    .project(ShiftPenaltyProjection)
    .penalize_with(|row: &ShiftPenalty| row.score)
    .named("Shift penalty")
```

Joined-pair projection should also start from generated methods on both sides:

```rust
Streams::new()
    .assignments()
    .join((
        Streams::new().capacities(),
        equal_bi(
            |assignment: &Assignment| assignment.capacity_id,
            |capacity: &Capacity| Some(capacity.id),
        ),
    ))
    .project(|assignment: &Assignment, capacity: &Capacity| CapacityViolation {
        assignment_id: assignment.id,
        score: HardSoftScore::of_hard((assignment.demand - capacity.amount).max(0)),
    })
    .penalize_with(|row: &CapacityViolation| row.score)
    .named("Capacity violation")
```

## Naming Rules

Generated factory methods use the exact Rust field names from the planning
solution. A field named `shifts` generates `.shifts()`. A field named
`employee_skills` generates `.employee_skills()`.

The methods do not create aliases. If you rename a solution collection field,
update every constraint that calls the generated method.

Solver configuration still refers to canonical entity and variable descriptor
names, not these stream method names.

## Common Mistakes

- Starting normal constraints with `Streams::new().for_each(vec(|s: &Schedule| &s.shifts))`
  instead of `Streams::new().shifts()`.
- Joining facts through a custom extractor or closure when `.employees()`
  is generated.
- Forgetting to import `{Solution}ConstraintStreams` before calling generated
  collection methods.
- Forgetting to import `{Entity}UnassignedFilter` before calling
  `.unassigned()`.
- Expecting generated method aliases that do not match the solution field name.
- Using `for_each(...)` for projected rows that should keep localized source
  ownership.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - the stream operation pipeline
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - retained scoring-only rows
- [Planning Solutions](/docs/solverforge/modeling/planning-solutions/) - generated solution helpers
