---
title: "SolverForge Lessons Use Case"
linkTitle: "Lessons Use Case"
icon: fa-solid fa-school
date: 2026-05-14
weight: 8
description: "A lesson-timetabling worked example that shows teachers, cohorts, rooms, weekly timeslots, two scalar planning variables, retained jobs, and timetable views in one SolverForge app"
categories: [Quickstarts]
tags: [quickstart, rust, timetabling, scheduling]
---

# SolverForge Lessons Use Case

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [The Teaching Spine](#the-teaching-spine)
5. [Understanding the Data Model](#understanding-the-data-model)
6. [The Demo Dataset](#the-demo-dataset)
7. [How Optimization Works](#how-optimization-works)
8. [Writing Constraints](#writing-constraints)
9. [Solver Policy](#solver-policy)
10. [Runtime and Browser Behavior](#runtime-and-browser-behavior)
11. [Testing and Validation](#testing-and-validation)
12. [Quick Reference](#quick-reference)

---

## Introduction

This guide shows how the generic
[`solverforge-cli` Getting Started](/docs/solverforge-cli/getting-started/)
shell becomes `solverforge-lessons`, a lesson-timetabling app for teachers,
student cohorts, rooms, and weekly timeslots. It is the scalar multi-variable
counterpart to the
[SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/):
hospital assigns one employee to each shift, while lessons assign two values to
each lesson.

The app answers one concrete question:

> Given lessons, teachers, student groups, rooms, and weekly timeslots, which
> timeslot and room should each lesson receive?

You will:

- install `solverforge-cli` and scaffold a neutral SolverForge app
- know when to switch from the learning scaffold to the complete Lessons Space
  repository
- keep the checked-in SolverForge 0.18.0 use-case dependency shape
- understand why lesson timetabling uses two scalar planning variables
- follow the current `Timeslot`, `Teacher`, `Group`, `Room`, `Lesson`, and
  `Plan` model
- read the hard, medium, and soft timetable constraints
- use retained jobs, snapshots, analysis, SSE, and browser timetable views
- validate the app locally before publishing the Space

**No timetabling or optimization background required**. The article keeps the
domain concepts explicit and points to the source files that carry the full
implementation.

### Prerequisites

- Rust `1.95+`, matching the checked-in SolverForge use-case runtime line
- `cargo` and a stable Rust toolchain
- Basic Rust knowledge: structs, enums, traits, modules, derive macros
- Familiarity with HTTP APIs
- Node.js if you want frontend syntax and browser validation
- Docker if you want to run the Hugging Face Space image locally

---

## Getting Started

### Start with the Generic CLI Shell

Start from an empty working directory:

```bash
cargo install solverforge-cli --force
solverforge --version
solverforge new solverforge-lessons --quiet
cd solverforge-lessons
```

Those commands give you the neutral scaffold. It is runnable, but it is not the
lesson-timetabling app yet. The finished Lessons app specializes that scaffold
into a school timetable application through manual domain, data, constraint,
API, and browser code.

Right after scaffolding, the generated project already gives you:

- a runnable Axum server
- retained `/jobs` routes and solver lifecycle controls
- a planning solution, score field, solver config, and generated seams
- `solverforge-ui` integration
- a neutral frontend shell
- compiler-owned sample data and codegen markers

Use the fresh scaffold as the learning workspace. Use the finished Space
repository when you want the complete timetable dataset, constraints, frontend,
Dockerfile, and validation pipeline.

### Download the Finished Example

Clone the finished app from the Hugging Face Space repository:

```bash
git clone https://huggingface.co/spaces/SolverForge/solverforge-lessons
cd solverforge-lessons
```

The Space source is the reference implementation. It includes the deterministic
lesson dataset, retained API, timetable browser workspace, score analysis
surface, Docker build, and validation commands.

### Keep the Published Dependency Shape

The tagged `solverforge-lessons@2.0.4` use-case source targets the published
SolverForge 0.18.0 line:

```toml
[dependencies]
solverforge = { version = "0.18.0", features = [
  "serde",
  "console",
  "verbose-logging",
] }
solverforge-ui = { version = "0.6.5" }

# Web server
axum = "0.8.9"
tokio = { version = "1.52.1", features = ["full"] }
tokio-stream = { version = "0.1.18", features = ["sync"] }
tower-http = { version = "0.6.8", features = ["fs", "cors"] }
tower = "0.5.3"

# Serialization
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.149"

# Utilities
uuid = { version = "1.23.1", features = ["v4", "serde"] }
parking_lot = "0.12.5"
chrono = { version = "0.4.44", features = ["serde"] }
```

The app contract in `solverforge.app.toml` names the app-owned runtime target.
`solverforge-cli 2.2.2` scaffolds `solverforge 0.15.2`; the finished Lessons
app records its deliberate `solverforge 0.18.0` runtime target separately:

```toml
[app]
name = "solverforge-lessons"
starter = "neutral-shell"
shell = "web"
cli_version = "2.2.2"

[runtime]
target = "solverforge 0.18.0"
runtime_source = "crates.io: solverforge 0.18.0"
ui_source = "crates.io: solverforge-ui 0.6.5"

[demo]
default_size = "LARGE"
available_sizes = ["LARGE"]

[solution]
name = "Plan"
score = "HardMediumSoftScore"
```

### Generate the Managed Seams

The CLI can create the repeatable app seams:

```bash
solverforge generate score HardMediumSoftScore
solverforge generate fact timeslot \
  --field day_of_week:Weekday \
  --field start_time:NaiveTime \
  --field end_time:NaiveTime
solverforge generate fact teacher \
  --field name:String \
  --field "availability:Vec<bool>"
solverforge generate fact group \
  --field name:String \
  --field student_count:usize \
  --field "availability:Vec<bool>"
solverforge generate fact room \
  --field name:String \
  --field kind:RoomKind \
  --field capacity:usize
solverforge generate entity lesson \
  --field subject:String \
  --field group_idx:usize \
  --field student_count:usize \
  --field "teacher_idx:Option<usize>" \
  --field duration:u32 \
  --field required_room_kind:RoomKind
solverforge generate variable timeslot_idx \
  --entity Lesson \
  --kind scalar \
  --range timeslots
solverforge generate variable room_idx \
  --entity Lesson \
  --kind scalar \
  --range rooms

solverforge generate constraint assign_timeslot --unary --medium
solverforge generate constraint assign_room --unary --medium
solverforge generate constraint teacher_availability --join --hard
solverforge generate constraint group_availability --join --hard
solverforge generate constraint room_kind --join --soft
solverforge generate constraint room_capacity --join --hard
solverforge generate constraint no_teacher_conflict --pair --hard
solverforge generate constraint no_group_conflict --pair --hard
solverforge generate constraint no_room_conflict --pair --hard
solverforge generate constraint late_lesson --join --soft
solverforge generate constraint repeated_subject_day --pair --soft
solverforge generate data --mode stub
```

Those commands are the learning skeleton, not the full finished app. The
Lessons repository then supplies the timetable-specific work:

- weekdays, school-day timeslots, teachers, cohorts, rooms, and lesson demand
- `RoomKind` and subject catalogs that tie lessons to room types
- `Lesson.timeslot_idx` and `Lesson.room_idx` as scalar planning variables
- `Plan::rebuild_derived_fields()` to normalize indexes after transport
- hard rules for teacher, group, room, capacity, and availability conflicts
- medium rules that push every lesson toward a timeslot and a room
- soft rules for room-kind fit, late lessons, and repeated same-day subjects
- a browser workspace with group, room, teacher, raw data, and API views

### Run the Finished App

From the finished repository:

```bash
make run-release
```

Open:

```text
http://localhost:7860
```

The browser first reads `/demo-data`, verifies that its default id is present in
the advertised catalog, and then loads `/demo-data/LARGE`. It renders retained
solve controls, score status, cohort timetables, room views, teacher views, raw
data, and the visible REST API guide. A catalog mismatch is shown as a bootstrap
error and leaves Solve disabled instead of guessing a dataset.

### Inspect Demo Data

List available demos:

```bash
curl http://localhost:7860/demo-data
```

Load the public timetable instance:

```bash
curl http://localhost:7860/demo-data/LARGE
```

Current dataset shape:

| Dataset | Lessons | Groups | Timeslots | Rooms | Purpose |
| ------- | ------- | ------ | --------- | ----- | ------- |
| `LARGE` | 300 | 12 | 40 | 10 | Weekly school timetable demo |

The instance starts with every lesson unassigned. Because each lesson has a
timeslot variable and a room variable, the initial medium score is
`0hard/-600medium/0soft`.

---

## The Problem We're Solving

Lesson timetabling asks the solver to make two linked decisions for every
lesson:

- which weekly timeslot the lesson should occupy
- which room should host the lesson

That differs from a one-dimensional assignment problem. Moving a lesson to a
new timeslot can create a teacher conflict, group conflict, or availability
violation. Moving it to a new room can create a room conflict, capacity
violation, or room-kind mismatch. The solver therefore changes both variables
and scores the timetable as one planning solution.

The domain includes the timetable details that make the problem real:

- teachers have availability calendars
- student groups have availability calendars
- rooms have capacity and room kind
- lessons require a subject, teacher, cohort, duration, and room kind
- hard feasibility matters before softer timetable quality

---

## The Teaching Spine

The finished app's core path is:

1. `Timeslot` stores weekly teaching periods.
2. `Teacher` stores teacher names and availability calendars.
3. `Group` stores student cohorts, sizes, and availability calendars.
4. `Room` stores room kind and capacity.
5. `Lesson` is the planning entity.
6. `Lesson.timeslot_idx` is a scalar planning variable.
7. `Lesson.room_idx` is a scalar planning variable.
8. `Plan` is the planning solution.
9. `generate_large()` builds the deterministic public plan.
10. `create_constraints()` assembles the timetable score.
11. `solver.toml` runs construction plus local search.
12. `src/solver/service.rs` exposes retained jobs through `SolverManager`.
13. `src/api/` converts retained jobs into JSON and SSE.
14. `static/` renders the timetable workspace with stock `solverforge-ui`
    assets.

---

## Understanding the Data Model

### Facts

Facts are immutable input data. The solver reads them but does not move them.

| Fact | Purpose |
| ---- | ------- |
| `Timeslot` | Candidate weekly teaching period |
| `Teacher` | Instructor with a weekly availability calendar |
| `Group` | Student cohort with size and availability |
| `Room` | Teaching space with type and capacity |

### Planning Entity

`Lesson` is the thing the solver changes. It carries stable lesson data plus
two mutable choices:

```rust
#[planning_entity]
pub struct Lesson {
    #[planning_id]
    pub id: String,
    pub subject: String,
    pub group_idx: usize,
    pub student_count: usize,
    pub teacher_idx: Option<usize>,
    pub duration: u32,
    pub required_room_kind: RoomKind,
    #[planning_variable(value_range_provider = "timeslots", allows_unassigned = false)]
    pub timeslot_idx: Option<usize>,
    #[planning_variable(value_range_provider = "rooms", allows_unassigned = false)]
    pub room_idx: Option<usize>,
}
```

The index fields point into `Plan.timeslots`, `Plan.rooms`, `Plan.teachers`,
and `Plan.groups`. The app rebuilds those dense indexes after generation and
after JSON decoding so constraints score normalized data.

### Planning Solution

`Plan` holds facts, lesson entities, and the current score:

```rust
#[planning_solution(
    constraints = "crate::constraints::create_constraints",
    solver_toml = "../../solver.toml"
)]
pub struct Plan {
    #[problem_fact_collection]
    pub timeslots: Vec<Timeslot>,
    #[problem_fact_collection]
    pub teachers: Vec<Teacher>,
    #[problem_fact_collection]
    pub groups: Vec<Group>,
    #[planning_entity_collection]
    pub lessons: Vec<Lesson>,
    #[problem_fact_collection]
    pub rooms: Vec<Room>,
    #[planning_score]
    pub score: Option<HardMediumSoftScore>,
}
```

`HardMediumSoftScore` keeps feasibility and completeness separate:

- hard score: timetable rules that must hold
- medium score: missing timeslot or room assignments
- soft score: timetable quality preferences

---

## The Demo Dataset

The `LARGE` dataset is deterministic and intentionally visible:

- 40 weekly timeslots across Monday to Friday
- 20 teachers with subject-specific availability
- 12 student groups
- 300 lessons, based on weekly subject demand per group
- 10 typed rooms

The subject catalog includes English, Mathematics, Physics, Chemistry, Biology,
Computer Science, History, Geography, French, and German. Each subject carries
weekly lesson demand, qualified teachers, and required room kind.

---

## How Optimization Works

The solver starts from an unassigned timetable. Construction assigns candidate
timeslots and rooms when legal candidates exist. Local search then keeps moving
lesson variables to improve the score.

A change can affect several rules at once:

- assigning a timeslot removes one medium penalty
- assigning a room removes one medium penalty
- choosing a bad timeslot can create teacher or group unavailability
- choosing a full or wrong-kind room can create hard or soft penalties
- placing two lessons in the same slot can create teacher, group, or room
  conflicts

The retained job lifecycle lets the browser observe that progress through
status, snapshot, analysis, and SSE events instead of blocking on one request.

---

## Writing Constraints

The finished app keeps one timetable rule per file under `src/constraints/`.

Hard constraints:

- `teacher_availability`: teachers can teach only available timeslots
- `group_availability`: student groups can attend only available timeslots
- `room_capacity`: assigned room capacity must cover the student count
- `no_teacher_conflict`: one teacher cannot teach overlapping lessons
- `no_group_conflict`: one group cannot attend overlapping lessons
- `no_room_conflict`: one room cannot host overlapping lessons

Medium constraints:

- `assign_timeslot`: every lesson should receive a timeslot
- `assign_room`: every lesson should receive a room

Soft constraints:

- `room_kind`: room kind should match the subject requirement
- `late_lesson`: avoid late-day lessons when possible
- `repeated_subject_day`: avoid repeating the same subject twice in one day for
  a cohort

The pair constraints project assigned lessons into compact scoring rows before
matching conflicts. That keeps the conflict checks focused on the fields the
rule actually needs.

---

## Solver Policy

`solver.toml` is embedded by `Plan` and is the runtime source of truth:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "cheapest_insertion"
construction_obligation = "assign_when_candidate_exists"
value_candidate_limit = 40

[[phases]]
type = "local_search"
[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400
[phases.forager]
type = "accepted_count"
limit = 4

[termination]
seconds_spent_limit = 30
```

The policy matches the app shape:

- construction fills the two scalar variables when a legal candidate exists
- the candidate limit bounds construction scans over weekly timeslots and rooms
- late acceptance allows local search to move through temporary soft-score
  regressions
- accepted-count foraging keeps each local-search step bounded
- the public solve stops after 30 seconds

---

## Runtime and Browser Behavior

The Lessons app is one Axum process:

```text
Browser
  |
  | GET /
  v
Axum server in src/main.rs
  |
  | serves /sf/* from solverforge-ui
  | serves static/* from this app
  | exposes /demo-data, /jobs, snapshots, analysis, and SSE
  v
Retained solver service in src/solver/
  |
  | builds demo data from src/data/
  | solves Plan from src/domain/
  | scores constraints from src/constraints/
  v
JSON DTOs and live events in src/api/
```

The browser has views for cohorts, rooms, teachers, raw data, and the REST API.
The Solve button starts a retained job. The status strip reports lifecycle
state, score, and constraint count. Snapshots and analysis are fetched by
revision so the UI can render a consistent timetable and score explanation.

The public API includes:

- `GET /health`
- `GET /info`
- `GET /demo-data`
- `GET /demo-data/{id}`
- `POST /jobs`
- `GET /jobs/{id}`
- `DELETE /jobs/{id}`
- `GET /jobs/{id}/status`
- `GET /jobs/{id}/snapshot`
- `GET /jobs/{id}/analysis`
- `POST /jobs/{id}/pause`
- `POST /jobs/{id}/resume`
- `POST /jobs/{id}/cancel`
- `GET /jobs/{id}/events`

---

## Testing and Validation

Standard validation:

```bash
make test
```

Full local validation:

```bash
make ci-local
```

Slow acceptance solve:

```bash
make test-slow
```

`make test` runs Rust tests, frontend syntax checks, and a Playwright browser
smoke. `make ci-local` adds formatting, clippy, release build, and Docker image
build. `make pre-release` runs `ci-local` plus the slow acceptance solve.

For local Space readiness:

```bash
make space-build
make space-run
```

---

## Quick Reference

| Surface | File or command |
| ------- | --------------- |
| Finished app | [Hugging Face Space](https://huggingface.co/spaces/SolverForge/solverforge-lessons) |
| Tagged app release | `solverforge-lessons@2.0.4` |
| Local run | `make run-release` |
| Standard validation | `make test` |
| Full local validation | `make ci-local` |
| Slow acceptance solve | `make test-slow` |
| App contract | `solverforge.app.toml` |
| Solver policy | `solver.toml` |
| Planning model manifest | `src/domain/mod.rs` |
| Solution root | `src/domain/plan.rs` |
| Planning entity | `src/domain/lesson.rs` |
| Scalar variables | `Lesson.timeslot_idx`, `Lesson.room_idx` |
| Demo data generator | `src/data/data_seed/` |
| Constraints | `src/constraints/` |
| Retained API | `src/api/routes.rs` |
| Solver manager wrapper | `src/solver/service.rs` |
| Browser workspace | `static/` |
| Space build | `Dockerfile` |

Related docs:

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
- [SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/)
- [SolverForge FSR Use Case](/docs/getting-started/solverforge-fsr-use-case/)
- [Planning Entities](/docs/solverforge/modeling/planning-entities/)
- [SolverManager](/docs/solverforge/solver/solver-manager/)
