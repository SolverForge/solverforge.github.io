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

## Stock Representation

In the current stock runtime, a list variable is represented as `Vec<usize>` on
the owner entity. The indices refer to a named collection on the planning
solution.

```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Visit {
    #[planning_id]
    pub id: usize,
    pub location: Location,
    pub demand: i32,
}

#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    pub capacity: i32,
    pub depot: Location,
    #[planning_list_variable(element_collection = "visits")]
    pub visits: Vec<usize>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct VehicleRoutePlan {
    #[problem_fact_collection]
    pub visits: Vec<Visit>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

The list variable stores visit indices, not `Visit` structs directly. This keeps
move generation and list manipulation aligned with the stock `0.8.5` runtime.

## Solution-Side Trait Bounds

Some list-variable helpers, distance meters, or route utilities need more from
the planning solution than the base `PlanningSolution` contract. In `0.8.2`,
`#[planning_list_variable]` can express that directly:

```rust
#[planning_list_variable(
    element_collection = "visits",
    solution_trait = "crate::routing::RouteContext"
)]
pub visits: Vec<usize>,
```

Use `solution_trait` only when stock list-variable helpers must see an explicit
extra trait on the solution type.

## Shadow Updates

Advanced predecessor, successor, inverse, and aggregate updates are configured
on the planning solution with `#[shadow_variable_updates(...)]` plus matching
shadow fields on the relevant entity types.

Stock list solving does **not** require shadow updates. Add them only when your
domain model needs derived state such as previous/next pointers or per-route
aggregates.

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

## Example: Vehicle Routing Constraint

```rust
fn define_constraints() -> impl ConstraintSet<VehicleRoutePlan, HardSoftScore> {
    use VehicleRoutePlanConstraintStreams;

    let factory = ConstraintFactory::<VehicleRoutePlan, HardSoftScore>::new();

    (
        factory.vehicles()
            .filter(|v| v.total_demand() > v.capacity)
            .penalize_hard_with(|v: &Vehicle| {
                HardSoftScore::of_hard((v.total_demand() - v.capacity) as i64)
            })
            .named("Capacity"),

        factory.vehicles()
            .penalize_with(|v: &Vehicle| HardSoftScore::of_soft(v.total_distance()))
            .named("Distance"),
    )
}
```

## Nearby and K-Opt Search

List-heavy problems often use nearby selectors or k-opt search. In config-driven
solving, that is expressed through `move_selector` variants such as:

- `nearby_list_change_move_selector`
- `nearby_list_swap_move_selector`
- `k_opt_move_selector`
- `list_ruin_move_selector`

## See Also

- [Moves](/docs/solverforge/solver/moves/) — Move types including list-specific moves
- [Planning Entities](../planning-entities/) — Shadow variable attributes
