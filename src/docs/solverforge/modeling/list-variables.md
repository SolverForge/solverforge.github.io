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
`solverforge::cvrp::ProblemData` (capacity, depot, demands, time windows,
service durations, and a route metric) to the stock meters and hooks. List
values are location indexes into that data; location `depot` is the depot.

`ProblemData` reads leg distances and travel times from its `metric`, whose
type the solution names as `VrpSolution::Metric`. Both stock metrics implement
`solverforge::cvrp::RouteMetric`:

| Metric | Legs | Memory |
| --- | --- | --- |
| `DenseMatrix::new(distances, travel_times)` | supplied `[from][to]` tables, such as road-network matrices | quadratic in the locations |
| `EuclideanMetric::new(coordinates, speed)` | straight-line length between `(x, y)` points, rounded half away from zero (TSPLIB `EUC_2D`); travel time is length / speed, rounded the same way | linear in the locations |

`UNREACHABLE` or a negative leg value marks a leg that cannot be traversed,
and a location outside the metric (past a `DenseMatrix` row, or without a
coordinate) makes every route through it structurally invalid.
`EuclideanMetric::new` panics on a speed that is not finite and positive or on
a coordinate that is not finite. A custom metric implements `distance`,
`travel_time`, and `covers`; its provided `nearest` ranks every pair, and
`EuclideanMetric` overrides it with a spatial grid.

A complete model on `EuclideanMetric`, `src/domain/model.rs`:

<!-- rust: crate=cvrp-routes file=src/domain/model.rs -->
```rust
use solverforge::cvrp::{EuclideanMetric, ProblemData, VrpSolution};
use solverforge::prelude::*;

#[problem_fact]
pub struct Stop {
    #[planning_id]
    pub id: usize,
}

#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    #[planning_list_variable(element_collection = "stop_locations", domain = "cvrp")]
    pub visits: Vec<usize>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct VehicleRoutePlan {
    pub routing: ProblemData<EuclideanMetric>,
    #[problem_fact_collection]
    pub stops: Vec<Stop>,
    #[planning_list_element_collection(owner = "vehicles")]
    pub stop_locations: Vec<usize>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl VrpSolution for VehicleRoutePlan {
    type Metric = EuclideanMetric;

    fn vehicle_data(&self, _vehicle_idx: usize) -> Option<&ProblemData<EuclideanMetric>> {
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

`stop_locations` holds the location of every stop the vehicles must visit;
each `Stop` fact carries the same location as its `id`. A model on supplied
tables writes `ProblemData<DenseMatrix>` (the default type parameter, so plain
`ProblemData` also names it), `type Metric = DenseMatrix;`, and
`metric: DenseMatrix::new(distances, travel_times)`.

`src/domain/mod.rs`:

<!-- rust: crate=cvrp-routes file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Stop, Vehicle, VehicleRoutePlan};
}
```

`src/constraints.rs` penalizes a stop that no route visits:

<!-- rust: crate=cvrp-routes file=src/constraints.rs -->
```rust
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;

use crate::domain::{Stop, Vehicle, VehicleRoutePlan};

pub fn define_constraints() -> impl ConstraintSet<VehicleRoutePlan, HardSoftScore> {
    type Streams = ConstraintFactory<VehicleRoutePlan, HardSoftScore>;

    (Streams::new()
        .for_each(VehicleRoutePlan::stops())
        .if_not_exists((
            Streams::new()
                .for_each(VehicleRoutePlan::vehicles())
                .flattened(|vehicle: &Vehicle| &vehicle.visits),
            equal_bi(|stop: &Stop| stop.id, |location: &usize| *location),
        ))
        .penalize(HardSoftScore::ONE_HARD)
        .named("Unrouted stop"),)
}
```

This program builds routes for two vehicles with one Clarke-Wright
construction phase. `savings_neighbors = 2` scores a pair of stops only when
one is among the other's two nearest, which the profile asks the metric for:

<!-- rust: crate=cvrp-routes file=src/main.rs -->
```rust
mod constraints;
mod domain;

use domain::{Stop, Vehicle, VehicleRoutePlan};
use solverforge::cvrp::{EuclideanMetric, ProblemData};
use solverforge::SolverConfig;

fn main() {
    // Location 0 is the depot; stops 1-3 lie west of it, stops 4-6 east.
    let coordinates = vec![
        (0.0, 0.0),
        (-3.0, 1.0),
        (-4.0, -1.0),
        (-6.0, 0.0),
        (3.0, 1.0),
        (4.0, -1.0),
        (6.0, 0.0),
    ];
    let locations = coordinates.len();
    let plan = VehicleRoutePlan {
        routing: ProblemData {
            capacity: 3,
            depot: 0,
            demands: vec![0, 1, 1, 1, 1, 1, 1],
            metric: EuclideanMetric::new(coordinates, 1.0),
            time_windows: vec![(0, i64::MAX); locations],
            service_durations: vec![0; locations],
            vehicle_departure_time: 0,
        },
        stops: (1..locations).map(|id| Stop { id }).collect(),
        stop_locations: (1..locations).collect(),
        vehicles: (0..2).map(|id| Vehicle { id, visits: Vec::new() }).collect(),
        score: None,
    };

    let config = SolverConfig::from_toml_str(
        r#"
        [[phases]]
        type = "construction_heuristic"
        construction_heuristic_type = "list_clarke_wright"
        savings_neighbors = 2
        "#,
    )
    .expect("config parses");

    let solved = plan.solve_with_config(config).expect("construction solves");
    for vehicle in &solved.vehicles {
        println!("vehicle {}: {:?}", vehicle.id, vehicle.visits);
    }
    println!("score: {}", solved.score.expect("solved plan is scored"));
}
```

`cargo run` prints:

<!-- rust: crate=cvrp-routes output -->
```text
vehicle 0: [4, 6, 5]
vehicle 1: [1, 3, 2]
score: 0hard/0soft
```

Each vehicle serves one side of the depot. For models past roughly 10,000
stops, pair `EuclideanMetric` with
[bounded savings](/docs/solverforge/solver/construction/#bounded-clarke-wright-savings):
a dense matrix alone needs 16 bytes per location pair, and unbounded savings
32 bytes per stop pair.

The profile expands to `solverforge::cvrp::VrpSolution`, the stock
`MatrixDistanceMeter` and `MatrixIntraDistanceMeter`, `route_hooks`,
`savings_hooks`, `savings_metric_class`, and `savings_neighbors`. Route-local
phases such as k-opt use strict stock CVRP feasibility: structural validity,
capacity, and time windows. Clarke-Wright construction uses relaxed savings
feasibility: malformed owners, data, or visit IDs are rejected, but scoreable
capacity and time-window violations can still be assigned and compared against
unassigned work. Unreachable travel-time legs remain strict route-local
infeasibilities, and unreachable or undefined distance legs become large finite
costs so construction and local search stay panic-free. `vehicle_data`
returning `None` for a vehicle is an initialization error: the stock route
helpers panic on it and the feasibility gates reject the route.

## Custom Route Construction Hooks

For non-CVRP route domains, or for a custom pruning policy, omit
`domain = "cvrp"` and name the hooks on `#[planning_list_variable]`:

| Attribute | Value |
| --- | --- |
| `solution_trait` | extra trait the solution implements, such as `crate::routing::RouteContext` |
| `route_hooks` | module path exporting `get`, `set`, `depot`, `distance`, and `feasible` |
| `savings_hooks` | module path exporting `depot`, `distance`, and `feasible` |
| `savings_metric_class_fn` | function grouping owners that share construction depot and distance behavior |
| `savings_neighbors_fn` | function appending each element's nearest other elements, for bounded Clarke-Wright savings |

A `savings_neighbors_fn` has the shape
`fn(&Solution, owner: usize, values: &[usize], k: usize, out: &mut Vec<usize>)`:
for each of `values` in order it appends the indexes into `values` of its
`min(k, values.len() - 1)` nearest other values, nearest first. A phase that
sets `savings_neighbors` on a list variable without this hook fails the solve
before construction starts.

The hooks
receive the route owner, so heterogeneous fleets can score and check routes
against the correct depot, distances, capacity, and time-window context.
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
| `element_group_fn` | the members of each element's group; see [Element Groups](#element-groups) |

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

## Element Groups

Some elements must travel together: the pick-up and drop-off of one ride, or
every stop of a multi-stop job. Name a hook with
`element_group_fn` on `#[planning_list_variable]`. It has the signature
`fn(&Solution, usize, &mut Vec<usize>)` and appends the members of the
element's group, in order and including the element, or nothing for an element
without a group. Only groups of two or more members count, and every member
must report the same group; a conflicting answer panics. Groups are read once
per step and once per construction phase.

`src/domain/mod.rs`:

<!-- rust: crate=rides file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Rides, Stop, Vehicle};
}
```

`src/domain/model.rs`. Ride `r` is stops `2r` (pick-up) and `2r + 1`
(drop-off); a stop without a ride is a single stop:

<!-- rust: crate=rides file=src/domain/model.rs -->
```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Stop {
    #[planning_id]
    pub id: usize,
    pub ride: Option<usize>,
    pub pickup: bool,
    pub location: i64,
    pub vehicle: Option<usize>,
    pub index: Option<usize>,
    pub previous: Option<usize>,
}

#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    #[planning_list_variable(element_collection = "stops", element_group_fn = "ride_stops")]
    pub stops: Vec<usize>,
}

/// A ride's pick-up and drop-off, in that order; a single stop has no group.
pub(super) fn ride_stops(plan: &super::Rides, stop: usize, members: &mut Vec<usize>) {
    if let Some(ride) = plan.stops[stop].ride {
        members.extend([2 * ride, 2 * ride + 1]);
    }
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
#[shadow_variable_updates(
    list_owner = "vehicles",
    inverse_field = "vehicle",
    index_field = "index",
    previous_field = "previous"
)]
pub struct Rides {
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[problem_fact_collection]
    pub stops: Vec<Stop>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

A group's members always share one owner. Their order within the route is
the model's business: a single-element move may reorder a grouped stop inside
its route, so the constraints below penalize a drop-off before its pick-up.

`src/constraints.rs`:

<!-- rust: crate=rides file=src/constraints.rs -->
```rust
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;

use crate::domain::{Rides, Stop};

pub fn define_constraints() -> impl ConstraintSet<Rides, HardSoftScore> {
    type Streams = ConstraintFactory<Rides, HardSoftScore>;

    (
        Streams::new()
            .for_each(Rides::stops())
            .filter(|stop: &Stop| stop.vehicle.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned stop"),
        Streams::new()
            .for_each(Rides::stops())
            .filter(|stop: &Stop| stop.pickup)
            .join((
                Streams::new().for_each(Rides::stops()),
                equal_bi(|pickup: &Stop| pickup.ride, |stop: &Stop| stop.ride),
            ))
            .filter(|pickup: &Stop, dropoff: &Stop| !dropoff.pickup && pickup.index > dropoff.index)
            .penalize(HardSoftScore::ONE_HARD)
            .named("Drop-off before pick-up"),
        Streams::new()
            .for_each(Rides::stops())
            .join((
                Streams::new().for_each(Rides::stops()),
                equal_bi(|stop: &Stop| stop.previous, |before: &Stop| Some(before.id)),
            ))
            .penalize(|stop: &Stop, before: &Stop| {
                HardSoftScore::of_soft((stop.location - before.location).abs())
            })
            .named("Driving"),
        Streams::new()
            .for_each(Rides::stops())
            .filter(|stop: &Stop| stop.vehicle.is_some() && stop.previous.is_none())
            .penalize(|stop: &Stop| HardSoftScore::of_soft(stop.location.abs()))
            .named("Leaving the depot"),
    )
}
```

`src/main.rs` solves three rides and one single stop on a line with the
default policy, which constructs a grouped list with `list_cheapest_insertion`
and searches it with group moves among the other list families:

<!-- rust: crate=rides file=src/main.rs -->
```rust
mod constraints;
mod domain;

use domain::{Rides, Stop, Vehicle};
use solverforge::SolverConfig;

fn stop(id: usize, ride: Option<usize>, location: i64) -> Stop {
    let pickup = ride.is_some() && id % 2 == 0;
    Stop { id, ride, pickup, location, vehicle: None, index: None, previous: None }
}

const CONFIG: &str = r#"
random_seed = 7
move_thread_count = "none"

[termination]
step_count_limit = 200
"#;

fn main() {
    let mut stops = Vec::new();
    for (ride, (from, to)) in [(5, 60), (70, 12), (33, 90)].into_iter().enumerate() {
        stops.push(stop(2 * ride, Some(ride), from));
        stops.push(stop(2 * ride + 1, Some(ride), to));
    }
    stops.push(stop(6, None, 25));
    let plan = Rides {
        vehicles: (0..2).map(|id| Vehicle { id, stops: Vec::new() }).collect(),
        stops,
        score: None,
    };

    let config = SolverConfig::from_toml_str(CONFIG).expect("config parses");
    let solved = plan.solve_with_config(config).expect("solve completes");
    println!("score {:?}", solved.score);
    for vehicle in &solved.vehicles {
        println!("vehicle {}: {:?}", vehicle.id, vehicle.stops);
    }
}
```

`cargo run` prints:

<!-- rust: crate=rides output -->
```text
score Some(HardSoftScore(0, -168))
vehicle 0: [0, 6, 4, 5, 2, 1, 3]
vehicle 1: []
```

Every ride rides one vehicle, pick-up first, with other stops between its
members: ride 2 (stops 4 and 5) sits inside ride 0, as a shared ride needs.

The stock list moves respect groups:

- `list_group_change_move_selector` moves a whole group to positions of one
  owner, its own included; `max_member_distance` caps the positions from one
  member to the next.
- `list_group_swap_move_selector` exchanges two groups of the same size on
  different owners, member slot for member slot.
- `list_ruin_move_selector` ruins whole groups and recreates them in one pass,
  each group jointly at its best placement given the groups placed before it.
- `list_cheapest_insertion` and `list_regret_insertion` place a group as one
  unit. A member is never placed alone, and members already assigned pin the
  rest of their group to that owner.
- The single-element list moves keep a grouped element on its owner, so they
  can reorder it within its route but never split a group.

A group moves only to an owner that every member allows under
`element_owner_fn` and that is not pinned. Placing a group of `m` members
jointly tries O(L^m) position tuples per owner; `max_member_distance` and
`max_group_owners` (an owner shortlist, by best contiguous fit) bound it. See
[List Move Selectors](/docs/solverforge/solver/list-move-selectors/#element-groups)
for the selectors and their defaults.

`element_group_fn` cannot be combined with precedence hooks, and
`list_round_robin`, `list_clarke_wright` and the global `first_fit` and
`cheapest_insertion` construction reject a list with groups, since they place
elements one at a time. A list without the hook compiles none of this.

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

### Cascading Shadows Across Lists

A cascading shadow is an element value computed from the element's previous
element in its list and from elements it waits on, which other owners' lists
may hold: a start time with precedence across machines, employees or
vehicles. Declare the field, the per-element compute and the dependencies on
`#[shadow_variable_updates]`, and SolverForge owns the ordering, propagation
and change reporting.

`src/domain/mod.rs`:

<!-- rust: crate=shop file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Machine, Shop, Task};
}
```

`src/domain/model.rs`. A task starts once the previous task on its machine and
the task it waits on have ended:

<!-- rust: crate=shop file=src/domain/model.rs -->
```rust
use solverforge::prelude::*;

#[planning_entity]
pub struct Machine {
    #[planning_id]
    pub id: usize,
    #[planning_list_variable(element_collection = "tasks")]
    pub tasks: Vec<usize>,
}

#[problem_fact]
pub struct Task {
    #[planning_id]
    pub id: usize,
    pub duration: i64,
    pub waits_on: Option<usize>,
    pub machine: Option<usize>,
    pub previous: Option<usize>,
    pub next: Option<usize>,
    pub start: Option<i64>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
#[shadow_variable_updates(
    list_owner = "machines",
    inverse_field = "machine",
    previous_field = "previous",
    next_field = "next",
    cascading_field = "start",
    cascading_compute = "compute_start",
    cascading_dependencies = "task_dependencies"
)]
pub struct Shop {
    #[planning_entity_collection]
    pub machines: Vec<Machine>,
    #[problem_fact_collection]
    pub tasks: Vec<Task>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl Shop {
    fn end(&self, task: usize) -> Option<i64> {
        let task = &self.tasks[task];
        task.start.map(|start| start + task.duration)
    }

    /// After the previous task on the machine and the task it waits on.
    pub fn compute_start(&self, task: usize) -> Option<i64> {
        let mut start = 0;
        if let Some(previous) = self.tasks[task].previous {
            start = start.max(self.end(previous)?);
        }
        if let Some(dependency) = self.tasks[task].waits_on {
            start = start.max(self.end(dependency)?);
        }
        Some(start)
    }

    pub fn task_dependencies(&self, task: usize) -> Option<usize> {
        self.tasks[task].waits_on
    }
}
```

- `cascading_field` names an `Option<_>` element field; its value type must
  implement `PartialEq`.
- `cascading_compute` names a solution method
  `fn(&self, element: usize) -> Option<_>`. It runs only for an element held
  by a list, after the previous element in that list and every dependency
  hold their final values for the move.
- `cascading_dependencies` (optional) names a solution method returning the
  elements `element` waits on, as any `IntoIterator<Item = usize>` (an
  `Option<usize>`, a slice, a `Vec`). Dependencies are problem facts; moves
  never change them, and a problem change that does is applied through a
  reset.
- `cascading_peers` (optional) names the elements computed together with
  `element`; see [Joint Groups](#joint-groups).
- `inverse_field`, `previous_field` and `next_field` are required.
  `cascading_listener`, `post_update_listener`, `entity_aggregate` and
  `entity_compute` cannot be combined with a cascading shadow: they run per
  changed owner and would not see the values a move changes in other owners'
  lists.

`src/constraints.rs` penalizes an unscheduled task and every task's end:

<!-- rust: crate=shop file=src/constraints.rs -->
```rust
use solverforge::prelude::*;

use crate::domain::{Shop, Task};

pub fn define_constraints() -> impl ConstraintSet<Shop, HardSoftScore> {
    type Streams = ConstraintFactory<Shop, HardSoftScore>;

    (
        Streams::new()
            .for_each(Shop::tasks())
            .filter(|task: &Task| task.start.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unscheduled task"),
        Streams::new()
            .for_each(Shop::tasks())
            .penalize(|task: &Task| {
                HardSoftScore::of_soft(task.start.map_or(0, |start| start + task.duration))
            })
            .named("Task end"),
    )
}
```

`src/main.rs` puts a long task on the saw in front of the cut, through the
same score-director notifications the solver sends for every move:

<!-- rust: crate=shop file=src/main.rs -->
```rust
mod constraints;
mod domain;

use constraints::define_constraints;
use domain::{Machine, Shop, Task};
use solverforge::ScoreDirector;

fn task(id: usize, duration: i64, waits_on: Option<usize>) -> Task {
    Task { id, duration, waits_on, machine: None, previous: None, next: None, start: None }
}

fn starts(shop: &Shop) -> Vec<Option<i64>> {
    shop.tasks.iter().map(|task| task.start).collect()
}

fn main() {
    // The saw cuts (task 0); the mill mills the cut part (task 1, which waits
    // on task 0), then drills (task 2). Task 3 is on no machine yet.
    let shop = Shop {
        machines: vec![
            Machine { id: 0, tasks: vec![0] },
            Machine { id: 1, tasks: vec![1, 2] },
        ],
        tasks: vec![task(0, 4, None), task(1, 3, Some(0)), task(2, 2, None), task(3, 10, None)],
        score: None,
    };

    let mut director = ScoreDirector::new(shop, define_constraints());
    println!("{} {:?}", director.calculate_score(), starts(director.working_solution()));

    // Put task 3 on the saw, in front of the cut.
    director.before_variable_changed(0, 0);
    director.working_solution_mut().machines[0].tasks.insert(0, 3);
    director.after_variable_changed(0, 0);
    println!("{} {:?}", director.calculate_score(), starts(director.working_solution()));
}
```

`cargo run` prints:

<!-- rust: crate=shop output -->
```text
-1hard/-20soft [Some(0), Some(4), Some(7), None]
0hard/-60soft [Some(10), Some(14), Some(17), Some(0)]
```

Changing the saw's list moved the milling and drilling on the mill: the
milling waits on the cut, which now ends at 14.

After each move the score director recomputes the downstream cone of the
changed elements in dependency order: each element once, after its inputs,
and only when an input changed, so propagation stops where a value is
unchanged. Every element whose value changes is rescored exactly once, and so
is every element whose owner, previous or next element changes (or whose
index changes, when `index_field` is configured); the other elements keep
their stream rows, so a change near the end of a long route rescores only
what it touches. An element in no list, or on a dependency cycle a move
creates (a task that waits on a task queued after it), is unset (`None`),
which constraints can penalize. Models without a cascading shadow compile
none of this into their move path.

### Joint Groups

Some elements in different lists must be timed together: a job that needs two
technicians starts when the later of them arrives, so each technician's visit
waits on the other's arrival. Declaring that as two dependencies would be a
cycle. Declare the visits peers with `cascading_peers` instead.

`src/domain/mod.rs`:

<!-- rust: crate=crew file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Crew, Technician, Visit};
}
```

`src/domain/model.rs`:

<!-- rust: crate=crew file=src/domain/model.rs -->
```rust
use solverforge::prelude::*;

#[planning_entity]
pub struct Technician {
    #[planning_id]
    pub id: usize,
    #[planning_list_variable(element_collection = "visits")]
    pub visits: Vec<usize>,
}

#[problem_fact]
pub struct Visit {
    #[planning_id]
    pub id: usize,
    pub duration: i64,
    /// The other visits of the same job, made by other technicians.
    pub partners: Vec<usize>,
    pub technician: Option<usize>,
    pub previous: Option<usize>,
    pub next: Option<usize>,
    pub start: Option<i64>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
#[shadow_variable_updates(
    list_owner = "technicians",
    inverse_field = "technician",
    previous_field = "previous",
    next_field = "next",
    cascading_field = "start",
    cascading_compute = "compute_start",
    cascading_peers = "visit_partners"
)]
pub struct Crew {
    #[planning_entity_collection]
    pub technicians: Vec<Technician>,
    #[problem_fact_collection]
    pub visits: Vec<Visit>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl Crew {
    /// When the technician can be at the visit: one unit of travel after the
    /// previous visit ends.
    fn arrival(&self, visit: usize) -> Option<i64> {
        match self.visits[visit].previous {
            Some(previous) => {
                let previous = &self.visits[previous];
                Some(previous.start? + previous.duration + 1)
            }
            None => Some(0),
        }
    }

    /// When the last assigned technician of the job arrives.
    pub fn compute_start(&self, visit: usize) -> Option<i64> {
        let mut start = self.arrival(visit)?;
        for &partner in &self.visits[visit].partners {
            if self.visits[partner].technician.is_some() {
                start = start.max(self.arrival(partner)?);
            }
        }
        Some(start)
    }

    pub fn visit_partners(&self, visit: usize) -> Vec<usize> {
        self.visits[visit].partners.clone()
    }
}
```

`src/constraints.rs`:

<!-- rust: crate=crew file=src/constraints.rs -->
```rust
use solverforge::prelude::*;

use crate::domain::{Crew, Visit};

pub fn define_constraints() -> impl ConstraintSet<Crew, HardSoftScore> {
    type Streams = ConstraintFactory<Crew, HardSoftScore>;

    (
        Streams::new()
            .for_each(Crew::visits())
            .filter(|visit: &Visit| visit.start.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unscheduled visit"),
        Streams::new()
            .for_each(Crew::visits())
            .penalize(|visit: &Visit| {
                HardSoftScore::of_soft(visit.start.map_or(0, |start| start + visit.duration))
            })
            .named("Visit end"),
    )
}
```

`src/main.rs` gives Ann a long visit before the joint one:

<!-- rust: crate=crew file=src/main.rs -->
```rust
mod constraints;
mod domain;

use constraints::define_constraints;
use domain::{Crew, Technician, Visit};
use solverforge::ScoreDirector;

fn visit(id: usize, duration: i64, partners: &[usize]) -> Visit {
    Visit {
        id,
        duration,
        partners: partners.to_vec(),
        technician: None,
        previous: None,
        next: None,
        start: None,
    }
}

fn starts(crew: &Crew) -> Vec<Option<i64>> {
    crew.visits.iter().map(|visit| visit.start).collect()
}

fn main() {
    // Visits 2 and 3 are one job for two technicians. Ann makes visit 0, then
    // visit 2; Bob starts with visit 3. Visit 4 is on no route yet.
    let crew = Crew {
        technicians: vec![
            Technician { id: 0, visits: vec![0, 2] },
            Technician { id: 1, visits: vec![3, 1] },
        ],
        visits: vec![
            visit(0, 4, &[]),
            visit(1, 3, &[]),
            visit(2, 6, &[3]),
            visit(3, 6, &[2]),
            visit(4, 10, &[]),
        ],
        score: None,
    };

    let mut director = ScoreDirector::new(crew, define_constraints());
    director.calculate_score();
    println!("{:?}", starts(director.working_solution()));

    // Ann makes the long visit 4 first.
    director.before_variable_changed(0, 0);
    director.working_solution_mut().technicians[0].visits.insert(0, 4);
    director.after_variable_changed(0, 0);
    director.calculate_score();
    println!("{:?}", starts(director.working_solution()));
}
```

`cargo run` prints:

<!-- rust: crate=crew output -->
```text
[Some(0), Some(12), Some(5), Some(5), None]
[Some(11), Some(23), Some(16), Some(16), Some(0)]
```

Bob reaches the joint job at 0 but waits for Ann, who arrives at 5; once Ann
makes visit 4 first she arrives at 16, and Bob's joint visit and the visit
after it move with her.

Peers are joined transitively into a joint group, and propagation treats the
group as one node: it waits until the previous element and every dependency
of every member hold their final values, then computes the members once each,
in ascending element order. A member's compute may read those inputs of its
peers; it must not read a peer's cascading value, which is being computed in
the same step. Peers are problem facts, like dependencies. A group whose
members wait on each other through their lists (two members on one route, or
a member after an element that waits on its peer) is a cycle, and its members
are unset. A model without peers maps every element to its own node and pays
nothing for the feature.

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
| group change / swap | Move a whole element group to one owner, or exchange two groups (lists with `element_group_fn`) |

## Nearby and K-Opt Search

List-heavy problems often use nearby selectors or k-opt search. In config-driven
solving, that is expressed through `move_selector` variants such as:

- `nearby_list_change_move_selector`
- `nearby_list_swap_move_selector`
- `list_permute_move_selector`
- `list_precedence_move_selector`
- `k_opt_move_selector`
- `list_ruin_move_selector`
- `list_group_change_move_selector` and `list_group_swap_move_selector`, for
  lists with element groups

For ruin-and-recreate search, the current runtime samples only non-empty list
owners for the ruin step. That keeps a vehicle with no visits, or a machine
with no queued jobs, from using a local-search attempt that cannot remove
anything.

## See Also

- [Moves](/docs/solverforge/solver/moves/) — Move types including list-specific moves
- [Planning Entities](/docs/solverforge/modeling/planning-entities/) — Shadow variable attributes
- [SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/) — List-variable vehicle routing with road-network scoring
- [SolverForge FSR Use Case](/docs/getting-started/solverforge-fsr-use-case/) — List-variable technician routing with skills, parts, and route geometry
