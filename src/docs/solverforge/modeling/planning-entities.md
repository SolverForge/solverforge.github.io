---
title: "Planning Entities"
linkTitle: "Planning Entities"
weight: 20
description: >
  Structs with planning variables that the solver assigns during optimization.
---

A **planning entity** is a struct that contains one or more **planning
variables**. These are the fields the solver changes while searching for a good
solution.

## The `#[planning_entity]` Macro

This page's examples come from one model. `src/domain/model.rs`:

<!-- rust: crate=entity-variables file=src/domain/model.rs -->
```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub id: usize,
    pub name: String,
}

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub allowed_employees: Vec<usize>,
    #[planning_pin]
    pub pinned: bool,
    #[planning_variable(value_range_provider = "allowed_employees", allows_unassigned = true)]
    pub employee_idx: Option<usize>,
    #[planning_variable(countable_range = "5..10")]
    pub priority_bucket: Option<usize>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

`src/domain/mod.rs` registers it:

<!-- rust: crate=entity-variables file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Employee, Schedule, Shift};
}
```

`src/constraints.rs` penalizes unassigned shifts and prefers low buckets:

<!-- rust: crate=entity-variables file=src/constraints.rs -->
```rust
use solverforge::prelude::*;

use crate::domain::{Schedule, Shift};

pub fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    (
        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift: &Shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),
        Streams::new()
            .for_each(Schedule::shifts())
            .penalize(|shift: &Shift| {
                HardSoftScore::of_soft(shift.priority_bucket.map_or(0, |bucket| bucket as i64))
            })
            .named("Priority bucket"),
    )
}
```

## Field Attributes

### `#[planning_id]`

Provides stable identity for the entity. This is strongly recommended for joins,
analysis, and readable telemetry.

<!-- rust: crate=entity-variables excerpt -->
```rust
#[planning_id]
pub id: usize,
```

### `#[planning_variable]`

Marks a field as a planning variable — the solver assigns values to this field.

<!-- rust: crate=entity-variables excerpt -->
```rust
#[planning_variable(value_range_provider = "allowed_employees", allows_unassigned = true)]
pub employee_idx: Option<usize>,
#[planning_variable(countable_range = "5..10")]
pub priority_bucket: Option<usize>,
```

Common parameters:

- `value_range_provider = "employees"`: references a solution collection for a
  shared legal index range, or a `Vec<usize>` field on the entity for a
  per-entity legal domain
- `allows_unassigned = true`: permits `None` for `Option<T>` variables
- `countable_range = "5..10"`: declares a half-open integer range of candidate
  values directly on the field. The field is `Option<usize>` and stores the
  chosen value itself (5 through 9), not a position in the range
- `candidate_values = "fn_name"`: supplies an ordered bounded scalar value
  neighborhood for construction, change, pillar-change, and ruin-recreate.
  It is a search hint, not a legal-domain restriction; swap families ignore it
- `nearby_value_candidates = "fn_name"` and
  `nearby_entity_candidates = "fn_name"`: supply bounded candidates for nearby
  scalar local-search selectors
- `nearby_value_distance_meter = "fn_name"` and
  `nearby_entity_distance_meter = "fn_name"`: rank or filter already bounded
  nearby candidates; they do not discover candidates by themselves
- `construction_entity_order_key = "fn_name"` and
  `construction_value_order_key = "fn_name"`: provide live construction-order
  keys for scalar-only construction heuristics

For a per-entity domain, store legal indexes on the entity and name that field:

<!-- rust: crate=entity-variables excerpt -->
```rust
pub allowed_employees: Vec<usize>,
#[planning_pin]
pub pinned: bool,
#[planning_variable(value_range_provider = "allowed_employees", allows_unassigned = true)]
pub employee_idx: Option<usize>,
```

Construction and all scalar move families, including swap, nearby swap, and
pillar swap, enforce the receiving entity's legal domain.

This program solves two shifts: shift 0 may only take employee 1, and shift 1
is pinned to employee 0 with bucket 7. With no termination configured the
solver runs construction only:

<!-- rust: crate=entity-variables file=src/main.rs -->
```rust
mod constraints;
mod domain;

use domain::{Employee, Schedule, Shift};
use solverforge::{SolverEvent, SolverManager};

static MANAGER: SolverManager<Schedule> = SolverManager::new();

fn main() {
    let schedule = Schedule {
        employees: vec![
            Employee { id: 0, name: "Amina".into() },
            Employee { id: 1, name: "Bruno".into() },
        ],
        shifts: vec![
            Shift { id: 0, allowed_employees: vec![1], pinned: false, employee_idx: None, priority_bucket: None },
            Shift { id: 1, allowed_employees: vec![0, 1], pinned: true, employee_idx: Some(0), priority_bucket: Some(7) },
        ],
        score: None,
    };

    let (job_id, mut events) = MANAGER.solve(schedule).expect("solver job should start");
    while let Some(event) = events.blocking_recv() {
        match event {
            SolverEvent::Completed { solution, .. } => {
                for shift in &solution.shifts {
                    println!(
                        "shift {}: employee {:?}, bucket {:?}",
                        shift.id, shift.employee_idx, shift.priority_bucket
                    );
                }
                println!("score: {:?}", solution.score);
                break;
            }
            SolverEvent::Failed { error, .. } => panic!("solve failed: {error}"),
            _ => {}
        }
    }
    MANAGER.delete(job_id).expect("finished job should delete");
}
```

`cargo run` prints:

<!-- rust: crate=entity-variables output -->
```text
shift 0: employee Some(1), bucket Some(5)
shift 1: employee Some(0), bucket Some(7)
score: Some(HardSoftScore(0, -12))
```

Shift 0 takes employee 1, its only legal value, and bucket 5, the lowest value
of `5..10`. The pinned shift keeps its input. A swap can receive a
value outside `candidate_values` if it is inside that domain. Use
`#[planning_pin]`, not a one-value domain, to preserve an input assignment.

Nullability is not the same as required coverage. An assignment-backed
`ScalarGroup::assignment(...)` can mark nullable rows required with
`with_required_entity`, and uses named grouped construction and
`grouped_scalar_move_selector`. Optional kept-unassigned decisions complete
only their anchor group slot and allow construction to continue to later rows;
completed optional roots are skipped before reading candidate domains.
See [Construction](/docs/solverforge/solver/construction/) for group declaration,
capacity hooks, assignment limits, and completion semantics.

The macro also generates an `.unassigned()` stream helper when the entity has
exactly one `Option<_>` planning variable.

Construction order keys are construction-only. Local-search ranking uses
separate `search_entity_order_key` and `search_value_order_key` hooks.

### Guided Scalar Search

Declare `search_entity_order_key = "fn_name"` to rank ordinary scalar change
and swap entities, and `search_value_order_key = "fn_name"` to rank ordinary
change values. The signatures are `fn(&S, &Entity) -> i64` and
`fn(&S, &Entity, value: usize) -> i64`. Lower keys are tried first; equal keys
retain the seeded candidate order. Variables without these hooks retain their
unguided ordering. These hooks rank enumeration, not acceptance: the score,
acceptor, and forager still decide which candidate is committed.

Callbacks may read the whole solution. A change to another entity can change
a candidate domain, order key, legality verdict, or ownership policy; do not
treat a callback as row-local merely because it receives one entity.

Scalar variables remain direct one-slot assignments. When planning owns
membership or order as well as assignment, use a list variable instead.

### `#[planning_list_variable]`

Declares the canonical ordered-sequence variable for routing or sequencing: a
`Vec<usize>` plus an `element_collection` name. From the routing model on
[List Variables](/docs/solverforge/modeling/list-variables/):

<!-- rust: crate=routes excerpt -->
```rust
#[planning_list_variable(element_collection = "visits")]
pub visits: Vec<usize>,
```

Common parameters:

- `element_collection = "visits"`: names the solution collection that contains
  all list elements
- `domain = "cvrp"`: uses the stock CVRP profile for route-list models,
  including the CVRP solution trait, distance meters, route hooks, savings
  hooks, and savings metric class
- `solution_trait = "path::Trait"`: adds an explicit solution-side trait bound
  for generated stock list-variable helpers when meters or route utilities need
  richer solution context

### `#[planning_pin]`

Prevents the solver from changing an entity's variables. Useful for pre-assigned or locked entities.

<!-- rust: crate=entity-variables excerpt -->
```rust
#[planning_pin]
pub pinned: bool,
```

When `pinned` is `true`, the solver treats the entity as immovable.

## Shadow Variables

Shadow variables are derived fields maintained from genuine planning variables.
They are advanced modeling features; you do not assign them directly. The
attributes go on fields of a `#[planning_entity]` element type, and the
solution's `#[shadow_variable_updates(...)]` names the fields to maintain. The
examples come from the routing model on
[List Variables](/docs/solverforge/modeling/list-variables/).

### `#[inverse_relation_shadow_variable]`

Tracks an inverse relationship from a source variable.

<!-- rust: crate=routes excerpt -->
```rust
#[inverse_relation_shadow_variable(source_variable_name = "visits")]
pub vehicle: Option<usize>,
```

### `#[index_shadow_variable]`

For list variables, tracks the element's current zero-based position. Declare
`#[index_shadow_variable(source_variable_name = "visits")]` on an
`Option<usize>` field and name that field with `index_field` on the solution's
`#[shadow_variable_updates(...)]` configuration.

### `#[previous_element_shadow_variable]`

For list variables — automatically tracks the previous element in the list.

<!-- rust: crate=routes excerpt -->
```rust
#[previous_element_shadow_variable(source_variable_name = "visits")]
pub previous_stop: Option<usize>,
```

### `#[next_element_shadow_variable]`

For list variables — automatically tracks the next element in the list.

<!-- rust: crate=routes excerpt -->
```rust
#[next_element_shadow_variable(source_variable_name = "visits")]
pub next_stop: Option<usize>,
```

## Requirements

- Must be a named Rust struct
- Holds the `#[planning_variable]` or `#[planning_list_variable]` fields the
  solver changes; a list element type may instead carry only shadow fields,
  as `Visit` does in the routing model

The macro adds the standard derives and trait implementations for you; you do
not need to duplicate `Clone` or `Debug` manually in the common case.

## See Also

- [Planning Solutions](/docs/solverforge/modeling/planning-solutions/) — The container that holds entities
- [Problem Facts](/docs/solverforge/modeling/problem-facts/) — Immutable input data
- [List Variables](/docs/solverforge/modeling/list-variables/) — Sequencing and routing variables
