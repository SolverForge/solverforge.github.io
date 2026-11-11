---
title: "SolverForge Hospital Use Case"
linkTitle: "Hospital Use Case"
icon: fa-brands fa-rust
date: 2026-04-23
weight: 5
description: "A long-form worked example that grows a solverforge-cli scaffold into a hospital scheduler that solves, then walks through the finished hospital app: model, constraints, solver policy, retained jobs, and browser"
categories: [Quickstarts]
tags: [quickstart, rust, hospital]
---

# SolverForge Hospital Use Case

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Build the App from the Scaffold](#build-the-app-from-the-scaffold)
4. [Run the Finished Example](#run-the-finished-example)
5. [The Problem We're Solving](#the-problem-were-solving)
6. [The Teaching Spine](#the-teaching-spine)
7. [Understanding the Data Model](#understanding-the-data-model)
8. [The Demo Dataset](#the-demo-dataset)
9. [How Optimization Works](#how-optimization-works)
10. [Writing Constraints](#writing-constraints)
11. [Solver Policy](#solver-policy)
12. [Runtime and Browser Behavior](#runtime-and-browser-behavior)
13. [Making Your First Customization](#making-your-first-customization)
14. [Testing and Validation](#testing-and-validation)
15. [Quick Reference](#quick-reference)

---

## Introduction

This guide has two working paths. The first starts from the generic
[`solverforge-cli` Getting Started](/docs/solverforge-cli/getting-started/)
flow and grows the neutral scaffold into a small hospital scheduler: the CLI
generates the model and constraint seams, and you write the domain type, the
nine scheduling rules, and a demo dataset. The second downloads the finished
hospital app from Hugging Face, the reference implementation with a
deterministic benchmark dataset, nearby search, and a complete browser UI. The
rest of the article explains how that finished app works.

You will:

- install `solverforge-cli` and scaffold a neutral app with `solverforge new`
- switch the score to `HardSoftDecimalScore` and generate `Employee`, `Shift`,
  and the scalar `employee_idx` planning variable
- define the `CareHub` type the model refers to
- replace every generated constraint placeholder with a real rule, seed demo
  data, and solve it in the browser
- run, test, and read the finished hospital app
- follow how `employee_idx` moves through constraints, solver policy, retained
  jobs, snapshots, and the browser

**No optimization background required**. The article explains the end-to-end
path. The code comments in the example repo explain the local intent at the
exact place where a concept is implemented.

### Prerequisites

- Basic Rust knowledge: structs, enums, traits, closures, modules, derive
  macros
- Familiarity with HTTP APIs
- Comfort with command-line work
- Rust `1.95+`
- Node.js for the finished example's frontend and browser tests

---

## Getting Started

Install the CLI and check which runtime it scaffolds:

```bash
cargo install solverforge-cli --locked
solverforge --version
```

`solverforge-cli 4.0.4` scaffolds `solverforge 0.26.1` with
`solverforge-ui 0.9.1`; `solverforge --version` prints the targets your binary
carries.

Both paths below start from the directory where you keep projects. Run each
one from there, not from inside the other path's app: the scaffold path creates
`hospital-scheduler/` and the finished example clones `solverforge-hospital/`.

---

## Build the App from the Scaffold

### Scaffold the Project

```bash
solverforge new hospital-scheduler --quiet
cd hospital-scheduler
```

The scaffold is a runnable neutral app: a `Plan` solution with a
`HardSoftScore`, retained `/jobs` routes (status, snapshot, analysis, pause,
resume, cancel, delete, and SSE), a neutral frontend in `static/app.js`, and
sample data in `src/data/data_seed.rs`. All commands below run from
`hospital-scheduler/`.

### Generate the Domain

```bash
solverforge generate score HardSoftDecimalScore
solverforge generate fact employee \
  --field index:usize \
  --field home_hub:CareHub \
  --field "skills:BTreeSet<String>" \
  --field "unavailable_dates:BTreeSet<NaiveDate>" \
  --field "undesired_dates:BTreeSet<NaiveDate>" \
  --field "desired_dates:BTreeSet<NaiveDate>"
solverforge generate entity shift \
  --field "start:NaiveDateTime" \
  --field "end:NaiveDateTime" \
  --field location:String \
  --field care_hub:CareHub \
  --field required_skill:String
solverforge generate variable employee_idx \
  --entity Shift \
  --kind scalar \
  --range employees \
  --allows-unassigned
```

`generate fact` and `generate entity` declare `id` and `name` (facts) or `id`
(entities) themselves, import the field types, and add `chrono` to
`Cargo.toml` for the date fields. `Employee.index` stores the employee's
position in `Plan.employees`, which is the value `Shift.employee_idx` holds;
the rules below join on it.

Both commands warn that `CareHub` is not defined yet. Define it next.

### Define CareHub

`CareHub` is the care area a shift belongs to and an employee usually works
in. Create `src/domain/care_hub.rs`:

```rust
// file: src/domain/care_hub.rs
use serde::{Deserialize, Serialize};

/// The care area a shift belongs to and an employee usually works in.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CareHub {
    Ambulatory,
    CriticalCare,
    Surgery,
    #[default]
    Unknown,
}
```

Then export it from the model manifest. Replace `src/domain/mod.rs` with:

```rust
// file: src/domain/mod.rs
solverforge::planning_model! {
    root = "src/domain";

    // @solverforge:begin domain-exports
    mod care_hub;
    mod employee;
    mod shift;
    mod plan;

    pub use care_hub::CareHub;
    pub use employee::Employee;
    pub use shift::Shift;
    pub use plan::Plan;
    // @solverforge:end domain-exports
}
```

`mod care_hub;` and `pub use care_hub::CareHub;` sit inside the
`@solverforge:begin domain-exports` block, where the CLI keeps the model's
modules.

### Write the Rules

Generate one constraint module per scheduling rule:

```bash
solverforge generate constraint assigned_shift --unary --hard
solverforge generate constraint required_skill --join --hard
solverforge generate constraint overlapping_shift --pair --hard
solverforge generate constraint minimum_rest --pair --hard
solverforge generate constraint one_shift_per_day --pair --hard
solverforge generate constraint unavailable_employee --join --hard
solverforge generate constraint undesired_day --join --soft
solverforge generate constraint desired_day --join --soft
solverforge generate constraint balance_assignments --balance --soft
```

Each command writes `src/constraints/<name>.rs`, declares it in
`src/constraints/mod.rs`, and adds its call to `create_constraints` in
`src/constraints/assemble.rs`. The generated stream is ready; the placeholder
functions (the condition, and for joins the employee key) call `panic!` until
you replace them, and a solve fails with that message while any is left.
Replace each file with the version below.

A unary rule filters single shifts. `assigned_shift` penalizes a shift with no
employee:

```rust
// file: src/constraints/assigned_shift.rs
use crate::domain::{Plan, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: every shift needs an employee.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .filter(unary_condition)
        .penalize(hard_weight(unary_weight))
        .named("assigned_shift")
}

/// Selects each shift that has no employee yet.
fn unary_condition(entity: &Shift) -> bool {
    entity.employee_idx.is_none()
}

/// Penalty for one unassigned shift.
fn unary_weight(_entity: &Shift) -> HardSoftDecimalScore {
    <HardSoftDecimalScore as Score>::one_hard()
}
```

A join rule pairs each shift with the employee its `employee_idx` points to.
The employee side of the join key is `Some(fact.index)`, so a shift joins the
employee at that position. `required_skill` penalizes an employee without the
shift's skill:

```rust
// file: src/constraints/required_skill.rs
use crate::domain::{Employee, Plan, Shift};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// HARD: the assigned employee has the skill the shift requires.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .join((Plan::employees(), equal_bi(entity_join_key, fact_join_key)))
        .penalize(hard_weight(join_weight))
        .named("required_skill")
}

fn entity_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

/// `employee_idx` is a position in `Plan.employees`; `index` stores it.
fn fact_join_key(fact: &Employee) -> Option<usize> {
    Some(fact.index)
}

fn join_condition(entity: &Shift, fact: &Employee) -> bool {
    !fact.skills.contains(&entity.required_skill)
}

fn join_weight(entity: &Shift, fact: &Employee) -> HardSoftDecimalScore {
    if join_condition(entity, fact) {
        <HardSoftDecimalScore as Score>::one_hard()
    } else {
        <HardSoftDecimalScore as Score>::zero()
    }
}
```

`unavailable_employee` is the same join with a hard penalty for a shift on a
date the employee cannot work:

```rust
// file: src/constraints/unavailable_employee.rs
use crate::domain::{Employee, Plan, Shift};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// HARD: nobody works on a date they marked unavailable.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .join((Plan::employees(), equal_bi(entity_join_key, fact_join_key)))
        .penalize(hard_weight(join_weight))
        .named("unavailable_employee")
}

fn entity_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

/// `employee_idx` is a position in `Plan.employees`; `index` stores it.
fn fact_join_key(fact: &Employee) -> Option<usize> {
    Some(fact.index)
}

fn join_condition(entity: &Shift, fact: &Employee) -> bool {
    fact.unavailable_dates.contains(&entity.start.date())
}

fn join_weight(entity: &Shift, fact: &Employee) -> HardSoftDecimalScore {
    if join_condition(entity, fact) {
        <HardSoftDecimalScore as Score>::one_hard()
    } else {
        <HardSoftDecimalScore as Score>::zero()
    }
}
```

`undesired_day` and `desired_day` are soft preferences on the shift's start
date. `desired_day` rewards instead of penalizing:

```rust
// file: src/constraints/undesired_day.rs
use crate::domain::{Employee, Plan, Shift};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// SOFT: avoid assigning a shift on a date the employee would rather not work.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .join((Plan::employees(), equal_bi(entity_join_key, fact_join_key)))
        .penalize(join_weight)
        .named("undesired_day")
}

fn entity_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

/// `employee_idx` is a position in `Plan.employees`; `index` stores it.
fn fact_join_key(fact: &Employee) -> Option<usize> {
    Some(fact.index)
}

fn join_condition(entity: &Shift, fact: &Employee) -> bool {
    fact.undesired_dates.contains(&entity.start.date())
}

fn join_weight(entity: &Shift, fact: &Employee) -> HardSoftDecimalScore {
    if join_condition(entity, fact) {
        <HardSoftDecimalScore as Score>::one_soft()
    } else {
        <HardSoftDecimalScore as Score>::zero()
    }
}
```

```rust
// file: src/constraints/desired_day.rs
use crate::domain::{Employee, Plan, Shift};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// SOFT: reward assigning a shift on a date the employee asked for.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .join((Plan::employees(), equal_bi(entity_join_key, fact_join_key)))
        .reward(join_weight)
        .named("desired_day")
}

fn entity_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

/// `employee_idx` is a position in `Plan.employees`; `index` stores it.
fn fact_join_key(fact: &Employee) -> Option<usize> {
    Some(fact.index)
}

fn join_condition(entity: &Shift, fact: &Employee) -> bool {
    fact.desired_dates.contains(&entity.start.date())
}

fn join_weight(entity: &Shift, fact: &Employee) -> HardSoftDecimalScore {
    if join_condition(entity, fact) {
        <HardSoftDecimalScore as Score>::one_soft()
    } else {
        <HardSoftDecimalScore as Score>::zero()
    }
}
```

A pair rule joins the shifts of one employee with each other.
`overlapping_shift` penalizes two shifts whose times overlap:

```rust
// file: src/constraints/overlapping_shift.rs
use crate::domain::{Plan, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: one employee cannot cover two shifts that overlap in time.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .filter(has_employee_idx)
        .join(joiner::equal(employee_idx_join_key))
        .filter(pair_condition)
        .penalize(hard_weight(pair_weight))
        .named("overlapping_shift")
}

/// Unassigned entities share no value, so they never form a pair.
fn has_employee_idx(entity: &Shift) -> bool {
    entity.employee_idx.is_some()
}

/// A self-join on this key yields each unordered pair once.
fn employee_idx_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

/// Selects two shifts of one employee whose times overlap.
fn pair_condition(left: &Shift, right: &Shift) -> bool {
    left.start < right.end && right.start < left.end
}

/// Penalty for one pair selected by `pair_condition`.
fn pair_weight(_left: &Shift, _right: &Shift) -> HardSoftDecimalScore {
    <HardSoftDecimalScore as Score>::one_hard()
}
```

`minimum_rest` penalizes less than 10 hours between the end of one shift and
the start of the next:

```rust
// file: src/constraints/minimum_rest.rs
use crate::domain::{Plan, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: an employee rests at least 10 hours between two shifts.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .filter(has_employee_idx)
        .join(joiner::equal(employee_idx_join_key))
        .filter(pair_condition)
        .penalize(hard_weight(pair_weight))
        .named("minimum_rest")
}

/// Unassigned entities share no value, so they never form a pair.
fn has_employee_idx(entity: &Shift) -> bool {
    entity.employee_idx.is_some()
}

/// A self-join on this key yields each unordered pair once.
fn employee_idx_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

/// Selects two shifts of one employee with less than 10 hours between them.
fn pair_condition(left: &Shift, right: &Shift) -> bool {
    let (earlier, later) = if left.start <= right.start {
        (left, right)
    } else {
        (right, left)
    };
    let rest = later.start - earlier.end;
    rest >= chrono::TimeDelta::zero() && rest < chrono::TimeDelta::hours(10)
}

/// Penalty for one pair selected by `pair_condition`.
fn pair_weight(_left: &Shift, _right: &Shift) -> HardSoftDecimalScore {
    <HardSoftDecimalScore as Score>::one_hard()
}
```

`one_shift_per_day` penalizes two shifts that start on the same date:

```rust
// file: src/constraints/one_shift_per_day.rs
use crate::domain::{Plan, Shift};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: an employee works at most one shift per calendar day.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .filter(has_employee_idx)
        .join(joiner::equal(employee_idx_join_key))
        .filter(pair_condition)
        .penalize(hard_weight(pair_weight))
        .named("one_shift_per_day")
}

/// Unassigned entities share no value, so they never form a pair.
fn has_employee_idx(entity: &Shift) -> bool {
    entity.employee_idx.is_some()
}

/// A self-join on this key yields each unordered pair once.
fn employee_idx_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

/// Selects two shifts of one employee that start on the same date.
fn pair_condition(left: &Shift, right: &Shift) -> bool {
    left.start.date() == right.start.date()
}

/// Penalty for one pair selected by `pair_condition`.
fn pair_weight(_left: &Shift, _right: &Shift) -> HardSoftDecimalScore {
    <HardSoftDecimalScore as Score>::one_hard()
}
```

A balance rule groups shifts by employee and scores the spread of the counts.
`balance_assignments` penalizes the unfairness `load_balance` computes, in the
same soft unit as `one_soft()`:

```rust
// file: src/constraints/balance_assignments.rs
use crate::domain::{Plan, Shift};
use solverforge::prelude::*;
use solverforge::stream::collector::LoadBalance;
use solverforge::IncrementalConstraint;

/// SOFT: spread shifts evenly across employees.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .group_by(
            balance_scope,
            load_balance(balance_group_key, balance_metric),
        )
        .penalize(balance_weight)
        .named("balance_assignments")
}

fn balance_scope(_entity: &Shift) -> usize {
    0
}

fn balance_group_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

fn balance_metric(_entity: &Shift) -> i64 {
    1
}

/// Penalizes the spread of shift counts across assigned employees.
fn balance_weight(_scope: &usize, load: &LoadBalance<Option<usize>>) -> HardSoftDecimalScore {
    HardSoftDecimalScore::of_soft_scaled(load.unfairness())
}
```

### Seed Demo Data

The scaffold's sample data fills every field with defaults. Replace
`src/data/data_seed.rs` with a small week of hospital work: three wards with a
day and a late shift each, and fifteen nurses with skills, one unavailable date,
one undesired date, and one desired date each. `SMALL`, `STANDARD`, and
`LARGE` cover 3, 7, and 14 days:

```rust
// file: src/data/data_seed.rs
use std::collections::BTreeSet;
use std::str::FromStr;

use chrono::{NaiveDate, NaiveDateTime, TimeDelta};

use crate::domain::{CareHub, Employee, Plan, Shift};

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

/// The number of days each demo dataset schedules.
pub fn generate(demo: DemoData) -> Plan {
    match demo {
        DemoData::Small => generate_plan(3),
        DemoData::Standard => generate_plan(7),
        DemoData::Large => generate_plan(14),
    }
}

/// Wards with the skill each one requires.
const WARDS: &[(&str, CareHub, &str)] = &[
    ("Ambulatory care", CareHub::Ambulatory, "Ambulatory nurse"),
    (
        "Critical care",
        CareHub::CriticalCare,
        "Critical care nurse",
    ),
    ("Surgery", CareHub::Surgery, "Surgery nurse"),
];

/// Day shift 07:00-15:00 and late shift 15:00-23:00.
const SHIFT_STARTS: &[u32] = &[7, 15];

const EMPLOYEES: &[(&str, &[&str])] = &[
    ("Amy Cole", &["Ambulatory nurse"]),
    ("Beth Fox", &["Ambulatory nurse", "Surgery nurse"]),
    ("Chad Green", &["Critical care nurse"]),
    ("Dan Jones", &["Critical care nurse", "Ambulatory nurse"]),
    ("Elsa King", &["Surgery nurse"]),
    ("Flo Li", &["Surgery nurse", "Critical care nurse"]),
    ("Gus Poe", &["Ambulatory nurse"]),
    ("Hugo Rye", &["Critical care nurse"]),
    ("Ivy Shaw", &["Surgery nurse"]),
    (
        "Jay Watt",
        &["Ambulatory nurse", "Critical care nurse", "Surgery nurse"],
    ),
    ("Kai Ng", &["Ambulatory nurse"]),
    ("Lena Ortiz", &["Critical care nurse"]),
    ("Mo Park", &["Surgery nurse"]),
    ("Nina Quinn", &["Ambulatory nurse", "Surgery nurse"]),
    ("Omar Reed", &["Critical care nurse", "Surgery nurse"]),
];

fn generate_plan(days: i64) -> Plan {
    let first_day = NaiveDate::from_ymd_opt(2027, 1, 4).expect("valid date");
    let date = |offset: i64| first_day + TimeDelta::days(offset);

    let employees = EMPLOYEES
        .iter()
        .enumerate()
        .map(|(index, (name, skills))| {
            let skills: BTreeSet<String> = skills.iter().map(|skill| skill.to_string()).collect();
            let home_hub = WARDS
                .iter()
                .find(|(_, _, skill)| skills.contains(*skill))
                .map(|(_, hub, _)| *hub)
                .unwrap_or_default();
            let day = index as i64;
            Employee {
                id: format!("employee-{index}"),
                name: name.to_string(),
                index,
                home_hub,
                skills,
                unavailable_dates: BTreeSet::from([date(day % days)]),
                undesired_dates: BTreeSet::from([date((day + 1) % days)]),
                desired_dates: BTreeSet::from([date((day + 2) % days)]),
            }
        })
        .collect::<Vec<_>>();

    let mut shifts = Vec::new();
    for day in 0..days {
        for (location, care_hub, skill) in WARDS {
            for hour in SHIFT_STARTS {
                let start: NaiveDateTime = date(day).and_hms_opt(*hour, 0, 0).expect("valid time");
                shifts.push(Shift {
                    id: format!("shift-{}", shifts.len()),
                    start,
                    end: start + TimeDelta::hours(8),
                    location: location.to_string(),
                    care_hub: *care_hub,
                    required_skill: skill.to_string(),
                    employee_idx: None,
                });
            }
        }
    }

    Plan::new(employees, shifts)
}
```

### Configure the Solver

The scaffold's `solver.toml` runs the default pipeline. Name the phases
instead, in the shape the finished app uses: cheapest-insertion construction
over `employee_idx`, then late-acceptance local search that changes one
shift's employee or swaps the employees of two shifts. `random_seed` fixes
the solver's random choices. Replace `solver.toml` with:

```toml
# file: solver.toml
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
type = "change_move_selector"
entity_class = "Shift"
variable_name = "employee_idx"

[[phases.move_selector.selectors]]
type = "swap_move_selector"
entity_class = "Shift"
variable_name = "employee_idx"
```

`Plan` embeds this file at compile time through
`#[planning_solution(solver_toml = "../../solver.toml")]`.

### Build and Run

Check the managed seams, run the generated tests, and start the server:

```bash
solverforge check
cargo test
solverforge server -p 7860
```

`solverforge check` validates the managed blocks and model wiring without
compiling; `cargo test` compiles the app and runs the generated tests.
`solverforge server` builds the release binary and serves it on the port you
pass. Open `http://localhost:7860` and press **Solve**: the default `STANDARD`
dataset (42 shifts, 15 employees) solves to `0hard/...soft`, a schedule that
breaks no hard rule. The analysis view lists each rule by its module id, such
as `minimum_rest`.

This scheduler is the teaching core. The finished example adds what a
production demo needs on top: a deterministic month-long benchmark dataset,
derived fields rebuilt after JSON decoding, nearby search, minute-proportional
penalties, and a schedule UI.

---

## Run the Finished Example

### Download the Finished Example

Clone the Hugging Face Space repository and start the app:

```bash
git clone https://huggingface.co/spaces/SolverForge/solverforge-hospital
cd solverforge-hospital
make run-release
```

`make run-release` serves the release build on port 7860 (`PORT=<n>` picks
another). Open `http://localhost:7860` and press **Solve**.

The Space source is the finished app: it includes the deterministic hospital
benchmark generator, retained-job API, modular schedule frontend, tests, and
deployment files. The tagged release is `solverforge-hospital@3.0.4`.

### Keep the Published Dependency Shape

The finished app runs on `solverforge 0.26.1` and the `solverforge-ui 0.9.0`
web-shell assets. Its `Cargo.toml` dependencies:

```toml
[dependencies]
solverforge = { version = "0.26.1", features = [
  "serde",
  "console",
  "verbose-logging",
] }
solverforge-ui = "0.9.0"
rand = "0.10.1"

axum = "0.8.9"
tokio = { version = "1.52.3", features = ["full"] }
tokio-stream = { version = "0.1.18", features = ["sync"] }
tower-http = { version = "0.6.10", features = ["fs", "cors"] }
tower = "0.5.3"
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.149"
chrono = { version = "0.4.44", features = ["serde"] }
parking_lot = "0.12.5"
```

### Align App Metadata

`solverforge.app.toml` records the app's scaffold lineage and the public
crates it runs on:

```toml
[app]
name = "SolverForge Hospital"
starter = "neutral-shell"
shell = "web"
cli_version = "2.2.2"

[runtime]
target = "solverforge 0.26.1"
runtime_source = "crates.io: solverforge 0.26.1"
ui_source = "crates.io: solverforge-ui 0.9.0"

[demo]
default_size = "LARGE"
available_sizes = ["LARGE"]

[solution]
name = "Plan"
score = "HardSoftDecimalScore"
```

`cli_version` records the CLI release that first scaffolded the app; the
`[runtime]` lines name the crates.io versions the app builds against.
`solverforge check` validates this file and the managed blocks in the source.

### Project Shape

The finished hospital example is organized as:

```text
solverforge-hospital/
├── Cargo.toml
├── Makefile
├── package.json
├── solver.toml
├── solverforge.app.toml
├── src/
│   ├── api/
│   ├── constraints/
│   ├── data/
│   ├── domain/
│   ├── solver/
│   ├── lib.rs
│   └── main.rs
├── static/
│   ├── app/
│   ├── generated/ui-model.json
│   ├── index.html
│   └── sf-config.json
└── tests/
    ├── e2e/
    └── frontend/
```

Read the article for the cross-layer story, then read the comments in each file
for local intent.

---

## The Problem We're Solving

Hospital scheduling asks:

> Given a hospital workforce and a month of shifts, which employee should cover
> each shift?

The finished app ships one deterministic instance:

- a 28-day horizon with 50 employees and 688 shifts
- one public dataset id: `LARGE`
- two browser views: `By location` and `By employee`
- retained solve lifecycle with status, snapshot, analysis, pause, resume,
  cancel, delete, and SSE

The score model separates feasibility from quality. Each rule is named after
its module in `src/constraints/`, and score analysis reports that id:

| Rule                   | Kind | Meaning                                                     |
| ---------------------- | ---- | ----------------------------------------------------------- |
| `assigned_shift`       | Hard | Every shift is assigned to someone                          |
| `required_skill`       | Hard | The assigned employee has the required skill                |
| `overlapping_shift`    | Hard | One employee cannot cover overlapping shifts                |
| `minimum_rest`         | Hard | At least 10 hours between two shifts                        |
| `one_shift_per_day`    | Hard | One employee works at most one shift per touched day        |
| `unavailable_employee` | Hard | Unavailable dates are hard violations                       |
| `undesired_day`        | Soft | Softly penalize assignments on undesired dates              |
| `desired_day`          | Soft | Reward assignments on desired dates                         |
| `balance_assignments`  | Soft | Discourage concentrating too many shifts on one employee    |

Hard constraints define feasibility. Soft constraints define quality among
feasible schedules. The browser shows readable labels for these ids from
`static/app/app-model.json`.

---

## The Teaching Spine

The hospital app is the scalar-assignment tutorial in the SolverForge examples.
Its core path is:

1. `Employee` is immutable problem data.
2. `Shift` is the planning entity.
3. `Shift.employee_idx` is the scalar planning variable SolverForge mutates.
4. Constraints score each proposed assignment.
5. `solver.toml` defines how the solver constructs and improves schedules.
6. The retained job API keeps snapshots, analysis, pause, resume, cancel, and
   delete available to the browser.
7. `static/app/main.mjs` renders schedule views from the latest retained plan.

The comments in the repo do not repeat this whole story. They explain the local
reasoning at the point of implementation: why a field is skipped in JSON, why a
constraint is proportional to minutes, why nearby meters are hints rather than
rules, or why a generator pass exists.

---

## Understanding the Data Model

Open `src/domain/`.

The domain is deliberately small:

- `care_hub.rs`
  service-line grouping used by nearby search
- `employee.rs`
  problem fact, transport identity, skills, availability, preferences, and
  derived runtime helpers
- `plan.rs`
  `Shift`, `Plan`, scalar planning variable, normalization, and nearby meters
- `mod.rs`
  the `planning_model!` manifest and public exports

### Employee as Problem Fact

`Employee` is input data. The solver reads employees but does not move them.
The transport-visible identity is `Employee.id`; the solver-facing join key is
the dense `Employee.index`, which the finished app rebuilds during
normalization instead of sending it over HTTP.

This split matters because APIs need stable human-readable IDs, while hot solver
paths need cheap index comparisons.

### Shift as Planning Entity

`Shift` is the movable thing:

```rust
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
    // @solverforge:begin entity-variables
    // SolverForge mutates this scalar slot. The value is an index into
    // `Plan.employees`; `Employee.id` remains transport identity for API/UI use.
    #[planning_variable(
        value_range_provider = "employees",
        allows_unassigned = true,
        candidate_values = "shift_employee_candidates",
        nearby_value_candidates = "shift_nearby_employee_candidates",
        nearby_entity_candidates = "shift_nearby_shift_candidates",
        nearby_value_distance_meter = "shift_to_employee_nearby_distance",
        nearby_entity_distance_meter = "shift_to_shift_nearby_distance"
    )]
    pub employee_idx: Option<usize>,
    // @solverforge:end entity-variables
}
```

`employee_idx` points into `Plan.employees`, not to `Employee.id`. That is the
central scalar-assignment idea in this example. The candidate and nearby
attributes name functions in `plan.rs` that feed construction and nearby moves.

### Plan as Planning Solution

`Plan` carries the two collections and the score:

```rust
#[planning_solution(
    constraints = "crate::constraints::create_constraints",
    solver_toml = "../../solver.toml"
)]
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Plan {
    // @solverforge:begin solution-collections
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    // @solverforge:end solution-collections
    #[planning_score]
    pub score: Option<HardSoftDecimalScore>,
    #[serde(skip)]
    employee_indices: Vec<usize>,
    #[serde(skip)]
    shift_indices: Vec<usize>,
}
```

`Plan::rebuild_derived_fields()` is the normalization boundary. It restores
employee indexes, inferred `CareHub` values, touched calendar dates, and
range-safe assignments after generation or HTTP decoding.

### Domain Manifest

`src/domain/mod.rs` is not just a list of modules. It is the SolverForge model
manifest:

```rust
solverforge::planning_model! {
    root = "src/domain";

    // @solverforge:begin domain-exports
    mod care_hub;
    mod employee;
    mod plan;

    pub use care_hub::CareHub;
    pub use employee::Employee;
    pub use plan::Plan;
    pub use plan::PlanConstraintStreams;
    pub use plan::Shift;
    // @solverforge:end domain-exports
}
```

The `@solverforge` markers are scaffold/codegen boundary markers. You can read
past them while learning the domain; they exist so generated edits know where
managed exports begin and end.

---

## The Demo Dataset

The finished app exposes one public dataset. `GET /demo-data` returns:

```json
["LARGE"]
```

The route handler reads that list from `data::list_demo_data()`, so the public
API and the generator stay aligned.

The dataset is not random filler. It is a deterministic benchmark designed to
teach real search:

1. Workforce blueprints define skill mix and service-line identity.
2. Demand templates generate the public shifts.
3. A hidden feasible witness roster proves the generator can shape a hard
   feasible problem.
4. Availability and preference passes add real pressure without destroying that
   feasibility margin.
5. Validation checks the exact public plan before it is served.

The hidden witness is never shown to the solver. It exists only to shape a
public problem that has both hard-feasible assignments and useful soft-score
movement.

---

## How Optimization Works

Traditional programming says: "do this, then do that."

Constraint-based optimization says: "here is the domain, here are the rules,
and here is what better means."

The hospital example uses `HardSoftDecimalScore`.

Hard score records feasibility problems. Soft score records quality once the
plan is feasible enough to compare. The hard constraint modules use one
fixed-point scale:

```rust
const SCORE_SCALE: i64 = 100_000;
```

Using the same scale across rules lets the app express very different priorities
without changing the shape of the score model. A wrong-skilled assignment can
be much worse than an unassigned shift. Preferences can remain small enough to
matter only after hard problems are under control.

---

## Writing Constraints

Open `src/constraints/`.

Each sibling file defines one incremental rule. `src/constraints/mod.rs`
declares the rule modules and re-exports `create_constraints`; it holds no
code. `create_constraints()` in `src/constraints/assemble.rs` assembles the
rules into the scoring model, in the order score analysis lists them:

```rust
pub fn create_constraints() -> impl ConstraintSet<Plan, HardSoftDecimalScore> {
    // @solverforge:begin constraint-calls
    (
        super::assigned_shift::constraint(),
        super::required_skill::constraint(),
        super::overlapping_shift::constraint(),
        super::minimum_rest::constraint(),
        super::one_shift_per_day::constraint(),
        super::unavailable_employee::constraint(),
        super::undesired_day::constraint(),
        super::desired_day::constraint(),
        super::balance_assignments::constraint(),
    )
    // @solverforge:end constraint-calls
}
```

Read the constraint files in this order:

1. `assigned_shift.rs`
   A unary hard rule over unassigned `Shift` entities.
2. `required_skill.rs`
   A fact join from `Shift.employee_idx` to `Employee.index`.
3. `overlapping_shift.rs`, `minimum_rest.rs`, and `one_shift_per_day.rs`
   Self-joins that compare two shifts for the same employee.
4. `unavailable_employee.rs`
   A fact join with a minute-proportional hard penalty.
5. `desired_day.rs` and `undesired_day.rs`
   Soft preference signals from touched calendar dates.
6. `balance_assignments.rs`
   A grouped balance rule over `employee_idx`.

The teaching pattern is the same in every file:

```text
stream shape -> join/filter -> score impact -> why the weight matters
```

Constraints do not assign employees. They score the assignments the solver is
considering.

For a complete grouped rule that mixes joins, a collector, and a medium
penalty in one worked example — including why the grouping key must be the
shift or block, not the employee — read
[Shift-Group Uniformity](/docs/solverforge/constraints/shift-group-uniformity/)
in the constraint documentation.

### Required Skill

The required-skill rule is the best first join to read. It matches a shift to
its employee by comparing `shift.employee_idx` with `Some(employee.index)`, then
hard-penalizes missing skills:

```rust
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .join((
            ConstraintFactory::<Plan, HardSoftDecimalScore>::new().employees(),
            joiner::equal_bi(
                |shift: &Shift| shift.employee_idx,
                |employee: &Employee| Some(employee.index),
            ),
        ))
        .filter(|shift: &Shift, employee: &Employee| {
            !employee.skills.contains(&shift.required_skill)
        })
        .penalize(HardSoftDecimalScore::of_hard_scaled(10 * SCORE_SCALE))
        .named("required_skill")
}
```

That is the scalar index pattern used throughout the app.

### Availability and Preferences

`unavailable_employee` is hard and minute-proportional. If a shift overlaps an
unavailable date by more minutes, the penalty is larger.

`desired_day` and `undesired_day` are soft and date-count based. They shape which
feasible schedule is better, but they do not decide feasibility.

### Balance

`balance_assignments` groups shifts by `employee_idx` and softly penalizes
uneven assignment counts. The finished app writes it with the compact
`.balance(...)` stream:

```rust
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .shifts()
        .balance(|shift: &Shift| shift.employee_idx)
        .penalize(HardSoftDecimalScore::one_soft())
        .named("balance_assignments")
}
```

---

## Solver Policy

`solver.toml` is embedded by `Plan` and is the runtime source of truth:

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

Construction assigns shifts one at a time by trying candidate employee values
and choosing the least damaging option. Local search then improves that plan by
changing assignments and swapping assignments. Solving stops after 30 seconds,
or after 5 seconds without improvement.

Nearby search is a hint layer, not a rule layer. The `CareHub` meters rank
promising employees and shift pairs before exact scoring. The constraints still
decide feasibility and quality.

---

## Runtime and Browser Behavior

The hospital app keeps the stock retained lifecycle and adapts it to its domain.

The public job API is:

```text
POST   /jobs
GET    /jobs/{id}
DELETE /jobs/{id}
GET    /jobs/{id}/status
GET    /jobs/{id}/snapshot
GET    /jobs/{id}/analysis
POST   /jobs/{id}/pause
POST   /jobs/{id}/resume
POST   /jobs/{id}/cancel
GET    /jobs/{id}/events
```

`GET /health`, `GET /info`, `GET /demo-data`, and `GET /demo-data/{id}` serve
the app's health, metadata, and demo data. `snapshot_revision={n}` is optional
for snapshots and analysis.

`src/solver/service.rs` wraps `SolverManager<Plan>`, stores per-job SSE state,
and translates runtime events into the JSON payloads consumed by the browser.

`src/api/dto.rs` is the transport boundary. `PlanDto::to_domain()` rebuilds the
domain `Plan` from flattened JSON and calls normalization before the solver sees
the schedule.

`static/app/main.mjs` is the browser entrypoint. Its config loader reads
`sf-config.json`, the CLI-generated `generated/ui-model.json`, and the
app-owned `app/app-model.json` (labels, constraint catalog, and views), then
confirms that the configured `LARGE` id is listed by `/demo-data`. The
entrypoint creates the shared `solverforge-ui` shell and renders the schedule
in both views. Snapshot analysis is fetched from `/jobs/{id}/analysis` only
when the user requests it.

The neutral scaffold has `static/app.js`; the finished hospital app uses
focused modules under `static/app/`.

---

## Making Your First Customization

A good first scheduling expansion is a new constraint that touches only the
domain rule layer. A home-hub preference is a soft fact join. From the
`solverforge-hospital/` clone:

```bash
solverforge generate constraint home_hub_match --join --soft
```

The CLI writes the module, declares it in `src/constraints/mod.rs`, and
appends `super::home_hub_match::constraint()` to `src/constraints/assemble.rs`.
Replace its placeholders: join `Shift.employee_idx` to `Employee.index`, keep
pairs where `employee.home_hub == shift.care_hub`, and reward the match.
Replace `src/constraints/home_hub_match.rs` with:

```rust
// file: src/constraints/home_hub_match.rs
use crate::domain::{Employee, Plan, Shift};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// SOFT: reward assigning a shift to an employee from the shift's care hub.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftDecimalScore> {
    ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
        .for_each(Plan::shifts())
        .join((Plan::employees(), equal_bi(entity_join_key, fact_join_key)))
        .reward(join_weight)
        .named("home_hub_match")
}

fn entity_join_key(entity: &Shift) -> Option<usize> {
    entity.employee_idx
}

fn fact_join_key(fact: &Employee) -> Option<usize> {
    Some(fact.index)
}

fn join_condition(entity: &Shift, fact: &Employee) -> bool {
    fact.home_hub == entity.care_hub
}

fn join_weight(entity: &Shift, fact: &Employee) -> HardSoftDecimalScore {
    if join_condition(entity, fact) {
        <HardSoftDecimalScore as Score>::one_soft()
    } else {
        <HardSoftDecimalScore as Score>::zero()
    }
}
```

This is the normal SolverForge growth path:

1. generate the managed seam
2. write the domain rule
3. run the tests and inspect score analysis, which lists `home_hub_match`

The retained backend and browser contract do not have to change for a pure
constraint addition.

---

## Testing and Validation

From the `solverforge-hospital/` clone, run the baseline checks:

```bash
solverforge check
solverforge routes
cargo fmt --check
make install-e2e
make test
```

`solverforge check` validates the app metadata and model wiring without
compiling. `solverforge routes` lists the routes in `src/api/routes.rs`.
`make install-e2e` installs the Playwright version pinned in the app's
`package-lock.json`, and the Chromium it needs when the system has none.
`make test` runs the Rust tests, browserless frontend tests, and Playwright
browser tests. Browser test servers honor `CARGO_TARGET_DIR`, so a shared
Cargo build location works as well as the app-local `target` directory.

`make ci-local` adds formatting, clippy, a release build, and the Docker image
build used for the Space. `make test-slow` runs the release-profile acceptance
solve that proves the public `LARGE` dataset reaches a hard-feasible terminal
state.

---

## Quick Reference

| Need                             | File or directory                          |
| -------------------------------- | ------------------------------------------ |
| Tagged app release               | `solverforge-hospital@3.0.4`               |
| App metadata                     | `solverforge.app.toml`                     |
| Solver policy                    | `solver.toml`                              |
| Planning model manifest          | `src/domain/mod.rs`                        |
| Employee fact                    | `src/domain/employee.rs`                   |
| Care hub                         | `src/domain/care_hub.rs`                   |
| Shift entity and scalar variable | `src/domain/plan.rs`                       |
| Constraint module declarations   | `src/constraints/mod.rs`                   |
| Constraint assembly              | `src/constraints/assemble.rs`              |
| One scheduling rule              | `src/constraints/*.rs`                     |
| Public demo-data entrypoints     | `src/data/data_seed/entrypoints.rs`        |
| Published benchmark generator    | `src/data/data_seed/large.rs` and siblings |
| Hidden feasibility witness       | `src/data/data_seed/witness.rs`            |
| API routes                       | `src/api/routes.rs`                        |
| DTO contract                     | `src/api/dto.rs`                           |
| SSE endpoint                     | `src/api/sse.rs`                           |
| Solver service                   | `src/solver/service.rs`                    |
| Browser controller               | `static/app/main.mjs`                      |
| Constraint labels and views      | `static/app/app-model.json`                |
| Schedule views                   | `static/app/schedule/*.mjs`                |

### Common Gotchas

- `generate fact` and `generate entity` declare `id` (and `name` for facts);
  pass only your own fields.
- A type named in `--field` that is not a Rust or `chrono` type must be defined
  under `src/domain/` and exported from `src/domain/mod.rs` before the app
  compiles.
- Generated constraint placeholders `panic!` until replaced; a solve fails with
  the file name of the first one it reaches.
- `employee_idx` is an index into `Plan.employees`; `Employee.id` is API/UI
  identity.
- Nearby meters rank candidates before exact scoring; they do not replace
  constraints.
- `Plan::rebuild_derived_fields()` must run after JSON decoding.
- `/demo-data` must agree with `data::list_demo_data()`.
- The finished app's public dataset is `LARGE` only.
- The finished browser app is module-based and starts from
  `static/app/main.mjs`.

### Additional Resources

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [solverforge-cli Modeling and Generation](/docs/solverforge-cli/modeling-and-generation/)
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
- [Solver Phases](/docs/solverforge/solver/phases/)
- [Python Hospital Example](/docs/solverforge-python/hospital-example/)
- [Project Overview](/docs/overview/)
