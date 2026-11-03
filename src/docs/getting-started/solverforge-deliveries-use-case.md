---
title: "SolverForge Deliveries Use Case"
linkTitle: "Deliveries Use Case"
icon: fa-solid fa-route
date: 2026-04-26
weight: 6
description: "A worked vehicle-routing example that shows list variables, route scoring, retained jobs, maps, and delivery insertion recommendations in one SolverForge app"
categories: [Quickstarts]
tags: [quickstart, rust, routing, deliveries]
---

# SolverForge Deliveries Use Case

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [The Teaching Spine](#the-teaching-spine)
5. [Understanding the Data Model](#understanding-the-data-model)
6. [Prepared Routing Pipeline](#prepared-routing-pipeline)
7. [How Optimization Works](#how-optimization-works)
8. [Writing Constraints](#writing-constraints)
9. [Solver Policy](#solver-policy)
10. [Runtime and Browser Behavior](#runtime-and-browser-behavior)
11. [Making Your First Customization](#making-your-first-customization)
12. [Testing and Validation](#testing-and-validation)
13. [Quick Reference](#quick-reference)

---

## Introduction

This guide has two working paths. The first starts from the generic
[`solverforge-cli` Getting Started](/docs/solverforge-cli/getting-started/)
flow and shows how the neutral shell becomes one concrete delivery-routing
application. The second points to the downloadable finished app when you want to
run the real example, inspect complete code, or compare your work against the
reference implementation. It is the list-variable counterpart to the
[SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/),
which teaches scalar assignment.

That split is intentional. `solverforge-cli` gives you the runnable shell,
managed model seams, retained job lifecycle, generic sample data, and neutral
frontend. The deliveries use case still needs manual domain code: the city data
generators, route-preparation pipeline, route endpoints, insertion
recommendations, map rendering, timelines, and complete browser UI live in the
finished example.

Hospital asks SolverForge to choose one employee for each shift. Deliveries asks
SolverForge to choose which vehicle owns each delivery and where that delivery
appears in the vehicle route.

You will:

- install `solverforge-cli` and verify the scaffold targets carried by your
  binary
- scaffold a neutral app with `solverforge new`, generate the fact, entity,
  list variable, and constraint seams, and code a small router on top of them
- solve it, then run the complete Hugging Face example with the three city
  datasets: `PHILADELPHIA`, `HARTFORD`, and `FIRENZE`
- understand why delivery routing uses a list planning variable
- follow the current `Delivery`, `Vehicle`, and `Plan` model
- connect map preparation, route shadows, constraints, and previews
- use the retained `/jobs` lifecycle plus `/jobs/{id}/routes`
- study `/recommendations/delivery-insertions` as an interactive optimization
  workflow

**No routing or optimization background required**. The article explains the
end-to-end pipeline. The code comments explain the local reason each function,
hook, cache, and route exists.

### Prerequisites

- Basic Rust knowledge: structs, enums, traits, derive macros, modules
- Familiarity with HTTP APIs
- Comfort with command-line work
- Node.js if you want to run the frontend and browser tests
- Rust `1.95+`, matching the checked-in SolverForge use-case runtime line

---

## Getting Started

### Install the CLI

```bash
cargo install solverforge-cli --force
solverforge --version
```

`solverforge --version` prints the CLI version and the runtime it scaffolds.
This page uses `solverforge-cli 3.8`, which scaffolds `solverforge 0.24.0`,
`solverforge-ui 0.9.0`, and `solverforge-maps 2.1.5`.

### Build a Router from the CLI

This path turns the neutral scaffold into a small delivery router: one list
planning variable, route totals kept as shadow values, four rules, and demo
data you can solve in the browser. It keeps the finished app's names so you
can compare the two, but it measures travel as straight-line distance at a
fixed speed instead of preparing a road network.

Start from an empty working directory:

```bash
solverforge new solverforge-deliveries --quiet
cd solverforge-deliveries
solverforge generate fact delivery \
  --field index:usize \
  --field lat:CoordValue \
  --field lng:CoordValue \
  --field demand:i32 \
  --field min_start_time:i64 \
  --field max_end_time:i64 \
  --field service_duration:i64
solverforge generate entity vehicle \
  --field capacity:i32 \
  --field home_lat:CoordValue \
  --field home_lng:CoordValue \
  --field departure_time:i64
solverforge generate variable delivery_order \
  --entity Vehicle \
  --kind list \
  --elements deliveries
solverforge generate constraint all_deliveries_assigned --unary --hard
solverforge generate constraint vehicle_capacity --unary --hard
solverforge generate constraint delivery_time_windows --unary --hard
solverforge generate constraint total_travel_time --unary --soft
```

`generate fact` adds `id` and `name` on its own. `Delivery.index` is the
delivery's position in `Plan.deliveries`, which is the value a route stores.
Times are seconds since midnight. `CoordValue` is this app's coordinate type:
the CLI warns that it is not defined yet, and the next step defines it. Fact
fields must implement `Eq` and `Hash`, which `f64` does not, so `CoordValue`
wraps an `f64` and compares its bits:

```rust
// file: src/domain/coord_value.rs
use serde::{Deserialize, Serialize};
use std::fmt;
use std::hash::{Hash, Hasher};

#[derive(Copy, Clone, Default, Serialize, Deserialize)]
#[serde(transparent)]
pub struct CoordValue(pub f64);

impl CoordValue {
    pub fn get(self) -> f64 {
        self.0
    }
}

impl From<f64> for CoordValue {
    fn from(value: f64) -> Self {
        Self(value)
    }
}

impl fmt::Debug for CoordValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

impl PartialEq for CoordValue {
    fn eq(&self, other: &Self) -> bool {
        self.0.to_bits() == other.0.to_bits()
    }
}

impl Eq for CoordValue {}

impl Hash for CoordValue {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.0.to_bits().hash(state);
    }
}
```

Export it from the planning model manifest. Replace `src/domain/mod.rs` with:

```rust
// file: src/domain/mod.rs
solverforge::planning_model! {
    root = "src/domain";

    // @solverforge:begin domain-exports
    mod coord_value;
    mod delivery;
    mod vehicle;
    mod plan;

    pub use coord_value::CoordValue;
    pub use delivery::Delivery;
    pub use vehicle::Vehicle;
    pub use plan::Plan;
    // @solverforge:end domain-exports
}
```

The constraints need route totals: how much a vehicle carries, how long it
drives, and how late it arrives. Computing them inside every constraint would
walk each route once per rule, so the vehicle stores them as shadow values.
Replace `src/domain/vehicle.rs` with a version that adds the three
`route_*` fields and the walk that fills them:

```rust
// file: src/domain/vehicle.rs
use super::{CoordValue, Delivery};
use serde::{Deserialize, Serialize};
use solverforge::prelude::*;

/// A vehicle that leaves its depot, serves its route in order, and returns.
#[planning_entity]
#[derive(Serialize, Deserialize)]
pub struct Vehicle {
    #[planning_id]
    pub id: String,
    pub capacity: i32,
    pub home_lat: CoordValue,
    pub home_lng: CoordValue,
    pub departure_time: i64,
    // @solverforge:begin entity-variables
    #[planning_list_variable(element_collection = "deliveries")]
    pub delivery_order: Vec<usize>,
    // @solverforge:end entity-variables
    /// Route totals derived from `delivery_order`; constraints read these.
    #[cascading_update_shadow_variable]
    #[serde(skip, default)]
    pub route_demand: i64,
    #[cascading_update_shadow_variable]
    #[serde(skip, default)]
    pub route_travel_seconds: i64,
    #[cascading_update_shadow_variable]
    #[serde(skip, default)]
    pub route_late_seconds: i64,
}

/// Straight-line driving speed used for travel times, in meters per second.
const SPEED_METERS_PER_SECOND: f64 = 11.0;

impl Vehicle {
    pub fn new(
        id: impl Into<String>,
        capacity: i32,
        home_lat: CoordValue,
        home_lng: CoordValue,
        departure_time: i64,
    ) -> Self {
        Self {
            id: id.into(),
            capacity,
            home_lat,
            home_lng,
            departure_time,
            // @solverforge:begin entity-variable-init
            delivery_order: Vec::new(),
            // @solverforge:end entity-variable-init
            route_demand: 0,
            route_travel_seconds: 0,
            route_late_seconds: 0,
        }
    }

    /// Walks the route in order and stores demand, travel, and lateness.
    pub fn refresh_route_shadows(&mut self, deliveries: &[Delivery]) {
        let mut demand = 0_i64;
        let mut travel = 0_i64;
        let mut late = 0_i64;
        let mut clock = self.departure_time;
        let mut position = (self.home_lat.get(), self.home_lng.get());

        for &idx in &self.delivery_order {
            let delivery = &deliveries[idx];
            let stop = (delivery.lat.get(), delivery.lng.get());
            let leg = travel_seconds(position, stop);
            travel += leg;
            clock = (clock + leg).max(delivery.min_start_time) + delivery.service_duration;
            late += (clock - delivery.max_end_time).max(0);
            demand += i64::from(delivery.demand);
            position = stop;
        }
        if !self.delivery_order.is_empty() {
            travel += travel_seconds(position, (self.home_lat.get(), self.home_lng.get()));
        }

        self.route_demand = demand;
        self.route_travel_seconds = travel;
        self.route_late_seconds = late;
    }

    pub fn capacity_overage(&self) -> i64 {
        (self.route_demand - i64::from(self.capacity)).max(0)
    }
}

/// Haversine distance between two (lat, lng) points, driven at a fixed speed.
fn travel_seconds(from: (f64, f64), to: (f64, f64)) -> i64 {
    let (lat1, lng1) = (from.0.to_radians(), from.1.to_radians());
    let (lat2, lng2) = (to.0.to_radians(), to.1.to_radians());
    let a = ((lat2 - lat1) / 2.0).sin().powi(2)
        + lat1.cos() * lat2.cos() * ((lng2 - lng1) / 2.0).sin().powi(2);
    let meters = 2.0 * 6_371_000.0 * a.sqrt().asin();
    (meters / SPEED_METERS_PER_SECOND).round() as i64
}
```

SolverForge refreshes those fields through a list-variable listener on the
solution. Replace `src/domain/plan.rs` with the generated plan plus
`#[shadow_variable_updates(...)]` and the listener it names:

```rust
// file: src/domain/plan.rs
use serde::{Deserialize, Serialize};
use solverforge::prelude::*;

// @solverforge:neutral-solution
// @solverforge:begin solution-imports
use super::Delivery;
use super::Vehicle;
// @solverforge:end solution-imports

/// Deliveries to serve and the vehicles whose ordered routes serve them.
#[planning_solution(
    constraints = "crate::constraints::create_constraints",
    solver_toml = "../../solver.toml"
)]
#[shadow_variable_updates(
    list_owner = "vehicles",
    post_update_listener = "refresh_vehicle_route_shadows"
)]
#[derive(Serialize, Deserialize)]
pub struct Plan {
    // @solverforge:begin solution-collections
    #[problem_fact_collection]
    pub deliveries: Vec<Delivery>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    // @solverforge:end solution-collections
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl Plan {
    #[rustfmt::skip]
    pub fn new(
        // @solverforge:begin solution-constructor-params
        deliveries: Vec<Delivery>,
        vehicles: Vec<Vehicle>,
        // @solverforge:end solution-constructor-params
    ) -> Self {
        Self {
            // @solverforge:begin solution-constructor-init
            deliveries,
            vehicles,
            // @solverforge:end solution-constructor-init
            score: None,
        }
    }

    /// Called by SolverForge after a move changes one vehicle's route.
    pub fn refresh_vehicle_route_shadows(&mut self, vehicle_idx: usize) {
        if let Some(vehicle) = self.vehicles.get_mut(vehicle_idx) {
            vehicle.refresh_route_shadows(&self.deliveries);
        }
    }
}
```

Every generated constraint starts with a placeholder that panics, so a solve
fails until each one is replaced. `all_deliveries_assigned` flattens every
route into delivery indexes and penalizes each delivery missing from all of
them; the other three read one shadow value per vehicle:

```rust
// file: src/constraints/all_deliveries_assigned.rs
use crate::domain::{Delivery, Plan, Vehicle};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// HARD: every delivery appears in some vehicle route.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::deliveries())
        .if_not_exists((
            ConstraintFactory::<Plan, HardSoftScore>::new()
                .for_each(Plan::vehicles())
                .flattened(|vehicle: &Vehicle| &vehicle.delivery_order),
            equal_bi(|delivery: &Delivery| delivery.index, |assigned: &usize| *assigned),
        ))
        .penalize(hard_weight(|_: &Delivery| HardSoftScore::of(1, 0)))
        .named("all_deliveries_assigned")
}
```

```rust
// file: src/constraints/vehicle_capacity.rs
use crate::domain::{Plan, Vehicle};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: a vehicle's route demand fits its capacity.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::vehicles())
        .filter(|vehicle: &Vehicle| vehicle.capacity_overage() > 0)
        .penalize(hard_weight(|vehicle: &Vehicle| HardSoftScore::of(vehicle.capacity_overage(), 0)))
        .named("vehicle_capacity")
}
```

```rust
// file: src/constraints/delivery_time_windows.rs
use crate::domain::{Plan, Vehicle};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: every stop finishes before its window closes.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::vehicles())
        .filter(|vehicle: &Vehicle| vehicle.route_late_seconds > 0)
        .penalize(hard_weight(|vehicle: &Vehicle| HardSoftScore::of(vehicle.route_late_seconds, 0)))
        .named("delivery_time_windows")
}
```

```rust
// file: src/constraints/total_travel_time.rs
use crate::domain::{Plan, Vehicle};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// SOFT: prefer routes with less total travel time.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::vehicles())
        .penalize(|vehicle: &Vehicle| HardSoftScore::of(0, vehicle.route_travel_seconds))
        .named("total_travel_time")
}
```

The generated sample data leaves every coordinate at zero. Replace it with
stops spread around a depot in Philadelphia: 8 stops and 2 vehicles for
`SMALL`, 24 and 4 for `STANDARD`, 48 and 8 for `LARGE`. Every third stop has
a 08:00 to 10:00 window:

```rust
// file: src/data/data_seed.rs
use std::str::FromStr;

use crate::domain::{Delivery, Plan, Vehicle};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DemoData {
    Small,
    Standard,
    Large,
}

const AVAILABLE_DEMO_DATA: &[DemoData] = &[DemoData::Small, DemoData::Standard, DemoData::Large];
const DEFAULT_DEMO_DATA: DemoData = DemoData::Standard;

pub fn default_demo_data() -> DemoData {
    DEFAULT_DEMO_DATA
}

pub fn available_demo_data() -> &'static [DemoData] {
    AVAILABLE_DEMO_DATA
}

impl DemoData {
    pub fn id(self) -> &'static str {
        match self {
            DemoData::Small => "SMALL",
            DemoData::Standard => "STANDARD",
            DemoData::Large => "LARGE",
        }
    }

    pub fn default_demo_data() -> Self {
        default_demo_data()
    }

    pub fn available_demo_data() -> &'static [Self] {
        available_demo_data()
    }
}

impl FromStr for DemoData {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_ascii_uppercase().as_str() {
            "SMALL" => Ok(DemoData::Small),
            "STANDARD" => Ok(DemoData::Standard),
            "LARGE" => Ok(DemoData::Large),
            _ => Err(()),
        }
    }
}

/// Depot near Philadelphia City Hall.
const DEPOT: (f64, f64) = (39.9526, -75.1652);
const HOUR: i64 = 3600;

pub fn generate(demo: DemoData) -> Plan {
    match demo {
        DemoData::Small => generate_plan(8, 2),
        DemoData::Standard => generate_plan(24, 4),
        DemoData::Large => generate_plan(48, 8),
    }
}

fn generate_plan(count_deliveries: usize, count_vehicles: usize) -> Plan {
    let deliveries = (0..count_deliveries)
        .map(|idx| {
            // Spread the stops on a spiral around the depot, 1 to 7 km out.
            let angle = idx as f64 * 2.4;
            let radius = 0.01 + 0.05 * (idx as f64 / count_deliveries as f64);
            let lat = DEPOT.0 + radius * angle.sin();
            let lng = DEPOT.1 + radius * 1.3 * angle.cos();
            // Every third stop has a two-hour morning window; the rest are open all day.
            let (min_start, max_end) = if idx % 3 == 0 {
                (8 * HOUR, 10 * HOUR)
            } else {
                (8 * HOUR, 18 * HOUR)
            };
            Delivery::new(
                format!("delivery-{idx}"),
                format!("Stop {}", idx + 1),
                idx,
                lat.into(),
                lng.into(),
                1 + (idx % 3) as i32,
                min_start,
                max_end,
                10 * 60,
            )
        })
        .collect::<Vec<_>>();

    let vehicles = (0..count_vehicles)
        .map(|idx| {
            Vehicle::new(
                format!("vehicle-{idx}"),
                16,
                DEPOT.0.into(),
                DEPOT.1.into(),
                8 * HOUR,
            )
        })
        .collect::<Vec<_>>();

    Plan::new(deliveries, vehicles)
}
```

Build the app and start the server:

```bash
cargo build
solverforge server
```

`solverforge server` listens on port 7860 (`--port` or `PORT` picks another).
Open `http://localhost:7860` and press Solve, or drive the retained job API
from a second terminal:

```bash
curl -s http://localhost:7860/demo-data/STANDARD -o plan.json
curl -s -X POST -H 'Content-Type: application/json' --data @plan.json http://localhost:7860/jobs
curl -s http://localhost:7860/jobs/0
curl -s http://localhost:7860/jobs/0/analysis
```

The scaffold's `solver.toml` stops each solve after 30 seconds. The job then
reports `"lifecycleState":"COMPLETED"` with a `0hard` score: every delivery is
on a route, no vehicle is over capacity, and every stop finishes inside its
window. The soft score is the total travel time in seconds, negated.

The generated variable uses the stock list moves. The finished app declares
it with `domain = "cvrp"` (what `solverforge generate variable ... --domain
cvrp` writes), which wires SolverForge's CVRP construction and k-opt hooks.
That profile also requires the solution to implement
`solverforge::cvrp::VrpSolution` over prepared travel matrices, which the
finished app builds in `src/domain/route_metrics/`.

### Run the Finished Example

The finished app lives in the Hugging Face Space repository. If you are still
inside the scaffold from the previous section, step out of it first, then
clone the Space into its own directory and start it:

```bash
cd ..
git clone https://huggingface.co/spaces/SolverForge/solverforge-deliveries solverforge-deliveries-space
cd solverforge-deliveries-space
make run-release
```

Then open:

```text
http://localhost:7860
```

The browser loads the default Philadelphia plan and renders retained solve
controls, route summaries, a map, timelines, raw data, analysis, and insertion
recommendations.

Solving a plan prepares road-network travel times first. `solverforge-maps`
downloads the road graph for the plan's area from the public Overpass API
(`overpass-api.de`) and caches it under `.osm_cache/` in the app directory, so
the first solve of each city needs network access and later solves read the
cache. When Overpass cannot be reached, `POST /jobs` answers with a JSON error
body instead of starting a job; retry once the service answers.

### Inspect Demo Data

With the finished app running, list the available demos:

```bash
curl http://localhost:7860/demo-data
```

Load a specific plan:

```bash
curl http://localhost:7860/demo-data/PHILADELPHIA
curl http://localhost:7860/demo-data/HARTFORD
curl http://localhost:7860/demo-data/FIRENZE
```

Current dataset sizes:

| Dataset        | Vehicles | Deliveries | Purpose                       |
| -------------- | -------- | ---------- | ----------------------------- |
| `PHILADELPHIA` | 10       | 82         | Default road-network baseline |
| `HARTFORD`     | 10       | 50         | Smaller city demo             |
| `FIRENZE`      | 10       | 80         | European street-network demo  |

### Published Dependency Shape

The tagged `solverforge-deliveries@3.0.1` release uses SolverForge core, UI,
and Maps from crates.io:

```toml
[dependencies]
solverforge = { version = "0.24.0", features = [
  "serde",
  "console",
  "verbose-logging",
] }
solverforge-ui = "0.9.0"
solverforge-maps = "2.1.5"
# Web server
axum = "0.8.9"
tokio = { version = "1.52.3", features = ["full"] }
tokio-stream = { version = "0.1.18", features = ["sync"] }
tower-http = { version = "0.6.10", features = ["fs", "cors"] }
tower = "0.5.3"

# Serialization
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.149"
rand = "0.10.1"

# Utilities
uuid = { version = "1.23.1", features = ["v4", "serde"] }
parking_lot = "0.12.5"
```

The app contract in `solverforge.app.toml` records the app-owned runtime and
the delivery-specific demo catalog. The finished app keeps the `2.2.2` CLI
version it was first scaffolded with:

```toml
[app]
name = "solverforge-deliveries"
starter = "neutral-shell"
cli_version = "2.2.2"
shell = "web"

[runtime]
target = "solverforge 0.24.0"
runtime_source = "crates.io: solverforge 0.24.0"
ui_source = "crates.io: solverforge-ui 0.9.0"

[demo]
default_size = "PHILADELPHIA"
available_sizes = [
    "PHILADELPHIA",
    "HARTFORD",
    "FIRENZE",
]

[solution]
name = "Plan"
score = "HardSoftScore"
```

### What the Finished App Adds

Compared with the CLI build above, the Space repository supplies the
road-network router:

- `DeliveryKind` and labels on each delivery, and names on each vehicle
- `Vehicle.delivery_order` declared with `domain = "cvrp"`, plus the
  `VrpSolution` implementation on `Plan`
- `Plan` fields for `routing_mode`, `view_state`, and prepared route data, and
  `Plan::normalize()` to keep route ids dense after transport
- `src/domain/route_metrics/`: road-network preparation, CVRP route metrics,
  scoring previews, route geometry, and insertion ranking
- the Philadelphia, Hartford, and Firenze demo seeds
- a tuned `solver.toml` with Clarke-Wright and k-opt construction
- the map, timeline, route-list, raw data, analysis, and recommendation
  frontend modules

That is the teaching boundary: the CLI owns repeatable project seams, while the
manual code owns delivery-routing semantics. When you want to see every manual
line in context, keep the Space checkout open next to this article.

---

## The Problem We're Solving

Delivery routing asks:

> Given depots, vehicles, delivery stops, capacities, and time windows, which
> vehicle should visit each delivery and in what order?

That second part is what makes routing different from simple assignment. A route
`A -> B -> C` can have a very different travel time from `C -> A -> B`.

The solver therefore chooses both:

- the vehicle that owns each delivery
- the position of each delivery inside that vehicle's route

This is why the app uses a list planning variable. Each vehicle owns an ordered
list of delivery IDs.

---

## The Teaching Spine

The delivery app is the list-variable and map-backed routing tutorial. Its core
path is:

1. `Delivery` is immutable problem data.
2. `Vehicle` is the planning entity.
3. `Vehicle.delivery_order` is the list planning variable.
4. `PlanDto::to_domain()` normalizes transport data back into dense route IDs.
5. `prepare_plan()` builds travel matrices and per-vehicle routing caches.
6. The stock CVRP list profile lets SolverForge construction and k-opt read
   those caches.
7. Route shadows convert ordered visits into demand, travel, lateness, and
   unreachable-leg totals.
8. Constraints score assignment coverage, capacity, time windows, and travel
   time.
9. `/jobs/{id}/routes` turns a retained snapshot into map geometry.
10. `/recommendations/delivery-insertions` ranks route edits without a full
    solve.

The comments in `src/domain/route_metrics/` teach the local mechanics. This
article connects those mechanics across the API, solver, and browser.

---

## Understanding the Data Model

Open `src/domain/`.

The domain splits responsibility this way:

- `delivery.rs`
  stop data, demand, time windows, service duration, and coordinates
- `vehicle.rs`
  depot, capacity, route list, and route shadow values
- `plan.rs`
  planning solution, routing mode, list shadow refresh, and CVRP solution data
- `preview.rs`
  browser-facing preview state
- `route_metrics/`
  preparation, CVRP route metrics, scoring previews, route geometry, and
  insertion ranking
- `mod.rs`
  the `planning_model!` manifest and exports

### Delivery as Problem Fact

`Delivery` is input data:

```rust
#[problem_fact]
pub struct Delivery {
    #[planning_id]
    pub id: usize,
    pub label: String,
    pub demand: i32,
    pub min_start_time: i64,
    pub max_end_time: i64,
    pub service_duration: i64,
}
```

The solver reads deliveries but does not mutate delivery records. It mutates the
vehicle route lists that contain delivery IDs.

### Vehicle as Planning Entity

`Vehicle.delivery_order` is the central list variable:

```rust
#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    pub capacity: i32,
    #[planning_list_variable(
        element_collection = "deliveries",
        domain = "cvrp"
    )]
    pub delivery_order: Vec<usize>,
}
```

The CVRP domain profile is stock SolverForge 0.24.0; `solverforge generate
variable ... --domain cvrp` writes the same attribute. It expands to the
`VrpSolution` bound, CVRP distance meters, strict route-local hooks for route
assignment and k-opt, relaxed Clarke-Wright savings hooks, and the stock savings
metric class. The delivery app keeps city-level routing preparation in the
domain while the macro wires the standard CVRP route-list profile. The
article-level point is still simple: the route is an ordered list of delivery
IDs, not a copied list of delivery structs.

### Plan as Routing Solution

`Plan` carries the facts, entities, score, routing mode, and prepared data:

```rust
#[planning_solution(
    constraints = "crate::constraints::create_constraints",
    solver_toml = "../../solver.toml"
)]
#[shadow_variable_updates(
    list_owner = "vehicles",
    post_update_listener = "refresh_vehicle_route_shadows"
)]
pub struct Plan {
    pub name: String,
    pub routing_mode: RoutingMode,
    #[problem_fact_collection]
    pub deliveries: Vec<Delivery>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

`shadow_variable_updates(...)` is the list-variable handoff. When SolverForge
changes a route list, the app refreshes the derived route totals before
constraints read them.

### Codegen Markers

You will see `@solverforge:begin` and `@solverforge:end` markers in the domain
and constraint modules. They are scaffold/codegen boundaries. You can read past
them while learning the domain logic.

---

## Prepared Routing Pipeline

This is the heart of the delivery example.

The browser submits a `PlanDto` to `POST /jobs`. The backend does:

```text
PlanDto::to_domain()
  -> Plan::normalize()
  -> prepare_plan(&mut plan).await
  -> SolverService::start_job(plan)
```

`Plan::normalize()` makes route IDs dense again after transport. If public data
arrived with older delivery IDs, the route lists are remapped onto the current
delivery positions before scoring.

`prepare_plan()` is the boundary before solving:

1. normalize route IDs
2. collect delivery coordinates, demand, time windows, and service durations
3. build delivery-to-delivery travel data
4. build per-vehicle depot-to-delivery and delivery-to-depot legs
5. attach `ProblemData` for the SolverForge CVRP profile
6. attach `PreparedVehicleRouting` for app route shadows and previews

Preparation uses `solverforge-maps` to load the road graph for the plan's
bounding box from `.osm_cache/`, or fetch it from the Overpass API on a cache
miss, and to compute matrix data from it. A failed fetch ends the request with
a JSON error body before any job starts.

Preparation creates the travel-time data the solver scores against. Route
drawing is a separate snapshot read: `/jobs/{id}/routes` turns the selected
solution revision into encoded geometry for the browser.

---

## How Optimization Works

The delivery app uses `HardSoftScore`.

Read a score as:

```text
{hard}hard/{soft}soft
```

Hard score records feasibility problems:

- missing deliveries
- capacity overage
- time-window violations
- unreachable route legs

Soft score records route quality:

- total travel seconds

A plan with `0hard/-14000soft` is feasible on the hard rules and better than a
plan with `0hard/-18000soft`, because both are feasible and the first spends
less time traveling.

Route shadow values keep scoring incremental. `Vehicle::refresh_route_shadows()`
walks the current `delivery_order` and updates total demand, capacity overage,
travel seconds, lateness, and unreachable legs. Constraints then read one
derived value per route instead of recalculating the route from scratch.

---

## Writing Constraints

Open `src/constraints/`.

`create_constraints()` assembles four rules:

```rust
pub fn create_constraints() -> impl ConstraintSet<Plan, HardSoftScore> {
    (
        all_deliveries_assigned::constraint(),
        vehicle_capacity::constraint(),
        delivery_time_windows::constraint(),
        total_travel_time::constraint(),
    )
}
```

Read them in this order:

1. `all_deliveries_assigned.rs`
   Flatten every `Vehicle.delivery_order` and hard-penalize deliveries that do
   not appear in any route.
2. `vehicle_capacity.rs`
   Hard-penalize positive capacity overage from the route shadows.
3. `delivery_time_windows.rs`
   Hard-penalize route lateness and unreachable-leg pressure from the shadows.
4. `total_travel_time.rs`
   Soft-penalize travel seconds so feasible route plans can be compared.

This mirrors the beginner routing pattern:

```text
assign every stop -> keep each route feasible -> minimize travel
```

---

## Solver Policy

`solver.toml` is embedded by `Plan` and drives the solve.

The policy starts with two construction phases:

- `list_clarke_wright`
  builds initial delivery routes from depot, delivery, distance, load, and
  capacity hooks
- `list_k_opt`
  improves route edge structure before local search starts

Then local search combines list-aware route edits:

- `nearby_list_change_move_selector`
  move one delivery to another route or position
- `nearby_list_swap_move_selector`
  exchange deliveries between route positions
- `list_reverse_move_selector`
  reverse a contiguous route segment
- `k_opt_move_selector`
  reconnect route edges
- `list_ruin_move_selector`
  remove a small group of visits and reinsert them elsewhere
- limited `sublist_change_move_selector`
  move a short contiguous run while keeping neighborhood size bounded

The late-acceptance phase uses the
`first_last_step_score_improving` forager. It keeps scanning through accepted
ties and stops when a candidate improves on the score at the start of the
step.

For beginners, this is the difference between writing one greedy dispatcher and
building a search space. The solver starts from a route plan and repeatedly asks
which route edit improves the score.

---

## Runtime and Browser Behavior

Deliveries uses the same retained lifecycle shape as the other SolverForge UI
examples:

```text
POST   /jobs
GET    /jobs/{id}
GET    /jobs/{id}/status
GET    /jobs/{id}/snapshot
GET    /jobs/{id}/analysis
POST   /jobs/{id}/pause
POST   /jobs/{id}/resume
POST   /jobs/{id}/cancel
DELETE /jobs/{id}
GET    /jobs/{id}/events
```

The delivery-specific additions are:

```text
GET  /jobs/{id}/routes
POST /recommendations/delivery-insertions
```

### Snapshot-Bound Routes

`/jobs/{id}/routes` accepts the same optional `snapshot_revision={n}` query used
by snapshots and analysis. That makes score, route table, and map geometry
describe the same retained solution revision.

The route endpoint rebuilds display geometry for the snapshot. It is not the
solver's scoring matrix. That distinction keeps the solver hot path and browser
map path separate.

### Insertion Recommendations

`/recommendations/delivery-insertions` answers a dispatcher-style question:

> If I need to insert this delivery into the current plan, where are the best
> candidate positions?

The endpoint:

1. removes the selected delivery from the current plan
2. prepares the same route data used by solving
3. tries every vehicle and insertion index
4. evaluates the resulting preview plan
5. returns the best candidates by feasibility first and travel quality second

This is not a separate solver run. It is a fast recommendation pass that reuses
the same model and route metrics.

### Browser State Guard

`static/app/main.mjs` keeps route geometry truthful by tracking the active route
identity:

```text
job id + snapshot revision + routing mode
```

When the user changes datasets, routing mode, or receives a newer snapshot, the
browser invalidates old `currentRoutes`. A route response is rendered only if it
still matches the active job, snapshot revision, and routing mode.

That is the frontend counterpart to snapshot-bound `/jobs/{id}/routes`: maps
must never silently draw geometry for a different solution than the table and
score are showing.

### Routing Mode

The submitted plan carries `routingMode`, which records the road-network
contract: `road_network` is the only value the API accepts, and `POST /jobs`
rejects any other value with `400 Bad Request`. Preview scoring and solving
both use map-backed travel data.

---

## Making Your First Customization

### Change Capacity

Open `src/data/data_seed/entrypoints.rs` for the capacity ranges. The
city-specific depot and visit coordinates live under:

```text
src/data/data_seed/philadelphia/
src/data/data_seed/hartford/
src/data/data_seed/firenze/
```

Lowering capacity makes the hard capacity rule more difficult. Raising capacity
lets the solver focus more quickly on route travel time.

This teaches the relationship between:

- domain data
- route preparation
- route shadows
- hard feasibility
- list construction
- local search
- score analysis

### Change a Time Window

Changing a delivery time window in a city visit file changes route feasibility.
Narrower windows create hard pressure unless the route order supports them.
Wider windows let the solver prioritize travel quality.

---

## Testing and Validation

Browser test servers honor `CARGO_TARGET_DIR`, so a shared Cargo build
location works as well as the app-local `target` directory.

The domain's `test_solve_with_config` helper passes a constraint-set
constructor rather than a prebuilt constraint set. Each parallel evaluator
replica can therefore construct an identical independent set.


After you have cloned the finished example, or after your manual build-out
matches it, run the baseline checks from the app root:

```bash
solverforge check
solverforge routes
cargo fmt --check
cargo test
```

`solverforge check` validates the app metadata and model wiring; it does not
compile the project, which is what `cargo test` is for. `solverforge routes`
lists the retained lifecycle and delivery-specific endpoints registered in the
Axum router.

The browser tests use the Playwright version pinned in the app's own
`package-lock.json`. Install it once per clone, then run the convenience
target:

```bash
make install-e2e
make test
```

`make install-e2e` uses the system Chromium at `/usr/bin/chromium` when there is
one and otherwise downloads Playwright's bundled Chromium. `make test` runs the
Rust tests, frontend module syntax checks, browserless frontend model tests,
and the Playwright browser tests against a release build.

Run the full example gate before publishing or updating the hosted demo:

```bash
make ci-local
```

`make ci-local` runs format check, clippy, release build, the standard test
suite, and the Docker/Space image build, so it needs Docker.

Run the live road-network smoke when you need to prove the map-backed route
path. It fetches road data from the Overpass API, so it needs network access:

```bash
make test-live-road
```

---

## Quick Reference

| Need                             | File or directory                   |
| -------------------------------- | ----------------------------------- |
| Tagged app release               | `solverforge-deliveries@3.0.1`       |
| App metadata                     | `solverforge.app.toml`              |
| Solver policy                    | `solver.toml`                       |
| Planning model manifest          | `src/domain/mod.rs`                 |
| Planning solution                | `src/domain/plan.rs`                |
| Delivery fact                    | `src/domain/delivery.rs`            |
| Vehicle entity and list variable | `src/domain/vehicle.rs`             |
| Route preparation and CVRP profile data | `src/domain/route_metrics/`         |
| Constraint assembly              | `src/constraints/mod.rs`            |
| City demo IDs                    | `src/data/data_seed/entrypoints.rs` |
| API routes                       | `src/api/routes.rs`                 |
| DTO contract                     | `src/api/dto.rs`                    |
| SSE endpoint                     | `src/api/sse.rs`                    |
| Solver service                   | `src/solver/service.rs`             |
| Browser controller               | `static/app/main.mjs`               |
| Visible API guide                | `static/app/ui/api-guide.mjs`       |

### Common Gotchas

- The CLI scaffold is a starting shell, not a generator for the complete
  deliveries app.
- The full city data generators, route previews, insertion recommendations, and
  complete frontend live in the Hugging Face Space repository.
- A route is an ordered list of delivery IDs, not delivery structs.
- `Plan::normalize()` keeps route IDs dense after transport.
- Road-network preparation builds scoring data; `/jobs/{id}/routes` builds
  display geometry for a snapshot.
- Route shadows are what constraints read.
- Snapshot, analysis, and routes should use the same `snapshot_revision`.
- The first solve of a city fetches road data from the Overpass API; later
  solves read `.osm_cache/`.
- `delete` removes a terminal retained job; `cancel` stops a live or paused one.
- The finished app intentionally uses published crates.io dependencies.

### Additional Resources

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
- [Python Deliveries Example](/docs/solverforge-python/deliveries-example/)
- [List Variables](/docs/solverforge/modeling/list-variables/)
- [Solver Moves](/docs/solverforge/solver/moves/)
- [solverforge-maps Routing](/docs/solverforge-maps/routing/)
- [solverforge-ui Getting Started](/docs/solverforge-ui/getting-started/)
