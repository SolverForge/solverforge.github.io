---
title: "Problem Facts"
linkTitle: "Problem Facts"
weight: 30
description: >
  Immutable input data and derived list-element shadow state used by constraints.
---

A **problem fact** supplies immutable input data. The solver reads those inputs
when evaluating constraints. Examples include employees,
rooms, timeslots, and vehicle visits.

List elements may also carry configured derived shadows such as owner, index,
previous, or next. Those fields are maintained by the score director, not
independent planning decisions. Generated sources for such collections receive
incremental element notifications when owner lists change; ordinary fact
collections remain static. See [List Variables](/docs/solverforge/modeling/list-variables/#shadow-updates).

## The `#[problem_fact]` Macro

The examples on this page come from the model on
[Domain Modeling](/docs/solverforge/modeling/), `src/domain/employee.rs`:

<!-- rust: crate=modeling excerpt -->
```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub id: usize,
    pub name: String,
    pub skills: Vec<String>,
}
```

## Field Attributes

### `#[planning_id]`

Provides stable identity for the fact. This is recommended whenever the fact is
referenced by a planning variable or appears in analysis output.

<!-- rust: crate=modeling excerpt -->
```rust
#[planning_id]
pub id: usize,
```

## When to Use Problem Facts vs Planning Entities

| | Problem Fact | Planning Entity |
|---|---|---|
| **Modified by solver?** | No | Yes |
| **Has planning variables?** | No | Yes |
| **Example** | `Employee`, `Room`, `Timeslot` | `Shift`, `Lesson`, `Visit` |
| **Role** | Input data / possible values | Things being assigned |

A common pattern is to use a problem-fact collection as the named value range
for a planning variable. `value_range_provider = "employees"` names the
`Schedule::employees` collection, and `employee_idx` stores a position in it:

<!-- rust: crate=modeling excerpt -->
```rust
#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub required_skill: String,

    #[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
    pub employee_idx: Option<usize>,
}
```

## Requirements

- Must be a named Rust struct

The macro provides the standard derives and trait impls automatically.

## See Also

- [Planning Entities](/docs/solverforge/modeling/planning-entities/) — Mutable structs with planning variables
- [Planning Solutions](/docs/solverforge/modeling/planning-solutions/) — The container struct
