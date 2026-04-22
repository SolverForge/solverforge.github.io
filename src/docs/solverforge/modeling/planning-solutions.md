---
title: "Planning Solutions"
linkTitle: "Planning Solutions"
weight: 10
description: >
  The top-level container that holds entities, facts, and the current score.
---

A **planning solution** is the root struct that represents your entire problem
and its current solution state. It owns your entity collections, problem facts,
and score field.

## The `#[planning_solution]` Macro

```rust
use solverforge::prelude::*;

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[problem_fact_collection]
    pub availability: Vec<Availability>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

The `constraints` parameter is optional, but it is what enables the generated
`Solvable` and `Analyzable` implementations used by the stock runtime.

## Field Attributes

### `#[planning_entity_collection]`

Marks a `Vec<T>` field containing planning entities. The solver iterates these
collections to find variables to change.

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

### `#[planning_score]`

Marks the field that holds the current solution quality. Must be `Option<ScoreType>`.

```rust
#[planning_score]
pub score: Option<HardSoftScore>,
```

Supported score types: `SoftScore`, `HardSoftScore`, `HardMediumSoftScore`, `HardSoftDecimalScore`, `BendableScore`.

## Generated Helpers

When `constraints = "..."` is present, `#[planning_solution]` also generates:

- A `{Name}ConstraintStreams<Sc>` trait implemented on `ConstraintFactory`, so
  you can write `factory.shifts()` instead of repeating `for_each(...)`
- `Solvable` for channel-based solving through `SolverManager`
- `Analyzable` for score breakdowns via `analyze()`

For advanced list-shadow workflows, the struct can also carry
`#[shadow_variable_updates(...)]`. When present, the macro generates
`PlanningSolution::update_entity_shadows(...)` and `update_all_shadows()`
overrides directly on the solution type, and the stock `ScoreDirector` calls
those hooks automatically during solving and score analysis.

## Requirements

- Must be a named Rust struct
- Must have exactly one `#[planning_score]` field
- Must have at least one `#[planning_entity_collection]` field for stock solving

Common value-range setup lives on the entity side, for example
`#[planning_variable(value_range = "employees")]`.

## See Also

- [Planning Entities](../planning-entities/) — What the solver changes
- [Score Types](/docs/solverforge/constraints/score-types/) — Available score types
