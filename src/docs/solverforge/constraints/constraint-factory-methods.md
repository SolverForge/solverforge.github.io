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

Generated solution methods carry source ownership metadata that a
hand-written extractor does not carry. The examples on this page use the
[example model](/docs/solverforge/constraints/#example-model) and compile in
its `src/examples.rs`.

## Standard Pattern

<!-- rust: crate=schedule in=example -->
```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

#[solverforge_constraints]
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

<!-- rust: crate=schedule in=example -->
```rust
let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();
```

The solution type is the struct annotated with `#[planning_solution]`. The score
type is the same score type used by the `#[planning_score]` field, such as
`SoftScore`, `HardSoftScore`, `HardMediumSoftScore`, `HardSoftDecimalScore`, or
`BendableScore`.

`ConstraintFactory` also implements `Default`, so these are equivalent:

<!-- rust: crate=schedule in=example -->
```rust
let explicit = ConstraintFactory::<Schedule, HardSoftScore>::new();
let defaulted = ConstraintFactory::<Schedule, HardSoftScore>::default();
```

Prefer `new()` in documentation and application code because it makes the
solution and score binding obvious at the top of the constraint function.

Generated stream roots consume the factory value so stream builder types remain
concrete. `ConstraintFactory` stores no runtime solution data, so construct a
fresh factory for each independent source:

<!-- rust: crate=schedule in=example -->
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
method with the same name as the field. The example model's solution:

<!-- rust: crate=schedule excerpt -->
```rust
#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[problem_fact_collection]
    pub unavailability: Vec<Unavailability>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

This solution generates:

<!-- rust: crate=schedule in=example -->
```rust
let shifts = Schedule::shifts();
let employees = Schedule::employees();
let unavailability = Schedule::unavailability();
```

Each generated method returns a source-aware collection extractor over the
collection item type. Pass that extractor to `ConstraintFactory::for_each(...)`
to start a `UniConstraintStream`. The stream starts with the default true
filter and source ownership metadata, so it can be used directly as a
constraint source or as the right-hand collection in a keyed cross-join.

Use these methods as the first operation in a stream:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift| shift.employee_idx.is_none())
    .penalize(HardSoftScore::ONE_HARD)
    .named("Unassigned shift")
```

Use generated methods again when joining another solution collection:

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
```

Do not replace generated methods with custom slice-returning helpers unless you
intentionally need a lower-level custom extractor.

## Source Metadata

Generated collection source methods preserve the source of each collection:

| Solution field annotation | Generated source kind | Incremental meaning |
| ------------------------- | --------------------- | ------------------- |
| `#[planning_entity_collection]` | Descriptor source | The stream owns localized updates for that entity descriptor |
| `#[problem_fact_collection]` | Static source, or list-shadow change source | Input facts stay static unless the configured list-shadow update writes their element rows |
| `#[planning_list_element_collection]` | Static source, or list-shadow change source | Shadow-bearing elements react to their owner's list edits |

That metadata matters for localized incremental scoring. Entity-source streams
can react only to the descriptor that changed; ordinary fact-source streams
remain stable. Generated shadow-bearing element sources use
`PlanningSolution::list_shadow_source(...)` so the director can retract old
element rows before rewriting their shadows and insert the refreshed rows.
This is important for generated sources used with operations such as
`join`, `if_exists`, `if_not_exists`, `project`, `flatten_last`, `balance`, and
`unassigned`.

Hand-written `source(...)` extractors passed to `for_each(...)` do not have
descriptor source metadata; see `for_each(...)` below.

## Filtered Unary Join Targets

A unary stream implements `CollectionExtract` and keeps its accumulated filter
as source membership when used as a keyed or predicate right-hand cross-join
target. For the first unary keyed equality cross-join, the left unary filter is
also applied before key extraction and pair creation, without renumbering the
source indexes or losing incremental change metadata. Put nullable-row filters
before that equality join if a key extractor requires an assigned value.

Post-join filters operate on joined rows, not source keys. The left-source
pushdown does not apply to comparison, overlap, composed-condition, predicate,
or same-source self-join dispatch. Fluent collection targets are not arbitrary
derived operators: compatible derived producers can instead feed low-level
`JoinNode` inputs. See [Constraint Streams](/docs/solverforge/constraints/constraint-streams/).

## `for_each(...)`

`for_each(...)` starts a stream from an extractor that implements
`CollectionExtract<Solution>`. For solution collections, pass the generated
source method:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new().for_each(Schedule::shifts())
```

Closures and plain `fn` items are not extractors. A hand-written extractor
wraps a `fn` pointer with `source(...)` and declares how its rows change;
`ChangeSource::Static` says they never change during a solve:

<!-- rust: crate=schedule in=example -->
```rust
use solverforge::stream::{source, ChangeSource};

fn rows(schedule: &Schedule) -> &[Unavailability] {
    &schedule.unavailability
}

Streams::new().for_each(source(rows as fn(&Schedule) -> &[Unavailability], ChangeSource::Static))
```

A hand-written extractor has no descriptor metadata, so incremental scoring
cannot localize changes to it. Use one only for low-level scoring or runtime
tests; constraints over model collections use the generated methods.

## Generated `unassigned()`

`unassigned()` is not a `ConstraintFactory` method. It is available on streams
whose planning entity has exactly one `Option<_>` planning variable with
unassigned support.

<!-- rust: crate=schedule in=example -->
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

<!-- rust: crate=schedule in=example -->
```rust
struct ShiftHours {
    hours: i64,
}

struct HoursOf;

impl Projection<Shift> for HoursOf {
    type Out = ShiftHours;
    const MAX_EMITS: usize = 1;

    fn project<Sink: ProjectionSink<ShiftHours>>(&self, shift: &Shift, sink: &mut Sink) {
        sink.emit(ShiftHours { hours: shift.hours() });
    }
}

Streams::new()
    .for_each(Schedule::shifts())
    .project(HoursOf)
    .penalize(|row: &ShiftHours| HardSoftScore::of_soft(row.hours))
    .named("Shift hours")
```

Joined-pair projection should also start from generated methods on both sides:

<!-- rust: crate=schedule in=example -->
```rust
struct HoursOverMax {
    shift_id: usize,
    score: HardSoftScore,
}

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
    .project(|shift: &Shift, employee: &Employee| HoursOverMax {
        shift_id: shift.id,
        score: HardSoftScore::of_hard((shift.hours() - employee.max_hours).max(0)),
    })
    .penalize(hard_weight(|row: &HoursOverMax| row.score))
    .named("Shift longer than the employee's limit")
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

- Starting normal constraints from a hand-written `source(...)` extractor
  instead of `Streams::new().for_each(Schedule::shifts())`.
- Joining facts through a custom extractor or closure when `Schedule::employees()`
  is generated.
- Extending a joined pair with only `(source, key_fn)`. Chained joins need
  `(source, equal_on(left_row_key, right_leaf_key))`, with borrowed row views
  and a fresh condition for the added relationship. At each of `Bi::join`,
  `Tri::join`, `Quad::join`, `Penta::join`, and `Chain::join`, the left key
  receives the whole prior row and the right key receives `&Leaf<'_, T>`;
  read entity fields through `.entity`. `equal_bi` with plain entity closures
  is for the first unary join and fails to typecheck at these continuations
  (`E0631`).
- Expecting generated method aliases that do not match the solution field name.
- Using `for_each(...)` for projected rows that should keep localized source
  ownership.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - the stream operation pipeline
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - retained scoring-only rows
- [Planning Solutions](/docs/solverforge/modeling/planning-solutions/) - generated solution helpers
