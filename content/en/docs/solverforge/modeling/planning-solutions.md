---
title: "Planning Solutions"
linkTitle: "Planning Solutions"
weight: 10
description: >
  The top-level container that holds entities, problem facts, value ranges, and the score.
---

A **planning solution** is the root struct that represents your entire problem and its current solution state. It holds all entities, problem facts, available values, and the score.

## The `#[planning_solution]` Macro

```rust
use solverforge::prelude::*;

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    #[value_range_provider]
    pub employees: Vec<Employee>,

    #[problem_fact_collection]
    pub availability: Vec<Availability>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

The `constraints` parameter specifies the module path to the constraint provider function.

## Field Attributes

### `#[planning_entity_collection]`

Marks a `Vec<T>` field containing planning entities. The solver iterates these to find variables to change.

```rust
#[planning_entity_collection]
pub shifts: Vec<Shift>,
```

### `#[problem_fact_collection]`

Marks a `Vec<T>` field containing immutable problem facts. Used by constraints but never modified by the solver.

```rust
#[problem_fact_collection]
pub employees: Vec<Employee>,
```

### `#[value_range_provider]`

Marks a collection as providing possible values for planning variables. Usually combined with `#[problem_fact_collection]`.

```rust
#[problem_fact_collection]
#[value_range_provider]
pub timeslots: Vec<Timeslot>,
```

The solver draws from this collection when trying assignments for any `#[planning_variable]` field whose type matches.

### `#[planning_score]`

Marks the field that holds the current solution quality. Must be `Option<ScoreType>`.

```rust
#[planning_score]
pub score: Option<HardSoftScore>,
```

Supported score types: `SoftScore`, `HardSoftScore`, `HardMediumSoftScore`, `HardSoftDecimalScore`, `BendableScore`.

## Requirements

- Must derive `Clone` and `Debug` (added automatically by the macro)
- Must have exactly one `#[planning_score]` field
- Must have at least one `#[planning_entity_collection]` field
- Must have at least one `#[value_range_provider]` field

## See Also

- [Planning Entities](../planning-entities/) — What the solver changes
- [Score Types](/docs/solverforge/constraints/score-types/) — Available score types
