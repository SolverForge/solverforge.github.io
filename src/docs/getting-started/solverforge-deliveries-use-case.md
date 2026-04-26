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
10. [API, Routes, and Browser State](#api-routes-and-browser-state)
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
- scaffold a neutral app with `solverforge new`
- know when to switch from the learning scaffold to the complete Hugging Face
  example
- generate the managed fact, entity, list variable, data, and constraint seams
- manually code the delivery-routing domain on top of those seams
- replace the generic scaffold sample data with the three delivery city datasets:
  `PHILADELPHIA`, `HARTFORD`, and `FIRENZE`
- understand why delivery routing uses a list planning variable
- follow the current `Delivery`, `Vehicle`, and `Plan` model
- connect map preparation, route shadows, constraints, and previews
- use the retained `/jobs` lifecycle plus `/jobs/{id}/routes`
- study `/recommendations/delivery-insertions` as an interactive optimization
  surface

**No routing or optimization background required**. The article explains the
end-to-end pipeline. The code comments explain the local reason each function,
hook, cache, and route exists.

### Prerequisites

- Basic Rust knowledge: structs, enums, traits, derive macros, modules
- Familiarity with HTTP APIs
- Comfort with command-line work
- Node.js if you want to run the frontend and browser tests
- Rust `1.95+`, matching the current published `solverforge` crate line

---

## Getting Started

### Start with the Generic CLI Shell

Start from an empty working directory:

```bash
cargo install solverforge-cli --force
solverforge --version
solverforge new solverforge-deliveries --quiet
cd solverforge-deliveries
```

Those commands give you the neutral scaffold. It is runnable, but it is not the
delivery app yet. The current delivery app specializes that generated project
into list-variable vehicle routing through manual domain, routing, API, and
frontend code.

Right after scaffolding, the generated project already contains:

- a neutral `Plan` and `HardSoftScore`
- retained `/jobs` routes, status, snapshot, analysis, pause, resume, cancel,
  delete, and SSE
- published SolverForge core, UI, and maps dependencies
- a neutral frontend in `static/app.js`
- compiler-owned sample data in `src/data/data_seed.rs`

Use this fresh scaffold as the learning workspace for the generator commands and
the ownership boundaries below. Use the finished example when you want the full
city data generators, map-backed routes, complete frontend, and tested
application.

### Download the Finished Example

If you want the complete reference implementation instead of rebuilding it step
by step, download the Hugging Face Space repository:

```bash
git clone https://huggingface.co/spaces/SolverForge/solverforge-deliveries
cd solverforge-deliveries
```

The Space source is the finished app: it includes the Philadelphia, Hartford,
and Firenze data generators, route-preparation pipeline, map/timeline frontend,
recommendation endpoint, tests, and deployment files. The tutorial below
explains how that app is assembled from the CLI scaffold plus manual
delivery-routing code.

### Keep the Published Dependency Shape

The CLI emits the current public crate line. Keep those published dependencies
and add the delivery app's normal web/runtime dependencies:

```toml
[dependencies]
solverforge = { version = "0.9.1", features = [
  "serde",
  "console",
  "verbose-logging",
] }
solverforge-ui = "0.6.3"
solverforge-maps = "2.1.3"
```

Fresh scaffolds also start with generic demo sample data:
`SMALL`, `STANDARD`, and `LARGE`. Those sizes are useful for proving the shell,
but they are not the delivery-routing datasets. The finished tutorial app
replaces the generated seed flow with app-owned city visits and records that
delivery-specific catalog in `solverforge.app.toml`:

```toml
[app]
name = "solverforge-deliveries"
starter = "neutral-shell"
cli_version = "2.0.1"

[runtime]
target = "solverforge 0.9.1"
runtime_source = "crates.io: solverforge 0.9.1"
ui_source = "crates.io: solverforge-ui 0.6.3"
maps_source = "crates.io: solverforge-maps 2.1.3"

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

That metadata matters because this example teaches the current public
integration: SolverForge core, SolverForge UI, and SolverForge Maps working
together in one released-crate app.

### Generate the Managed Seams

Use the CLI to create the parts SolverForge can safely own:

```bash
solverforge generate fact delivery \
  --field label:String \
  --field kind:DeliveryKind \
  --field lat:CoordValue \
  --field lng:CoordValue \
  --field demand:i32 \
  --field min_start_time:i64 \
  --field max_end_time:i64 \
  --field service_duration:i64
solverforge generate entity vehicle \
  --field name:String \
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
solverforge generate data --mode stub
```

Those commands are not the final app. They create the managed anchors. They do
not generate the city data, map-backed route pipeline, insertion endpoint, or
finished frontend. The app code then supplies the routing meaning:

- keep the scaffolded `Plan` as the solution root
- replace the generated `Delivery` fact with stop data, coordinates, demand, and
  time windows
- replace the generated `Vehicle` entity with depot data, the `delivery_order`
  list variable, CVRP hook attributes, and route shadow fields
- expand `Plan` with `routing_mode`, `view_state`, route preparation caches, and
  the list-variable shadow update hook
- add `CoordValue`, preview types, and `src/domain/route_metrics/`
- replace the generated constraint skeletons with the four route rules
- replace the generated `SMALL`/`STANDARD`/`LARGE` sample-data seed with the
  Philadelphia, Hartford, and Firenze demo seeds
- split the neutral frontend into the finished map, timeline, route-list, raw
  data, analysis, and recommendation modules

That is the teaching boundary: the CLI owns repeatable project seams, while the
manual code owns delivery-routing semantics. When you want to see every manual
line in context, keep the Space checkout open next to this article.

### Run the Finished App

After the manual code is in place, validate the project and start the server:

```bash
solverforge check
solverforge routes
cargo run --release --bin solverforge_deliveries
```

Then open:

```text
http://localhost:7860
```

The browser loads the default Philadelphia plan and renders retained solve
controls, route summaries, a map, timelines, raw data, analysis, and insertion
recommendations.

### Inspect Demo Data

List the available demos:

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
6. CVRP hooks let SolverForge construction and k-opt read those caches.
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
  planning solution, routing mode, list shadow refresh, and CVRP solution hooks
- `preview.rs`
  browser-facing preview state
- `route_metrics/`
  preparation, CVRP hooks, metrics, scoring previews, route geometry, and
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
        solution_trait = "crate::domain::DeliveryRoutingSolution",
        distance_meter = "solverforge::cvrp::MatrixDistanceMeter",
        intra_distance_meter = "solverforge::cvrp::MatrixIntraDistanceMeter"
    )]
    pub delivery_order: Vec<usize>,
}
```

The real attribute in the repo names the full set of Clarke-Wright and k-opt
hooks. Those hook comments explain the local contract. The article-level point
is simpler: the route is an ordered list of delivery IDs, not a copied list of
delivery structs.

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
5. attach `ProblemData` for SolverForge CVRP hooks
6. attach `PreparedVehicleRouting` for app route shadows and previews

In `road_network` mode, preparation uses `solverforge-maps` to load or fetch a
road graph and compute matrix data. In `straight_line` mode, it uses fast draft
geometry with the same app shape.

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

For beginners, this is the difference between writing one greedy dispatcher and
building a search space. The solver starts from a route plan and repeatedly asks
which route edit improves the score.

---

## API, Routes, and Browser State

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

### Routing Modes

The selected `routingMode` travels with the submitted plan.

- `road_network`
  default map-backed mode using `solverforge-maps`
- `straight_line`
  draft/testing mode that keeps the same API and UI shape with faster geometry

In `straight_line`, both preview scoring and solve submission use draft
geometry. In `road_network`, both use map-backed travel data.

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

### Try Straight-Line Routing

For quick model experiments, submit a plan with `routingMode = "straight_line"`.
It is not a replacement for road-network validation, but it is useful when you
are checking domain, API, and UI behavior before paying full road-preparation
cost.

---

## Testing and Validation

After you have cloned the finished example, or after your manual build-out
matches it, run the foundational checks from the app root:

```bash
solverforge check
solverforge routes
cargo fmt --check
cargo test
```

`solverforge check` validates the app metadata and model wiring. `solverforge
routes` confirms that the retained lifecycle and delivery-specific endpoints are
visible from the generated Axum route surface.

In the finished example repository, the convenience target is:

```bash
make test
```

That target adds frontend module syntax checks, browserless frontend model tests,
and Playwright browser tests.

Run the full example gate before publishing or updating the hosted demo:

```bash
make ci-local
```

`make ci-local` runs format check, clippy, release build, the standard test
surface, and the Docker/Space image build.

Run the live road-network smoke when you need to prove the map-backed route
path:

```bash
make test-live-road
```

---

## Quick Reference

| Need                             | File or directory                   |
| -------------------------------- | ----------------------------------- |
| App metadata                     | `solverforge.app.toml`              |
| Solver policy                    | `solver.toml`                       |
| Planning model manifest          | `src/domain/mod.rs`                 |
| Planning solution                | `src/domain/plan.rs`                |
| Delivery fact                    | `src/domain/delivery.rs`            |
| Vehicle entity and list variable | `src/domain/vehicle.rs`             |
| Route preparation and CVRP hooks | `src/domain/route_metrics/`         |
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
- The selected `routingMode` must match the routes the browser is drawing.
- `delete` removes a terminal retained job; `cancel` stops a live or paused one.
- The finished app intentionally uses published crates.io dependencies.

### Additional Resources

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
- [List Variables](/docs/solverforge/modeling/list-variables/)
- [Solver Moves](/docs/solverforge/solver/moves/)
- [solverforge-maps Routing](/docs/solverforge-maps/routing/)
- [solverforge-ui Getting Started](/docs/solverforge-ui/getting-started/)
