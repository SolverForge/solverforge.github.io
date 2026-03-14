---
title: "List Variables"
linkTitle: "List Variables"
weight: 40
description: >
  Ordered sequence variables for routing, sequencing, and scheduling problems.
---

**List variables** model problems where the solver must determine the **order** of elements in a sequence — not just which value is assigned, but what comes before and after. This is essential for vehicle routing (stop ordering), job shop scheduling (operation sequencing), and similar problems.

## When to Use List Variables

Use list variables when:
- The order of assignments matters (routes, sequences)
- Each element belongs to exactly one list
- The solver needs to optimize both assignment and ordering

Use basic planning variables when:
- Only the assignment matters, not the order
- Multiple entities can share the same value

## The `ListVariableSolution` Trait

List variable solutions implement `ListVariableSolution` to define the relationship between lists and their elements.

```rust
use solverforge::prelude::*;

#[problem_fact]
#[derive(Clone, Debug)]
pub struct Stop {
    #[planning_id]
    pub id: i64,
    pub location: Location,
    pub demand: i32,
}

#[planning_entity]
#[derive(Clone, Debug)]
pub struct Vehicle {
    #[planning_id]
    pub id: i64,
    pub capacity: i32,
    pub depot: Location,
    #[planning_list_variable]
    pub stops: Vec<Stop>,
}

#[planning_solution]
#[derive(Clone, Debug)]
pub struct VehicleRoutePlan {
    #[problem_fact_collection]
    pub stops: Vec<Stop>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

## Shadow Variables for Lists

List variables support shadow variables that automatically track predecessor and successor relationships:

```rust
#[problem_fact]
#[derive(Clone, Debug)]
pub struct Stop {
    #[planning_id]
    pub id: i64,

    #[previous_element_shadow_variable(source_variable = "stops")]
    pub previous_stop: Option<Stop>,

    #[next_element_shadow_variable(source_variable = "stops")]
    pub next_stop: Option<Stop>,

    #[inverse_relation_shadow_variable(source_variable = "stops")]
    pub vehicle: Option<Vehicle>,
}
```

These shadow variables are maintained automatically as the solver moves elements between lists and reorders them.

## List Moves

The solver uses specialized moves for list variables:

| Move | Description |
|------|-------------|
| `ListChangeMove` | Move an element from one list to another (or within the same list) |
| `ListSwapMove` | Swap two elements between or within lists |
| `ListReverseMove` | Reverse a subsequence within a list |
| `SubListChangeMove` | Move a contiguous subsequence to another position |
| `SubListSwapMove` | Swap two contiguous subsequences |
| `KOptMove` | K-opt style moves for routing problems |
| `RuinMove` | Remove elements and reinsert them (ruin-and-recreate) |

## Example: Vehicle Routing

```rust
fn define_constraints(factory: &ConstraintFactory<VehicleRoutePlan>) -> Vec<Constraint<VehicleRoutePlan>> {
    vec![
        // Hard: don't exceed vehicle capacity
        factory.for_each::<Vehicle>()
            .filter(|v| v.total_demand() > v.capacity)
            .penalize_hard_with("Capacity", |v| v.total_demand() - v.capacity)
            .as_constraint(),

        // Soft: minimize total driving distance
        factory.for_each::<Vehicle>()
            .penalize_soft_with("Distance", |v| v.total_distance())
            .as_constraint(),
    ]
}
```

## See Also

- [Moves](/docs/solverforge/solver/moves/) — Move types including list-specific moves
- [Planning Entities](../planning-entities/) — Shadow variable attributes
