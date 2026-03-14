---
title: "Planning Entities"
linkTitle: "Planning Entities"
weight: 20
description: >
  Structs with planning variables that the solver assigns during optimization.
---

A **planning entity** is a struct that contains one or more **planning variables** — fields the solver changes to find a good solution. In employee scheduling, a `Shift` is an entity because the solver assigns an `Employee` to each shift.

## The `#[planning_entity]` Macro

```rust
use solverforge::prelude::*;

#[planning_entity]
#[derive(Clone, Debug)]
pub struct Shift {
    #[planning_id]
    pub id: i64,
    pub required_skill: String,
    pub timeslot: Timeslot,
    #[planning_variable(allows_unassigned = true)]
    pub employee: Option<Employee>,
}
```

## Field Attributes

### `#[planning_id]`

Uniquely identifies the entity. Required on every planning entity.

```rust
#[planning_id]
pub id: i64,
```

### `#[planning_variable]`

Marks a field as a planning variable — the solver assigns values to this field.

```rust
// Nullable variable (solver can leave unassigned)
#[planning_variable(allows_unassigned = true)]
pub employee: Option<Employee>,

// Non-nullable variable (solver must assign a value)
#[planning_variable]
pub timeslot: Timeslot,
```

**`allows_unassigned = true`**: The variable can be `None`, meaning the solver may leave some entities unassigned. Use this when not every entity must be assigned (e.g., optional shifts). The field type must be `Option<T>`.

### `#[planning_pin]`

Prevents the solver from changing an entity's variables. Useful for pre-assigned or locked entities.

```rust
#[planning_pin]
pub pinned: bool,
```

When `pinned` is `true`, the solver treats the entity as immovable.

## Shadow Variables

Shadow variables are automatically calculated from genuine planning variables. They are derived values that the solver maintains — you never assign them directly.

### `#[inverse_relation_shadow_variable]`

Automatically tracks which entities are assigned to a value. For example, tracking which shifts an employee has:

```rust
#[planning_entity]
#[derive(Clone, Debug)]
pub struct Employee {
    #[planning_id]
    pub id: i64,
    #[inverse_relation_shadow_variable(source_variable = "employee")]
    pub assigned_shifts: Vec<Shift>,
}
```

### `#[previous_element_shadow_variable]`

For list variables — automatically tracks the previous element in the list.

```rust
#[previous_element_shadow_variable(source_variable = "stops")]
pub previous_stop: Option<Stop>,
```

### `#[next_element_shadow_variable]`

For list variables — automatically tracks the next element in the list.

```rust
#[next_element_shadow_variable(source_variable = "stops")]
pub next_stop: Option<Stop>,
```

## Requirements

- Must derive `Clone` and `Debug`
- Must have exactly one `#[planning_id]` field
- Must have at least one `#[planning_variable]` or list variable field

## See Also

- [Planning Solutions](../planning-solutions/) — The container that holds entities
- [Problem Facts](../problem-facts/) — Immutable input data
- [List Variables](../list-variables/) — Sequencing and routing variables
