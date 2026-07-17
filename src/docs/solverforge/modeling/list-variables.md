---
title: "List Variables"
linkTitle: "List Variables"
weight: 40
description: >
  Ordered sequence variables for routing, sequencing, and scheduling problems.
---

**List variables** model problems where the solver must determine the **order** of elements in a sequence — not just which value is assigned, but what comes before and after. This is essential for vehicle routing (stop ordering), job shop scheduling (operation sequencing), and similar problems.

SolverForge 0.19 uses this owner-held list as the sole planning representation
for ordered assignments. Scalar variables still model one direct assignment;
they no longer have a chained predecessor mode.

## When to Use List Variables

Use list variables when:

- The order of assignments matters (routes, sequences)
- Each element belongs to exactly one list
- The solver needs to optimize both assignment and ordering

Use scalar planning variables when:

- Only the assignment matters, not the order
- Multiple entities can share the same value

## Stock Representation

In the current stock runtime, the canonical sequence is represented as
`Vec<usize>` on the owner entity. The indices refer to a named collection on
the planning solution.

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
move generation and list manipulation aligned with the stock runtime and its
shared `RuntimeModel`-based construction path.

## Solution-Side Trait Bounds

Some list-variable helpers, distance meters, or route utilities need more from
the planning solution than the base `PlanningSolution` contract. The current
runtime lets `#[planning_list_variable]` express that directly:

```rust
#[planning_list_variable(
    element_collection = "visits",
    solution_trait = "crate::routing::RouteContext"
)]
pub visits: Vec<usize>,
```

Use `solution_trait` only when stock list-variable helpers must see an explicit
extra trait on the solution type.

## CVRP Route Profile

Stock CVRP route lists can use the built-in domain profile:

```rust
#[planning_list_variable(
    element_collection = "visits",
    domain = "cvrp"
)]
pub visits: Vec<usize>,
```

The profile expands to `solverforge::cvrp::VrpSolution`, the stock
`MatrixDistanceMeter` and `MatrixIntraDistanceMeter`, `route_hooks`,
`savings_hooks`, and `savings_metric_class`. Route-local phases such as k-opt
use strict stock CVRP feasibility: structural validity, capacity, and time
windows. Clarke-Wright construction uses relaxed savings feasibility: malformed
owners, data, or visit IDs are rejected, but scoreable capacity and time-window
violations can still be assigned and compared against unassigned work.
Unreachable travel-time legs remain strict route-local infeasibilities, and
unreachable or malformed distance entries become large finite costs so
construction and local search stay panic-free.

## Custom Route Construction Hooks

For non-CVRP route domains, or for a custom pruning policy, omit
`domain = "cvrp"` and wire explicit route-local and savings hooks:

```rust
#[planning_list_variable(
    element_collection = "visits",
    solution_trait = "crate::routing::RouteContext",
    route_hooks = "crate::routing::route_hooks",
    savings_hooks = "crate::routing::savings_hooks",
    savings_metric_class_fn = "crate::routing::savings_metric_class"
)]
pub visits: Vec<usize>,
```

`route_hooks` must export `get`, `set`, `depot`, `distance`, and `feasible`.
`savings_hooks` must export `depot`, `distance`, and `feasible`. The hooks
receive the route owner, so heterogeneous fleets can score and check routes
against the correct depot, distance matrix, capacity, and time-window context.
Use `savings_metric_class_fn` when several owners share the same construction
depot and distance behavior. Clarke-Wright computes savings once per savings
metric class, then still asks the savings `feasible` hook for each candidate
owner before assigning routes. Route-local feasibility remains available to
k-opt and route assignment through `route_hooks`.

## Ownership and Precedence Hooks

List variables can also declare plain stock hooks for fixed ownership,
construction order, and precedence-aware sequencing:

```rust
#[planning_list_variable(
    element_collection = "operations",
    element_owner_fn = "operation_owner",
    construction_element_order_key = "operation_construction_order",
    precedence_duration_fn = "operation_duration",
    precedence_successors_fn = "operation_successors"
)]
pub operations: Vec<usize>,
```

`element_owner_fn` returns `Some(owner_index)` when an element is fixed to one
list owner and `None` when the element is unrestricted. Construction,
Clarke-Wright, ruin/recreate, and owner-changing list neighborhoods consume the
same normalized owner relation, so an element fixed to a different owner is not
silently moved.

`construction_element_order_key` affects list construction only. Precedence
hooks expose element durations and fixed successor arcs to the stock
`ListPrecedenceMakespanConstraint` and `list_precedence_move_selector`; they do
not introduce a benchmark-specific adapter or a new public selector trait.

## Stable Element Source Identity

Generated `usize` list models bind declared elements by a stable source key.
Construction uses that identity for declaration order, ownership, precedence,
candidate tracing, and static/dynamic parity; it does not fall back to payload
equality or hashing. Duplicate declarations, unknown or duplicate assigned
values, and inconsistent precedence successors fail when the reached
construction node binds its source.

If you build specialized list phases through lower-level APIs, supply the
required `element_source_key` explicitly. Multiple phases targeting the same
slot reuse the frozen declaration binding but refresh current assignments before
each phase, so later construction cannot reinsert work committed earlier.

## Shadow Updates

Previous, next, index, inverse, and aggregate views are derived from the owner
list. Configure them on the planning solution with
`#[shadow_variable_updates(...)]` plus matching shadow fields on the relevant
entity types. For example, an element field declared as
`#[index_shadow_variable(source_variable_name = "visits")]` with type
`Option<usize>` is maintained by
`#[shadow_variable_updates(list_owner = "routes", index_field = "index")]` on
the planning solution.

Stock list solving does **not** require shadow updates. Add them only when your
domain model needs derived state such as owner/index lookup, previous/next
pointers, or per-route aggregates. When you do configure them, the canonical
`ScoreDirector` invokes
those solution hooks automatically.

## Generated Runtime Surface

Generated public list mutation helpers such as `list_len_static()`,
`element_count()`, and `assign_element()` are no longer part of the user-facing
model API in the current release. Keep application code on the public modeling,
constraint-stream, descriptor, solver, and configuration APIs instead of
calling hidden runtime operations directly.

The generated model publishes typed slot declarations to the runtime compiler.
The compiler validates access operations, distance/route/precedence bundles,
stable sources, and configured selector requirements once, then freezes the
result for the solve. Dynamic binding models declare the corresponding list
access and metadata capability bundles explicitly and enter the same graph.

For constraints over list-owner entities, start from the generated solution
source method and let the stream API preserve source ownership. The vehicle
routing example below uses `VehicleRoutePlan::vehicles()` for that reason.

## List Moves

The solver uses specialized moves for list variables:

| Move                | Description                                                        |
| ------------------- | ------------------------------------------------------------------ |
| `ListChangeMove`    | Move an element from one list to another (or within the same list) |
| `ListSwapMove`      | Swap two elements between or within lists                          |
| `ListPermuteMove`   | Permute a contiguous window inside one list                        |
| `ListReverseMove`   | Reverse a subsequence within a list                                |
| `SubListChangeMove` | Move a contiguous subsequence to another position                  |
| `SubListSwapMove`   | Swap two contiguous subsequences                                   |
| `KOptMove`          | K-opt style moves for routing problems                             |
| `RuinMove`          | Remove elements and reinsert them (ruin-and-recreate)              |
| precedence support  | Critical-path precedence repairs for list variables with precedence hooks |

## Example: Vehicle Routing Constraint

```rust
fn define_constraints() -> impl ConstraintSet<VehicleRoutePlan, HardSoftScore> {
    type Streams = ConstraintFactory<VehicleRoutePlan, HardSoftScore>;

    (
        Streams::new()
            .for_each(VehicleRoutePlan::vehicles())
            .filter(|v| v.total_demand() > v.capacity)
            .penalize(hard_weight(|v: &Vehicle| {
                HardSoftScore::of_hard((v.total_demand() - v.capacity) as i64)
            }))
            .named("Capacity"),

        Streams::new()
            .for_each(VehicleRoutePlan::vehicles())
            .penalize(|v: &Vehicle| HardSoftScore::of_soft(v.total_distance()))
            .named("Distance"),
    )
}
```

## Nearby and K-Opt Search

List-heavy problems often use nearby selectors or k-opt search. In config-driven
solving, that is expressed through `move_selector` variants such as:

- `nearby_list_change_move_selector`
- `nearby_list_swap_move_selector`
- `list_permute_move_selector`
- `list_precedence_move_selector`
- `k_opt_move_selector`
- `list_ruin_move_selector`

For ruin-and-recreate search, the current runtime samples only non-empty list
owners for the ruin step. That keeps a vehicle with no visits, or a machine
with no queued jobs, from using a local-search attempt that cannot remove
anything.

## See Also

- [Moves](/docs/solverforge/solver/moves/) — Move types including list-specific moves
- [Planning Entities](/docs/solverforge/modeling/planning-entities/) — Shadow variable attributes
- [SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/) — List-variable vehicle routing with road-network scoring
- [SolverForge FSR Use Case](/docs/getting-started/solverforge-fsr-use-case/) — List-variable technician routing with skills, parts, and route geometry
