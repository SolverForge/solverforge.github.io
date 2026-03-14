---
title: "Problem Facts"
linkTitle: "Problem Facts"
weight: 30
description: >
  Immutable input data that constraints reference but the solver doesn't modify.
---

A **problem fact** is an immutable struct that represents input data. The solver reads problem facts when evaluating constraints but never modifies them. Examples include employees, timeslots, rooms, and skills.

## The `#[problem_fact]` Macro

```rust
use solverforge::prelude::*;

#[problem_fact]
#[derive(Clone, Debug)]
pub struct Employee {
    #[planning_id]
    pub id: i64,
    pub name: String,
    pub skills: Vec<String>,
}

#[problem_fact]
#[derive(Clone, Debug)]
pub struct Timeslot {
    #[planning_id]
    pub id: i64,
    pub day_of_week: String,
    pub start_time: String,
    pub end_time: String,
}
```

## Field Attributes

### `#[planning_id]`

Uniquely identifies the problem fact. Required.

```rust
#[planning_id]
pub id: i64,
```

## When to Use Problem Facts vs Planning Entities

| | Problem Fact | Planning Entity |
|---|---|---|
| **Modified by solver?** | No | Yes |
| **Has planning variables?** | No | Yes |
| **Example** | `Employee`, `Room`, `Timeslot` | `Shift`, `Lesson`, `Visit` |
| **Role** | Input data / possible values | Things being assigned |

A common pattern: problem facts serve as the value range for planning variables.

```rust
#[planning_solution]
pub struct Schedule {
    #[problem_fact_collection]
    #[value_range_provider]       // Employees are possible values...
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,       // ...assigned to shift.employee
}
```

## Requirements

- Must derive `Clone` and `Debug`
- Must have exactly one `#[planning_id]` field

## See Also

- [Planning Entities](../planning-entities/) — Mutable structs with planning variables
- [Planning Solutions](../planning-solutions/) — The container struct
