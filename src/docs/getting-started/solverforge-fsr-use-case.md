---
title: "SolverForge FSR Use Case"
linkTitle: "FSR Use Case"
icon: fa-solid fa-screwdriver-wrench
date: 2026-05-05
weight: 7
description: "A field-service routing quickstart that shows technicians, service visits, skills, parts, shifts, road-network travel, retained jobs, and route geometry in one SolverForge app"
categories: [Quickstarts]
tags: [quickstart, rust, routing, field-service]
---

# SolverForge FSR Use Case

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [The Teaching Spine](#the-teaching-spine)
5. [Understanding the Data Model](#understanding-the-data-model)
6. [Bergamo Routing Data](#bergamo-routing-data)
7. [How Optimization Works](#how-optimization-works)
8. [Writing Constraints](#writing-constraints)
9. [Solver Policy](#solver-policy)
10. [Runtime and Browser Behavior](#runtime-and-browser-behavior)
11. [Making Your First Customization](#making-your-first-customization)
12. [Testing and Validation](#testing-and-validation)
13. [Quick Reference](#quick-reference)

---

## Introduction

This guide shows how the generic
[`solverforge-cli` Getting Started](/docs/solverforge-cli/getting-started/)
shell becomes `solverforge-fsr`, a field-service routing app for technicians in
Bergamo. It is the field-service counterpart to the
[SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/):
both use list variables and road-network data, but FSR adds technician skills,
parts, shifts, territories, route reachability, and snapshot-bound route
geometry for service dispatch.

The app answers one concrete question:

> Given technicians, service visits, skills, parts, shifts, territories, and
> road-network travel, which technician should serve each visit and in what
> order?

You will:

- install `solverforge-cli` and build a small dispatcher from the neutral
  scaffold, then solve it
- run the complete FSR app from its Hugging Face Space repository
- read the finished app's SolverForge 0.26.0 dependency shape
- understand why field-service routing uses a list planning variable
- follow the current `Location`, `ServiceVisit`, `TravelLeg`,
  `TechnicianRoute`, and `FieldServicePlan` model
- see where Bergamo OSM data becomes the travel-leg matrix used by constraints
- see how route shadow values let stock SolverForge constraint streams score
  route-wide business rules
- read the ten route-constraint modules in their intended order
- use retained jobs, snapshots, analysis, SSE, and `/jobs/{id}/routes`
- validate the app locally before publishing the Space

**No dispatch or route-optimization background required**. The article keeps
the domain concepts explicit and points to the exact source files that carry
the full implementation.

### Prerequisites

- Rust `1.95+`, matching the checked-in SolverForge use-case runtime line
- `cargo` and a stable Rust toolchain
- Basic Rust knowledge: structs, enums, traits, modules, derive macros
- Familiarity with HTTP APIs
- Node.js and npm for the finished app's frontend checks and browser tests
- Network access to the Overpass API for the finished app's first solve
- Docker if you want to build or run the Hugging Face Space image locally

---

## Getting Started

### Install the CLI

```bash
cargo install solverforge-cli --force
solverforge --version
```

`solverforge --version` prints the CLI version and the runtime it scaffolds.
This page uses `solverforge-cli 4.0.3`, which scaffolds `solverforge 0.26.0`,
`solverforge-ui 0.9.1`, and `solverforge-maps 2.3.3`.

### Build a Dispatcher from the CLI

This path turns the neutral scaffold into a small field-service dispatcher: one
list planning variable per technician, route measurements kept as shadow
values, five rules, and Bergamo demo data you can solve in the browser. It
keeps the finished app's names so you can compare the two, but it measures
travel as straight-line distance at a fixed speed instead of preparing a road
network, and it leaves out parts, territories, and priorities.

Start from an empty working directory:

```bash
solverforge new solverforge-fsr --quiet
cd solverforge-fsr
solverforge generate fact location \
  --field lat_e6:i64 \
  --field lng_e6:i64
solverforge generate fact service_visit \
  --field index:usize \
  --field location_idx:usize \
  --field duration_minutes:i64 \
  --field earliest_minute:i64 \
  --field latest_minute:i64 \
  --field required_skill_mask:i64
solverforge generate entity technician_route \
  --field depot_location_idx:usize \
  --field shift_start_minute:i64 \
  --field shift_end_minute:i64 \
  --field skill_mask:i64
solverforge generate variable visits \
  --entity TechnicianRoute \
  --kind list \
  --elements service_visits
solverforge generate constraint assigned_visits --unary --hard
solverforge generate constraint required_skills --unary --hard
solverforge generate constraint time_windows --unary --hard
solverforge generate constraint shift_capacity --unary --hard
solverforge generate constraint minimize_travel --unary --soft
```

Each `generate constraint` writes `src/constraints/<name>.rs`, declares it in
`src/constraints/mod.rs`, and adds its call to `create_constraints` in
`src/constraints/assemble.rs`.

`generate fact` adds `id` and `name` on its own. Coordinates are integer
microdegrees, as in the finished app, because fact fields must implement `Eq`
and `Hash`. Times are minutes since midnight, and skills are bit masks.
`ServiceVisit.index` is the visit's position in `Plan.service_visits`, which is
the value a route stores.

Replace `src/domain/mod.rs` so the manifest lists the modules in this order:

```rust
// file: src/domain/mod.rs
solverforge::planning_model! {
    root = "src/domain";

    // @solverforge:begin domain-exports
    mod location;
    mod service_visit;
    mod technician_route;
    mod plan;

    pub use location::Location;
    pub use service_visit::ServiceVisit;
    pub use technician_route::TechnicianRoute;
    pub use plan::Plan;
    // @solverforge:end domain-exports
}
```

The rules need route measurements: how many visits lack a skill, how late
visits start, how far past the shift the technician returns, and how long the
technician drives. The route stores them as shadow values so each rule reads
one number per technician. Replace `src/domain/technician_route.rs` with a
version that adds the four `route_*` fields and the walk that fills them:

```rust
// file: src/domain/technician_route.rs
use super::{Location, ServiceVisit};
use serde::{Deserialize, Serialize};
use solverforge::prelude::*;

/// One technician's working day: depot, shift, skills, and ordered visits.
#[planning_entity]
#[derive(Serialize, Deserialize)]
pub struct TechnicianRoute {
    #[planning_id]
    pub id: String,
    pub depot_location_idx: usize,
    pub shift_start_minute: i64,
    pub shift_end_minute: i64,
    pub skill_mask: i64,
    // @solverforge:begin entity-variables
    #[planning_list_variable(element_collection = "service_visits")]
    pub visits: Vec<usize>,
    // @solverforge:end entity-variables
    /// Route measurements derived from `visits`; constraints read these.
    #[cascading_update_shadow_variable]
    #[serde(skip, default)]
    pub route_missing_skill_visits: i64,
    #[cascading_update_shadow_variable]
    #[serde(skip, default)]
    pub route_late_minutes: i64,
    #[cascading_update_shadow_variable]
    #[serde(skip, default)]
    pub route_overtime_minutes: i64,
    #[cascading_update_shadow_variable]
    #[serde(skip, default)]
    pub route_travel_seconds: i64,
}

/// Straight-line driving speed used for travel times, in meters per second.
const SPEED_METERS_PER_SECOND: f64 = 8.0;

impl TechnicianRoute {
    pub fn new(
        id: impl Into<String>,
        depot_location_idx: usize,
        shift_start_minute: i64,
        shift_end_minute: i64,
        skill_mask: i64,
    ) -> Self {
        Self {
            id: id.into(),
            depot_location_idx,
            shift_start_minute,
            shift_end_minute,
            skill_mask,
            // @solverforge:begin entity-variable-init
            visits: Vec::new(),
            // @solverforge:end entity-variable-init
            route_missing_skill_visits: 0,
            route_late_minutes: 0,
            route_overtime_minutes: 0,
            route_travel_seconds: 0,
        }
    }

    /// Walks the route in order and stores skill gaps, lateness, overtime,
    /// and travel.
    pub fn refresh_route_shadows(&mut self, locations: &[Location], visits: &[ServiceVisit]) {
        let mut missing_skill = 0_i64;
        let mut late = 0_i64;
        let mut travel = 0_i64;
        let mut minute = self.shift_start_minute;
        let mut at = self.depot_location_idx;

        for &idx in &self.visits {
            let visit = &visits[idx];
            let leg = travel_seconds(&locations[at], &locations[visit.location_idx]);
            travel += leg;
            minute = (minute + leg / 60).max(visit.earliest_minute);
            late += (minute - visit.latest_minute).max(0);
            minute += visit.duration_minutes;
            if visit.required_skill_mask & self.skill_mask != visit.required_skill_mask {
                missing_skill += 1;
            }
            at = visit.location_idx;
        }
        let back = travel_seconds(&locations[at], &locations[self.depot_location_idx]);
        travel += back;
        minute += back / 60;

        self.route_missing_skill_visits = missing_skill;
        self.route_late_minutes = late;
        self.route_overtime_minutes = (minute - self.shift_end_minute).max(0);
        self.route_travel_seconds = travel;
    }
}

/// Haversine distance between two locations, driven at a fixed speed.
fn travel_seconds(from: &Location, to: &Location) -> i64 {
    let deg = |e6: i64| (e6 as f64 / 1_000_000.0).to_radians();
    let (lat1, lng1) = (deg(from.lat_e6), deg(from.lng_e6));
    let (lat2, lng2) = (deg(to.lat_e6), deg(to.lng_e6));
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
use super::Location;
use super::ServiceVisit;
use super::TechnicianRoute;
// @solverforge:end solution-imports

/// Service visits to schedule and the technician routes that serve them.
#[planning_solution(
    constraints = "crate::constraints::create_constraints",
    solver_toml = "../../solver.toml"
)]
#[shadow_variable_updates(
    list_owner = "technician_routes",
    post_update_listener = "refresh_technician_route_shadows"
)]
#[derive(Serialize, Deserialize)]
pub struct Plan {
    // @solverforge:begin solution-collections
    #[problem_fact_collection]
    pub locations: Vec<Location>,
    #[problem_fact_collection]
    pub service_visits: Vec<ServiceVisit>,
    #[planning_entity_collection]
    pub technician_routes: Vec<TechnicianRoute>,
    // @solverforge:end solution-collections
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl Plan {
    #[rustfmt::skip]
    pub fn new(
        // @solverforge:begin solution-constructor-params
        locations: Vec<Location>,
        service_visits: Vec<ServiceVisit>,
        technician_routes: Vec<TechnicianRoute>,
        // @solverforge:end solution-constructor-params
    ) -> Self {
        Self {
            // @solverforge:begin solution-constructor-init
            locations,
            service_visits,
            technician_routes,
            // @solverforge:end solution-constructor-init
            score: None,
        }
    }

    /// Called by SolverForge after a move changes one technician's route.
    pub fn refresh_technician_route_shadows(&mut self, route_idx: usize) {
        if let Some(route) = self.technician_routes.get_mut(route_idx) {
            route.refresh_route_shadows(&self.locations, &self.service_visits);
        }
    }
}
```

Every generated constraint starts with a placeholder that panics, so a solve
fails until each one is replaced. `assigned_visits` flattens every route into
visit indexes and penalizes each visit missing from all of them; the other four
read one shadow value per route:

```rust
// file: src/constraints/assigned_visits.rs
use crate::domain::{Plan, ServiceVisit, TechnicianRoute};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// HARD: every service visit appears in some technician route.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::service_visits())
        .if_not_exists((
            ConstraintFactory::<Plan, HardSoftScore>::new()
                .for_each(Plan::technician_routes())
                .flattened(|route: &TechnicianRoute| &route.visits),
            equal_bi(|visit: &ServiceVisit| visit.index, |assigned: &usize| *assigned),
        ))
        .penalize(hard_weight(|_: &ServiceVisit| HardSoftScore::of(1, 0)))
        .named("assigned_visits")
}
```

```rust
// file: src/constraints/required_skills.rs
use crate::domain::{Plan, TechnicianRoute};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: a technician has every skill a visit on the route requires.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::technician_routes())
        .filter(|route: &TechnicianRoute| route.route_missing_skill_visits > 0)
        .penalize(hard_weight(|route: &TechnicianRoute| {
            HardSoftScore::of(route.route_missing_skill_visits, 0)
        }))
        .named("required_skills")
}
```

```rust
// file: src/constraints/time_windows.rs
use crate::domain::{Plan, TechnicianRoute};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: each visit starts by its latest minute.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::technician_routes())
        .filter(|route: &TechnicianRoute| route.route_late_minutes > 0)
        .penalize(hard_weight(|route: &TechnicianRoute| {
            HardSoftScore::of(route.route_late_minutes, 0)
        }))
        .named("time_windows")
}
```

```rust
// file: src/constraints/shift_capacity.rs
use crate::domain::{Plan, TechnicianRoute};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: the route returns to the depot before the shift ends.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::technician_routes())
        .filter(|route: &TechnicianRoute| route.route_overtime_minutes > 0)
        .penalize(hard_weight(|route: &TechnicianRoute| {
            HardSoftScore::of(route.route_overtime_minutes, 0)
        }))
        .named("shift_capacity")
}
```

```rust
// file: src/constraints/minimize_travel.rs
use crate::domain::{Plan, TechnicianRoute};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// SOFT: prefer routes with less travel time.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::technician_routes())
        .penalize(|route: &TechnicianRoute| HardSoftScore::of(0, route.route_travel_seconds))
        .named("minimize_travel")
}
```

The generated sample data puts every location at the same point. Replace it
with a depot and twelve customer sites in Bergamo: 6 visits and 2 technicians
for `SMALL`, 18 and 3 for `STANDARD`, 36 and 6 for `LARGE`. Every second visit
must start by 12:00, and each technician covers two of three skills:

```rust
// file: src/data/data_seed.rs
use std::str::FromStr;

use crate::domain::{Location, Plan, ServiceVisit, TechnicianRoute};

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

const ELECTRICAL: i64 = 1;
const PLUMBING: i64 = 2;
const HEATING: i64 = 4;

/// Depot and customer sites in Bergamo, in microdegrees.
const SITES: &[(&str, i64, i64)] = &[
    ("Depot", 45_695_000, 9_670_000),
    ("Citta Alta", 45_703_900, 9_662_400),
    ("Borgo Palazzo", 45_694_000, 9_690_500),
    ("Malpensata", 45_684_300, 9_676_900),
    ("Longuelo", 45_697_600, 9_640_700),
    ("Redona", 45_710_500, 9_690_000),
    ("Valtesse", 45_715_800, 9_678_000),
    ("Colognola", 45_672_300, 9_668_600),
    ("Celadina", 45_699_000, 9_708_900),
    ("Loreto", 45_701_200, 9_650_300),
    ("Santa Lucia", 45_699_400, 9_655_700),
    ("Boccaleone", 45_686_200, 9_697_900),
    ("Grumello", 45_676_900, 9_645_600),
];

pub fn generate(demo: DemoData) -> Plan {
    match demo {
        DemoData::Small => generate_plan(6, 2),
        DemoData::Standard => generate_plan(18, 3),
        DemoData::Large => generate_plan(36, 6),
    }
}

fn generate_plan(count_visits: usize, count_technicians: usize) -> Plan {
    let locations = SITES
        .iter()
        .enumerate()
        .map(|(idx, (name, lat_e6, lng_e6))| {
            Location::new(format!("location-{idx}"), *name, *lat_e6, *lng_e6)
        })
        .collect::<Vec<_>>();

    let skills = [ELECTRICAL, PLUMBING, HEATING];
    let service_visits = (0..count_visits)
        .map(|idx| {
            let location_idx = 1 + idx % (SITES.len() - 1);
            // Morning visits close at 12:00; the rest are open until 17:00.
            let latest_minute = if idx % 2 == 0 { 12 * 60 } else { 17 * 60 };
            ServiceVisit::new(
                format!("visit-{idx}"),
                format!("Visit {}", idx + 1),
                idx,
                location_idx,
                45,
                8 * 60,
                latest_minute,
                skills[idx % skills.len()],
            )
        })
        .collect::<Vec<_>>();

    // Every technician covers two of the three skills.
    let technician_skills = [
        ELECTRICAL | PLUMBING,
        PLUMBING | HEATING,
        HEATING | ELECTRICAL,
    ];
    let technician_routes = (0..count_technicians)
        .map(|idx| {
            TechnicianRoute::new(
                format!("technician-{idx}"),
                0,
                8 * 60,
                17 * 60,
                technician_skills[idx % technician_skills.len()],
            )
        })
        .collect::<Vec<_>>();

    Plan::new(locations, service_visits, technician_routes)
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
reports `"lifecycleState":"COMPLETED"` with a `0hard` score: every visit is on
a route, each technician has the skills their visits need, and every visit and
shift ends on time. The soft score is the total travel time in seconds,
negated.

### Run the Finished Example

The finished app lives in the Hugging Face Space repository. If you are still
inside the scaffold from the previous section, step out of it first, then
clone the Space into its own directory and start it:

```bash
cd ..
git clone https://huggingface.co/spaces/SolverForge/solverforge-fsr solverforge-fsr-space
cd solverforge-fsr-space
make run-release
```

Open:

```text
http://localhost:7860
```

The Space source is the reference implementation. It includes the Bergamo
technicians, service locations, OSM routing setup, retained API, map workspace,
score analysis surface, route tables, Docker build, and tests.

Solving a plan prepares road-network travel first. The app downloads the
Bergamo road graph from the public Overpass API (`overpass-api.de`) and caches
it under:

```text
.osm_cache/field-service-routing/bergamo
```

The first solve therefore needs network access; later solves read the cache.
When Overpass cannot be reached, `POST /jobs` answers `503 Service Unavailable`
with a JSON error body instead of starting a job; retry once the service
answers.

### Inspect Demo Data

With the finished app running, list available demos:

```bash
curl http://localhost:7860/demo-data
```

Load the standard Bergamo plan:

```bash
curl http://localhost:7860/demo-data/STANDARD
```

Current dataset shape:

| Dataset | Technicians | Service Visits | Locations | Purpose |
| ------- | ----------- | -------------- | --------- | ------- |
| `STANDARD` | 6 | 48 | 26 | Bergamo road-network field-service demo |

### Published Dependency Shape

The tagged `solverforge-fsr@3.0.4` release targets the published SolverForge
0.26.0 line:

```toml
[dependencies]
solverforge = { version = "0.26.0", features = ["serde", "console", "verbose-logging"] }
solverforge-core = "0.26.0"
solverforge-ui = { version = "0.9.0" }
solverforge-maps = { version = "2.1.5" }
# Web server
axum = "0.8.9"
tokio = { version = "1.52.3", features = ["full"] }
tokio-stream = { version = "0.1.18", features = ["sync"] }
tower-http = { version = "0.6.10", features = ["fs", "cors"] }
tower = "0.5.3"

# Serialization
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.149"

# Utilities
uuid = { version = "1.23.1", features = ["v4", "serde"] }
parking_lot = "0.12.5"
```

The FSR app keeps `solverforge-core` pinned beside the facade so its low-level
runtime helpers stay on the same release line. The scoring code itself uses
stock `ConstraintFactory` streams over `TechnicianRoute` rows and route shadow
values; most applications only need the top-level `solverforge` facade.

The app contract in `solverforge.app.toml` names the app-owned runtime target.
The finished app records `solverforge 0.26.0` as its runtime while keeping the
`2.2.2` CLI version it was first scaffolded with:

```toml
[app]
name = "solverforge-fsr"
starter = "neutral-shell"
cli_version = "2.2.2"
shell = "web"

[runtime]
target = "solverforge 0.26.0"
runtime_source = "crates.io: solverforge 0.26.0"
ui_source = "crates.io: solverforge-ui 0.9.0"

[demo]
default_size = "STANDARD"
available_sizes = [
    "STANDARD",
]

[solution]
name = "FieldServicePlan"
score = "HardSoftScore"
```

### What the Finished App Adds

Compared with the CLI build above, the FSR repository supplies the
field-service-specific work:

- the solution named `FieldServicePlan` instead of the scaffold's `Plan`
- Bergamo depots, customer locations, technician profiles, visit profiles, and
  catalog masks
- the road-network fetch and matrix build using `solverforge-maps`
- `TravelLeg` facts derived from matrix duration, distance, and reachability
- parts, territories, priorities, and route caps, with five more rules over them
- `/jobs/{id}/routes` for snapshot-bound map geometry
- a browser workspace with map, route list, timeline, raw data, and score
  analysis views

---

## The Problem We're Solving

Field-service routing asks the solver to make two linked decisions:

- which technician owns each service visit
- where each visit appears inside that technician's route

That differs from a simple assignment problem. A technician route is ordered:

```text
depot -> visit 03 -> visit 17 -> visit 08 -> depot
```

Changing that order changes travel time, shift feasibility, reachability, and
time-window slack. The app therefore models each technician as one planning
entity with one list variable. The solver mutates the ordered visit list, and
the constraints score the resulting route.

The domain also includes field-service details that plain delivery routing does
not cover:

- service visits require skills and parts
- technicians carry skills, inventory, territory, shift bounds, and route caps
- road-network legs can be unreachable
- high-priority visits are better when served with deadline slack
- balanced workload matters after feasibility is satisfied

---

## The Teaching Spine

The finished app's core path is:

1. `Location` stores depots and service-location coordinates.
2. `ServiceVisit` stores job duration, time window, skills, parts, priority,
   and territory.
3. `TechnicianRoute` is the planning entity.
4. `TechnicianRoute.visits` is the list planning variable.
5. `FieldServicePlan` refreshes route shadow values after list-variable edits.
6. `TravelLeg` stores matrix duration, distance, and reachability.
7. `generate(STANDARD)` builds the initial Bergamo plan.
8. `prepare_routing(&mut plan)` loads or fetches the OSM road graph and
   computes the travel matrix.
9. `SolverService::start_job(plan)` starts a retained solve.
10. `/jobs/{id}/snapshot`, `/jobs/{id}/analysis`, and `/jobs/{id}/routes`
    expose the selected retained solution revision to the browser.

The important boundary is that scoring and display geometry are related but not
the same operation. The solver scores against prepared `TravelLeg` facts. The
route endpoint rebuilds display geometry for a particular retained snapshot so
the map, route list, score, and analysis stay aligned.

---

## Understanding the Data Model

Open `src/domain/` in the finished repository.

| File | Role |
| ---- | ---- |
| `location.rs` | Problem fact for depots and customer locations, stored as integer microdegrees with `lat()` and `lng()` helpers |
| `service_visit.rs` | Problem fact for service job identity, customer, location index, duration, time window, required skill mask, required parts mask, priority, and territory |
| `travel_leg.rs` | Problem fact for from-location, to-location, duration, distance, and reachability |
| `technician_route.rs` | Planning entity for technician identity, depot indexes, shift bounds, maximum route minutes, skill mask, inventory mask, territory, `visits`, and route shadow fields |
| `route_metrics.rs` | Shared route walk that turns ordered visits into travel, reachability, skill, parts, time-window, workload, territory, and priority-slack counters |
| `field_service_plan.rs` | Planning solution with `locations`, `service_visits`, `travel_legs`, `technician_routes`, `score`, and the list-variable shadow refresh hook |
| `mod.rs` | Domain exports |

### Service Visits Are Problem Facts

`ServiceVisit` records the work that needs to be scheduled. The solver reads
those records but does not mutate them.

The fields that matter most for routing are:

- `location_idx`
- `duration_minutes`
- `earliest_minute`
- `latest_minute`
- `required_skill_mask`
- `required_parts_mask`
- `priority`
- `territory`

### Technician Routes Are Planning Entities

`TechnicianRoute` owns the mutable route:

```text
TechnicianRoute.visits: Vec<usize>
```

Each item in `visits` is an index into `FieldServicePlan.service_visits`.
Keeping the route as indexes avoids copying service records into the mutable
planning entity and keeps route edits small.

### Travel Legs Are Prepared Facts

`TravelLeg` is prepared before solving. For each location pair, it records:

- duration in seconds
- distance in meters
- whether the road-network route is reachable

Constraints use those facts to decide whether a route is feasible and how much
travel it carries.

### Route Shadows Bridge Lists and Streams

Several business rules need the same expensive route walk. Rather than keeping
that walk inside a custom constraint adapter, the use case stores the
derived measurements on `TechnicianRoute` as cascading shadow variables:

- invalid and valid visit counts
- scored and unreachable travel-leg counts
- missing skill and missing part counts
- late visits and late minutes
- overtime minutes
- travel seconds and distance meters
- service, waiting, route, and finish minutes
- territory matches
- priority slack

`FieldServicePlan` declares the list-variable update hook:

```rust
#[shadow_variable_updates(
    list_owner = "technician_routes",
    post_update_listener = "refresh_technician_route_shadows"
)]
```

When SolverForge changes a route, `refresh_technician_route_shadows()` calls
`route_stats()` and copies the fresh counters onto the route. The constraint
files can then stay declarative: each one streams `technician_routes()`,
filters on the relevant shadow field, and applies a hard or soft score impact.

---

## Bergamo Routing Data

Open `src/data/`.

| File | Role |
| ---- | ---- |
| `bergamo_locations.rs` | Two depots and the service-location catalog |
| `bergamo_technicians.rs` | Six technician profiles, colors, depot indexes, skill masks, inventory masks, and territories |
| `bergamo_profiles.rs` | Six recurring service profiles with duration, time window, skills, parts, and priority |
| `bergamo_catalog.rs` | Skill, parts, location, technician, and visit-profile seed types |
| `data_seed.rs` | Demo catalog, plan generation, road-network loading, matrix computation, and `TravelLeg` construction |

The `bergamo_*.rs` modules own the static fact catalogs. `data_seed.rs` owns
`STANDARD` plan assembly and routing preparation, so catalog data does not
drift into the mutable planning model.

`DemoData::Standard` builds 48 service visits by cycling the visit profiles
across the Bergamo service locations. `prepare_routing()` then:

1. converts every `Location` into a `solverforge_maps::Coord`
2. loads or fetches the Bergamo road network
3. computes a travel-time matrix
4. writes one `TravelLeg` for each location pair

The road-network bounding box is scoped to Bergamo, and the OSM cache lives
inside `.osm_cache/field-service-routing/bergamo`. This keeps the finished Space
self-contained after the cache has been populated in the running environment.

---

## How Optimization Works

FSR uses `HardSoftScore`.

Hard score records feasibility:

- every service visit appears exactly once
- every route leg is reachable
- assigned visits match technician skills
- assigned visits match technician inventory
- routes fit inside shift and route-cap limits
- visits start before their latest service minute

Soft score records route quality and dispatcher preference:

- lower road travel time and distance
- balanced workload
- familiar territory
- deadline slack weighted by visit priority

A plan with `0hard/-420soft` is feasible on the hard rules and better than
`0hard/-600soft`, because both satisfy hard constraints and the first loses
less soft score.

---

## Writing Constraints

Open `src/constraints/`.

`src/constraints/mod.rs` declares the rule modules and a test-only
`route_metrics_tests` module outside the managed `constraint-modules` block.
`create_constraints()` in `src/constraints/assemble.rs` assembles the ten
business-rule modules. The
`assigned_visits` module expands into separate missing, duplicate, and invalid
assignment constraints so each failure mode keeps its own score-analysis
identity: score analysis reports them as `assigned_visits` (missing visits),
`duplicate_visit_assignments`, and `invalid_visit_assignments`.

| Constraint module | Type | Purpose |
| ----------------- | ---- | ------- |
| `assigned_visits` | Hard | Penalizes unassigned, duplicate, or invalid visit indexes |
| `reachable_legs` | Hard | Penalizes depot-to-visit, visit-to-visit, and visit-to-depot legs that cannot be routed |
| `required_skills` | Hard | Penalizes visits assigned to technicians without the required skill mask |
| `required_parts` | Hard | Penalizes visits assigned to technicians without the required parts mask |
| `shift_capacity` | Hard | Penalizes routes that exceed the technician shift or max route minutes |
| `time_windows` | Hard | Penalizes late service starts |
| `minimize_travel` | Soft | Penalizes route travel minutes and travel kilometers |
| `balance_workload` | Soft | Penalizes concentrated service and travel load |
| `territory_affinity` | Soft | Rewards visits inside the technician's territory |
| `priority_slack` | Soft | Rewards high-priority visits served with slack before the deadline |

`assigned_visits` is a three-part cross-route coverage contract. Missing visits
use a stock `service_visits()` stream, flattened `TechnicianRoute.visits`, and
`if_not_exists(...)`. Invalid indexes use a stock route-shadow stream. Exact
duplicate counts use a small custom incremental constraint because a grouped
stream would count singleton groups as analysis matches. One extra occurrence
costs one hard point, while analysis reports one match per duplicated visit id.

The other nine modules stream `technician_routes()` and score the route shadow
values refreshed by `FieldServicePlan`. For example, `reachable_legs` reads
the route shadow `route.route_unreachable_legs`, `required_skills` reads
`route_missing_skill_visits`, `minimize_travel` reads `travel_penalty()`, and
`priority_slack` rewards `route_priority_slack`.

The teaching point is that whole-route business measurements can live
as domain shadow values, while the scoring rules remain stock SolverForge
constraint streams with normal score-analysis metadata.

Read the hard rules first. They define whether the dispatch plan is usable.
Then read the soft rules. They define which usable route plan is preferred.

---

## Solver Policy

`solver.toml` drives the solve:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "list_round_robin"

[[phases]]
type = "local_search"

[phases.acceptor]
type = "hill_climbing"

[phases.forager]
type = "first_best_score_improving"

[phases.move_selector]
type = "union_move_selector"
selection_order = "round_robin"

[[phases.move_selector.selectors]]
type = "list_change_move_selector"
entity_class = "TechnicianRoute"
variable_name = "visits"

[[phases.move_selector.selectors]]
type = "list_swap_move_selector"
entity_class = "TechnicianRoute"
variable_name = "visits"

[[phases.move_selector.selectors]]
type = "sublist_change_move_selector"
min_sublist_size = 1
max_sublist_size = 3
entity_class = "TechnicianRoute"
variable_name = "visits"

[[phases.move_selector.selectors]]
type = "sublist_swap_move_selector"
min_sublist_size = 1
max_sublist_size = 3
entity_class = "TechnicianRoute"
variable_name = "visits"

[[phases.move_selector.selectors]]
type = "list_reverse_move_selector"
entity_class = "TechnicianRoute"
variable_name = "visits"

[termination]
seconds_spent_limit = 60
```

Construction assigns visits to technicians round-robin. Local search is hill
climbing that takes the first move improving the best score, drawn in turn from
a union of list moves:

- `list_change_move_selector`
- `list_swap_move_selector`
- `sublist_change_move_selector`
- `sublist_swap_move_selector`
- `list_reverse_move_selector`

That policy is intentionally easy to inspect. It lets beginners see the route
edit vocabulary directly: move a visit, swap visits, move a contiguous run, swap
contiguous runs, or reverse a route segment.

---

## Runtime and Browser Behavior

The app keeps the standard retained SolverForge lifecycle:

```text
GET    /health
GET    /info
GET    /demo-data
GET    /demo-data/{id}
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

The FSR-specific map endpoint is:

```text
GET /jobs/{id}/routes
```

### API, Routes, and Browser State

`/jobs/{id}/routes` accepts the same optional
`snapshot_revision={n}` query used by snapshots and analysis. The response
contains one route geometry object per technician route, with segment-level
duration, distance, reachability, encoded polyline, and geometry status:

- `ROUTED`
- `UNREACHABLE_LEG`
- `SNAP_FAILED`
- `NO_PATH`

That segment status is deliberate. One failed or unreachable leg should not
erase the rest of the snapshot's route geometry.

The browser is split into small modules under `static/`:

| File | Role |
| ---- | ---- |
| `app.js` | Lifecycle bootstrap |
| `app-dataset.js` | Demo-data loading |
| `app-route-state.js` | Snapshot-bound route fetching |
| `app-layout.js` | Map and routes workspace layout |
| `app-render-map.js` | Leaflet/map rendering |
| `app-render-routes.js` | Route list and timeline rendering |
| `app-render.js` | Summary, raw data, and score-analysis rendering |
| `generated/ui-model.json` | Generated SolverForge UI model metadata |

---

## Making Your First Customization

Start with a source change that is easy to verify.

### Add a Service Profile

Edit `src/data/bergamo_profiles.rs` and add a new recurring service profile.
Then run:

```bash
make test
```

The next `STANDARD` generated plan will cycle through the expanded profile set.

### Add a Technician

Edit `src/data/bergamo_technicians.rs`. Give the technician:

- a stable `id`
- display `name`
- route `color`
- start and end depot indexes
- skill and inventory masks
- territory

Then adjust `DemoData::technician_count()` in `src/data/data_seed.rs` if you
want the new technician included in the standard demo.

### Tune the Search Policy

Edit `solver.toml`. For example, increase `seconds_spent_limit` when you want
the local-search phase to spend more time improving the route plan.

### Add a Constraint

Use the generator for the module seam:

```bash
solverforge generate constraint emergency_response --unary --hard
```

The generator declares the module in `src/constraints/mod.rs` and appends
`super::emergency_response::constraint()` to `create_constraints` in
`src/constraints/assemble.rs`. Its placeholder
panics on every solve until you implement the rule in
`src/constraints/emergency_response.rs`. If the rule needs another whole-route
measurement, add it to `RouteStats`, copy it through
`TechnicianRoute::apply_route_stats()`, and score the resulting shadow field
from a stock `ConstraintFactory` stream. Keep hard constraints for requirements
and soft constraints for preferences.

---

## Testing and Validation

Run these from the finished app's directory. To list the Makefile targets:

```bash
make help
```

The browser tests use the Playwright version pinned in the app's own
`package-lock.json`. Install it once per clone, then run the standard
validation:

```bash
make install-e2e
make test
```

`make install-e2e` uses the system Chromium at `/usr/bin/chromium` when there is
one and otherwise downloads Playwright's bundled Chromium. `make test` runs the
Rust tests, frontend syntax checks, frontend Node tests, and the Playwright
browser tests against a release build. Browser test servers honor
`CARGO_TARGET_DIR`, so a shared Cargo build location works as well as the
app-local `target` directory.

For linting:

```bash
make lint
```

For local Space readiness:

```bash
make ci-local
```

`make ci-local` runs formatting, Clippy, release build, tests, and Docker image
build. It requires Docker.

To build and run the Hugging Face Space image locally:

```bash
make space-build
make space-run
```

For a quick HTTP smoke check after starting the server:

```bash
curl http://localhost:7860/health
curl http://localhost:7860/info
curl http://localhost:7860/demo-data
```

---

## Quick Reference

| Topic | File |
| ----- | ---- |
| Tagged app release | `solverforge-fsr@3.0.4` |
| App contract | `solverforge.app.toml` |
| Solver policy | `solver.toml` |
| Solution root | `src/domain/field_service_plan.rs` |
| List planning variable | `src/domain/technician_route.rs` |
| Route shadows and scoring counters | `src/domain/route_metrics.rs` |
| Service jobs | `src/domain/service_visit.rs` |
| Road-network matrix facts | `src/domain/travel_leg.rs` |
| Demo data and route preparation | `src/data/data_seed.rs` |
| Constraints | `src/constraints/` |
| Constraint assembly | `src/constraints/assemble.rs` |
| Retained API | `src/api/routes.rs` |
| Route geometry DTO | `src/api/route_dto.rs` |
| Route geometry builder | `src/api/route_geometry.rs` |
| Solver manager wrapper | `src/solver/service.rs` |
| Browser workspace | `static/` |
| Space build | `Dockerfile` |

Related docs:

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/)
- [SolverForge Maps Getting Started](/docs/solverforge-maps/getting-started/)
- [SolverForge UI Getting Started](/docs/solverforge-ui/getting-started/)
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
