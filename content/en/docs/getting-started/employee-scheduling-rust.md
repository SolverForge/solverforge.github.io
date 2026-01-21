---
title: "Employee Scheduling (Rust)"
linkTitle: "Employee Scheduling (Rust)"
icon: fa-brands fa-rust
date: 2026-01-21
weight: 5
description: "Build efficient employee scheduling with SolverForge's native Rust constraint solver"
categories: [Quickstarts]
tags: [quickstart, rust]
---

{{% pageinfo color="primary" %}}
**Native Rust Implementation**

This guide uses **SolverForge's native Rust constraint solver** — a fully monomorphized, zero-erasure implementation with no JVM bridge. All constraints compile to concrete types at build time, enabling aggressive compiler optimizations and true native performance.

If you're looking for the Python implementation (legacy JPype bridge), see [Employee Scheduling (Python)](/docs/getting-started/employee-scheduling/).
{{% /pageinfo %}}

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
11. [Quick Reference](#quick-reference)

---

## Introduction

### What You'll Learn

This guide walks you through a complete employee scheduling application built with **SolverForge**, a native Rust constraint-based optimization framework. You'll learn:

- How to model real-world scheduling problems as **optimization problems** using Rust's type system
- How to express business rules as **constraints** using a fluent API
- How SolverForge's zero-erasure architecture enables native performance
- How to customize the system for your specific needs

**No optimization background required** — we'll explain concepts as we encounter them in the code.

### Prerequisites

- Rust knowledge (structs, traits, closures, derive macros)
- Familiarity with REST APIs
- Comfort with command-line operations

### What is Constraint-Based Optimization?

Traditional programming: You write explicit logic that says "do this, then that."

**Constraint-based optimization**: You describe what a good solution looks like and the solver figures out how to achieve it.

Think of it like describing what puzzle pieces you have and what rules they must follow — then having a computer try millions of arrangements per second to find the best fit.

### Why Native Rust?

SolverForge's Rust implementation offers key advantages:

- **Zero-erasure architecture**: All generic types resolve at compile time — no `Box<dyn Trait>`, no `Arc`, no runtime dispatch
- **Full monomorphization**: Each constraint compiles to specialized machine code
- **Memory efficiency**: Index-based references instead of string cloning
- **True parallelism**: No GIL, no JVM pause, native threading

---

## Getting Started

### Running the Application

1. **Clone the quickstarts repository:**
   ```bash
   git clone https://github.com/SolverForge/solverforge-quickstarts
   cd ./solverforge-quickstarts/rust/employee-scheduling
   ```

2. **Build the project:**
   ```bash
   cargo build --release
   ```

3. **Run the server:**
   ```bash
   cargo run --release
   ```

4. **Open your browser:**
   ```
   http://localhost:7860
   ```

You'll see a scheduling interface with employees, shifts and a "Solve" button. Click it and watch the solver automatically assign employees to shifts while respecting business rules.

### File Structure Overview

```
rust/employee-scheduling/
├── src/
│   ├── main.rs           # Axum server entry point
│   ├── lib.rs            # Library crate root
│   ├── domain.rs         # Data models (Employee, Shift, EmployeeSchedule)
│   ├── constraints.rs    # Business rules (90% of customization happens here)
│   ├── api.rs            # REST endpoint handlers
│   ├── dto.rs            # JSON serialization types
│   └── demo_data.rs      # Sample data generation
├── static/
│   ├── index.html        # Web UI
│   └── app.js            # UI logic and visualization
└── Cargo.toml            # Dependencies
```

**Key insight:** Most business customization happens in `constraints.rs` alone. You rarely need to modify other files.

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

For even 20 shifts and 10 employees, there are **10^20 possible assignments** (100 quintillion). A human can't evaluate them all. Even a computer trying random assignments would take years.

**Optimization algorithms** use smart strategies to explore this space efficiently, finding high-quality solutions in seconds.

---

## Understanding the Data Model

Let's examine the three core structs that model our problem. Open `src/domain.rs`:

### The Employee Struct (Problem Fact)

```rust
#[problem_fact]
#[derive(Serialize, Deserialize)]
pub struct Employee {
    /// Index of this employee in `EmployeeSchedule.employees` for O(1) join matching.
    pub index: usize,
    pub name: String,
    pub skills: HashSet<String>,
    #[serde(rename = "unavailableDates", default)]
    pub unavailable_dates: HashSet<NaiveDate>,
    #[serde(rename = "undesiredDates", default)]
    pub undesired_dates: HashSet<NaiveDate>,
    #[serde(rename = "desiredDates", default)]
    pub desired_dates: HashSet<NaiveDate>,
    /// Sorted unavailable dates for `flatten_last` compatibility.
    #[serde(skip)]
    pub unavailable_days: Vec<NaiveDate>,
    #[serde(skip)]
    pub undesired_days: Vec<NaiveDate>,
    #[serde(skip)]
    pub desired_days: Vec<NaiveDate>,
}
```

**What it represents:** A person who can be assigned to shifts.

**Key fields:**
- `index`: Position in the employees array — enables O(1) lookups without string comparison
- `name`: Human-readable identifier
- `skills`: What skills this employee possesses (e.g., `{"Doctor", "Cardiology"}`)
- `unavailable_dates`: Days the employee absolutely cannot work (hard constraint)
- `undesired_dates` / `desired_dates`: Soft preference fields

**Rust-specific design:**
- `#[problem_fact]`: Derive macro that marks this as immutable solver data
- `HashSet<NaiveDate>` for O(1) membership testing during JSON deserialization
- `Vec<NaiveDate>` sorted copies for `flatten_last` stream compatibility

### The Builder Pattern with `finalize()`

The Employee struct uses a builder pattern with explicit finalization:

```rust
impl Employee {
    pub fn new(index: usize, name: impl Into<String>) -> Self {
        Self {
            index,
            name: name.into(),
            skills: HashSet::new(),
            // ... fields initialized empty
        }
    }

    /// Populates derived Vec fields from HashSets for zero-erasure stream compatibility.
    /// Must be called after all dates have been added to HashSets.
    pub fn finalize(&mut self) {
        self.unavailable_days = self.unavailable_dates.iter().copied().collect();
        self.unavailable_days.sort();
        // ... same for undesired_days, desired_days
    }

    pub fn with_skill(mut self, skill: impl Into<String>) -> Self {
        self.skills.insert(skill.into());
        self
    }
}
```

**Why `finalize()`?** The constraint stream API's `flatten_last` operation requires sorted slices for O(1) index-based lookups. After JSON deserialization or programmatic construction, `finalize()` converts HashSets to sorted Vecs.

### The Shift Struct (Planning Entity)

```rust
#[planning_entity]
#[derive(Serialize, Deserialize)]
pub struct Shift {
    #[planning_id]
    pub id: String,
    pub start: NaiveDateTime,
    pub end: NaiveDateTime,
    pub location: String,
    #[serde(rename = "requiredSkill")]
    pub required_skill: String,
    /// Index into `EmployeeSchedule.employees` (O(1) lookup, no String cloning).
    #[planning_variable(allows_unassigned = true)]
    pub employee_idx: Option<usize>,
}
```

**What it represents:** A time slot that needs an employee assignment.

**Key annotations:**
- `#[planning_entity]`: Derive macro marking this as containing decisions to optimize
- `#[planning_id]`: Marks `id` as the unique identifier
- `#[planning_variable(allows_unassigned = true)]`: The decision variable — what the solver assigns

**Critical design choice — index-based references:**

```rust
pub employee_idx: Option<usize>  // ✓ O(1) lookup, no allocation
// NOT: pub employee: Option<String>  // ✗ String clone on every comparison
```

Using `usize` indices instead of employee names provides:
- O(1) lookups via `schedule.employees[idx]`
- Zero allocations during constraint evaluation
- Direct equality comparison (integer vs string)

### The EmployeeSchedule Struct (Planning Solution)

```rust
#[planning_solution]
#[basic_variable_config(
    entity_collection = "shifts",
    variable_field = "employee_idx",
    variable_type = "usize",
    value_range = "employees"
)]
#[solverforge_constraints_path = "crate::constraints::create_fluent_constraints"]
#[derive(Serialize, Deserialize)]
pub struct EmployeeSchedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftDecimalScore>,
    #[serde(rename = "solverStatus", skip_serializing_if = "Option::is_none")]
    pub solver_status: Option<String>,
}
```

**What it represents:** The complete problem and its solution.

**Annotations explained:**
- `#[planning_solution]`: Top-level problem definition
- `#[basic_variable_config(...)]`: Declarative configuration specifying:
  - Which collection contains planning entities (`shifts`)
  - Which field is the planning variable (`employee_idx`)
  - The variable's type (`usize`)
  - Where valid values come from (`employees`)
- `#[solverforge_constraints_path]`: Points to the constraint factory function
- `#[problem_fact_collection]`: Immutable data (doesn't change during solving)
- `#[planning_entity_collection]`: Entities being optimized
- `#[planning_score]`: Where the solver stores the calculated score

---

## How Optimization Works

Before diving into constraints, let's understand how the solver finds solutions.

### The Search Process (Simplified)

1. **Start with an initial solution** (often random or all unassigned)
2. **Evaluate the score** using your constraint functions
3. **Make a small change** (assign a different employee to one shift)
4. **Evaluate the new score**
5. **Keep the change if it improves the score** (with some controlled randomness)
6. **Repeat millions of times** in seconds
7. **Return the best solution found**

### Why This Works: Metaheuristics

SolverForge uses sophisticated **metaheuristic algorithms** like:

- **Tabu Search**: Remembers recent moves to avoid cycling
- **Simulated Annealing**: Occasionally accepts worse solutions to escape local optima
- **Late Acceptance**: Compares current solution to recent history, not just the immediate previous

These techniques efficiently explore the massive solution space without getting stuck.

### The Score: How "Good" is a Solution?

Every solution gets a score with two parts:

```
0hard/-45soft
```

- **Hard score**: Counts hard constraint violations (must be 0 for a valid solution)
- **Soft score**: Counts soft constraint violations/rewards (higher is better)

**Scoring rules:**
- Hard score must be 0 or positive (negative = invalid/infeasible)
- Among valid solutions (hard score = 0), highest soft score wins
- Hard score always takes priority over soft score

---

## Writing Constraints: The Business Rules

Now the heart of the system. Open `src/constraints.rs`.

### The Constraint Factory Pattern

All constraints are created in one function:

```rust
pub fn create_fluent_constraints() -> impl ConstraintSet<EmployeeSchedule, HardSoftDecimalScore> {
    let factory = ConstraintFactory::<EmployeeSchedule, HardSoftDecimalScore>::new();

    // Build each constraint...
    let required_skill = factory.clone()
        .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
        // ...

    // Return all constraints as a tuple
    (
        required_skill,
        no_overlap,
        at_least_10_hours,
        one_per_day,
        unavailable,
        undesired,
        desired,
        balanced,
    )
}
```

The function returns `impl ConstraintSet` — a trait implemented for tuples of constraints. Each constraint is fully typed with no runtime dispatch.

### Hard Constraint: Required Skill

**Business rule:** "An employee assigned to a shift must have the required skill."

```rust
let required_skill = factory
    .clone()
    .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
    .join(
        |s: &EmployeeSchedule| s.employees.as_slice(),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |emp: &Employee| Some(emp.index),
        ),
    )
    .filter(|shift: &Shift, emp: &Employee| {
        shift.employee_idx.is_some() && !emp.skills.contains(&shift.required_skill)
    })
    .penalize(HardSoftDecimalScore::ONE_HARD)
    .as_constraint("Required skill");
```

**How to read this:**
1. `for_each(|s| s.shifts.as_slice())`: Stream over all shifts
2. `.join(..., equal_bi(...))`: Join with employees where `shift.employee_idx == Some(emp.index)`
3. `.filter(...)`: Keep only where employee lacks the required skill
4. `.penalize(ONE_HARD)`: Each violation subtracts 1 from hard score
5. `.as_constraint(...)`: Name for debugging

**Key Rust adaptation — `equal_bi` joiner:**

```rust
equal_bi(
    |shift: &Shift| shift.employee_idx,      // Option<usize>
    |emp: &Employee| Some(emp.index),         // Option<usize>
)
```

The `equal_bi` joiner takes two closures — one for each side of the join. This enables joining different types with potentially different key extraction logic.

### Hard Constraint: No Overlapping Shifts

**Business rule:** "An employee can't work two shifts that overlap in time."

```rust
let no_overlap = factory
    .clone()
    .for_each_unique_pair(
        |s: &EmployeeSchedule| s.shifts.as_slice(),
        joiner::equal(|shift: &Shift| shift.employee_idx),
    )
    .filter(|a: &Shift, b: &Shift| {
        a.employee_idx.is_some() && a.start < b.end && b.start < a.end
    })
    .penalize_hard_with(|a: &Shift, b: &Shift| {
        HardSoftDecimalScore::of_hard_scaled(overlap_minutes(a, b) * 100000)
    })
    .as_constraint("Overlapping shift");
```

**How to read this:**
1. `for_each_unique_pair(...)`: Create pairs of shifts from the same collection
2. `joiner::equal(|shift| shift.employee_idx)`: Only pair shifts with the same employee
3. `.filter(...)`: Check time overlap with interval comparison
4. `.penalize_hard_with(...)`: Variable penalty based on overlap duration

**Optimization concept:** `for_each_unique_pair` ensures we don't count violations twice (A,B vs B,A). The joiner uses hash indexing for O(1) pair matching.

### Hard Constraint: Rest Between Shifts

**Business rule:** "Employees need at least 10 hours rest between shifts."

```rust
let at_least_10_hours = factory
    .clone()
    .for_each_unique_pair(
        |s: &EmployeeSchedule| s.shifts.as_slice(),
        joiner::equal(|shift: &Shift| shift.employee_idx),
    )
    .filter(|a: &Shift, b: &Shift| a.employee_idx.is_some() && gap_penalty_minutes(a, b) > 0)
    .penalize_hard_with(|a: &Shift, b: &Shift| {
        HardSoftDecimalScore::of_hard_scaled(gap_penalty_minutes(a, b) * 100000)
    })
    .as_constraint("At least 10 hours between 2 shifts");
```

**Helper function:**
```rust
fn gap_penalty_minutes(a: &Shift, b: &Shift) -> i64 {
    const MIN_GAP_MINUTES: i64 = 600;  // 10 hours

    let (earlier, later) = if a.end <= b.start {
        (a, b)
    } else if b.end <= a.start {
        (b, a)
    } else {
        return 0;  // Overlapping, handled by different constraint
    };

    let gap = (later.start - earlier.end).num_minutes();
    if (0..MIN_GAP_MINUTES).contains(&gap) {
        MIN_GAP_MINUTES - gap
    } else {
        0
    }
}
```

**Optimization concept:** The penalty `600 - actual_gap` creates **incremental guidance**. 9 hours rest (penalty 60) is better than 5 hours rest (penalty 300).

### Hard Constraint: One Shift Per Day

**Business rule:** "Employees can work at most one shift per calendar day."

```rust
let one_per_day = factory
    .clone()
    .for_each_unique_pair(
        |s: &EmployeeSchedule| s.shifts.as_slice(),
        joiner::equal(|shift: &Shift| (shift.employee_idx, shift.date())),
    )
    .filter(|a: &Shift, b: &Shift| a.employee_idx.is_some() && b.employee_idx.is_some())
    .penalize(HardSoftDecimalScore::ONE_HARD)
    .as_constraint("One shift per day");
```

**Key pattern — tuple joiner:**
```rust
joiner::equal(|shift: &Shift| (shift.employee_idx, shift.date()))
```

The joiner matches on a tuple `(Option<usize>, NaiveDate)` — same employee AND same date.

### Hard Constraint: Unavailable Employee

**Business rule:** "Employees cannot work on days they marked as unavailable."

```rust
let unavailable = factory
    .clone()
    .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
    .join(
        |s: &EmployeeSchedule| s.employees.as_slice(),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |emp: &Employee| Some(emp.index),
        ),
    )
    .flatten_last(
        |emp: &Employee| emp.unavailable_days.as_slice(),
        |date: &NaiveDate| *date,      // C → index key
        |shift: &Shift| shift.date(),  // A → lookup key
    )
    .filter(|shift: &Shift, date: &NaiveDate| {
        shift.employee_idx.is_some() && shift_date_overlap_minutes(shift, *date) > 0
    })
    .penalize_hard_with(|shift: &Shift, date: &NaiveDate| {
        HardSoftDecimalScore::of_hard_scaled(shift_date_overlap_minutes(shift, *date) * 100000)
    })
    .as_constraint("Unavailable employee");
```

**The `flatten_last` Operation:**

```rust
.flatten_last(
    |emp: &Employee| emp.unavailable_days.as_slice(),  // Collection to flatten
    |date: &NaiveDate| *date,                          // Index key extractor
    |shift: &Shift| shift.date(),                      // Lookup key extractor
)
```

This is a powerful pattern unique to SolverForge's fluent API:

1. Takes the last element of the current tuple (the `Employee`)
2. Flattens their `unavailable_days` collection
3. Pre-indexes by the date key
4. On lookup, finds matching dates in O(1) using the shift's date

**Why sorted Vecs?** The `flatten_last` operation uses binary search internally, requiring sorted input. That's why `Employee::finalize()` sorts the date vectors.

### Soft Constraint: Undesired Days

**Business rule:** "Prefer not to schedule employees on days they marked as undesired."

```rust
let undesired = factory
    .clone()
    .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
    .join(
        |s: &EmployeeSchedule| s.employees.as_slice(),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |emp: &Employee| Some(emp.index),
        ),
    )
    .flatten_last(
        |emp: &Employee| emp.undesired_days.as_slice(),
        |date: &NaiveDate| *date,
        |shift: &Shift| shift.date(),
    )
    .filter(|shift: &Shift, _date: &NaiveDate| shift.employee_idx.is_some())
    .penalize(HardSoftDecimalScore::ONE_SOFT)
    .as_constraint("Undesired day for employee");
```

**Key difference:** Uses `ONE_SOFT` instead of `ONE_HARD`. The solver will try to avoid undesired days but may violate this if necessary.

### Soft Constraint: Desired Days (Reward)

**Business rule:** "Prefer to schedule employees on days they marked as desired."

```rust
let desired = factory
    .clone()
    .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
    .join(
        |s: &EmployeeSchedule| s.employees.as_slice(),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |emp: &Employee| Some(emp.index),
        ),
    )
    .flatten_last(
        |emp: &Employee| emp.desired_days.as_slice(),
        |date: &NaiveDate| *date,
        |shift: &Shift| shift.date(),
    )
    .filter(|shift: &Shift, _date: &NaiveDate| shift.employee_idx.is_some())
    .reward(HardSoftDecimalScore::ONE_SOFT)
    .as_constraint("Desired day for employee");
```

**Key difference:** Uses `.reward()` instead of `.penalize()`. Rewards **increase** the score.

### Soft Constraint: Load Balancing

**Business rule:** "Distribute shifts fairly across employees."

```rust
let balanced = factory
    .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
    .balance(|shift: &Shift| shift.employee_idx)
    .penalize(HardSoftDecimalScore::of_soft(1))
    .as_constraint("Balance employee assignments");
```

**The `balance()` Operation:**

This is the simplest and most powerful load balancing pattern:

1. Groups shifts by the grouping key (employee index)
2. Calculates standard deviation incrementally
3. Penalizes based on unfairness metric

Unlike manual `group_by` + `count` + math, the `balance()` operation:
- Maintains O(1) incremental updates during solving
- Handles edge cases (empty groups, single element)
- Provides mathematically sound fairness calculation

---

## The Solver Engine

### Configuration via Derive Macros

Unlike configuration files, SolverForge uses compile-time configuration through derive macros:

```rust
#[planning_solution]
#[basic_variable_config(
    entity_collection = "shifts",
    variable_field = "employee_idx",
    variable_type = "usize",
    value_range = "employees"
)]
#[solverforge_constraints_path = "crate::constraints::create_fluent_constraints"]
pub struct EmployeeSchedule { ... }
```

This generates:
- The `Solvable` trait implementation
- Variable descriptor metadata
- Move selector configuration
- Constraint factory wiring

### The `Solvable` Trait

The derive macro implements `Solvable`:

```rust
// Generated by #[planning_solution]
impl Solvable for EmployeeSchedule {
    type Score = HardSoftDecimalScore;

    fn solve(self, config: Option<SolverConfig>, callback: Sender<...>) {
        // Metaheuristic search loop
    }
}
```

### Starting the Solver

In `src/api.rs`:

```rust
async fn create_schedule(
    State(state): State<Arc<AppState>>,
    Json(dto): Json<ScheduleDto>,
) -> String {
    let id = Uuid::new_v4().to_string();
    let schedule = dto.to_domain();

    // Store initial state
    {
        let mut jobs = state.jobs.write();
        jobs.insert(id.clone(), SolveJob {
            solution: schedule.clone(),
            solver_status: "SOLVING".to_string(),
        });
    }

    // Create channel for solution updates
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    // Spawn async task to receive updates
    tokio::spawn(async move {
        while let Some((solution, _score)) = rx.recv().await {
            // Update stored solution
        }
    });

    // Spawn solver on rayon thread pool
    rayon::spawn(move || {
        schedule.solve(None, tx);
    });

    id
}
```

**Architecture notes:**
- Solving runs on `rayon` thread pool (CPU-bound work)
- Updates sent via `tokio::sync::mpsc` channel
- Async Axum handler for non-blocking HTTP
- `parking_lot::RwLock` for thread-safe state access

### TypedScoreDirector for Analysis

For score breakdown without solving:

```rust
async fn analyze_schedule(Json(dto): Json<ScheduleDto>) -> Json<AnalyzeResponse> {
    let schedule = dto.to_domain();
    let constraints = create_fluent_constraints();
    let director = TypedScoreDirector::new(schedule, constraints);

    let score = director.get_score();
    let analyses = director
        .constraints()
        .evaluate_detailed(director.working_solution());

    // Convert to DTO...
}
```

The `TypedScoreDirector`:
- Evaluates all constraints against a solution
- Returns detailed match information per constraint
- No actual solving — just score calculation

---

## Web Interface and API

### REST API Endpoints

The API is built with Axum (`src/api.rs`):

```rust
pub fn router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/healthz", get(health))
        .route("/info", get(info))
        .route("/demo-data", get(list_demo_data))
        .route("/demo-data/{id}", get(get_demo_data))
        .route("/schedules", post(create_schedule))
        .route("/schedules", get(list_schedules))
        .route("/schedules/analyze", put(analyze_schedule))
        .route("/schedules/{id}", get(get_schedule))
        .route("/schedules/{id}/status", get(get_schedule_status))
        .route("/schedules/{id}", delete(stop_solving))
        .with_state(state)
}
```

#### GET /demo-data

Returns available demo datasets:
```json
["SMALL", "LARGE"]
```

#### GET /demo-data/{id}

Generates and returns sample data:
```json
{
  "employees": [
    {
      "name": "Amy Cole",
      "skills": ["Doctor", "Cardiology"],
      "unavailableDates": ["2026-01-25"],
      "undesiredDates": ["2026-01-26"],
      "desiredDates": ["2026-01-27"]
    }
  ],
  "shifts": [
    {
      "id": "0",
      "start": "2026-01-25T06:00:00",
      "end": "2026-01-25T14:00:00",
      "location": "Ambulatory care",
      "requiredSkill": "Doctor",
      "employee": null
    }
  ]
}
```

#### POST /schedules

Submit a schedule to solve. Returns job ID:
```
"a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

#### GET /schedules/{id}

Get current solution state:
```json
{
  "employees": [...],
  "shifts": [...],
  "score": "0hard/-12soft",
  "solverStatus": "SOLVING"
}
```

#### DELETE /schedules/{id}

Stop solving early. Returns `204 No Content`.

#### PUT /schedules/analyze

Analyze a schedule without solving:
```json
{
  "score": "-2hard/-45soft",
  "constraints": [
    {
      "name": "Required skill",
      "constraintType": "hard",
      "weight": "1hard",
      "score": "-2hard",
      "matches": [
        {
          "score": "-1hard",
          "justification": "Shift 5 assigned to Amy Cole without required skill"
        }
      ]
    }
  ]
}
```

### Server Entry Point

`src/main.rs`:

```rust
#[tokio::main]
async fn main() {
    solverforge::console::init();

    let state = Arc::new(api::AppState::new());

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let static_path = if PathBuf::from("examples/employee-scheduling/static").exists() {
        "examples/employee-scheduling/static"
    } else {
        "static"
    };

    let app = api::router(state)
        .fallback_service(ServeDir::new(static_path))
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], 7860));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    println!("Server running at http://localhost:{}", addr.port());
    axum::serve(listener, app).await.unwrap();
}
```

---

## Making Your First Customization

Let's modify an existing constraint to understand the pattern.

### Adjusting Constraint Weights

The balancing constraint currently uses a weight of 1:

```rust
let balanced = factory
    .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
    .balance(|shift: &Shift| shift.employee_idx)
    .penalize(HardSoftDecimalScore::of_soft(1))  // Weight: 1
    .as_constraint("Balance employee assignments");
```

To make fairness more important relative to other soft constraints:

```rust
    .penalize(HardSoftDecimalScore::of_soft(10))  // Weight: 10
```

Now each unit of imbalance costs 10 soft points instead of 1, making the solver prioritize fair distribution over other soft preferences.

### Adding a New Hard Constraint

Let's add: "No employee can work more than 5 shifts total."

In `src/constraints.rs`, add the constraint:

```rust
use solverforge::stream::collector::count;

// Inside create_fluent_constraints()
let max_shifts = factory
    .clone()
    .for_each(|s: &EmployeeSchedule| s.shifts.as_slice())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(|shift: &Shift| shift.employee_idx, count())
    .penalize_hard_with(|shift_count: &usize| {
        if *shift_count > 5 {
            HardSoftDecimalScore::of_hard((*shift_count - 5) as i64)
        } else {
            HardSoftDecimalScore::ZERO
        }
    })
    .as_constraint("Max 5 shifts per employee");
```

Then add it to the return tuple:

```rust
(
    required_skill,
    no_overlap,
    at_least_10_hours,
    one_per_day,
    unavailable,
    undesired,
    desired,
    balanced,
    max_shifts,  // Add here
)
```

Rebuild and test:
```bash
cargo build --release
cargo run --release
```

---

## Advanced Constraint Patterns

### Zero-Erasure Architecture

SolverForge's constraints are fully monomorphized — every generic parameter resolves to concrete types at compile time:

```rust
// This type is FULLY concrete at compile time:
ConstraintStream<
    EmployeeSchedule,
    HardSoftDecimalScore,
    (Shift, Employee),  // Tuple of concrete types
    JoinedMatcher<...>  // Concrete matcher type
>
```

**No `Box<dyn Constraint>`**, no `Arc<dyn Stream>`, no vtable dispatch. The compiler sees the entire constraint graph and can inline, vectorize, and optimize aggressively.

### Index-Based References

The pattern of using indices instead of cloned values:

```rust
// In Shift
pub employee_idx: Option<usize>  // Index into employees array

// In constraint - O(1) lookup
.filter(|shift: &Shift, emp: &Employee| {
    shift.employee_idx == Some(emp.index)
})
```

Benefits:
- Integer comparison vs string comparison
- No allocation during constraint evaluation
- Cache-friendly memory access patterns

### The `flatten_last` Pattern

For constraints involving collections on joined entities:

```rust
.join(employees, equal_bi(...))
.flatten_last(
    |emp| emp.unavailable_days.as_slice(),  // What to flatten
    |date| *date,                            // Index key
    |shift| shift.date(),                    // Lookup key
)
```

This creates an indexed structure during stream setup, enabling O(1) lookups during constraint evaluation.

### Custom Penalty Functions

Variable penalties guide the solver more effectively:

```rust
.penalize_hard_with(|a: &Shift, b: &Shift| {
    let overlap = overlap_minutes(a, b);
    HardSoftDecimalScore::of_hard_scaled(overlap * 100000)
})
```

The `100000` multiplier ensures minute-level granularity affects the score meaningfully compared to unit penalties.

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Add/change business rule | `src/constraints.rs` |
| Add field to Employee/Shift | `src/domain.rs` + `src/dto.rs` |
| Change API endpoints | `src/api.rs` |
| Change demo data | `src/demo_data.rs` |
| Change UI | `static/index.html`, `static/app.js` |

### Common Constraint Patterns

**Unary constraint (examine one entity):**
```rust
factory.for_each(|s| s.shifts.as_slice())
    .filter(|shift| /* condition */)
    .penalize(HardSoftDecimalScore::ONE_HARD)
```

**Binary constraint with join:**
```rust
factory.for_each(|s| s.shifts.as_slice())
    .join(|s| s.employees.as_slice(), equal_bi(...))
    .filter(|shift, emp| /* condition */)
    .penalize(...)
```

**Unique pairs (same collection):**
```rust
factory.for_each_unique_pair(
    |s| s.shifts.as_slice(),
    joiner::equal(|shift| shift.employee_idx),
)
```

**Flatten collections:**
```rust
.flatten_last(
    |emp| emp.dates.as_slice(),
    |date| *date,
    |shift| shift.date(),
)
```

**Load balancing:**
```rust
factory.for_each(|s| s.shifts.as_slice())
    .balance(|shift| shift.employee_idx)
    .penalize(HardSoftDecimalScore::of_soft(1))
```

### Python → Rust Translation

| Python | Rust |
|--------|------|
| `@dataclass` | `#[derive(...)]` struct |
| `@planning_entity` decorator | `#[planning_entity]` derive macro |
| `PlanningId` annotation | `#[planning_id]` attribute |
| `PlanningVariable` annotation | `#[planning_variable]` attribute |
| `constraint_factory.for_each(Shift)` | `factory.for_each(\|s\| s.shifts.as_slice())` |
| `Joiners.equal(lambda: ...)` | `joiner::equal(\|x\| x.field)` |
| `lambda shift: shift.employee` | `\|shift: &Shift\| shift.employee_idx` |
| FastAPI server | Axum server |
| `pip install` | `cargo build` |

### Debugging Tips

**Enable verbose logging:**
```rust
// In Cargo.toml
solverforge = { ..., features = ["verbose-logging"] }
```

**Print in constraints (debug only):**
```rust
.filter(|shift: &Shift, emp: &Employee| {
    eprintln!("Checking shift {} with {}", shift.id, emp.name);
    !emp.skills.contains(&shift.required_skill)
})
```

**Use the analyze endpoint:**
```bash
curl -X PUT http://localhost:7860/schedules/analyze \
  -H "Content-Type: application/json" \
  -d @schedule.json
```

### Common Gotchas

1. **Forgot to call `finalize()`** on employees after construction
   - Symptom: `flatten_last` constraints don't match anything

2. **Index out of sync** — employee indices don't match array positions
   - Always use `enumerate()` when constructing employees

3. **Missing `factory.clone()`** — factory is consumed by each constraint
   - Clone before each constraint chain

4. **Forgot to add constraint to return tuple**
   - Constraint silently not evaluated

5. **Using `String` instead of `usize` for references**
   - Performance degradation and allocation overhead

---

### Additional Resources

- [GitHub Repository](https://github.com/solverforge/solverforge-quickstarts)
- [SolverForge Rust API Documentation](/docs/api/rust/)
- [Employee Scheduling (Python)](/docs/getting-started/employee-scheduling/) — Legacy implementation for comparison
