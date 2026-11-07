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

- install `solverforge-cli` and build a small timetable app from the neutral
  scaffold, then solve it
- run the complete Lessons app from its Hugging Face Space repository
- read the finished app's SolverForge 0.24.0 dependency shape
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
- Node.js and npm for the finished app's frontend checks and browser tests
- Docker if you want to build or run the Hugging Face Space image locally

---

## Getting Started

### Install the CLI

```bash
cargo install solverforge-cli --force
solverforge --version
```

`solverforge --version` prints the CLI version and the runtime it scaffolds.
This page uses `solverforge-cli 3.8.3`, which scaffolds `solverforge 0.24.0` and
`solverforge-ui 0.9.1`.

### Build a Timetable from the CLI

This path builds a small lesson timetable from the neutral scaffold: two
scalar planning variables, hard, medium, and soft rules, and demo data you can
solve in the browser. It keeps the finished app's names so you can compare the
two side by side, but it models less: teachers and groups are plain names on
each lesson rather than facts with availability calendars.

Start from an empty working directory:

```bash
solverforge new solverforge-lessons --quiet
cd solverforge-lessons
solverforge generate score HardMediumSoftScore
solverforge generate fact timeslot \
  --field day_of_week:Weekday \
  --field start_time:NaiveTime \
  --field end_time:NaiveTime
solverforge generate fact room \
  --field kind:RoomKind \
  --field capacity:usize \
  --field index:usize
solverforge generate entity lesson \
  --field subject:String \
  --field teacher:String \
  --field group:String \
  --field student_count:usize \
  --field required_room_kind:RoomKind
solverforge generate variable timeslot_idx \
  --entity Lesson \
  --kind scalar \
  --range timeslots
solverforge generate variable room_idx \
  --entity Lesson \
  --kind scalar \
  --range rooms
solverforge generate constraint assign_timeslot --unary --soft
solverforge generate constraint assign_room --unary --soft
solverforge generate constraint no_teacher_conflict --pair --hard
solverforge generate constraint no_group_conflict --pair --hard
solverforge generate constraint no_room_conflict --pair --hard
solverforge generate constraint room_capacity --join --hard
solverforge generate constraint room_kind --join --soft
```

`generate fact` adds `id` and `name` to every fact on its own, so the commands
pass only the extra fields. `Weekday` and `NaiveTime` come from `chrono`, which
the CLI imports and adds to `Cargo.toml`. `RoomKind` is this app's own type: the
CLI warns that it is not defined yet, and the next step defines it. `Room.index`
is the room's position in `Plan.rooms`, which is the value `Lesson.room_idx`
stores, so constraints can join a lesson to its room.

Define `RoomKind` in its own domain file:

```rust
// file: src/domain/room_kind.rs
use serde::{Deserialize, Serialize};

/// The kind of teaching space a subject needs.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum RoomKind {
    #[default]
    Lecture,
    Laboratory,
    Computer,
}
```

Export it from the planning model manifest. Replace `src/domain/mod.rs` with:

```rust
// file: src/domain/mod.rs
solverforge::planning_model! {
    root = "src/domain";

    // @solverforge:begin domain-exports
    mod room_kind;
    mod timeslot;
    mod room;
    mod lesson;
    mod plan;

    pub use room_kind::RoomKind;
    pub use timeslot::Timeslot;
    pub use room::Room;
    pub use lesson::Lesson;
    pub use plan::Plan;
    // @solverforge:end domain-exports
}
```

Every generated constraint starts with a placeholder that panics, so a solve
fails until each one is replaced. Replace the seven generated files with the
rules below.

The two assignment rules score at the medium level. They are generated as soft
skeletons because the generator emits only `--hard` and `--soft`:

```rust
// file: src/constraints/assign_timeslot.rs
use crate::domain::{Lesson, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// MEDIUM: every lesson needs a timeslot.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::lessons())
        .filter(|lesson: &Lesson| lesson.timeslot_idx.is_none())
        .penalize(|_: &Lesson| HardMediumSoftScore::of_medium(1))
        .named("assign_timeslot")
}
```

```rust
// file: src/constraints/assign_room.rs
use crate::domain::{Lesson, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// MEDIUM: every lesson needs a room.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::lessons())
        .filter(|lesson: &Lesson| lesson.room_idx.is_none())
        .penalize(|_: &Lesson| HardMediumSoftScore::of_medium(1))
        .named("assign_room")
}
```

The three conflict rules self-join lessons that share a timeslot. The joiner
pairs each two lessons once, and the filter decides whether that pair is a
conflict:

```rust
// file: src/constraints/no_teacher_conflict.rs
use crate::domain::{Lesson, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: a teacher teaches one lesson per timeslot.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::lessons())
        .filter(|lesson: &Lesson| lesson.timeslot_idx.is_some())
        .join(joiner::equal(|lesson: &Lesson| lesson.timeslot_idx))
        .filter(|left: &Lesson, right: &Lesson| left.teacher == right.teacher)
        .penalize(hard_weight(|_: &Lesson, _: &Lesson| HardMediumSoftScore::of_hard(1)))
        .named("no_teacher_conflict")
}
```

```rust
// file: src/constraints/no_group_conflict.rs
use crate::domain::{Lesson, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: a student group attends one lesson per timeslot.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::lessons())
        .filter(|lesson: &Lesson| lesson.timeslot_idx.is_some())
        .join(joiner::equal(|lesson: &Lesson| lesson.timeslot_idx))
        .filter(|left: &Lesson, right: &Lesson| left.group == right.group)
        .penalize(hard_weight(|_: &Lesson, _: &Lesson| HardMediumSoftScore::of_hard(1)))
        .named("no_group_conflict")
}
```

```rust
// file: src/constraints/no_room_conflict.rs
use crate::domain::{Lesson, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: a room hosts one lesson per timeslot.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::lessons())
        .filter(|lesson: &Lesson| lesson.timeslot_idx.is_some())
        .join(joiner::equal(|lesson: &Lesson| lesson.timeslot_idx))
        .filter(|left: &Lesson, right: &Lesson| left.room_idx.is_some() && left.room_idx == right.room_idx)
        .penalize(hard_weight(|_: &Lesson, _: &Lesson| HardMediumSoftScore::of_hard(1)))
        .named("no_room_conflict")
}
```

The two room rules join each lesson to the room its `room_idx` points at:

```rust
// file: src/constraints/room_capacity.rs
use crate::domain::{Lesson, Plan, Room};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// HARD: the room seats every student in the lesson.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::lessons())
        .join((
            Plan::rooms(),
            equal_bi(|lesson: &Lesson| lesson.room_idx, |room: &Room| Some(room.index)),
        ))
        .filter(|lesson: &Lesson, room: &Room| lesson.student_count > room.capacity)
        .penalize(hard_weight(|_: &Lesson, _: &Room| HardMediumSoftScore::of_hard(1)))
        .named("room_capacity")
}
```

```rust
// file: src/constraints/room_kind.rs
use crate::domain::{Lesson, Plan, Room};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// SOFT: the room matches the kind the subject needs.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardMediumSoftScore> {
    ConstraintFactory::<Plan, HardMediumSoftScore>::new()
        .for_each(Plan::lessons())
        .join((
            Plan::rooms(),
            equal_bi(|lesson: &Lesson| lesson.room_idx, |room: &Room| Some(room.index)),
        ))
        .filter(|lesson: &Lesson, room: &Room| lesson.required_room_kind != room.kind)
        .penalize(|_: &Lesson, _: &Room| HardMediumSoftScore::of_soft(1))
        .named("room_kind")
}
```

The generated sample data fills every field with placeholders. Replace it with
a small weekly timetable: 20 timeslots from Monday to Friday, four rooms, and
ten lessons per student group (one group for `SMALL`, two for `STANDARD`, three
for `LARGE`):

```rust
// file: src/data/data_seed.rs
use std::str::FromStr;

use chrono::{NaiveTime, Weekday};

use crate::domain::{Lesson, Plan, Room, RoomKind, Timeslot};

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

/// Subjects with the teacher who teaches them, the room kind they need,
/// and how many lessons each group takes per week.
const SUBJECTS: &[(&str, &str, RoomKind, usize)] = &[
    ("Mathematics", "A. Turing", RoomKind::Lecture, 3),
    ("Physics", "M. Curie", RoomKind::Laboratory, 2),
    ("Chemistry", "M. Curie", RoomKind::Laboratory, 1),
    ("Computer Science", "G. Hopper", RoomKind::Computer, 2),
    ("History", "I. Jones", RoomKind::Lecture, 1),
    ("English", "J. Austen", RoomKind::Lecture, 1),
];

const DAYS: [Weekday; 5] = [
    Weekday::Mon,
    Weekday::Tue,
    Weekday::Wed,
    Weekday::Thu,
    Weekday::Fri,
];

pub fn generate(demo: DemoData) -> Plan {
    match demo {
        DemoData::Small => generate_plan(1),
        DemoData::Standard => generate_plan(2),
        DemoData::Large => generate_plan(3),
    }
}

fn generate_plan(group_count: usize) -> Plan {
    let mut timeslots = Vec::new();
    for day in DAYS {
        for hour in 8..12 {
            let start = NaiveTime::from_hms_opt(hour, 30, 0).unwrap();
            let end = NaiveTime::from_hms_opt(hour + 1, 30, 0).unwrap();
            let idx = timeslots.len();
            timeslots.push(Timeslot::new(
                format!("timeslot-{idx}"),
                format!("{day} {start}"),
                day,
                start,
                end,
            ));
        }
    }

    let rooms = vec![
        Room::new("room-0", "Room A", RoomKind::Lecture, 30, 0),
        Room::new("room-1", "Room B", RoomKind::Lecture, 30, 1),
        Room::new("room-2", "Lab", RoomKind::Laboratory, 30, 2),
        Room::new("room-3", "Computer room", RoomKind::Computer, 30, 3),
    ];

    let mut lessons = Vec::new();
    for group in 0..group_count {
        let group_name = format!("Grade {}", 9 + group);
        for (subject, teacher, room_kind, per_week) in SUBJECTS {
            for _ in 0..*per_week {
                let idx = lessons.len();
                lessons.push(Lesson::new(
                    format!("lesson-{idx}"),
                    subject.to_string(),
                    teacher.to_string(),
                    group_name.clone(),
                    25,
                    *room_kind,
                ));
            }
        }
    }

    Plan::new(timeslots, rooms, lessons)
}
```

The scaffold's `solver.toml` declares no phases, so the runtime picks a
default pipeline. Replace it with the finished app's policy: cheapest-insertion
construction places each lesson where it adds the least penalty, then late
acceptance improves the timetable until 30 seconds have passed (see
[Solver Policy](#solver-policy)):

```toml
# file: solver.toml
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

The policy stops each solve after 30 seconds. The job then
reports `"lifecycleState":"COMPLETED"` with a `0hard` score: every lesson has a
timeslot and a room, and no teacher, group, or room is double-booked. The
analysis lists each rule by its module name with its `weightMultiplier`, score,
and match count.

### Run the Finished Example

The finished app lives in the Hugging Face Space repository. If you are still
inside the scaffold from the previous section, step out of it first, then
clone the Space into its own directory and start it:

```bash
cd ..
git clone https://huggingface.co/spaces/SolverForge/solverforge-lessons solverforge-lessons-space
cd solverforge-lessons-space
make run-release
```

Open:

```text
http://localhost:7860
```

The Space source is the reference implementation. It includes the deterministic
lesson dataset, retained API, timetable browser workspace, score analysis
surface, Docker build, and validation commands.

The browser first reads `/demo-data`, verifies that its default id is present in
the advertised catalog, and then loads `/demo-data/LARGE`. It renders retained
solve controls, score status, cohort timetables, room views, teacher views, raw
data, and the visible REST API guide. A catalog mismatch is shown as a bootstrap
error and leaves Solve disabled instead of guessing a dataset.

### Inspect Demo Data

With the finished app running, list the available demos:

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

### Published Dependency Shape

The tagged `solverforge-lessons@3.0.0` release targets the published
SolverForge 0.24.0 line:

```toml
[dependencies]
solverforge = { version = "0.24.0", features = ["serde", "console", "verbose-logging"] }
solverforge-ui = { version = "0.9.0" }
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
The finished app records `solverforge 0.24.0` as its runtime while keeping the
`2.2.2` CLI version it was first scaffolded with:

```toml
[app]
name = "solverforge-lessons"
starter = "neutral-shell"
cli_version = "2.2.2"
shell = "web"

[runtime]
target = "solverforge 0.24.0"
runtime_source = "crates.io: solverforge 0.24.0"
ui_source = "crates.io: solverforge-ui 0.9.0"

[demo]
default_size = "LARGE"
available_sizes = [
    "LARGE",
]

[solution]
name = "Plan"
score = "HardMediumSoftScore"
```

### What the Finished App Adds

Compared with the CLI build above, the Lessons repository supplies the full
timetable:

- weekdays, school-day timeslots, teachers, cohorts, rooms, and lesson demand
- `Teacher` and `Group` facts with weekly availability calendars, joined to
  lessons by index
- `RoomKind` and subject catalogs that tie lessons to room types
- `Plan::rebuild_derived_fields()` to normalize indexes after transport
- hard rules for teacher, group, room, capacity, and availability conflicts,
  matched on overlapping times rather than equal timeslot indexes
- soft rules for room-kind fit, late lessons, and repeated same-day subjects
- a tuned `solver.toml` and a browser workspace with group, room, teacher, raw
  data, and API views

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

Run these from the finished app's directory. The browser tests use the
Playwright version pinned in the app's own `package-lock.json`; install it once
per clone:

```bash
make install-e2e
```

`make install-e2e` uses the system Chromium at `/usr/bin/chromium` when there is
one and otherwise downloads Playwright's bundled Chromium. Browser test servers
honor `CARGO_TARGET_DIR`, so a shared Cargo build location works as well as the
app-local `target` directory.

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

`make test` runs the Rust tests, frontend syntax checks, the frontend Node
tests, and a Playwright browser smoke against a release build. `make ci-local`
adds formatting, clippy, a release build, and the Docker image build, so it
needs Docker. `make test-slow` solves the `LARGE` instance in the release
profile and checks that the timetable is feasible. `make pre-release` runs
`ci-local` plus the slow acceptance solve.

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
| Tagged app release | `solverforge-lessons@3.0.0` |
| Local run | `make run-release` |
| Browser test setup | `make install-e2e` |
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
