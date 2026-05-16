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

- install `solverforge-cli` and scaffold a neutral SolverForge app
- know when to switch from the learning scaffold to the complete FSR Space
  repository
- keep the published SolverForge 0.14.0 dependency shape
- understand why field-service routing uses a list planning variable
- follow the current `Location`, `ServiceVisit`, `TravelLeg`,
  `TechnicianRoute`, and `FieldServicePlan` model
- see where Bergamo OSM data becomes the travel-leg matrix used by constraints
- read the ten route constraints in their intended order
- use retained jobs, snapshots, analysis, SSE, and `/jobs/{id}/routes`
- validate the app locally before publishing the Space

**No dispatch or route-optimization background required**. The article keeps
the domain concepts explicit and points to the exact source files that carry
the full implementation.

### Prerequisites

- Rust `1.95+`, matching the current published SolverForge app line
- `cargo` and a stable Rust toolchain
- Basic Rust knowledge: structs, enums, traits, modules, derive macros
- Familiarity with HTTP APIs
- Node.js if you want frontend syntax validation
- Docker if you want to run the Hugging Face Space image locally

---

## Getting Started

### Start with the Generic CLI Shell

Start from an empty working directory:

```bash
cargo install solverforge-cli --force
solverforge --version
solverforge new solverforge-fsr --quiet
cd solverforge-fsr
```

Those commands give you the neutral scaffold. It is runnable, but it is not the
field-service app yet. The finished FSR app specializes that scaffold into a
road-network technician-routing application through manual domain, routing,
constraint, API, and browser code.

Right after scaffolding, the generated project already gives you:

- a runnable Axum server
- retained `/jobs` routes and solver lifecycle controls
- a planning solution, score field, solver config, and generated seams
- `solverforge-ui` integration
- a neutral frontend shell
- compiler-owned sample-data and codegen markers

Use the fresh scaffold as the learning workspace. Use the finished Space
repository when you want the complete Bergamo dataset, routing preparation,
route geometry, constraints, frontend, Dockerfile, and validation pipeline.

### Download the Finished Example

Clone the finished app from the Hugging Face Space repository:

```bash
git clone https://huggingface.co/spaces/SolverForge/solverforge-fsr
cd solverforge-fsr
```

The Space source is the reference implementation. It includes the Bergamo
technicians, service locations, OSM routing setup, retained API, map workspace,
score analysis surface, route tables, Docker build, and tests.

### Keep the Published Dependency Shape

The current tutorial targets the published SolverForge 0.14.0 line:

```toml
[dependencies]
solverforge = { version = "0.14.0", features = [
  "serde",
  "console",
  "verbose-logging",
] }
solverforge-core = "0.14.0"
solverforge-ui = "0.6.5"
solverforge-maps = "2.1.4"

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

`solverforge-core` is a direct dependency because this app writes custom
incremental constraints that hold `ConstraintRef`. Most generated applications
only need the top-level `solverforge` facade.

The app contract in `solverforge.app.toml` names the app-owned runtime target.
`solverforge-cli 2.0.4` still scaffolds `solverforge 0.11.1`, so upgrade this
metadata with the dependency when following the current tutorial:

```toml
[app]
name = "solverforge-fsr"
starter = "neutral-shell"
cli_version = "2.0.4"

[runtime]
target = "solverforge 0.14.0"
runtime_source = "crates.io: solverforge 0.14.0"
ui_source = "crates.io: solverforge-ui 0.6.5"
maps_source = "crates.io: solverforge-maps 2.1.4"

[demo]
default_size = "standard"
available_sizes = ["standard"]

[solution]
name = "FieldServicePlan"
score = "HardSoftScore"
```

### Generate the Managed Seams

The CLI can create the repeatable app seams:

```bash
solverforge generate fact location
solverforge generate fact service_visit
solverforge generate fact travel_leg
solverforge generate entity technician_route
solverforge generate variable visits \
  --entity TechnicianRoute \
  --kind list \
  --elements service_visits

solverforge generate constraint assigned_visits --unary --hard
solverforge generate constraint reachable_legs --unary --hard
solverforge generate constraint required_skills --unary --hard
solverforge generate constraint required_parts --unary --hard
solverforge generate constraint shift_capacity --unary --hard
solverforge generate constraint time_windows --unary --hard
solverforge generate constraint minimize_travel --unary --soft
solverforge generate constraint balance_workload --unary --soft
solverforge generate constraint territory_affinity --unary --soft
solverforge generate constraint priority_slack --unary --soft
```

Those commands are the learning skeleton, not the full finished app. The FSR
repository then supplies the field-service-specific work:

- Bergamo depots, customer locations, technician profiles, visit profiles, and
  catalog masks
- the road-network fetch and matrix build using `solverforge-maps`
- `TravelLeg` facts derived from matrix duration, distance, and reachability
- custom incremental constraints over whole technician routes
- `/jobs/{id}/routes` for snapshot-bound map geometry
- a browser workspace with map, route list, timeline, raw data, and score
  analysis views
- Docker/Space validation commands

### Run the Finished App

From the finished repository:

```bash
make run-release
```

Open:

```text
http://localhost:7860
```

The first run may need to fetch and cache Bergamo OSM data. The app cache path
is:

```text
.osm_cache/field-service-routing/bergamo
```

To inspect the command surface:

```bash
make help
```

To run the Hugging Face Space image locally:

```bash
make space-build
make space-run
```

### Inspect Demo Data

List available demos:

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
5. `TravelLeg` stores matrix duration, distance, and reachability.
6. `FieldServicePlan` is the planning solution.
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
| `technician_route.rs` | Planning entity for technician identity, depot indexes, shift bounds, maximum route minutes, skill mask, inventory mask, territory, and `visits` |
| `field_service_plan.rs` | Planning solution with `locations`, `service_visits`, `travel_legs`, `technician_routes`, and `score` |
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
- slack for high-priority visits

A plan with `0hard/-420soft` is feasible on the hard rules and better than
`0hard/-600soft`, because both satisfy hard constraints and the first loses
less soft score.

---

## Writing Constraints

Open `src/constraints/`.

`create_constraints()` assembles ten rules:

| Constraint | Type | Purpose |
| ---------- | ---- | ------- |
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

Most route constraints share `RouteConstraint`, a custom incremental constraint
adapter that evaluates one technician route at a time and reports standard
SolverForge score-analysis metadata. `assigned_visits` is separate because it
must reason about coverage across all routes.

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

[termination]
seconds_spent_limit = 60
```

Local search uses a round-robin union of list moves:

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

Then implement the rule in `src/constraints/emergency_response.rs` and add it
to the assembled constraint set. Keep hard constraints for requirements and soft
constraints for preferences.

---

## Testing and Validation

Use the finished repository's Makefile:

```bash
make test
```

That runs Rust tests and frontend syntax checks.

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
| App contract | `solverforge.app.toml` |
| Solver policy | `solver.toml` |
| Solution root | `src/domain/field_service_plan.rs` |
| List planning variable | `src/domain/technician_route.rs` |
| Service jobs | `src/domain/service_visit.rs` |
| Road-network matrix facts | `src/domain/travel_leg.rs` |
| Demo data and route preparation | `src/data/data_seed.rs` |
| Constraints | `src/constraints/` |
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
