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

```rust
use solverforge::prelude::*;

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub required_skill: String,
    #[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
    pub employee_id: Option<usize>,
}
```

## Field Attributes

### `#[planning_id]`

Provides stable identity for the entity. This is strongly recommended for joins,
analysis, and readable telemetry.

```rust
#[planning_id]
pub id: usize,
```

### `#[planning_variable]`

Marks a field as a planning variable — the solver assigns values to this field.

```rust
#[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
pub employee_id: Option<usize>,

#[planning_variable(countable_range = "0..10")]
pub priority_bucket: i32,
```

Common parameters:

- `value_range_provider = "employees"`: references a field on the planning
  solution that supplies possible values
- `allows_unassigned = true`: permits `None` for `Option<T>` variables
- `countable_range = "0..10"`: declares an integer range directly on the field
- `candidate_values = "fn_name"`: supplies an ordered bounded scalar value
  neighborhood for construction, change, pillar-change, and ruin-recreate
- `nearby_value_candidates = "fn_name"` and
  `nearby_entity_candidates = "fn_name"`: supply bounded candidates for nearby
  scalar local-search selectors
- `nearby_value_distance_meter = "fn_name"` and
  `nearby_entity_distance_meter = "fn_name"`: rank or filter already bounded
  nearby candidates; they do not discover candidates by themselves
- `construction_entity_order_key = "fn_name"` and
  `construction_value_order_key = "fn_name"`: provide live construction-order
  keys for scalar-only construction heuristics

The macro also generates an `.unassigned()` stream helper when the entity has
exactly one `Option<_>` planning variable.

Construction order keys are construction-only. Local-search scalar selectors
keep canonical bounded candidate order even when the same variable declares
construction keys.

### `#[planning_list_variable]`

Declares a stock list variable for routing or sequencing. In the current runtime
this is represented as `Vec<usize>` plus an `element_collection` name.

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

```rust
#[planning_pin]
pub pinned: bool,
```

When `pinned` is `true`, the solver treats the entity as immovable.

## Shadow Variables

Shadow variables are derived fields maintained from genuine planning variables.
They are advanced modeling features; you do not assign them directly.

### `#[inverse_relation_shadow_variable]`

Tracks an inverse relationship from a source variable.

```rust
#[inverse_relation_shadow_variable(source_variable_name = "visits")]
pub vehicle: Option<usize>,
```

### `#[previous_element_shadow_variable]`

For list variables — automatically tracks the previous element in the list.

```rust
#[previous_element_shadow_variable(source_variable_name = "visits")]
pub previous_stop: Option<Stop>,
```

### `#[next_element_shadow_variable]`

For list variables — automatically tracks the next element in the list.

```rust
#[next_element_shadow_variable(source_variable_name = "visits")]
pub next_stop: Option<Stop>,
```

## Requirements

- Must be a named Rust struct
- Must have at least one `#[planning_variable]` or `#[planning_list_variable]`
  field

The macro adds the standard derives and trait implementations for you; you do
not need to duplicate `Clone` or `Debug` manually in the common case.

## See Also

- [Planning Solutions](/docs/solverforge/modeling/planning-solutions/) — The container that holds entities
- [Problem Facts](/docs/solverforge/modeling/problem-facts/) — Immutable input data
- [List Variables](/docs/solverforge/modeling/list-variables/) — Sequencing and routing variables
