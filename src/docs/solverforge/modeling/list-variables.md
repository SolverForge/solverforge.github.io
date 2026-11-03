---
title: "List Variables"
linkTitle: "List Variables"
weight: 40
description: >
  Ordered sequence variables for routing, sequencing, and scheduling problems.
---

**List variables** model problems where the solver must determine the **order** of elements in a sequence — not just which value is assigned, but what comes before and after. This is essential for vehicle routing (stop ordering), job shop scheduling (operation sequencing), and similar problems.

SolverForge uses owner-held lists for ordered assignments. Scalar variables
model one direct assignment and do not have a chained predecessor mode.

## When to Use List Variables

Use list variables when:

- The order of assignments matters (routes, sequences)
- Each element belongs to exactly one list
- The solver needs to optimize both assignment and ordering

Use scalar planning variables when:

- Only the assignment matters, not the order
- Multiple entities can share the same value

## Stock Representation

The canonical sequence is a `Vec<usize>` on the owner entity. The indices
refer to the solution collection named by `element_collection`. This
complete vehicle-routing model keeps each vehicle's load and distance as
shadow state, refreshed after every route change.

`src/domain/mod.rs`:

<!-- rust: crate=routes file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Vehicle, VehicleRoutePlan, Visit};
}
```

`src/domain/model.rs`. A location is an index into the plan's distance
matrix; location 0 is the depot:

<!-- rust: crate=routes file=src/domain/model.rs -->
```rust
use solverforge::prelude::*;

#[planning_entity]
pub struct Visit {
    #[planning_id]
    pub id: usize,
    pub location: usize,
    pub demand: i64,
    #[inverse_relation_shadow_variable(source_variable_name = "visits")]
    pub vehicle: Option<usize>,
    #[previous_element_shadow_variable(source_variable_name = "visits")]
    pub previous_stop: Option<usize>,
    #[next_element_shadow_variable(source_variable_name = "visits")]
    pub next_stop: Option<usize>,
}

#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    pub capacity: i64,
    #[planning_list_variable(element_collection = "visits")]
    pub visits: Vec<usize>,
    pub load: i64,
    pub distance: i64,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
#[shadow_variable_updates(
    list_owner = "vehicles",
    inverse_field = "vehicle",
    previous_field = "previous_stop",
    next_field = "next_stop",
    post_update_listener = "refresh_vehicle_totals"
)]
pub struct VehicleRoutePlan {
    pub distances: Vec<Vec<i64>>,
    #[planning_entity_collection]
    pub visits: Vec<Visit>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl VehicleRoutePlan {
    /// Recomputes one vehicle's load and its depot-to-depot distance.
    pub fn refresh_vehicle_totals(&mut self, vehicle_idx: usize) {
        let route = &self.vehicles[vehicle_idx].visits;
        let load = route.iter().map(|&visit| self.visits[visit].demand).sum();
        let mut distance = 0;
        let mut at = 0;
        for &visit in route {
            let next = self.visits[visit].location;
            distance += self.distances[at][next];
            at = next;
        }
        distance += self.distances[at][0];
        let vehicle = &mut self.vehicles[vehicle_idx];
        vehicle.load = load;
        vehicle.distance = distance;
    }
}
```

The list variable stores visit indices, not `Visit` structs. `Visit` is a
planning entity without planning variables only so its fields can carry the
shadow attributes; the solver assigns nothing on it. The shadow updates keep each visit's `vehicle`, `previous_stop` and `next_stop` in step
with the owner lists, and `post_update_listener` names a solution method the
score director calls with the owner index after each change, so constraints
can read `load` and `distance` from the vehicle itself.

`src/constraints.rs`:

<!-- rust: crate=routes file=src/constraints.rs -->
```rust
use solverforge::prelude::*;

use crate::domain::{Vehicle, VehicleRoutePlan, Visit};

pub fn define_constraints() -> impl ConstraintSet<VehicleRoutePlan, HardSoftScore> {
    type Streams = ConstraintFactory<VehicleRoutePlan, HardSoftScore>;

    (
        Streams::new()
            .for_each(VehicleRoutePlan::visits())
            .filter(|visit: &Visit| visit.vehicle.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned visit"),
        Streams::new()
            .for_each(VehicleRoutePlan::vehicles())
            .filter(|vehicle: &Vehicle| vehicle.load > vehicle.capacity)
            .penalize(hard_weight(|vehicle: &Vehicle| {
                HardSoftScore::of_hard(vehicle.load - vehicle.capacity)
            }))
            .named("Capacity"),
        Streams::new()
            .for_each(VehicleRoutePlan::vehicles())
            .penalize(|vehicle: &Vehicle| HardSoftScore::of_soft(vehicle.distance))
            .named("Distance"),
    )
}
```

This program scores a fixed plan: one vehicle of capacity 3 serves visits 0
and 1 (demand 2 each), and visit 2 is on no route. Its load and distance
start at zero; analysis refreshes them through the listener:

<!-- rust: crate=routes file=src/main.rs -->
```rust
mod constraints;
mod domain;

use domain::{Vehicle, VehicleRoutePlan, Visit};
use solverforge::Analyzable;

fn visit(id: usize, location: usize) -> Visit {
    Visit { id, location, demand: 2, vehicle: None, previous_stop: None, next_stop: None }
}

fn main() {
    let plan = VehicleRoutePlan {
        distances: vec![
            vec![0, 4, 5, 9],
            vec![4, 0, 3, 7],
            vec![5, 3, 0, 6],
            vec![9, 7, 6, 0],
        ],
        visits: vec![visit(0, 1), visit(1, 2), visit(2, 3)],
        vehicles: vec![Vehicle { id: 0, capacity: 3, visits: vec![0, 1], load: 0, distance: 0 }],
        score: None,
    };

    let analysis = plan.analyze();
    println!("score: {}", analysis.score);
    for constraint in &analysis.constraints {
        println!("{}: {} ({} matches)", constraint.name, constraint.score, constraint.match_count);
    }
}
```

`cargo run` prints:

<!-- rust: crate=routes output -->
```text
score: -2hard/-12soft
Unassigned visit: -1hard/0soft (1 matches)
Capacity: -1hard/0soft (1 matches)
Distance: 0hard/-12soft (1 matches)
```

The route depot → 1 → 2 → depot is 4 + 3 + 5 = 12, its load 4 exceeds the
capacity by 1, and visit 2 has no `vehicle`.

## Solution-Side Trait Bounds

Some list-variable helpers, distance meters, or route utilities need more from
the planning solution than the base `PlanningSolution` contract. Name that
extra trait with `solution_trait = "crate::routing::RouteContext"` on
`#[planning_list_variable]`; generated stock list helpers then require the
solution to implement it. Use `solution_trait` only when stock list-variable
helpers must see an explicit extra trait on the solution type.

## CVRP Route Profile

Stock CVRP route lists can use the built-in domain profile,
`domain = "cvrp"`. The profile makes the solution implement
`solverforge::cvrp::VrpSolution`, which hands each vehicle's
`solverforge::cvrp::ProblemData` (capacity, depot, demands, distance and
travel-time matrices, time windows) to the stock meters and hooks. A complete
model, `src/domain/model.rs` with the same `planning_model!` manifest as above:

<!-- rust: crate=cvrp-routes file=src/domain/model.rs -->
```rust
use solverforge::cvrp::{ProblemData, VrpSolution};
use solverforge::prelude::*;

#[problem_fact]
pub struct Visit {
    #[planning_id]
    pub id: usize,
}

#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    #[planning_list_variable(element_collection = "visits", domain = "cvrp")]
    pub visits: Vec<usize>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct VehicleRoutePlan {
    pub routing: ProblemData,
    #[problem_fact_collection]
    pub visits: Vec<Visit>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl VrpSolution for VehicleRoutePlan {
    fn vehicle_data(&self, _vehicle_idx: usize) -> Option<&ProblemData> {
        Some(&self.routing)
    }

    fn vehicle_visits(&self, vehicle_idx: usize) -> &[usize] {
        &self.vehicles[vehicle_idx].visits
    }

    fn vehicle_visits_mut(&mut self, vehicle_idx: usize) -> &mut Vec<usize> {
        &mut self.vehicles[vehicle_idx].visits
    }

    fn vehicle_count(&self) -> usize {
        self.vehicles.len()
    }
}
```

<!-- rust: crate=cvrp-routes file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Vehicle, VehicleRoutePlan, Visit};
}
```

<!-- rust: crate=cvrp-routes file=src/constraints.rs -->
```rust
use solverforge::prelude::*;

use crate::domain::{Vehicle, VehicleRoutePlan};

pub fn define_constraints() -> impl ConstraintSet<VehicleRoutePlan, HardSoftScore> {
    (
        ConstraintFactory::<VehicleRoutePlan, HardSoftScore>::new()
            .for_each(VehicleRoutePlan::vehicles())
            .penalize(|vehicle: &Vehicle| HardSoftScore::of_soft(vehicle.visits.len() as i64))
            .named("Route length"),
    )
}
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
construction and local search stay panic-free. `vehicle_data` returning
`None` for a vehicle is an initialization error: the stock route helpers
panic on it and the feasibility gates reject the route.

## Custom Route Construction Hooks

For non-CVRP route domains, or for a custom pruning policy, omit
`domain = "cvrp"` and name the hooks on `#[planning_list_variable]`:

| Attribute | Value |
| --- | --- |
| `solution_trait` | extra trait the solution implements, such as `crate::routing::RouteContext` |
| `route_hooks` | module path exporting `get`, `set`, `depot`, `distance`, and `feasible` |
| `savings_hooks` | module path exporting `depot`, `distance`, and `feasible` |
| `savings_metric_class_fn` | function grouping owners that share construction depot and distance behavior |

The hooks
receive the route owner, so heterogeneous fleets can score and check routes
against the correct depot, distance matrix, capacity, and time-window context.
Use `savings_metric_class_fn` when several owners share the same construction
depot and distance behavior. Clarke-Wright computes savings once per savings
metric class, while savings feasibility is still checked against the candidate
owners needed to admit routes and merges. Metric classes share distance behavior,
not a blanket feasibility policy. Interruption-time assignment of complete
buffered merges reuses the already verified class-wide (or all-owner)
feasibility evidence instead of calling `feasible` again or spending more
candidate budget. If that evidence cannot place the route set, construction
keeps its committed complete assignment. See
[Construction](/docs/solverforge/solver/construction/#clarke-wright-interruption-and-buffered-merges).
Route-local feasibility remains available to k-opt and route assignment through
`route_hooks`.

## Ownership and Precedence Hooks

List variables can also declare plain stock hooks for fixed ownership,
construction order, and precedence-aware sequencing. Each attribute names a
function:

| Attribute | Supplies |
| --- | --- |
| `element_owner_fn` | the owner an element is fixed to, if any |
| `construction_element_order_key` | the order list construction inserts elements in |
| `precedence_duration_fn` | each element's duration |
| `precedence_successors_fn` | each element's fixed successor arcs |

`element_owner_fn` returns `Some(owner_index)` when an element is fixed to one
list owner and `None` when the element is unrestricted. Construction,
Clarke-Wright, ruin/recreate, and owner-changing list neighborhoods consume the
same normalized owner relation, so an element fixed to a different owner is not
silently moved.

`construction_element_order_key` affects list construction only. Precedence
hooks expose element durations and fixed successor arcs to the stock
`ListPrecedenceMakespanConstraint` and `list_precedence_move_selector`; they do
not introduce a benchmark-specific adapter or a new public selector trait.

### Precedence Makespan Scoring

`ListPrecedenceMakespanConstraint` combines fixed successor arcs with the
adjacency arcs implied by each owner's list. On an acyclic graph, each element
starts after all its predecessors finish; the soft score is the negative of the
largest finish time. For example, operations with durations 2 and 3 linked by a
fixed successor arc have makespan 5 even when they occupy different owner lists.

The hard score penalizes missing or duplicate assignments, invalid list entries
or fixed successor IDs, and assignments that violate the optional expected-owner
relation. A cycle adds a hard penalty equal to the total element count and sets
the makespan contribution to zero; zero soft penalty alone does not mean the
schedule is valid. Construction-source validation still rejects malformed
sources before search; scoring invalid trial states is a separate concern.

During a list edit, the scorer compares the owner's old and new adjacency edges
and refreshes affected downstream timings. Unchanged edges remain in the graph,
so a trial and its undo do not require removing and rebuilding the entire route.
Use the director's paired before/after notifications for custom mutations; see
[Extension Contracts](/reference/extend-solver/#precedence-score-notifications).

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

Element streams can read those maintained shadows directly. Generated sources
for shadow-bearing `#[problem_fact_collection]` and
`#[planning_list_element_collection]` rows carry a change source rather than
remaining static. Before an owner edit, the director retracts its element rows
with their old shadows; after the edit it refreshes shadows and reinserts the
owner and its current elements. Elements that leave all lists have their
configured inverse, index, previous, and next fields cleared and are reinserted
as unassigned. Full shadow refresh clears those fields on every element before
visiting owners, so an unassigned element cannot retain stale topology.

`planning_model!` and `#[planning_solution]` generate the
`PlanningSolution::list_shadow_elements`, `clear_list_shadows`, and
`list_shadow_source` hooks for configured element-shadow writes, including
cascading updates. Hand-written solution implementations must supply the same
reporting contract when their owner updates write element rows. Custom moves
must pair before/after owner notifications for both edits and undo; changing
shadow fields behind the director bypasses incremental stream maintenance.

## Generated Runtime Surface

Generated list mutation helpers such as `list_len_static()`,
`element_count()`, and `assign_element()` are not part of the user-facing
model API. Keep application code on the public modeling,
constraint-stream, descriptor, solver, and configuration APIs instead of
calling hidden runtime operations directly.

The generated model publishes typed slot declarations to the runtime compiler.
The compiler validates access operations, distance/route/precedence bundles,
stable sources, and configured selector requirements once, then freezes the
result for the solve. Dynamic binding models declare the corresponding list
access and metadata capability bundles explicitly and enter the same graph.

For constraints over list-owner entities, start from the generated solution
source method and let the stream API preserve source ownership, as the
vehicle-routing constraints above do with `VehicleRoutePlan::vehicles()`.

## List Moves

The solver uses specialized moves for list variables:

| Move                | Description                                                        |
| ------------------- | ------------------------------------------------------------------ |
| `ListChangeMove`    | Move an element from one list to another (or within the same list) |
| `ListSwapMove`      | Swap two elements between or within lists                          |
| `ListPermuteMove`   | Permute a contiguous window inside one list                        |
| `ListReverseMove`   | Reverse a subsequence within a list                                |
| `SublistChangeMove` | Move a contiguous subsequence to another position                  |
| `SublistSwapMove`   | Swap two contiguous subsequences                                   |
| `KOptMove`          | K-opt style moves for routing problems                             |
| `ListRuinMove`      | Remove list elements and reinsert them (list ruin-and-recreate)    |
| precedence support  | Critical-path precedence repairs for list variables with precedence hooks |

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
