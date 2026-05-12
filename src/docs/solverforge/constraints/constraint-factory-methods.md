---
title: "Constraint Factory Methods"
linkTitle: "Constraint Factory Methods"
weight: 12
description: >
  Use ConstraintFactory and generated collection sources as the typed entry points for constraint streams.
---

`ConstraintFactory<Solution, Score>` is the typed entry point for constraint
streams. In normal application constraints, start each independent stream source
from a fresh zero-state factory and pass the generated collection source to
`for_each(...)`, such as `Streams::new().for_each(Schedule::shifts())` or
`Streams::new().for_each(Schedule::employees())`.

Generated solution methods carry source ownership metadata that ad hoc
slice-returning closures do not carry. Use `solverforge::stream::vec(...)` only
for custom collection surfaces that are not generated from the planning
solution.

## Standard Pattern

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    (
        Streams::new()
            .for_each(Schedule::shifts())
            .unassigned()
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),

        Streams::new()
            .for_each(Schedule::shifts())
            .join((
                Streams::new().for_each(Schedule::employees()),
                equal_bi(
                    |shift: &Shift| shift.employee_idx,
                    |employee: &Employee| Some(employee.index),
                ),
            ))
            .filter(|shift: &Shift, employee: &Employee| {
                !employee.skills.contains(&shift.required_skill)
            })
            .penalize(HardSoftScore::ONE_HARD)
            .named("Missing skill"),
    )
}
```

The generated collection source methods live on the model types emitted by
`#[planning_solution]`. When the solution type is in scope, the generated source
methods are available as `Schedule::shifts()`, `Schedule::employees()`, and so
on.

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

Generated stream roots consume the factory value so stream builder types remain
concrete. `ConstraintFactory` stores no runtime solution data, so construct a
fresh factory for each independent source:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let unassigned = Streams::new()
    .for_each(Schedule::shifts())
    .unassigned()
    .penalize(HardSoftScore::ONE_HARD)
    .named("Unassigned shift");

let preference = Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift| shift.is_preferred())
    .reward(HardSoftScore::ONE_SOFT)
    .named("Preferred assignment");
```

## Generated Collection Sources

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
Schedule::shifts();
Schedule::employees();
```

Each generated method returns a source-aware collection extractor over the
collection item type. Pass that extractor to `ConstraintFactory::for_each(...)`
to start a `UniConstraintStream`. The stream starts with the default true
filter and source ownership metadata, so it can be used directly as a
constraint source or as the right-hand collection in a keyed cross-join.

Use these methods as the first operation in a stream:

```rust
Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift| shift.employee_idx.is_none())
    .penalize(HardSoftScore::ONE_HARD)
    .named("Unassigned shift")
```

Use generated methods again when joining another solution collection:

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
```

Do not replace generated methods with custom slice-returning helpers unless you
intentionally need a lower-level custom extractor.

## Source Metadata

Generated collection source methods preserve the source of each collection:

| Solution field annotation | Generated source kind | Incremental meaning |
| ------------------------- | --------------------- | ------------------- |
| `#[planning_entity_collection]` | Descriptor source | The stream owns localized updates for that entity descriptor |
| `#[problem_fact_collection]` | Static source | The stream reads immutable facts and does not react to entity moves |

That metadata matters for localized incremental scoring. Entity-source streams
can react only to the descriptor that changed; fact-source streams remain
stable. This is important for generated sources used with operations such as
`join`, `if_exists`, `if_not_exists`, `project`, `flatten_last`, `balance`, and
`unassigned`.

Custom `vec(...)` extractors passed to `for_each(...)` do not have descriptor
source metadata. They are still supported, but they are a lower-level API.

## `for_each(...)`

`for_each(...)` starts a stream from any extractor that implements
`CollectionExtract<Solution>`.

For generated solution collections, pass the generated source method:

```rust
Streams::new().for_each(Schedule::shifts())
```

```rust
use solverforge::stream::vec;

Streams::new().for_each(vec(|solution: &Schedule| &solution.custom_rows))
```

Use it when:

- the collection is a generated planning entity or problem fact source, such as
  `Schedule::shifts()`
- the collection is a custom view wrapped with `vec(...)`
- you are writing low-level scoring or runtime tests

For `Vec<T>` fields, use the `vec(...)` wrapper from the stream API:

```rust
use solverforge::stream::vec;

Streams::new().for_each(vec(|solution: &Schedule| &solution.custom_rows))
```

For normal application constraints over generated solution fields, prefer the
generated source method:

```rust
Streams::new().for_each(Schedule::shifts())
```

instead of:

```rust
Streams::new().for_each(vec(|solution: &Schedule| &solution.shifts))
```

## Generated `unassigned()`

`unassigned()` is not a `ConstraintFactory` method. It is available on streams
whose planning entity has exactly one `Option<_>` planning variable with
unassigned support.

```rust
Streams::new()
    .for_each(Schedule::shifts())
    .unassigned()
    .penalize(HardSoftScore::ONE_HARD)
    .named("Unassigned shift")
```

The entity derive provides the unassigned predicate, and the stream API exposes
`.unassigned()` when that predicate exists. Normal constraint modules only need
the entity type and the `solverforge::prelude::*` / stream imports already used
by the surrounding constraint function.

## Projected Rows

Generated source methods are the preferred source for projected scoring rows because
the projection can keep the same localized source ownership.

```rust
Streams::new()
    .for_each(Schedule::shifts())
    .project(ShiftPenaltyProjection)
    .penalize(|row: &ShiftPenalty| row.score)
    .named("Shift penalty")
```

Joined-pair projection should also start from generated methods on both sides:

```rust
Streams::new()
    .for_each(Plan::assignments())
    .join((
        Streams::new().for_each(Plan::capacities()),
        equal_bi(
            |assignment: &Assignment| assignment.capacity_id,
            |capacity: &Capacity| Some(capacity.id),
        ),
    ))
    .project(|assignment: &Assignment, capacity: &Capacity| CapacityViolation {
        assignment_id: assignment.id,
        score: HardSoftScore::of_hard((assignment.demand - capacity.amount).max(0)),
    })
    .penalize(hard_weight(|row: &CapacityViolation| row.score))
    .named("Capacity violation")
```

## Naming Rules

Generated source methods use the exact Rust field names from the planning
solution. A field named `shifts` generates `Schedule::shifts()`. A field named
`employee_skills` generates `Schedule::employee_skills()`.

The methods do not create aliases. If you rename a solution collection field,
update every constraint that calls the generated method.

Solver configuration still refers to canonical entity and variable descriptor
names, not these stream method names.

## Common Mistakes

- Starting normal constraints with `Streams::new().for_each(vec(|s: &Schedule| &s.shifts))`
  instead of `Streams::new().for_each(Schedule::shifts())`.
- Joining facts through a custom extractor or closure when `Schedule::employees()`
  is generated.
- Expecting generated method aliases that do not match the solution field name.
- Using `for_each(...)` for projected rows that should keep localized source
  ownership.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - the stream operation pipeline
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - retained scoring-only rows
- [Planning Solutions](/docs/solverforge/modeling/planning-solutions/) - generated solution helpers
