---
title: "Problem Facts"
linkTitle: "Problem Facts"
weight: 30
description: >
  Immutable input data that constraints reference but the solver doesn't modify.
---

A **problem fact** is immutable input data. The solver reads problem facts when
evaluating constraints but never modifies them. Examples include employees,
rooms, timeslots, and vehicle visits.

## The `#[problem_fact]` Macro

```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub id: usize,
    pub name: String,
    pub skills: Vec<String>,
}

#[problem_fact]
pub struct Timeslot {
    #[planning_id]
    pub id: usize,
    pub day_of_week: String,
    pub start_time: String,
    pub end_time: String,
}
```

## Field Attributes

### `#[planning_id]`

Provides stable identity for the fact. This is recommended whenever the fact is
referenced by a planning variable or appears in analysis output.

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
for a planning variable:

```rust
#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,

    #[planning_variable(value_range = "employees", allows_unassigned = true)]
    pub employee_id: Option<usize>,
}

#[planning_solution]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
}
```

## Requirements

- Must be a named Rust struct

The macro provides the standard derives and trait impls automatically.

## See Also

- [Planning Entities](../planning-entities/) — Mutable structs with planning variables
- [Planning Solutions](../planning-solutions/) — The container struct
