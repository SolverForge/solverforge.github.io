---
title: "Employee Scheduling"
linkTitle: "Employee Scheduling"
icon: fa-brands fa-rust
date: 2026-04-17
weight: 5
description: "A comprehensive quickstart guide to understanding and building intelligent employee scheduling with SolverForge 0.8.12 in Rust"
categories: [Quickstarts]
tags: [quickstart, rust]
---

<%= render Ui::Callout.new do %>
This guide is written against **SolverForge 0.8.12**.

The standard onboarding path is **`solverforge-cli`**. This page intentionally
keeps the older employee scheduling tutorial shape and examples, but ports the
implementation to the current Rust runtime surface: generated stream accessors,
`solver.toml`, `SolverManager`, retained snapshots, and `analyze(...)`.
<% end %>

---

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

This guide walks you through a complete employee scheduling application built
with **SolverForge**, a constraint-based optimization framework. You'll learn:

- How to model real-world scheduling problems as **optimization problems**
- How to express business rules as **constraints** that guide the solution
- How optimization algorithms find high-quality solutions automatically
- How to customize the system for your specific needs

**No optimization background required** — we'll explain concepts as we encounter
them in the code.

> **Architecture Note:** In the current Rust surface, the core domain model is
> plain Rust structs annotated with SolverForge macros. If you add an HTTP API,
> keep DTOs at the boundary and keep solver-facing types simple. The standard
> scaffold for that shape comes from `solverforge-cli`.

### Prerequisites

- Basic Rust knowledge (structs, enums, traits, closures, derive macros)
- Familiarity with REST APIs
- Comfort with command-line operations

### What is Constraint-Based Optimization?

Traditional programming: You write explicit logic that says "do this, then
that."

**Constraint-based optimization**: You describe what a good solution looks like
and the solver figures out how to achieve it.

Think of it like describing what puzzle pieces you have and what rules they
must follow — then having a computer try millions of arrangements per second to
find the best fit.

### Why Native Rust?

SolverForge's Rust implementation gives you:

- Static, type-checked domain models
- Generated stream accessors such as `factory.shifts()`
- Current retained job lifecycle support through `SolverManager`
- Native performance without a Python-Java bridge

---

## Getting Started

### Running the Application

If you just want the default project shell, start with the CLI:

```bash
cargo install solverforge-cli
solverforge new clinic-scheduler
cd clinic-scheduler
```

This tutorial deliberately keeps the old employee scheduling walkthrough shape,
so after scaffolding, replace the neutral shell with the domain, constraints,
demo data, and optional API modules shown below.

If your example uses `chrono` dates and times, add it to `Cargo.toml`:

```toml
[dependencies]
chrono = "0.4"
solverforge = { version = "0.8.12", features = ["serde", "console", "verbose-logging"] }
```

Create a `solver.toml` so the runtime has an explicit search strategy:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"

[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[termination]
seconds_spent_limit = 30
```

Then run the app:

```bash
solverforge server
```

or, if you are wiring your own `main.rs`:

```bash
cargo run
```

Open your browser:

```text
http://localhost:7860
```

You'll see a scheduling interface with employees, shifts, and a "Solve" button.
Click it and watch the solver automatically assign employees to shifts while
respecting business rules.

### File Structure Overview

Fresh `solverforge-cli` projects start a little more generic, but once you
shape the employee scheduling example from this guide, you'll end up with
roughly this structure:

```text
clinic-scheduler/
├── src/
│   ├── main.rs           # Axum server entry point or console runner
│   ├── lib.rs            # Library crate root
│   ├── domain.rs         # Data models (Employee, Shift, EmployeeSchedule)
│   ├── constraints.rs    # Business rules (90% of customization happens here)
│   ├── demo_data.rs      # Sample data generation
│   ├── api.rs            # Optional REST handlers
│   └── solver.rs         # Optional retained-job service wrapper
├── static/
│   ├── index.html        # Web UI
│   └── app.js            # UI logic and visualization
└── solver.toml           # Search strategy and termination
```

**Key insight:** Most business customization happens in `constraints.rs` alone.
You rarely need to modify other files.

---

## The Problem We're Solving

### The Scheduling Challenge

You need to assign **employees** to **shifts** while satisfying rules like:

**Hard constraints** (must be satisfied):

- Employee must have the required skill for the shift
- Employee can't work overlapping shifts
- Employee needs 10 hours rest between shifts
- Employee can't work more than one shift per day
- Employee can't work on days they're unavailable

**Soft constraints** (preferences to optimize):

- Avoid scheduling on days the employee marked as "undesired"
- Prefer scheduling on days the employee marked as "desired"
- Balance workload fairly across all employees

### Why This is Hard

For even 20 shifts and 10 employees, there are **10^20 possible assignments**
(100 quintillion). A human can't evaluate them all. Even a computer trying
random assignments would take years.

**Optimization algorithms** use smart strategies to explore this space
efficiently, finding high-quality solutions in seconds.

---

## Understanding the Data Model

Let's examine the three core structs that model our problem. Open
`src/domain.rs`.

### Domain Model Architecture

The current Rust version keeps solver-facing types small and explicit:

- **Domain layer**: annotated Rust structs used directly by the solver
- **Optional API layer**: DTOs for JSON payloads
- **Mapping layer**: conversion between DTOs and the solver domain

This keeps the hot loop simple. Constraints run against the planning solution,
not against HTTP payload types.

### The Employee Struct

```rust
use std::collections::HashSet;

use chrono::NaiveDate;
use solverforge::prelude::*;

#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub id: usize,
    pub name: String,
    pub skills: HashSet<String>,
    pub unavailable_days: Vec<NaiveDate>,
    pub undesired_days: Vec<NaiveDate>,
    pub desired_days: Vec<NaiveDate>,
}
```

**What it represents:** A person who can be assigned to shifts.

**Key fields:**

- `id`: Stable numeric identifier
- `name`: Human-readable identifier
- `skills`: What skills this employee possesses
- `unavailable_days`: Days the employee absolutely cannot work
- `undesired_days`: Days the employee would prefer not to work
- `desired_days`: Days the employee wants to work

**Optimization concept:** These availability fields demonstrate **hard vs soft
constraints**. Unavailable is non-negotiable; undesired is a preference the
solver will try to honor but may violate if necessary.

> **Practical note:** If your planning variable is `Option<usize>`, keep the
> IDs aligned with the values the solver assigns. In the demo below, employees
> are numbered from `0` upward.

### The Shift Struct (Planning Entity)

```rust
use chrono::NaiveDateTime;
use solverforge::prelude::*;

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub label: String,
    pub required_skill: String,
    pub start: NaiveDateTime,
    pub end: NaiveDateTime,

    #[planning_variable(value_range = "employees", allows_unassigned = true)]
    pub employee_id: Option<usize>,
}

impl Shift {
    pub fn date(&self) -> chrono::NaiveDate {
        self.start.date()
    }
}
```

**What it represents:** A time slot that needs an employee assignment.

**Key fields:**

- `id`: Unique identifier
- `label`: Human-readable name for the shift
- `start` / `end`: When the shift occurs
- `required_skill`: What skill is needed
- **`employee_id`**: The assignment decision — this is what the solver
  optimizes

**Important annotations:**

- `#[planning_entity]`: Tells SolverForge this struct contains decisions to
  make
- `#[planning_variable(...)]`: Marks `employee_id` as the variable the solver
  changes
- `value_range = "employees"`: Valid values come from the `employees` field on
  the planning solution
- `allows_unassigned = true`: A shift may temporarily remain unassigned during
  search

### The EmployeeSchedule Struct (Planning Solution)

```rust
#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct EmployeeSchedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

**What it represents:** The complete problem and its solution.

**Key fields:**

- `employees`: All available employees
- `shifts`: All shifts that need assignment
- `score`: Solution quality metric calculated by constraints

**Annotations explained:**

- `#[planning_solution(constraints = "...")]`: Marks the top-level problem and
  wires it to the constraint function
- `#[problem_fact_collection]`: Immutable data
- `#[planning_entity_collection]`: Entities being optimized
- `#[planning_score]`: Where the solver stores the calculated score

**Optimization concept:** This is the **declarative modeling approach**. You
describe the problem structure and the solver handles the search process.

---

## How Optimization Works

Before diving into constraints, let's understand how the solver finds
solutions.

### The Search Process (Simplified)

1. **Start with an initial solution** (often unassigned or partially assigned)
2. **Evaluate the score** using your constraint function
3. **Make a small change** (assign a different employee to one shift)
4. **Evaluate the new score**
5. **Keep the change if it improves the score** (with some controlled
   randomness)
6. **Repeat thousands or millions of times**
7. **Return the best solution found**

### Why This Works: Metaheuristics

SolverForge uses standard **metaheuristic algorithms** such as:

- **Late Acceptance**: Compare the current move to recent history instead of
  only the immediate prior move
- **Tabu Search**: Remember recent moves to avoid cycling
- **Construction Heuristics**: Build a reasonable first solution quickly

These techniques efficiently explore the massive solution space without getting
stuck.

### The Score: How "Good" is a Solution?

Every solution gets a score with two parts:

```text
0hard/959soft
```

- **Hard score**: Counts hard constraint violations
- **Soft score**: Counts soft penalties and rewards

**Scoring rules:**

- Hard score must be `0` for a feasible solution
- Among feasible solutions, higher soft score wins
- Hard score always takes priority over soft score

**Optimization concept:** This is **multi-objective optimization** with a
**lexicographic ordering**. We absolutely prioritize hard constraints, then
optimize soft ones.

---

## Writing Constraints: The Business Rules

Now the heart of the system. Open `src/constraints.rs`.

### The Constraint Provider Pattern

All constraints are registered in one function:

```rust
use chrono::NaiveDate;
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

fn employees(schedule: &EmployeeSchedule) -> &[Employee] {
    schedule.employees.as_slice()
}

pub fn define_constraints() -> impl ConstraintSet<EmployeeSchedule, HardSoftScore> {
    use EmployeeScheduleConstraintStreams;
    use ShiftUnassignedFilter;

    let factory = ConstraintFactory::<EmployeeSchedule, HardSoftScore>::new();

    let unassigned = factory
        .clone()
        .shifts()
        .unassigned()
        .penalize_hard()
        .named("Unassigned shift");

    let required_skill = factory
        .clone()
        .shifts()
        .filter(|shift: &Shift| shift.employee_id.is_some())
        .join((
            employees,
            equal_bi(
                |shift: &Shift| shift.employee_id,
                |employee: &Employee| Some(employee.id),
            ),
        ))
        .filter(|shift: &Shift, employee: &Employee| {
            !employee.skills.contains(&shift.required_skill)
        })
        .penalize_hard()
        .named("Missing required skill");

    let no_overlapping_shifts = factory
        .clone()
        .shifts()
        .join(equal(|shift: &Shift| shift.employee_id))
        .filter(|a: &Shift, b: &Shift| {
            a.id < b.id
                && a.employee_id.is_some()
                && a.start < b.end
                && b.start < a.end
        })
        .penalize_hard_with(|a: &Shift, b: &Shift| HardSoftScore::of_hard(overlap_minutes(a, b)))
        .named("Overlapping shift");

    let at_least_10_hours_between_two_shifts = factory
        .clone()
        .shifts()
        .join(equal(|shift: &Shift| shift.employee_id))
        .filter(|a: &Shift, b: &Shift| {
            a.employee_id.is_some()
                && a.id != b.id
                && a.end <= b.start
                && rest_gap_minutes(a, b) < 600
        })
        .penalize_hard_with(|a: &Shift, b: &Shift| {
            HardSoftScore::of_hard(600 - rest_gap_minutes(a, b))
        })
        .named("At least 10 hours between 2 shifts");

    let one_shift_per_day = factory
        .clone()
        .shifts()
        .join(equal(|shift: &Shift| shift.employee_id))
        .filter(|a: &Shift, b: &Shift| {
            a.id < b.id
                && a.employee_id.is_some()
                && a.date() == b.date()
        })
        .penalize_hard()
        .named("Max one shift per day");

    let unavailable_employee = factory
        .clone()
        .shifts()
        .filter(|shift: &Shift| shift.employee_id.is_some())
        .join((
            employees,
            equal_bi(
                |shift: &Shift| shift.employee_id,
                |employee: &Employee| Some(employee.id),
            ),
        ))
        .flatten_last(
            |employee: &Employee| employee.unavailable_days.as_slice(),
            |day: &NaiveDate| *day,
            |shift: &Shift| shift.date(),
        )
        .filter(|shift: &Shift, day: &NaiveDate| overlap_with_day_minutes(shift, *day) > 0)
        .penalize_hard_with(|shift: &Shift, day: &NaiveDate| {
            HardSoftScore::of_hard(overlap_with_day_minutes(shift, *day))
        })
        .named("Unavailable employee");

    let undesired_day_for_employee = factory
        .clone()
        .shifts()
        .filter(|shift: &Shift| shift.employee_id.is_some())
        .join((
            employees,
            equal_bi(
                |shift: &Shift| shift.employee_id,
                |employee: &Employee| Some(employee.id),
            ),
        ))
        .flatten_last(
            |employee: &Employee| employee.undesired_days.as_slice(),
            |day: &NaiveDate| *day,
            |shift: &Shift| shift.date(),
        )
        .filter(|shift: &Shift, day: &NaiveDate| overlap_with_day_minutes(shift, *day) > 0)
        .penalize_with(|shift: &Shift, day: &NaiveDate| {
            HardSoftScore::of_soft(overlap_with_day_minutes(shift, *day))
        })
        .named("Undesired day for employee");

    let desired_day_for_employee = factory
        .clone()
        .shifts()
        .filter(|shift: &Shift| shift.employee_id.is_some())
        .join((
            employees,
            equal_bi(
                |shift: &Shift| shift.employee_id,
                |employee: &Employee| Some(employee.id),
            ),
        ))
        .flatten_last(
            |employee: &Employee| employee.desired_days.as_slice(),
            |day: &NaiveDate| *day,
            |shift: &Shift| shift.date(),
        )
        .filter(|shift: &Shift, day: &NaiveDate| overlap_with_day_minutes(shift, *day) > 0)
        .reward_with(|shift: &Shift, day: &NaiveDate| {
            HardSoftScore::of_soft(overlap_with_day_minutes(shift, *day))
        })
        .named("Desired day for employee");

    let balance_employee_shift_assignments = factory
        .shifts()
        .balance(|shift: &Shift| shift.employee_id)
        .penalize_soft()
        .named("Balance employee shift assignments");

    (
        unassigned,
        required_skill,
        no_overlapping_shifts,
        at_least_10_hours_between_two_shifts,
        one_shift_per_day,
        unavailable_employee,
        undesired_day_for_employee,
        desired_day_for_employee,
        balance_employee_shift_assignments,
    )
}
```

Each constraint is a builder chain returning a constraint value. Let's examine
them from simple to complex.

### Helper Functions for Time Calculations

The shift helpers used by several constraints are ordinary Rust functions:

```rust
fn overlap_minutes(a: &Shift, b: &Shift) -> i64 {
    let start = a.start.max(b.start);
    let end = a.end.min(b.end);
    if start < end {
        (end - start).num_minutes()
    } else {
        0
    }
}

fn rest_gap_minutes(a: &Shift, b: &Shift) -> i64 {
    if a.end <= b.start {
        (b.start - a.end).num_minutes()
    } else if b.end <= a.start {
        (a.start - b.end).num_minutes()
    } else {
        0
    }
}

fn overlap_with_day_minutes(shift: &Shift, day: NaiveDate) -> i64 {
    let day_start = day.and_hms_opt(0, 0, 0).unwrap();
    let day_end = day
        .succ_opt()
        .expect("next day should exist")
        .and_hms_opt(0, 0, 0)
        .unwrap();

    let start = shift.start.max(day_start);
    let end = shift.end.min(day_end);

    if start < end {
        (end - start).num_minutes()
    } else {
        0
    }
}
```

These keep the constraint bodies readable and make unit testing easier.

### Hard Constraint: Required Skill

**Business rule:** "An employee assigned to a shift must have the required
skill."

```rust
let required_skill = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .join((
        employees,
        equal_bi(
            |shift: &Shift| shift.employee_id,
            |employee: &Employee| Some(employee.id),
        ),
    ))
    .filter(|shift: &Shift, employee: &Employee| {
        !employee.skills.contains(&shift.required_skill)
    })
    .penalize_hard()
    .named("Missing required skill");
```

**How to read this:**

1. `factory.shifts()` starts from the generated `shifts` collection accessor
2. `.filter(...)` keeps only assigned shifts
3. `.join((employees, equal_bi(...)))` joins each shift to its assigned employee
4. The second `.filter(...)` keeps only skill mismatches
5. `.penalize_hard()` subtracts one hard point per violation

**Optimization concept:** This is a **cross-collection binary constraint**. The
solver is reasoning about relationships between `Shift` and `Employee`.

### Hard Constraint: No Overlapping Shifts

**Business rule:** "An employee can't work two shifts that overlap in time."

```rust
let no_overlapping_shifts = factory
    .clone()
    .shifts()
    .join(equal(|shift: &Shift| shift.employee_id))
    .filter(|a: &Shift, b: &Shift| {
        a.id < b.id
            && a.employee_id.is_some()
            && a.start < b.end
            && b.start < a.end
    })
    .penalize_hard_with(|a: &Shift, b: &Shift| HardSoftScore::of_hard(overlap_minutes(a, b)))
    .named("Overlapping shift");
```

**How to read this:**

1. `.join(equal(...))` creates a self-join over shifts with the same employee
2. `a.id < b.id` keeps the pair unique
3. `a.start < b.end && b.start < a.end` is the standard interval-overlap test
4. The hard penalty scales by overlapping minutes

**Optimization concept:** This replaces the older `for_each_unique_pair(...)`
style. In the current API, self-joins also go through `.join(...)`.

### Hard Constraint: Rest Between Shifts

**Business rule:** "Employees need at least 10 hours rest between shifts."

```rust
let at_least_10_hours_between_two_shifts = factory
    .clone()
    .shifts()
    .join(equal(|shift: &Shift| shift.employee_id))
    .filter(|a: &Shift, b: &Shift| {
        a.employee_id.is_some()
            && a.id != b.id
            && a.end <= b.start
            && rest_gap_minutes(a, b) < 600
    })
    .penalize_hard_with(|a: &Shift, b: &Shift| {
        HardSoftScore::of_hard(600 - rest_gap_minutes(a, b))
    })
    .named("At least 10 hours between 2 shifts");
```

**Optimization concept:** The penalty is **graded**. Nine hours rest is better
than five hours rest, so the solver gets better guidance than from a flat
penalty.

### Hard Constraint: One Shift Per Day

**Business rule:** "Employees can work at most one shift per calendar day."

```rust
let one_shift_per_day = factory
    .clone()
    .shifts()
    .join(equal(|shift: &Shift| shift.employee_id))
    .filter(|a: &Shift, b: &Shift| {
        a.id < b.id
            && a.employee_id.is_some()
            && a.date() == b.date()
    })
    .penalize_hard()
    .named("Max one shift per day");
```

### Hard Constraint: Unavailable Dates

**Business rule:** "Employees cannot work on days they marked as unavailable."

```rust
let unavailable_employee = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .join((
        employees,
        equal_bi(
            |shift: &Shift| shift.employee_id,
            |employee: &Employee| Some(employee.id),
        ),
    ))
    .flatten_last(
        |employee: &Employee| employee.unavailable_days.as_slice(),
        |day: &NaiveDate| *day,
        |shift: &Shift| shift.date(),
    )
    .filter(|shift: &Shift, day: &NaiveDate| overlap_with_day_minutes(shift, *day) > 0)
    .penalize_hard_with(|shift: &Shift, day: &NaiveDate| {
        HardSoftScore::of_hard(overlap_with_day_minutes(shift, *day))
    })
    .named("Unavailable employee");
```

**Optimization concept:** `flatten_last(...)` is how the current stream API
expands each employee's list of dates into individual `(shift, day)` pairs.

### Soft Constraint: Undesired Days

**Business rule:** "Prefer not to schedule employees on days they marked as
undesired."

```rust
let undesired_day_for_employee = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .join((
        employees,
        equal_bi(
            |shift: &Shift| shift.employee_id,
            |employee: &Employee| Some(employee.id),
        ),
    ))
    .flatten_last(
        |employee: &Employee| employee.undesired_days.as_slice(),
        |day: &NaiveDate| *day,
        |shift: &Shift| shift.date(),
    )
    .filter(|shift: &Shift, day: &NaiveDate| overlap_with_day_minutes(shift, *day) > 0)
    .penalize_with(|shift: &Shift, day: &NaiveDate| {
        HardSoftScore::of_soft(overlap_with_day_minutes(shift, *day))
    })
    .named("Undesired day for employee");
```

**Key difference from hard constraints:** This affects only the soft score.

### Soft Constraint: Desired Days (Reward)

**Business rule:** "Prefer to schedule employees on days they marked as
desired."

```rust
let desired_day_for_employee = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .join((
        employees,
        equal_bi(
            |shift: &Shift| shift.employee_id,
            |employee: &Employee| Some(employee.id),
        ),
    ))
    .flatten_last(
        |employee: &Employee| employee.desired_days.as_slice(),
        |day: &NaiveDate| *day,
        |shift: &Shift| shift.date(),
    )
    .filter(|shift: &Shift, day: &NaiveDate| overlap_with_day_minutes(shift, *day) > 0)
    .reward_with(|shift: &Shift, day: &NaiveDate| {
        HardSoftScore::of_soft(overlap_with_day_minutes(shift, *day))
    })
    .named("Desired day for employee");
```

**Optimization concept:** Rewards **increase** the score instead of decreasing
it. This actively pulls the solution toward preferred assignments.

### Soft Constraint: Load Balancing

**Business rule:** "Distribute shifts fairly across employees."

```rust
let balance_employee_shift_assignments = factory
    .shifts()
    .balance(|shift: &Shift| shift.employee_id)
    .penalize_soft()
    .named("Balance employee shift assignments");
```

This is the compact form of the old "count, complement, then load-balance"
pattern. It skips `None` values automatically, so unassigned shifts do not
distort fairness calculations.

---

## The Solver Engine

Now let's see how the current retained runtime is configured.

### Search Configuration

Put the search strategy in `solver.toml`:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"

[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[termination]
seconds_spent_limit = 30
```

This is now the preferred place to tune search. You do not need to rebuild the
Rust code just to adjust termination or acceptor settings.

### SolverManager: Retained Asynchronous Solving

The current runtime API is `SolverManager`:

```rust
use solverforge::{analyze, SolverEvent, SolverManager};

static MANAGER: SolverManager<EmployeeSchedule> = SolverManager::new();

fn solve(problem: EmployeeSchedule) {
    let initial_analysis = analyze(&problem);
    println!("Initial score: {}", initial_analysis.score);

    let (job_id, mut rx) = MANAGER.solve(problem).expect("solver job should start");

    while let Some(event) = rx.blocking_recv() {
        match event {
            SolverEvent::Progress { metadata } => {
                println!(
                    "current {:?}, best {:?}",
                    metadata.current_score,
                    metadata.best_score
                );
            }
            SolverEvent::BestSolution { metadata, .. } => {
                println!("new best at snapshot {:?}", metadata.snapshot_revision);
            }
            SolverEvent::Completed { metadata, solution } => {
                println!(
                    "completed with reason {:?} and score {:?}",
                    metadata.terminal_reason,
                    solution.score
                );
                break;
            }
            SolverEvent::Cancelled { .. } => break,
            SolverEvent::Failed { error, .. } => panic!("solve failed: {error}"),
            SolverEvent::PauseRequested { .. }
            | SolverEvent::Paused { .. }
            | SolverEvent::Resumed { .. } => {}
        }
    }

    MANAGER.delete(job_id).expect("delete retained terminal job");
}
```

### Configuration Breakdown

- `SolverManager::new()` creates the retained runtime
- `solve(problem)` starts solving immediately and returns `(job_id, receiver)`
- `SolverEvent` values stream progress, best-solution updates, pause/resume
  events, and the final completion state
- `delete(job_id)` frees the retained terminal job slot when you're done with
  it

### Solving Timeline

**Small problems** (10-20 shifts, 5-10 employees):

- Initial feasible solution: usually seconds
- Good solution: seconds to tens of seconds
- Higher-quality: tens of seconds to minutes

**Factors affecting speed:**

- Number of employees × shifts
- Constraint complexity
- How tight the hard constraints are
- Search settings in `solver.toml`

---

## Web Interface and API

The current scaffold exposes retained jobs rather than a single blocking solve
call, but the frontend flow is still the same old story: load demo data, click
solve, watch assignments improve, inspect the final answer.

### REST API Endpoints

#### GET /demo-data

Returns available demo datasets:

```json
["STANDARD", "SMALL"]
```

#### GET /demo-data/{dataset_id}

Generates and returns sample data:

```json
{
  "employees": [
    {
      "id": 0,
      "name": "Alice",
      "skills": ["Doctor"],
      "unavailableDays": [],
      "undesiredDays": ["2026-04-22"],
      "desiredDays": ["2026-04-20"]
    }
  ],
  "shifts": [
    {
      "id": 1,
      "label": "Mon ER Doctor",
      "requiredSkill": "Doctor",
      "start": "2026-04-20T06:00:00",
      "end": "2026-04-20T14:00:00",
      "employeeId": null
    }
  ]
}
```

#### POST /jobs

Submit a schedule to solve:

**Request body:** same shape as demo data

**Response:**

```json
{ "id": "0" }
```

**Implementation:**

```rust
async fn create_job(
    State(state): State<Arc<AppState>>,
    Json(dto): Json<PlanDto>,
) -> Result<Json<CreateJobResponse>, StatusCode> {
    let id = state
        .solver
        .start_job(dto.to_domain())
        .map_err(status_from_solver_error)?;
    Ok(Json(CreateJobResponse { id }))
}
```

#### GET /jobs/{id}

Returns retained job status:

```json
{
  "id": "0",
  "jobId": "0",
  "lifecycleState": "SOLVING",
  "terminalReason": null,
  "checkpointAvailable": false,
  "eventSequence": 12,
  "snapshotRevision": 6,
  "currentScore": "0hard/479soft",
  "bestScore": "0hard/959soft"
}
```

#### GET /jobs/{id}/snapshot

Returns a specific or latest solution snapshot.

#### GET /jobs/{id}/analysis

Returns score analysis for a snapshot:

```json
{
  "id": "0",
  "jobId": "0",
  "snapshotRevision": 6,
  "lifecycleState": "SOLVING",
  "analysis": {
    "score": "0hard/959soft",
    "constraints": [
      {
        "name": "Desired day for employee",
        "weight": "0hard/1soft",
        "score": "0hard/960soft",
        "matchCount": 2
      }
    ]
  }
}
```

#### POST /jobs/{id}/pause

Pause at the next safe checkpoint.

#### POST /jobs/{id}/resume

Resume a paused retained job.

#### POST /jobs/{id}/cancel

Cancel the solve.

#### DELETE /jobs/{id}

Delete the retained terminal job and free the slot.

### Web UI Flow

The frontend flow still looks like the old tutorial:

1. **User opens page** → load demo data
2. **Display** employees and shifts
3. **User clicks "Solve"** → `POST /jobs`
4. **Poll** status and snapshot endpoints, or subscribe to SSE events
5. **Update UI** with better assignments in real time
6. **When** lifecycle reaches a terminal state → stop polling
7. **Display** final score and optional analysis

---

## Making Your First Customization

The old tutorial used a max-shifts example because it demonstrates a very
common pattern. That still works well here.

### Understanding the Max Shifts Constraint

**Business rule:** "No employee can work more than 12 shifts in the schedule
period."

```rust
let max_shifts_per_employee = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .group_by(|shift: &Shift| shift.employee_id.unwrap(), count())
    .penalize_hard_with(|shift_count: &usize| {
        HardSoftScore::of_hard(shift_count.saturating_sub(12) as i64)
    })
    .named("Max 12 shifts per employee");
```

**How this works:**

1. Filter to shifts that are actually assigned
2. Group those shifts by employee
3. Count the shifts in each employee group
4. Return `0` until the limit is exceeded, then penalize only the overflow

After `group_by(...)`, you are scoring employee groups, not individual shifts.
The weighting closure sees only the grouped result. If you need to exclude
unassigned rows or other irrelevant records, do that before grouping.

**Why 12?** The exact limit depends on your demo data dimensions. A limit that's
too low makes the problem infeasible. Always make sure your rules and your data
agree.

### How It's Registered

Add it to `define_constraints()`:

```rust
(
    unassigned,
    required_skill,
    no_overlapping_shifts,
    at_least_10_hours_between_two_shifts,
    one_shift_per_day,
    unavailable_employee,
    max_shifts_per_employee,
    undesired_day_for_employee,
    desired_day_for_employee,
    balance_employee_shift_assignments,
)
```

### Understanding What You Did

You just implemented a **cardinality constraint** — limiting the count of
something. This pattern shows up everywhere:

- Maximum hours per week
- Minimum shifts per employee
- Exact number of nurses per shift

The pattern is always:

1. Filter row-level cases first if needed
2. Group by what you're counting
3. Aggregate the group
4. Express the threshold inside the weight closure

---

## Advanced Constraint Patterns

### Pattern 1: Weighted Penalties

**Scenario:** Some skills are harder to staff — reward those matches more
strongly.

```rust
let specialty_coverage = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| {
        matches!(shift.required_skill.as_str(), "Cardiology" | "Anaesthetics" | "Radiology")
    })
    .join((
        employees,
        equal_bi(
            |shift: &Shift| shift.employee_id,
            |employee: &Employee| Some(employee.id),
        ),
    ))
    .filter(|shift: &Shift, employee: &Employee| {
        employee.skills.contains(&shift.required_skill)
    })
    .reward_with(|_shift: &Shift, _employee: &Employee| HardSoftScore::of_soft(10))
    .named("Preferred specialty coverage");
```

### Pattern 2: Conditional Constraints

**Scenario:** Night shifts require two employees at the same location.

```rust
use chrono::Timelike;

let night_shift_minimum_staff = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.start.time().hour() >= 18)
    .group_by(|shift: &Shift| (shift.start, shift.label.clone()), count())
    .penalize_hard_with(|shift_count: &usize| {
        HardSoftScore::of_hard(2usize.saturating_sub(*shift_count) as i64)
    })
    .named("Night shift minimum 2 staff");
```

### Pattern 3: Employee Pairing (Incompatibility)

**Scenario:** Certain employees shouldn't work overlapping shifts together.

Add the field:

```rust
pub incompatible_with: HashSet<usize>,
```

Then follow the same general shape as the overlap constraint:

1. Self-join shifts for the same place and time window
2. Keep only overlapping pairs
3. Look at the two assigned employees
4. Penalize when one employee lists the other in `incompatible_with`

In practice, teams usually model these incompatibilities either directly on
`Employee` or as separate problem facts. The important part is the pattern:
first create the overlapping shift pair, then compare the assigned employees.

### Pattern 4: Time-Based Accumulation

**Scenario:** Limit total hours worked per week.

```rust
use chrono::Datelike;

let max_minutes_per_week = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .group_by(
        |shift: &Shift| (shift.employee_id.unwrap(), shift.start.date().iso_week().week()),
        sum(|shift: &Shift| (shift.end - shift.start).num_minutes()),
    )
    .penalize_hard_with(|total_minutes: &i64| {
        HardSoftScore::of_hard((*total_minutes).saturating_sub(2_400) / 60)
    })
    .named("Max 40 hours per week");
```

**Optimization concept:** This is **temporal aggregation**. You group by
employee and ISO week, sum shift duration in minutes, and turn the overtime
amount into a score only when the weekly cap is exceeded.

### When You Need Zero-Assignment Keys

Sometimes the rule is about every employee, including people who currently have
zero assigned shifts. That is when `complement(...)` belongs in the pipeline.

```rust
let minimum_one_shift = factory
    .clone()
    .shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .group_by(|shift: &Shift| shift.employee_id.unwrap(), count())
    .complement(
        employees,
        |employee: &Employee| employee.id,
        |_employee: &Employee| 0usize,
    )
    .penalize_with(|shift_count: &usize| {
        HardSoftScore::of_soft(1usize.saturating_sub(*shift_count) as i64)
    })
    .named("Prefer giving everyone at least 1 shift");
```

Use `complement(...)` only when missing groups must still participate in
scoring. Most grouped constraints do not need it.

---

## Testing and Validation

### Unit Testing Constraints

Best practice: test each constraint in isolation.

```rust
use solverforge::{analyze, HardSoftScore};

#[test]
fn required_skill_flags_bad_assignment() {
    let employee = Employee {
        id: 0,
        name: "Alice".to_string(),
        skills: ["Doctor"].into_iter().map(str::to_string).collect(),
        unavailable_days: vec![],
        undesired_days: vec![],
        desired_days: vec![],
    };

    let shift = Shift {
        id: 1,
        label: "Cardiology".to_string(),
        required_skill: "Cardiology".to_string(),
        start: NaiveDate::from_ymd_opt(2026, 4, 20).unwrap().and_hms_opt(6, 0, 0).unwrap(),
        end: NaiveDate::from_ymd_opt(2026, 4, 20).unwrap().and_hms_opt(14, 0, 0).unwrap(),
        employee_id: Some(0),
    };

    let schedule = EmployeeSchedule {
        employees: vec![employee],
        shifts: vec![shift],
        score: None,
    };

    let analysis = analyze(&schedule);
    let mismatch = analysis
        .constraints
        .iter()
        .find(|constraint| constraint.name == "Missing required skill")
        .expect("constraint should exist");

    assert_eq!(mismatch.score, HardSoftScore::of_hard(-1));
    assert_eq!(mismatch.match_count, 1);
}
```

Run with:

```bash
cargo test
```

### Integration Testing: Full Solve

```rust
use solverforge::{SolverEvent, SolverManager};

static MANAGER: SolverManager<EmployeeSchedule> = SolverManager::new();

#[test]
fn solve_small_dataset_to_feasibility() {
    let problem = demo_problem();
    let (job_id, mut rx) = MANAGER.solve(problem).expect("job should start");

    let mut solved = None;

    while let Some(event) = rx.blocking_recv() {
        match event {
            SolverEvent::Completed { solution, .. } => {
                solved = Some(solution);
                break;
            }
            SolverEvent::Cancelled { .. } => panic!("job cancelled"),
            SolverEvent::Failed { error, .. } => panic!("solve failed: {error}"),
            _ => {}
        }
    }

    let solved = solved.expect("solver should finish");
    assert_eq!(solved.score.expect("score should exist").hard(), 0);

    MANAGER.delete(job_id).expect("delete retained job");
}
```

### Manual Testing via UI

1. Start the application with `solverforge server`
2. Open the browser dev tools so you can see requests and events
3. Load demo data
4. Click **Solve**
5. Watch the score improve in real time
6. Inspect the final analysis output
7. Verify the resulting schedule against the hard business rules

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Add or change a business rule | `src/constraints.rs` |
| Add a field to `Employee` | `src/domain.rs` and any DTO mapper |
| Add a field to `Shift` | `src/domain.rs` and any DTO mapper |
| Change search behavior | `solver.toml` |
| Add demo data | `src/demo_data.rs` |
| Add retained-job endpoints | `src/api.rs` or `src/api/routes.rs` |
| Change the UI | `static/index.html`, `static/app.js` |

### Common Constraint Patterns

**Unary constraint**

```rust
factory.shifts()
    .filter(|shift: &Shift| shift.employee_id.is_none())
    .penalize_hard()
    .named("Unassigned shift")
```

**Self-join**

```rust
factory.shifts()
    .join(equal(|shift: &Shift| shift.employee_id))
    .filter(|a: &Shift, b: &Shift| a.id < b.id)
```

**Cross-join**

```rust
factory.shifts()
    .join((
        employees,
        equal_bi(
            |shift: &Shift| shift.employee_id,
            |employee: &Employee| Some(employee.id),
        ),
    ))
```

**Grouped constraint**

```rust
factory.shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .group_by(|shift: &Shift| shift.employee_id.unwrap(), count())
    .penalize_with(|shift_count: &usize| {
        HardSoftScore::of_soft(shift_count.saturating_sub(5) as i64)
    })
    .named("Grouped cap")
```

**Including zero-assignment keys**

```rust
factory.shifts()
    .filter(|shift: &Shift| shift.employee_id.is_some())
    .group_by(|shift: &Shift| shift.employee_id.unwrap(), count())
    .complement(employees, |employee: &Employee| employee.id, |_employee: &Employee| 0usize)
    .penalize_with(|shift_count: &usize| {
        HardSoftScore::of_soft(1usize.saturating_sub(*shift_count) as i64)
    })
    .named("Include zero-assignment employees")
```

**Working with collections**

```rust
.flatten_last(
    |employee: &Employee| employee.unavailable_days.as_slice(),
    |day: &NaiveDate| *day,
    |shift: &Shift| shift.date(),
)
```

### Common Joiners

| Joiner | Purpose |
|--------|---------|
| `equal(|x| x.field)` | Self-join on one field |
| `equal_bi(|a| ..., |b| ...)` | Cross-join on a shared key |

### Common Gotchas

1. **Using `#[basic_variable_config]`**
   That older attribute is gone from the current Rust surface.

2. **Using `for_each_unique_pair(...)`**
   Use `.join(equal(...))` plus `a.id < b.id` instead.

3. **Filtering after `group_by(...)`**
   Grouped constraints score aggregates, not rows. Filter entities before
   `group_by(...)`, then encode thresholds in the weighting closure.

4. **Forgetting `.named("...")`**
   The current stream API finalizes constraint chains with `.named(...)`.

5. **Skipping `solver.toml`**
   The runtime will still solve, but explicit configuration makes tutorial
   behavior much easier to reason about.

6. **Misaligned numeric IDs**
   If your planning variable is `Option<usize>`, keep the values aligned with
   the IDs you join against.

### Additional Resources

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
- [Score Analysis](/docs/solverforge/constraints/score-analysis/)
- [SolverManager](/docs/solverforge/solver/solver-manager/)
