---
title: "SolverForge Hospital Use Case"
linkTitle: "Hospital Use Case"
icon: fa-brands fa-rust
date: 2026-04-23
weight: 5
description: "A long-form worked example that starts with solverforge-cli and carries one concrete hospital scheduling app through to the current public surface"
categories: [Quickstarts]
tags: [quickstart, rust, hospital]
---

# SolverForge Hospital Use Case

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [Understanding the Data Model](#understanding-the-data-model)
5. [How Optimization Works](#how-optimization-works)
6. [Writing Constraints: The Business Rules](#writing-constraints-the-business-rules)
7. [The Solver Engine](#the-solver-engine)
8. [Web Interface and API](#web-interface-and-api)
9. [Making Your First Customization](#making-your-first-customization)
10. [Advanced Constraint Patterns](#advanced-constraint-patterns)
11. [Testing and Validation](#testing-and-validation)
12. [Quick Reference](#quick-reference)

---

## Introduction

### What You'll Learn

This guide starts from the generic
[`solverforge-cli` Getting Started](/docs/solverforge-cli/getting-started/)
flow, then carries that neutral shell into one concrete hospital scheduling
application.

You will:

- install `solverforge-cli` and verify the scaffold targets carried by your
  binary
- scaffold a neutral app with `solverforge new`
- replace the neutral `HardSoftScore` shell with the current
  `HardSoftDecimalScore` hospital contract
- grow the domain into the current hospital model with `Employee`, `CareHub`,
  `Shift`, and `Plan`
- keep the stock retained `/jobs` lifecycle while landing on the current
  hospital UI and data surface

**No optimization background required**. The tutorial explains the modeling,
runtime, and transport choices as they show up in a real SolverForge app.

### Prerequisites

- Basic Rust knowledge: structs, enums, traits, closures, modules, derive
  macros
- Familiarity with HTTP APIs
- Comfort with command-line work
- Node.js if you want to run the browserless frontend tests at the end

### Start with the Generic CLI Shell

Start with the public CLI flow:

```bash
cargo install solverforge-cli
solverforge --version
solverforge new solverforge-hospital --quiet
cd solverforge-hospital
```

Those commands give you the generic scaffold. The rest of this page begins
there and takes that shell further into one concrete hospital scheduling app.

Right after scaffolding, the generated project already contains:

- a neutral `Plan` and `HardSoftScore`
- retained `/jobs` routes, status, snapshot, analysis, pause, resume, cancel,
  delete, and SSE
- a neutral frontend in `static/app.js`
- compiler-owned sample data in `src/data/data_seed.rs`

### What is Constraint-Based Optimization?

Traditional programming says: "do this, then do that."

**Constraint-based optimization** says: "here is the domain, here are the
rules, here is what better means."

In a hospital scheduler, you usually are not writing one fixed assignment
algorithm by hand. You are describing:

- which employees exist
- which shifts need coverage
- which skills are required
- which assignments are invalid
- which assignments are merely undesirable
- which assignments are locally promising enough to search first

Then the solver searches those assignments and keeps the best retained result.

The power of this approach is that you separate the *what* from the *how*.
You declare the business rules, and the solver figures out how to satisfy them
while optimizing for quality. When the rules change—new labor laws, new
preferences, new skills—you update the constraints, not the search algorithm.

---

## Getting Started

### Replace the Dependency Contract

Switch the neutral scaffold to the current hospital runtime line by replacing
the dependency block in `Cargo.toml`:

```toml
[dependencies]
solverforge = { version = "0.9.0", features = [
  "serde",
  "console",
  "verbose-logging",
] }
solverforge-ui = "0.6.1"
rand = "0.8"

axum = "0.8"
tokio = { version = "1", features = ["full"] }
tokio-stream = { version = "0.1", features = ["sync"] }
tower-http = { version = "0.6", features = ["fs", "cors"] }
tower = "0.5"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
chrono = { version = "0.4", features = ["serde"] }
parking_lot = "0.12"
```

This keeps the app on the published `solverforge` and `solverforge-ui`
surfaces, while dropping scaffold extras that this concrete hospital example
does not use.

Now replace `solverforge.app.toml` with the public metadata shape this hospital
example should teach:

```toml
[app]
name = "SolverForge Hospital"
starter = "neutral-shell"
cli_version = "0.9.0"

[runtime]
target = "SolverForge crates.io target"
runtime_crate = "solverforge"
runtime_version = "0.9.0"
ui_crate = "solverforge-ui"
ui_version = "0.6.1"

[demo]
default_size = "large"
available_sizes = ["large"]

[solution]
name = "Plan"
score = "HardSoftDecimalScore"
```

This keeps the app metadata aligned with the current hospital repo while
switching the concrete app to the hospital score type and one public dataset.

### Replace the Neutral Score Contract First

This step matters.

While the project is still neutral, replace the neutral solution with a `Plan`
that uses `HardSoftDecimalScore`:

```bash
solverforge generate solution plan --score HardSoftDecimalScore
```

That command is the right next step because it retargets the neutral
runtime and DTO surface at the same time.

### Create the Managed Seams

Now use the CLI to create the hospital seams you will hand-finish:

```bash
solverforge generate fact employee
solverforge generate entity shift --field location:String --field required_skill:String
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees --allows-unassigned

solverforge generate constraint assigned_shift --unary --hard
solverforge generate constraint required_skill --join --hard
solverforge generate constraint overlapping_shift --pair --hard

solverforge generate data --mode stub
```

These commands do not finish the app. They do something more important:

- wire the managed blocks the CLI owns
- update `solverforge.app.toml`
- regenerate the compiler-owned data and UI projections
- give you the exact files you now need to replace with hospital-specific code

### Inspect the Starting Point

Run the standard scaffold checks:

```bash
solverforge info
solverforge check
solverforge routes
```

Then boot the server:

```bash
solverforge server --debug
```

Open:

```text
http://localhost:7860
```

You are still looking at the neutral UI shell. That is expected. The rest of
this tutorial replaces the neutral domain, solver policy, data surface, and
browser app until they match the current hospital use case.

### File Structure Overview

After the refactor, the project should look like the current hospital example:

```text
solverforge-hospital/
├── Cargo.toml
├── solver.toml
├── solverforge.app.toml
├── src/
│   ├── api/
│   │   ├── dto.rs
│   │   ├── routes.rs
│   │   └── sse.rs
│   ├── constraints/
│   │   ├── assigned_shift.rs
│   │   ├── balance_assignments.rs
│   │   ├── desired_day.rs
│   │   ├── minimum_rest.rs
│   │   ├── one_shift_per_day.rs
│   │   ├── overlapping_shift.rs
│   │   ├── required_skill.rs
│   │   ├── unavailable_employee.rs
│   │   ├── undesired_day.rs
│   │   └── mod.rs
│   ├── data/
│   │   ├── data_seed.rs
│   │   ├── data_seed/
│   │   │   ├── entrypoints.rs
│   │   │   ├── large.rs
│   │   │   ├── witness.rs
│   │   │   └── ...
│   │   └── mod.rs
│   ├── domain/
│   │   ├── care_hub.rs
│   │   ├── employee.rs
│   │   ├── mod.rs
│   │   └── plan.rs
│   ├── solver/
│   │   └── service.rs
│   ├── lib.rs
│   └── main.rs
└── static/
    ├── app/
    │   ├── main.mjs
    │   ├── schedule/
    │   ├── shell/
    │   └── views/
    ├── generated/ui-model.json
    ├── index.html
    └── sf-config.json
```

Two important differences from the generated shape:

- the final app no longer keeps `Shift` in `src/domain/shift.rs`; the current
  repo folds it into `src/domain/plan.rs`
- the final app no longer keeps the neutral `static/app.js`; it boots from
  `static/app/main.mjs` and a set of focused browser modules

---

## The Problem We're Solving

### Why Hospital Scheduling Matters

Hospital workforce scheduling is one of the most constrained real-world
planning problems. Every day, a hospital must staff dozens of service lines
around the clock. The schedule must satisfy hard regulatory and safety rules
while respecting employee preferences and avoiding burnout.

A manually built schedule often violates rules silently: one nurse works two
overlapping shifts, a critical care slot is filled by someone without the
right certification, or an employee is assigned on a day they marked
unavailable. These errors are expensive. They create overtime, legal exposure,
and staff turnover.

### The Concrete Question

The current hospital example answers one concrete question:

> Given a hospital workforce and a month of shifts, which employee should cover
> each shift?

This is not a toy classroom exercise. The current public demo ships one serious
deterministic dataset:

- 50 employees
- 688 shifts
- one public dataset id: `LARGE`
- retained solve lifecycle with status, snapshot, analysis, pause, resume,
  cancel, delete, and SSE
- two schedule views in the browser: `By location` and `By employee`

### Rules Overview

The current hard and soft rules are:

| Rule | Kind | Meaning |
|------|------|---------|
| Assigned shift | Hard | Every shift should be assigned to someone |
| Required skill | Hard | The assigned employee must have the required skill |
| Overlapping shift | Hard | One employee cannot cover overlapping shifts |
| Minimum rest | Hard | At least 10 hours between two shifts |
| One shift per day | Hard | One employee should not work two shifts on the same touched day |
| Unavailable employee | Hard | Unavailable dates are hard violations |
| Undesired day | Soft | Softly penalize assignments on undesired dates |
| Desired day | Soft | Reward assignments on desired dates |
| Balance assignments | Soft | Discourage concentrating too many shifts on one employee |

The app also adds a search-specific domain signal:

- `CareHub` groups locations and service lines so nearby local search can stay
  in promising neighborhoods

The distinction between hard and soft constraints is central to how the solver
thinks. Hard constraints define feasibility: a schedule that violates a hard
constraint is *broken* and must be fixed. Soft constraints define quality: among
all feasible schedules, the solver prefers those with fewer soft penalties.

---

## Understanding the Data Model

Open `src/domain/`.

The hospital domain is intentionally small. Three files—`care_hub.rs`,
`employee.rs`, and `plan.rs`—contain the entire planning model. Small models
are easier to reason about, easier to test, and easier to extend.

### Domain Model Architecture

The current hospital app splits the domain this way:

- `care_hub.rs`
  search-facing service-line proximity signal
- `employee.rs`
  transport-facing fact model plus derived runtime helpers
- `plan.rs`
  `Shift`, `Plan`, normalization, and nearby distance meters
- `mod.rs`
  exports used by constraints, API DTOs, and the solver service

### CareHub

Create `src/domain/care_hub.rs`:

```rust
use serde::{Deserialize, Serialize};

/// Coarse service-line grouping used to make nearby search meaningful.
///
/// The solver does not understand "hospital geography" by itself. We therefore
/// encode a lightweight domain signal that says which locations and employee
/// skill bundles are close to one another.
#[derive(
    Debug, Clone, Copy, Default, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize,
)]
#[serde(rename_all = "snake_case")]
pub enum CareHub {
    Ambulatory,
    Neurology,
    CriticalCare,
    PediatricCare,
    Surgery,
    Radiology,
    Outpatient,
    #[default]
    Unknown,
}

impl CareHub {
    /// Maps a published shift location label to the hub used by nearby search.
    pub fn from_location(location: &str) -> Self {
        match location {
            "Ambulatory care" => Self::Ambulatory,
            "Neurology" => Self::Neurology,
            "Critical care" => Self::CriticalCare,
            "Pediatric care" => Self::PediatricCare,
            "Surgery" => Self::Surgery,
            "Radiology" => Self::Radiology,
            "Outpatient" => Self::Outpatient,
            _ => Self::Unknown,
        }
    }

    /// Maps a required skill to the hub that most naturally owns that work.
    pub fn from_skill(skill: &str) -> Option<Self> {
        match skill {
            "Ambulatory doctor" | "Ambulatory nurse" => Some(Self::Ambulatory),
            "Neurology doctor" | "Neurology nurse" | "Cardiology" => Some(Self::Neurology),
            "Critical care doctor" | "Critical care nurse" => Some(Self::CriticalCare),
            "Pediatric doctor" | "Pediatric nurse" => Some(Self::PediatricCare),
            "Surgery doctor" | "Surgery nurse" | "Anaesthetics" => Some(Self::Surgery),
            "Radiology day" | "Radiology nurse" | "Radiology call" => Some(Self::Radiology),
            "Outpatient doctor" | "Outpatient nurse" => Some(Self::Outpatient),
            _ => None,
        }
    }

    /// Guesses an employee's home hub from the service-line skills they carry.
    ///
    /// This is only a fallback for generated or decoded employees that did not
    /// set `home_hub` explicitly.
    pub fn infer_from_skills<'a>(skills: impl IntoIterator<Item = &'a str>) -> Self {
        let mut counts = [0usize; 7];
        for skill in skills {
            match Self::from_skill(skill) {
                Some(Self::Ambulatory) => counts[0] += 1,
                Some(Self::Neurology) => counts[1] += 1,
                Some(Self::CriticalCare) => counts[2] += 1,
                Some(Self::PediatricCare) => counts[3] += 1,
                Some(Self::Surgery) => counts[4] += 1,
                Some(Self::Radiology) => counts[5] += 1,
                Some(Self::Outpatient) => counts[6] += 1,
                Some(Self::Unknown) | None => {}
            }
        }

        let Some((best_index, best_count)) = counts
            .iter()
            .copied()
            .enumerate()
            .max_by_key(|&(index, count)| (count, index))
        else {
            return Self::Unknown;
        };

        if best_count == 0 {
            Self::Unknown
        } else {
            match best_index {
                0 => Self::Ambulatory,
                1 => Self::Neurology,
                2 => Self::CriticalCare,
                3 => Self::PediatricCare,
                4 => Self::Surgery,
                5 => Self::Radiology,
                6 => Self::Outpatient,
                _ => Self::Unknown,
            }
        }
    }
}
```

`CareHub` is not decorative. The current solver policy uses it to make nearby
search meaningful. Without `CareHub`, the solver would treat a surgery shift and
an outpatient shift as equally good swap candidates. With `CareHub`, the local
search engine prefers shifts and employees that belong to the same service line,
which dramatically improves solution quality on large datasets.

### Employee

Replace `src/domain/employee.rs` with the current hospital fact model:

```rust
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use solverforge::prelude::*;
use std::collections::BTreeSet;

use super::CareHub;

/// Hospital staff member published as a SolverForge problem fact.
///
/// A few fields are "authoritative transport state" (`*_dates`), while others
/// are precomputed runtime helpers (`index`, `*_days`). `finalize()` keeps those
/// two views in sync after generation or JSON decoding.
#[problem_fact]
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Employee {
    pub id: String,
    #[serde(skip)]
    pub index: usize,
    pub name: String,
    #[serde(default)]
    pub home_hub: CareHub,
    #[serde(default)]
    pub skills: BTreeSet<String>,
    #[serde(default)]
    pub unavailable_dates: BTreeSet<NaiveDate>,
    #[serde(default)]
    pub undesired_dates: BTreeSet<NaiveDate>,
    #[serde(default)]
    pub desired_dates: BTreeSet<NaiveDate>,
    #[serde(skip)]
    pub unavailable_days: Vec<NaiveDate>,
    #[serde(skip)]
    pub undesired_days: Vec<NaiveDate>,
    #[serde(skip)]
    pub desired_days: Vec<NaiveDate>,
}

impl Employee {
    /// Creates a beginner-friendly builder seed with stable defaults.
    pub fn new(index: usize, name: impl Into<String>) -> Self {
        Self {
            id: format!("employee-{index}"),
            index,
            name: name.into(),
            home_hub: CareHub::Unknown,
            skills: BTreeSet::new(),
            unavailable_dates: BTreeSet::new(),
            undesired_dates: BTreeSet::new(),
            desired_dates: BTreeSet::new(),
            unavailable_days: Vec::new(),
            undesired_days: Vec::new(),
            desired_days: Vec::new(),
        }
    }

    /// Overrides the transport-visible identifier.
    pub fn with_id(mut self, id: impl Into<String>) -> Self {
        self.id = id.into();
        self
    }

    /// Sets the employee's home service line used by nearby search.
    pub fn with_home_hub(mut self, home_hub: CareHub) -> Self {
        self.home_hub = home_hub;
        self
    }

    /// Rebuilds the derived caches the solver reads frequently.
    ///
    /// The serialized `BTreeSet`s are the stable truth for transport. The
    /// `Vec`s are just pre-expanded, iteration-friendly mirrors used by
    /// constraints and heuristics.
    pub fn finalize(&mut self) {
        if self.home_hub == CareHub::Unknown {
            self.home_hub = CareHub::infer_from_skills(self.skills.iter().map(String::as_str));
        }
        self.unavailable_days = self.unavailable_dates.iter().copied().collect();
        self.undesired_days = self.undesired_dates.iter().copied().collect();
        self.desired_days = self.desired_dates.iter().copied().collect();
    }

    /// Adds one service-line skill to the employee.
    pub fn with_skill(mut self, skill: impl Into<String>) -> Self {
        self.skills.insert(skill.into());
        self
    }

    /// Adds several skills in one builder step.
    pub fn with_skills(mut self, skills: impl IntoIterator<Item = impl Into<String>>) -> Self {
        for skill in skills {
            self.skills.insert(skill.into());
        }
        self
    }

    /// Marks a day as completely unavailable.
    pub fn with_unavailable_date(mut self, date: NaiveDate) -> Self {
        self.unavailable_dates.insert(date);
        self
    }

    /// Marks a day the employee would prefer to avoid.
    pub fn with_undesired_date(mut self, date: NaiveDate) -> Self {
        self.undesired_dates.insert(date);
        self
    }

    /// Marks a day the employee would actively like to work.
    pub fn with_desired_date(mut self, date: NaiveDate) -> Self {
        self.desired_dates.insert(date);
        self
    }
}
```

The `Employee` design reveals an important SolverForge pattern: **transport
state and runtime state are not the same thing**.

`BTreeSet<NaiveDate>` is perfect for JSON serialization: deduplicated,
sorted, compact. But constraints iterate over these dates repeatedly.
Converting them to `Vec<NaiveDate>` in `finalize()` makes constraint evaluation
faster without changing the wire format.

The builder methods (`with_skill`, `with_unavailable_date`, etc.) let demo-data
generators and tests construct employees fluently while the struct itself stays
a plain data container.

### Shift and Plan

The current hospital repo does **not** keep `Shift` in its own file. After the
generator creates `src/domain/shift.rs`, move that struct into
`src/domain/plan.rs`, delete `shift.rs`, and land on the current layout:

```rust
//! Domain model for the hospital employee scheduling problem.

use chrono::{NaiveDate, NaiveDateTime, Timelike};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use solverforge::prelude::*;

use super::{CareHub, Employee};

/// Work item that the solver must assign to exactly one employee or leave open.
///
/// In this example a shift is the only planning entity, which keeps the
/// beginner mental model simple: SolverForge is choosing `employee_idx` values
/// for each `Shift`.
#[planning_entity]
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Shift {
    #[planning_id]
    pub id: String,
    #[serde(skip)]
    pub index: usize,
    pub start: NaiveDateTime,
    pub end: NaiveDateTime,
    pub location: String,
    #[serde(default)]
    pub care_hub: CareHub,
    pub required_skill: String,
    #[serde(skip)]
    pub touched_dates: Vec<NaiveDate>,
    // Scalar planning slot index into `Plan.employees`, not `Employee.id`.
    #[planning_variable(
        value_range = "employees",
        allows_unassigned = true,
        nearby_value_distance_meter = "shift_to_employee_nearby_distance",
        nearby_entity_distance_meter = "shift_to_shift_nearby_distance"
    )]
    pub employee_idx: Option<usize>,
}

impl Shift {
    /// Creates a new unassigned shift and derives its first-pass care hub.
    pub fn new(
        id: impl Into<String>,
        start: NaiveDateTime,
        end: NaiveDateTime,
        location: impl Into<String>,
        required_skill: impl Into<String>,
    ) -> Self {
        let location = location.into();
        Self {
            id: id.into(),
            index: 0,
            start,
            end,
            care_hub: CareHub::from_location(&location),
            location,
            required_skill: required_skill.into(),
            touched_dates: Vec::new(),
            employee_idx: None,
        }
    }

    /// Returns every calendar day touched by the shift, including overnight end days.
    pub fn touched_dates(&self) -> &[NaiveDate] {
        self.touched_dates.as_slice()
    }

    /// Convenience helper used by tests and data exploration.
    pub fn duration_hours(&self) -> f64 {
        (self.end - self.start).num_minutes() as f64 / 60.0
    }
}
```

Notice the `#[planning_variable]` attribute. It tells SolverForge three things:

1. `value_range = "employees"` — the valid values for this field are indices
   into `Plan.employees`
2. `allows_unassigned = true` — `None` is a legal state (the shift may stay
   unassigned if every employee is unsuitable)
3. The `nearby_*_distance_meter` attributes — these name the functions that
   guide local search toward promising candidates

Then define the planning solution exactly as the current app does:

```rust
/// Full planning solution published to the solver runtime and the HTTP API.
#[planning_solution(
    constraints = "crate::constraints::create_constraints",
    solver_toml = "../../solver.toml"
)]
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Plan {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftDecimalScore>,
}

impl Plan {
    /// Builds a plan and immediately restores all derived runtime helpers.
    pub fn new(employees: Vec<Employee>, shifts: Vec<Shift>) -> Self {
        let mut schedule = Self {
            employees,
            shifts,
            score: None,
        };
        schedule.rebuild_derived_fields();
        schedule
    }

    /// Recomputes indexes, inferred hubs, touched dates, and range-safe assignments.
    ///
    /// This runs after generation and after transport decoding so the domain
    /// model always reaches the solver in a normalized state.
    pub fn rebuild_derived_fields(&mut self) {
        for (index, employee) in self.employees.iter_mut().enumerate() {
            employee.index = index;
            employee.finalize();
        }

        for (index, shift) in self.shifts.iter_mut().enumerate() {
            shift.index = index;
            if shift.care_hub == CareHub::Unknown {
                shift.care_hub = CareHub::from_location(&shift.location);
            }
            shift.touched_dates = dates_touched_by_span(shift.start, shift.end);
            shift.employee_idx = shift
                .employee_idx
                .filter(|employee_idx| *employee_idx < self.employees.len());
        }
    }

    /// Converts the domain model into a flat JSON-object field map for transport DTOs.
    pub fn to_transport_fields(&self) -> Map<String, Value> {
        match serde_json::to_value(self).expect("failed to serialize employee schedule") {
            Value::Object(fields) => fields,
            _ => Map::new(),
        }
    }

    /// Rebuilds a domain plan from the transport field map used by `PlanDto`.
    pub fn from_transport_fields(fields: Map<String, Value>) -> Result<Self, serde_json::Error> {
        let mut schedule: Self = serde_json::from_value(Value::Object(fields))?;
        schedule.rebuild_derived_fields();
        Ok(schedule)
    }

    /// Safe index lookup used by nearby meters and constraint helpers.
    #[inline]
    pub fn get_employee(&self, idx: usize) -> Option<&Employee> {
        self.employees.get(idx)
    }

    /// Convenience accessor used by tests and diagnostics.
    #[inline]
    pub fn employee_count(&self) -> usize {
        self.employees.len()
    }

    /// Named slice accessor used by joins and generated transport code.
    #[inline]
    pub fn employees_slice(&self) -> &[Employee] {
        self.employees.as_slice()
    }
}
```

This is the current transport truth:

- public JSON keeps stable ids and serialized fields
- solver/runtime helpers such as `index`, `home_hub`, `care_hub`, and
  `touched_dates` are rebuilt after transport decoding

The `rebuild_derived_fields()` method is critical. After an HTTP request
decodes a `PlanDto` into JSON, the deserialized structs do not yet have
`index`, `touched_dates`, or inferred `care_hub` values. Calling
`rebuild_derived_fields()` restores all of them before the plan reaches the
solver.

### Why Scalar Index Semantics Matter

The planning variable is:

```text
Shift.employee_idx -> Option<usize>
```

That is the field the solver changes.

The important consequence is:

- `employee_idx` points into `Plan.employees`
- joins compare `Shift.employee_idx` to `Employee.index`
- `Employee.id` is transport identity, not the scalar value-range key

This design is deliberate. Using a `usize` index instead of a `String` id
makes constraint evaluation faster (no string comparisons, no hash lookups)
and makes the move system simpler (swapping two `usize` values is trivial).
The `Employee.id` field is still there for human readability in the UI and
API, but the solver reasons in indices.

### Domain Exports

Finish `src/domain/mod.rs` like the current repo:

```rust
//! Domain-layer exports for the planning model.
//!
//! This file is intentionally tiny: it keeps the public names for the rest of
//! the app in one place, while the real teaching material lives in the
//! dedicated domain modules.

// @solverforge:begin domain-exports
mod care_hub;
mod employee;
mod plan;

pub use care_hub::CareHub;
pub use employee::Employee;
pub use plan::{Plan, PlanConstraintStreams, Shift, ShiftUnassignedFilter};
// @solverforge:end domain-exports
```

---

## How Optimization Works

### HardSoftDecimalScore

The current hospital app uses `HardSoftDecimalScore`, not `HardSoftScore`.

That gives the repo two useful properties:

- large hard penalties can be scaled aggressively without integer overflow
- soft scoring can stay readable without pretending everything is a flat `-1`

The current constraint modules use an explicit scale:

```rust
const SCORE_SCALE: i64 = 100_000;
```

So the score string still looks human, but the runtime keeps stable fixed-point
units internally. A hard penalty of `20 * SCORE_SCALE` appears as
`-2000000hard` in raw form, but the decimal score type formats it as something
more readable like `-20.00hard`.

Why does this matter? In a hospital schedule, some violations are catastrophic
(assigning an unqualified nurse to surgery) while others are minor
(preferences). Decimal scoring lets you express these differences with clear,
stable magnitudes.

### Current Solver Policy

Replace `solver.toml` with the current hospital policy:

```toml
random_seed = 1

[termination]
seconds_spent_limit = 30
unimproved_seconds_spent_limit = 5

[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "cheapest_insertion"
entity_class = "Shift"
variable_name = "employee_idx"

[[phases]]
type = "local_search"

[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[phases.forager]
type = "accepted_count"
limit = 4

[phases.move_selector]
type = "union_move_selector"

[[phases.move_selector.selectors]]
type = "nearby_change_move_selector"
entity_class = "Shift"
variable_name = "employee_idx"
max_nearby = 10

[[phases.move_selector.selectors]]
type = "nearby_swap_move_selector"
entity_class = "Shift"
variable_name = "employee_idx"
max_nearby = 10
```

This matches the current hospital app policy. It is deliberately narrower than a
"max everything" neighborhood mix because this dataset performs best with the
nearby-only local-search surface.

### Construction Heuristic

The first phase is `cheapest_insertion`. It builds an initial feasible (or
near-feasible) schedule by assigning shifts one at a time. For each unassigned
shift, it tries every eligible employee and picks the one that causes the
smallest score deterioration.

This is much smarter than random assignment. A good construction heuristic
gives local search a strong starting point, which matters because local search
can only improve what construction provides.

### Local Search with Late Acceptance

The second phase is local search using the `late_acceptance` acceptor. This is
a well-known metaheuristic that keeps a history of recent scores and accepts a
move if it is better than the score from `late_acceptance_size` steps ago.

Why late acceptance? It balances exploration and exploitation better than simple
hill climbing. Hill climbing gets stuck in local optima too easily. Late
acceptance can temporarily accept worse moves, which helps escape shallow local
optima and find better schedules.

The `accepted_count` forager limits how many accepted moves the solver
considers before picking one. `limit = 4` means: generate candidates, keep the
first 4 that pass the acceptor, then pick the best among those. This keeps
move selection fast on large datasets.

### Why Nearby Search Exists Here

The current hospital repo does not just search arbitrary employee swaps. It uses
the `CareHub` signal to keep nearby moves plausible:

- employees closer in `home_hub` are cheaper candidates
- shifts closer in `care_hub` and start band are better swap partners

That logic lives in `src/domain/plan.rs` through:

- `shift_to_employee_nearby_distance(...)`
- `shift_to_shift_nearby_distance(...)`

Here is how the nearby meters work:

```rust
fn shift_to_employee_nearby_distance(solution: &Plan, shift: &Shift, employee_index: usize) -> f64 {
    let Some(employee) = solution.get_employee(employee_index) else {
        return f64::INFINITY;
    };

    let mut distance = 10.0 * care_hub_distance(shift.care_hub, employee.home_hub);

    if !employee.skills.contains(&shift.required_skill) {
        distance += 10_000.0;
    } else if CareHub::from_skill(&shift.required_skill) != Some(employee.home_hub) {
        distance += 12.0;
    }

    if shift
        .touched_dates()
        .iter()
        .any(|date| employee.unavailable_dates.contains(date))
    {
        distance += 2_000.0;
    }

    distance
}

fn shift_to_shift_nearby_distance(_solution: &Plan, left: &Shift, right: &Shift) -> f64 {
    10.0 * care_hub_distance(left.care_hub, right.care_hub)
        + start_band_distance(left.start.time().hour(), right.start.time().hour())
}
```

These meters are **not** constraints. They are hints. A shift can still be
assigned to a distant employee if the constraints permit it and the score
improves. But by ranking candidates by proximity, the solver spends less time
evaluating obviously bad moves.

The `max_nearby = 10` setting limits each move selector to the 10 closest
candidates. On a dataset with 50 employees and 688 shifts, this narrows the
search space dramatically without sacrificing solution quality.

---

## Writing Constraints: The Business Rules

Open `src/constraints/`.

Constraints are where business rules become code. In SolverForge, each
constraint is a small, pure function that returns a `ConstraintSet`. The solver
combines all constraints into one scoring function and evaluates it
incrementally as it explores moves.

### Constraint Assembly

Replace `src/constraints/mod.rs` with the current hospital module list:

```rust
//! Constraint assembly for employee scheduling.
//!
//! Each sibling module contributes one named rule. `create_constraints()`
//! simply lists them in the order we want them to appear in analysis output.

use crate::domain::Plan;
use solverforge::prelude::*;

pub use self::assemble::create_constraints;

// @solverforge:begin constraint-modules
mod assigned_shift;
mod balance_assignments;
mod desired_day;
mod minimum_rest;
mod one_shift_per_day;
mod overlapping_shift;
mod required_skill;
mod unavailable_employee;
mod undesired_day;
// @solverforge:end constraint-modules

mod assemble {
    use super::*;

    /// Collects the full scoring model used by `Plan`.
    pub fn create_constraints() -> impl ConstraintSet<Plan, HardSoftDecimalScore> {
        // @solverforge:begin constraint-calls
        (
            assigned_shift::constraint(),
            required_skill::constraint(),
            overlapping_shift::constraint(),
            minimum_rest::constraint(),
            one_shift_per_day::constraint(),
            unavailable_employee::constraint(),
            undesired_day::constraint(),
            desired_day::constraint(),
            balance_assignments::constraint(),
        )
        // @solverforge:end constraint-calls
    }
}
```

The order of constraints in the tuple matters only for readability and score
analysis output. The solver evaluates all constraints for every move, but the
analysis UI shows them in this order.

### Assigned Shift

Replace the generated placeholder with the current hard rule:

```rust
use crate::domain::{Plan, PlanConstraintStreams, ShiftUnassignedFilter};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

const SCORE_SCALE: i64 = 100_000;

/// Penalizes every shift that remains unassigned at the end of solving.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .unassigned()
        .penalize(HardSoftDecimalScore::of_hard_scaled(SCORE_SCALE))
        .named("Assigned shift")
}
```

This is the simplest constraint in the app. It says: every shift should have
an employee. The `.unassigned()` filter is generated by the macro system and
selects shifts where `employee_idx` is `None`.

The penalty is `1 * SCORE_SCALE`. Because this is a hard constraint, even one
unassigned shift makes the schedule infeasible. The solver will prioritize
fixing this over improving soft constraints.

### Required Skill

This is the rule where the scalar index semantics matter most:

```rust
use crate::domain::{Employee, Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

const SCORE_SCALE: i64 = 100_000;

/// Penalizes assignments where the employee lacks the required skill label.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join((
            Plan::employees_slice,
            joiner::equal_bi(
                |shift: &Shift| shift.employee_idx,
                |employee: &Employee| Some(employee.index),
            ),
        ))
        .filter(|shift: &Shift, employee: &Employee| {
            !employee.skills.contains(&shift.required_skill)
        })
        .penalize(HardSoftDecimalScore::of_hard_scaled(10 * SCORE_SCALE))
        .named("Required skill")
}
```

Let's break this down:

1. `.shifts()` — start with all shifts
2. `.filter(...)` — keep only shifts that are already assigned
3. `.join(...)` — match each shift to its employee using `equal_bi`. The
   `joiner::equal_bi` compares `shift.employee_idx` (an `Option<usize>`) to
   `Some(employee.index)` (also an `Option<usize>`). This is the scalar index
   join pattern.
4. `.filter(...)` — from the joined pairs, keep only those where the employee
   lacks the required skill
5. `.penalize(...)` — apply a hard penalty of `10 * SCORE_SCALE`

The penalty is ten times larger than the unassigned penalty because a
wrong-skilled assignment is worse than an unassigned shift. An unassigned shift
is a gap; a wrong-skilled assignment is a safety risk.

### Overlapping Shift

```rust
use crate::domain::{Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

const SCORE_SCALE: i64 = 100_000;
const STRUCTURAL_MINUTE_HARD_UNITS: i64 = 20;

/// Penalizes overlapping time windows for the same employee.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join(joiner::equal(|shift: &Shift| shift.employee_idx))
        .filter(|a: &Shift, b: &Shift| a.index < b.index && a.start < b.end && b.start < a.end)
        .penalize_hard_with(|a: &Shift, b: &Shift| {
            let overlap_start = a.start.max(b.start);
            let overlap_end = a.end.min(b.end);
            let overlap_minutes = if overlap_start < overlap_end {
                (overlap_end - overlap_start).num_minutes()
            } else {
                0
            };
            HardSoftDecimalScore::of_hard_scaled(
                overlap_minutes * STRUCTURAL_MINUTE_HARD_UNITS * SCORE_SCALE,
            )
        })
        .named("Overlapping shift")
}
```

This constraint uses a **self-join**: it joins `Shift` to `Shift` on the same
`employee_idx`. The `a.index < b.index` filter prevents counting each pair
twice.

The penalty is proportional to the overlap duration. A 60-minute overlap
penalizes `60 * 20 * 100_000`, which is much larger than a fixed penalty. This
reflects reality: a 5-minute overlap is different from a 4-hour overlap.

### Minimum Rest

Generate the seam:

```bash
solverforge generate constraint minimum_rest --pair --hard
```

Then replace the placeholder with the current implementation:

```rust
use crate::domain::{Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

const SCORE_SCALE: i64 = 100_000;
const STRUCTURAL_MINUTE_HARD_UNITS: i64 = 20;

/// Penalizes back-to-back shifts that leave less than 10 hours of rest.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join(joiner::equal(|shift: &Shift| shift.employee_idx))
        .filter(|a: &Shift, b: &Shift| {
            if a.index >= b.index {
                return false;
            }

            let (earlier, later) = if a.end <= b.start {
                (a, b)
            } else if b.end <= a.start {
                (b, a)
            } else {
                return false;
            };

            let gap_minutes = (later.start - earlier.end).num_minutes();
            (0..600).contains(&gap_minutes)
        })
        .penalize_hard_with(|a: &Shift, b: &Shift| {
            let (earlier, later) = if a.end <= b.start { (a, b) } else { (b, a) };
            let gap_minutes = (later.start - earlier.end).num_minutes();
            HardSoftDecimalScore::of_hard_scaled(
                (600 - gap_minutes) * STRUCTURAL_MINUTE_HARD_UNITS * SCORE_SCALE,
            )
        })
        .named("At least 10 hours between 2 shifts")
}
```

This constraint is subtle. It does not penalize all pairs of shifts for the
same employee. It only penalizes pairs where:

1. the shifts do not overlap (otherwise `overlapping_shift` handles it)
2. the gap between them is less than 600 minutes (10 hours)

The penalty is proportional to how short the gap is. A 30-minute gap is worse
than a 9-hour gap. This is a classic example of how constraints encode
real-world labor regulations.

### One Shift Per Day

Generate the seam:

```bash
solverforge generate constraint one_shift_per_day --pair --hard
```

Then replace the placeholder with the current implementation:

```rust
use crate::domain::{Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

const SCORE_SCALE: i64 = 100_000;

/// Forbids assigning two shifts that touch the same calendar day to one employee.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join(joiner::equal(|shift: &Shift| shift.employee_idx))
        .filter(|a: &Shift, b: &Shift| {
            a.index < b.index
                && a.touched_dates()
                    .iter()
                    .any(|date| b.touched_dates().contains(date))
        })
        .penalize(HardSoftDecimalScore::of_hard_scaled(20 * SCORE_SCALE))
        .named("One shift per day")
}
```

This constraint uses `touched_dates()` rather than simple start-date comparison
because shifts can span midnight. A night shift from 22:00 to 06:00 touches two
calendar days. The constraint correctly prevents assigning another shift on
*either* of those days.

### Unavailable Employee

Generate the seam:

```bash
solverforge generate constraint unavailable_employee --join --hard
```

Then replace the placeholder:

```rust
use crate::domain::{Employee, Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

const SCORE_SCALE: i64 = 100_000;
const STRUCTURAL_MINUTE_HARD_UNITS: i64 = 20;

/// Penalizes assigning someone on dates they declared unavailable.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join((
            Plan::employees_slice,
            joiner::equal_bi(
                |shift: &Shift| shift.employee_idx,
                |employee: &Employee| Some(employee.index),
            ),
        ))
        .filter(|shift: &Shift, employee: &Employee| {
            employee.unavailable_days.iter().any(|date| {
                let day_start = date.and_hms_opt(0, 0, 0).unwrap();
                let day_end = date
                    .succ_opt()
                    .unwrap_or(*date)
                    .and_hms_opt(0, 0, 0)
                    .unwrap();
                let overlap_start = shift.start.max(day_start);
                let overlap_end = shift.end.min(day_end);
                overlap_start < overlap_end
            })
        })
        .penalize_hard_with(|shift: &Shift, employee: &Employee| {
            let overlap_minutes: i64 = employee
                .unavailable_days
                .iter()
                .map(|date| {
                    let day_start = date.and_hms_opt(0, 0, 0).unwrap();
                    let day_end = date
                        .succ_opt()
                        .unwrap_or(*date)
                        .and_hms_opt(0, 0, 0)
                        .unwrap();
                    let overlap_start = shift.start.max(day_start);
                    let overlap_end = shift.end.min(day_end);
                    if overlap_start < overlap_end {
                        (overlap_end - overlap_start).num_minutes()
                    } else {
                        0
                    }
                })
                .sum();
            HardSoftDecimalScore::of_hard_scaled(
                overlap_minutes * STRUCTURAL_MINUTE_HARD_UNITS * SCORE_SCALE,
            )
        })
        .named("Unavailable employee")
}
```

This constraint penalizes proportional to how much of the shift falls on an
unavailable date. A shift that barely touches the edge of an unavailable day
gets a smaller penalty than one fully contained in it. This proportional
penalty helps the solver understand *how bad* each violation is.

### Desired and Undesired Days

Generate the seams:

```bash
solverforge generate constraint desired_day --join --soft
solverforge generate constraint undesired_day --join --soft
```

Both rules reuse the same normalized `touched_dates()` shape on `Shift` and the
derived `desired_days` / `undesired_days` vectors on `Employee`.

**Undesired day:**

```rust
use crate::domain::{Employee, Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// Softly penalizes assignments that land on an employee's undesired dates.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join((
            Plan::employees_slice,
            joiner::equal_bi(
                |shift: &Shift| shift.employee_idx,
                |employee: &Employee| Some(employee.index),
            ),
        ))
        .filter(|shift: &Shift, employee: &Employee| {
            employee
                .undesired_days
                .iter()
                .any(|date| shift.touched_dates().contains(date))
        })
        .penalize_with(|shift: &Shift, employee: &Employee| {
            HardSoftDecimalScore::of_soft(
                employee
                    .undesired_days
                    .iter()
                    .filter(|date| shift.touched_dates().contains(date))
                    .count() as i64,
            )
        })
        .named("Undesired day for employee")
}
```

**Desired day:**

```rust
use crate::domain::{Employee, Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// Rewards assigning an employee to dates they explicitly prefer.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join((
            Plan::employees_slice,
            joiner::equal_bi(
                |shift: &Shift| shift.employee_idx,
                |employee: &Employee| Some(employee.index),
            ),
        ))
        .filter(|shift: &Shift, employee: &Employee| {
            employee
                .desired_days
                .iter()
                .any(|date| shift.touched_dates().contains(date))
        })
        .reward_with(|shift: &Shift, employee: &Employee| {
            HardSoftDecimalScore::of_soft(
                employee
                    .desired_days
                    .iter()
                    .filter(|date| shift.touched_dates().contains(date))
                    .count() as i64,
            )
        })
        .named("Desired day for employee")
}
```

Notice the difference: undesired day uses `.penalize_with(...)` while desired
day uses `.reward_with(...)`. Both are soft constraints, so they do not affect
feasibility. They only influence which feasible schedule the solver prefers.

The count-based penalty/reward means that a shift touching two undesired dates
is penalized twice as much as one touching a single undesired date.

### Balance Assignments

Generate the seam:

```bash
solverforge generate constraint balance_assignments --balance --soft
```

The current implementation stays compact:

```rust
use crate::domain::{Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// Softly discourages concentrating too many shifts on one employee.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .balance(|shift: &Shift| shift.employee_idx)
        .penalize_soft()
        .named("Balance employee assignments")
}
```

The `.balance(...)` stream is one of SolverForge's most powerful features. It
groups shifts by their assigned employee and computes a fairness metric. The
solver then penalizes schedules where one employee has many more shifts than
others.

This single line replaces what would otherwise be a complex manual constraint
involving `group_by`, sum aggregations, and deviation calculations.

---

## The Solver Engine

The hospital app keeps the solving runtime stock, but it does not expose raw
runtime types directly. `src/solver/service.rs` is the application facade over
`SolverManager<Plan>`.

### What `SolverService` Owns

The current service does five things:

- starts retained jobs through a global `SolverManager<Plan>`
- exposes status, snapshots, and snapshot-bound analysis
- handles exact pause, resume, cancel, and delete
- maintains an SSE broadcast channel per retained job
- translates runtime events into the JSON payload expected by the frontend

The public methods line up with the HTTP routes:

```rust
pub fn start_job(&self, plan: Plan) -> Result<String, SolverManagerError>
pub fn get_status(&self, id: &str) -> Result<SolverStatus<HardSoftDecimalScore>, SolverManagerError>
pub fn pause(&self, id: &str) -> Result<(), SolverManagerError>
pub fn resume(&self, id: &str) -> Result<(), SolverManagerError>
pub fn cancel(&self, id: &str) -> Result<(), SolverManagerError>
pub fn delete(&self, id: &str) -> Result<(), SolverManagerError>
pub fn get_snapshot(&self, id: &str, snapshot_revision: Option<u64>) -> Result<SolverSnapshot<Plan>, SolverManagerError>
pub fn analyze_snapshot(&self, id: &str, snapshot_revision: Option<u64>) -> Result<SolverSnapshotAnalysis<HardSoftDecimalScore>, SolverManagerError>
```

The global `SolverManager` is declared as a `static`:

```rust
static MANAGER: SolverManager<Plan> = SolverManager::new();
```

This means all jobs share one runtime. The `SolverService` wraps this global
manager with per-job SSE state stored in a `HashMap<usize, JobState>`.

### SSE Event Translation

The runtime emits stock `SolverEvent<Plan>` values. The hospital app translates
them into UI-facing event payloads such as:

- `progress`
- `best_solution`
- `pause_requested`
- `paused`
- `resumed`
- `completed`
- `cancelled`
- `failed`

That translation happens inside `drain_receiver(...)` in
`src/solver/service.rs`.

Each event carries telemetry (elapsed time, step count, moves evaluated,
moves accepted, score calculations) and the current score. The browser uses
this to update the status bar in real time.

### Why the Retained Lifecycle Matters

The browser does not hold a direct pointer to a running solve. It interacts
through a stateless HTTP API:

- `POST /jobs` — start a new solve
- `GET /jobs/{id}` — get job summary
- `GET /jobs/{id}/status` — alias for job summary
- `GET /jobs/{id}/snapshot` — get the latest (or a specific) snapshot
- `GET /jobs/{id}/analysis` — run score analysis against a snapshot
- `POST /jobs/{id}/pause` — request pause at next safe point
- `POST /jobs/{id}/resume` — resume from checkpoint
- `POST /jobs/{id}/cancel` — cancel the job
- `DELETE /jobs/{id}` — delete a terminal job
- `GET /jobs/{id}/events` — SSE stream of lifecycle events

This retained contract is part of the current hospital app, not an optional
extra. It enables several important UX patterns:

1. **Page refresh safety** — if the user refreshes the browser, they can
   re-query `/jobs/{id}` and pick up where they left off
2. **Multiple viewers** — two browser tabs can watch the same solve
3. **Pause and resume** — the solver checkpoints its state, so a paused job
   can resume without losing progress
4. **Historical analysis** — old snapshots remain available for comparison

---

## Web Interface and API

### Demo Data Surface

The current hospital app does not keep demo data in one flat file anymore.

Keep the public data boundary thin:

`src/data/mod.rs`

```rust
//! Stable public entrypoint for demo data.
//!
//! Other modules should import from `crate::data` instead of reaching directly
//! into `data_seed/`. That keeps the app's public data surface small even though
//! the generator itself is split across many focused files.

mod data_seed;

pub use data_seed::{generate, list_demo_data, DemoData};
```

`src/data/data_seed.rs`

```rust
//! Public demo-data surface for the hospital example.
//!
//! Keep this file intentionally thin. The rest of the application imports
//! `crate::data::{generate, list_demo_data, DemoData}` as a stable boundary, so
//! the detailed dataset design lives in sibling modules where it can evolve
//! without making the top-level data surface noisy.

mod availability;
mod cohorts;
mod coverage;
mod demand;
mod employees;
mod entrypoints;
mod large;
mod preferences;
mod shifts;
mod skills;
mod time_utils;
mod validation;
mod vocabulary;
mod witness;

#[cfg(test)]
mod solve_tests;
#[cfg(test)]
mod tests;

pub use entrypoints::{generate, list_demo_data, DemoData};
```

The public demo id lives in `src/data/data_seed/entrypoints.rs`:

```rust
use std::str::FromStr;

use crate::domain::Plan;

use super::large::generate_large;

/// Public demo-data identifiers exposed through the HTTP API.
///
/// The hospital app currently ships one serious benchmark instance rather than a
/// menu of toy presets, so the surface stays explicit instead of pretending that
/// multiple sizes exist when they do not.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DemoData {
    Large,
}

impl FromStr for DemoData {
    type Err = ();

    /// Parses the case-insensitive demo id exposed over HTTP.
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_uppercase().as_str() {
            "LARGE" => Ok(DemoData::Large),
            _ => Err(()),
        }
    }
}

impl DemoData {
    /// Returns the canonical uppercase id used by the HTTP API.
    pub fn as_str(&self) -> &'static str {
        match self {
            DemoData::Large => "LARGE",
        }
    }
}

/// Lists the demo identifiers accepted by `/demo-data/{id}`.
pub fn list_demo_data() -> Vec<&'static str> {
    vec![DemoData::Large.as_str()]
}

/// Generates the requested demo dataset.
///
/// Dispatch stays here so callers see the supported public variants in one
/// place, while the dataset assembly itself remains hidden in the per-instance
/// modules.
pub fn generate(demo: DemoData) -> Plan {
    match demo {
        DemoData::Large => generate_large(),
    }
}
```

That means the current public API is:

```json
["LARGE"]
```

The `DemoData` enum is a small but important pattern. It makes the supported
dataset ids explicit and type-safe. Adding a new dataset means adding a variant
here and a generator function in a sibling module.

### Routes

Update the route handler so `/demo-data` is driven by the data module, not by a
hard-coded list:

```rust
/// Lists the demo ids accepted by `/demo-data/{id}`.
async fn list_demo_data() -> Json<Vec<&'static str>> {
    Json(data::list_demo_data())
}
```

The full current router in `src/api/routes.rs` exposes:

- `GET /health`
- `GET /info`
- `GET /demo-data`
- `GET /demo-data/{id}`
- `POST /jobs`
- `GET /jobs/{id}`
- `GET /jobs/{id}/status`
- `GET /jobs/{id}/snapshot`
- `GET /jobs/{id}/analysis`
- `POST /jobs/{id}/pause`
- `POST /jobs/{id}/resume`
- `POST /jobs/{id}/cancel`
- `DELETE /jobs/{id}`
- `GET /jobs/{id}/events`

Each handler is intentionally thin. The `AppState` holds a `SolverService`, and
each route decodes the request, calls one service method, and encodes the
response. This keeps the HTTP layer separate from the solving logic.

### DTOs

The current DTO layer keeps the domain flattened and transport-friendly:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlanDto {
    #[serde(flatten)]
    pub fields: Map<String, Value>,
    #[serde(default)]
    pub score: Option<String>,
}
```

The conversion boundary is:

```rust
impl PlanDto {
    pub fn from_plan(plan: &Plan) -> Self { ... }
    pub fn to_domain(&self) -> Result<Plan, serde_json::Error> {
        Plan::from_transport_fields(self.fields.clone())
    }
}
```

That `to_domain()` call is where derived fields get rebuilt safely after HTTP
transport. The flattening means the JSON payload looks like:

```json
{
  "employees": [...],
  "shifts": [...],
  "score": "0hard/-1234soft"
}
```

Instead of being wrapped in a nested object. This makes the API easier to read
and easier to construct by hand.

### Browser Entry

The current hospital app does not use the neutral `static/app.js`.

Replace `static/index.html` with the current module-based boot:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SolverForge Hospital — SolverForge</title>
  <link rel="stylesheet" href="/sf/sf.css">
  <link rel="stylesheet" href="/sf/vendor/fontawesome/css/fontawesome.min.css">
  <link rel="stylesheet" href="/sf/vendor/fontawesome/css/solid.min.css">
  <link rel="icon" href="/sf/img/solverforge-favicon.svg" type="image/svg+xml">
</head>
<body>
  <div id="sf-app"></div>
  <script src="/sf/sf.js"></script>
  <script type="module">
    import { bootApp } from '/app/main.mjs';
    bootApp();
  </script>
</body>
</html>
```

Then create the current app modules:

- `static/app/main.mjs`
- `static/app/shell/*.mjs`
- `static/app/schedule/*.mjs`
- `static/app/views/registry.mjs`

`static/app/main.mjs` is the current browser entrypoint. It:

1. loads `sf-config.json`
2. loads `generated/ui-model.json`
3. builds the shared app shell from `solverforge-ui`
4. creates a retained-job controller around `SF.createSolver(...)`
5. loads `/demo-data/LARGE`
6. renders the two current schedule views

### Current View Model

The current hospital app exposes two custom view kinds:

```json
{
  "views": [
    {
      "id": "by-location",
      "kind": "schedule-by-location",
      "label": "By location",
      "entity": "shift",
      "entityPlural": "shifts",
      "sourcePlural": "employees",
      "variableField": "employeeIdx",
      "allowsUnassigned": true
    },
    {
      "id": "by-employee",
      "kind": "schedule-by-employee",
      "label": "By employee",
      "entity": "shift",
      "entityPlural": "shifts",
      "sourcePlural": "employees",
      "variableField": "employeeIdx",
      "allowsUnassigned": true
    }
  ]
}
```

The corresponding renderer registry is:

```js
export function createViewRegistry() {
  return {
    'schedule-by-location': renderLocationView,
    'schedule-by-employee': renderEmployeeView,
  };
}
```

That is the current frontend endpoint of this tutorial.

### The Frontend Boot Sequence

When the page loads, the boot sequence is:

1. `sf.js` (from `solverforge-ui`) loads and exposes `globalThis.SF`
2. `bootApp()` loads `sf-config.json` and `generated/ui-model.json`
3. The app shell renders the header, controls (Solve, Pause, Resume, Stop,
   Analyze), and the tab bar
4. The solver controller connects to `/jobs/{id}/events` when a solve starts
5. Demo data is fetched from `/demo-data/LARGE` and rendered in both tabs
6. When the solver finds a better solution, the event payload contains the
   updated plan, and the views re-render

This architecture means the frontend is not tied to the hospital domain. The
same shell works for any SolverForge app that exposes the same HTTP contract
and provides a view registry.

---

## Making Your First Customization

The current hospital repo already includes a good "first real expansion":
**one shift per day per employee**.

Generate the seam:

```bash
solverforge generate constraint one_shift_per_day --pair --hard
```

Then replace the placeholder with the current implementation:

```rust
use crate::domain::{Plan, PlanConstraintStreams, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

const SCORE_SCALE: i64 = 100_000;

/// Forbids assigning two shifts that touch the same calendar day to one employee.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join(joiner::equal(|shift: &Shift| shift.employee_idx))
        .filter(|a: &Shift, b: &Shift| {
            a.index < b.index
                && a.touched_dates()
                    .iter()
                    .any(|date| b.touched_dates().contains(date))
        })
        .penalize(HardSoftDecimalScore::of_hard_scaled(20 * SCORE_SCALE))
        .named("One shift per day")
}
```

Register it in `src/constraints/mod.rs`:

```rust
mod one_shift_per_day;

(
    assigned_shift::constraint(),
    required_skill::constraint(),
    overlapping_shift::constraint(),
    minimum_rest::constraint(),
    one_shift_per_day::constraint(),
    unavailable_employee::constraint(),
    undesired_day::constraint(),
    desired_day::constraint(),
    balance_assignments::constraint(),
)
```

This is a good first customization because it touches only the domain-driven
constraint layer. The retained backend and browser contract do not have to
change.

Notice how the pattern is always the same:

1. generate the seam with the CLI
2. replace the placeholder with real domain logic
3. register the new constraint in `mod.rs`
4. run `cargo test` to verify

This workflow is the core of how SolverForge apps grow: the CLI handles the
repetitive structure, and you fill in the business rules.

---

## Advanced Constraint Patterns

The rest of the current hospital rules grow from the same pattern set.

### Pattern Recap

Every constraint in this app follows one of four shapes:

| Shape | Use when |
|-------|----------|
| Unary | The rule applies to one entity at a time (e.g., unassigned shift) |
| Self-join (pair) | The rule compares two entities of the same type (e.g., overlap) |
| Fact join | The rule needs entity + fact data (e.g., required skill) |
| Balance | The rule measures fairness across a grouping (e.g., balance) |

### Tuning Constraint Weights

The current weights are not arbitrary. They encode a priority hierarchy:

```text
Required skill:        10 * SCORE_SCALE  (worst: safety violation)
One shift per day:     20 * SCORE_SCALE  (bad: labor violation)
Overlapping shift:     variable (proportional to minutes)
Minimum rest:          variable (proportional to missing minutes)
Unavailable employee:  variable (proportional to overlap minutes)
Assigned shift:        1  * SCORE_SCALE  (gap, but not unsafe)
```

When you add a new constraint, think about where it fits in this hierarchy.
A constraint that prevents a catastrophic error should have a larger weight
than one that merely discourages mild inefficiency.

### Adding a New Soft Preference

Suppose you want to add a soft preference for matching employees to their
home hub. The pattern would be:

```bash
solverforge generate constraint home_hub_match --join --soft
```

Then implement it like `desired_day`, but filter on `employee.home_hub ==
shift.care_hub` and reward matches.

### Nearby Modeling

The current hospital repo also extends the model itself, not just the
constraints:

- `Employee.home_hub`
- `Shift.care_hub`
- `CareHub::from_location(...)`
- `CareHub::from_skill(...)`
- `CareHub::infer_from_skills(...)`
- `shift_to_employee_nearby_distance(...)`
- `shift_to_shift_nearby_distance(...)`

That nearby domain logic is what makes the current nearby-search policy
productive on the `LARGE` dataset. Without it, local search would waste most of
its time evaluating moves that assign a radiology shift to a surgery nurse.

---

## Testing and Validation

### Rust Tests

Run the current Rust suite:

```bash
cargo test --quiet
```

The hospital repo includes focused constraint tests, data-generator tests, route
tests, and retained-runtime tests.

Key test categories:

- **Domain tests** in `src/domain/plan.rs` verify round-trip serialization,
  `touched_dates` correctness, and descriptor shape
- **Constraint tests** verify that each constraint penalizes exactly the
  violations it should
- **Route tests** in `src/api/routes.rs` exercise the full HTTP lifecycle
- **Solver service tests** verify SSE payload shape and telemetry derivation

### Constraint Unit Tests

A good constraint test creates a tiny plan with one known violation, runs the
constraint, and checks the penalty. For example:

```rust
#[test]
fn required_skill_penalizes_missing_skill() {
    let plan = Plan::new(
        vec![Employee::new(0, "Alex")], // no skills
        vec![Shift::new(
            "shift-1",
            NaiveDate::from_ymd_opt(2024, 1, 1).unwrap().and_hms_opt(8, 0, 0).unwrap(),
            NaiveDate::from_ymd_opt(2024, 1, 1).unwrap().and_hms_opt(16, 0, 0).unwrap(),
            "ER",
            "Nurse",
        )],
    );

    let analysis = crate::constraints::create_constraints().evaluate_detailed(&plan);
    let required_skill = analysis
        .iter()
        .find(|a| a.constraint_ref.name == "Required skill")
        .expect("constraint should exist");

    assert!(required_skill.score.hard() < 0, "should penalize missing skill");
}
```

### Slow Acceptance Solve

Run the heavier acceptance solve when you want to prove the public `LARGE`
dataset reaches a hard-feasible terminal state:

```bash
cargo test large_demo_solves_to_feasible_terminal_state -- --ignored --nocapture
```

This test loads the full `LARGE` dataset, starts a retained solve, waits for
termination, and asserts that the final hard score is zero (no hard
violations).

### Frontend Module Checks

Run the current browserless frontend validation:

```bash
find static/app -name '*.mjs' -print0 | xargs -0 -n1 node --check
node --test tests/frontend/*.test.js
```

`node --check` validates syntax. The test suite (if present) validates that
view renderers produce expected DOM structures for sample data.

### Manual Runtime Checks

Boot the app:

```bash
cargo run --release --bin solverforge-hospital
```

Then verify:

1. `GET /demo-data` returns `["LARGE"]`
2. `GET /demo-data/LARGE` returns a current hospital `PlanDto`
3. clicking **Solve** starts a retained job
4. `/jobs/{id}/events` streams lifecycle changes
5. `/jobs/{id}/snapshot` and `/jobs/{id}/analysis` stay aligned to the same
   snapshot revision
6. pausing the job transitions the state to `PAUSED`
7. resuming continues from the checkpoint
8. cancelling reaches `CANCELLED` and allows deletion

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Change hospital service-line proximity | `src/domain/care_hub.rs` |
| Change the employee fact model | `src/domain/employee.rs` |
| Change the shift entity, plan, normalization, or nearby meters | `src/domain/plan.rs` |
| Export domain types and generated helpers | `src/domain/mod.rs` |
| Change active constraints | `src/constraints/mod.rs` |
| Change one hospital rule | `src/constraints/*.rs` |
| Change the public demo-data entrypoints | `src/data/data_seed/entrypoints.rs` |
| Change the large published dataset | `src/data/data_seed/large.rs` plus sibling generator modules |
| Keep the public data boundary stable | `src/data/mod.rs`, `src/data/data_seed.rs` |
| Change retained job routing | `src/api/routes.rs` |
| Change transport projection | `src/api/dto.rs` |
| Change SSE streaming | `src/api/sse.rs`, `src/solver/service.rs` |
| Change browser boot | `static/index.html`, `static/app/main.mjs` |
| Change schedule views | `static/app/schedule/*.mjs`, `static/app/views/registry.mjs` |
| Change current view metadata | `static/generated/ui-model.json` |
| Change search behavior | `solver.toml` |
| Change app metadata | `solverforge.app.toml` |

### Common Gotchas

1. **Use `scalar`, never `standard`, for planning variables**
   `standard` is a demo size label, not a variable kind.

2. **Replace the neutral solution before shaping the project**
   Use `solverforge generate solution plan --score HardSoftDecimalScore` while
   the app is still neutral.

3. **The scalar planning variable uses collection index**
   Join `Shift.employee_idx` to `Employee.index`, not to `Employee.id`.

4. **The current hospital repo folds `Shift` into `plan.rs`**
   The generator gives you `shift.rs`; the current hospital app does not keep
   that split.

5. **`/demo-data` must come from `data::list_demo_data()`**
   The public dataset list and the route handler must stay aligned.

6. **The current app uses `LARGE` only**
   `solverforge.app.toml`, `src/data/data_seed/entrypoints.rs`, `static/sf-config.json`,
   and the browser boot flow all agree on that.

7. **The current browser app is module-based**
   The neutral `static/app.js` is not the final hospital frontend.

### Additional Resources

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [solverforge-cli Modeling and Generation](/docs/solverforge-cli/modeling-and-generation/)
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
- [Solver Phases](/docs/solverforge/solver/phases/)
- [Project Overview](/docs/overview/)
