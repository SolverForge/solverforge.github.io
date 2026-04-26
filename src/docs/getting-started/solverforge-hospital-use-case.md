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
4. [The Teaching Spine](#the-teaching-spine)
5. [Understanding the Data Model](#understanding-the-data-model)
6. [The Demo Dataset](#the-demo-dataset)
7. [How Optimization Works](#how-optimization-works)
8. [Writing Constraints](#writing-constraints)
9. [Solver Policy](#solver-policy)
10. [Runtime and Browser Surface](#runtime-and-browser-surface)
11. [Making Your First Customization](#making-your-first-customization)
12. [Testing and Validation](#testing-and-validation)
13. [Quick Reference](#quick-reference)

---

## Introduction

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
- follow how `employee_idx` moves through constraints, solver policy, retained
  jobs, snapshots, and the browser
- keep the stock retained `/jobs` lifecycle while landing on the current
  hospital UI and data surface

**No optimization background required**. The article explains the end-to-end
path. The code comments in the example repo explain the local intent at the
exact place where a concept is implemented.

### Prerequisites

- Basic Rust knowledge: structs, enums, traits, closures, modules, derive
  macros
- Familiarity with HTTP APIs
- Comfort with command-line work
- Node.js if you want to run the browserless frontend tests
- Rust `1.95+`, matching the current published SolverForge crate line

---

## Getting Started

### Start with the Generic CLI Shell

Start with the public CLI flow:

```bash
cargo install solverforge-cli --force
solverforge --version
solverforge new solverforge-hospital --quiet
cd solverforge-hospital
```

Those commands give you the neutral scaffold. The current hospital app then
specializes the generated project into scalar employee scheduling.

Right after scaffolding, the generated project already contains:

- a neutral `Plan` and `HardSoftScore`
- retained `/jobs` routes, status, snapshot, analysis, pause, resume, cancel,
  delete, and SSE
- a neutral frontend in `static/app.js`
- compiler-owned sample data in `src/data/data_seed.rs`

The rest of this guide shows the manual coding path from that generic shell to
the finished hospital scheduling app.

### Keep the Published Dependency Shape

The CLI emits the current public crate line. Keep those published dependencies
and add the hospital app's normal scheduling and web/runtime dependencies:

```toml
[dependencies]
solverforge = { version = "0.9.1", features = [
  "serde",
  "console",
  "verbose-logging",
] }
solverforge-ui = "0.6.3"
rand = "0.10.1"

axum = "0.8.9"
tokio = { version = "1.52.1", features = ["full"] }
tokio-stream = { version = "0.1.18", features = ["sync"] }
tower-http = { version = "0.6.8", features = ["fs", "cors"] }
tower = "0.5.3"
serde = { version = "1.0.228", features = ["derive"] }
serde_json = "1.0.149"
chrono = { version = "0.4.44", features = ["serde"] }
parking_lot = "0.12.5"
```

`solverforge-cli 2.0.1` scaffolds the current `solverforge 0.9.1` and
`solverforge-ui 0.6.3` patch line. This tutorial keeps that published target
and adds the hospital-specific dependencies and domain model.

### Align App Metadata

The current hospital app metadata is intentionally explicit:

```toml
[app]
name = "SolverForge Hospital"
starter = "neutral-shell"
cli_version = "2.0.1"

[runtime]
target = "SolverForge crates.io target"
runtime_crate = "solverforge"
runtime_version = "0.9.1"
ui_crate = "solverforge-ui"
ui_version = "0.6.3"

[demo]
default_size = "large"
available_sizes = ["large"]

[solution]
name = "Plan"
score = "HardSoftDecimalScore"
```

This records the scaffold lineage and the public crates used by the running app.
It is not a local-path development recipe.

### Generate the Managed Seams

The scaffold gives you a neutral app. Use the CLI to create the managed seams:

```bash
solverforge generate score HardSoftDecimalScore
solverforge generate fact employee \
  --field id:String \
  --field name:String \
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

solverforge generate constraint assigned_shift --unary --hard
solverforge generate constraint required_skill --join --hard
solverforge generate constraint overlapping_shift --pair --hard
solverforge generate constraint minimum_rest --pair --hard
solverforge generate constraint one_shift_per_day --pair --hard
solverforge generate constraint unavailable_employee --join --hard
solverforge generate constraint undesired_day --join --soft
solverforge generate constraint desired_day --join --soft
solverforge generate constraint balance_assignments --balance --soft
solverforge generate data --mode stub
```

Those commands are not the final app. They create the managed anchors. The app
code then supplies the scheduling meaning:

- keep the scaffolded `Plan` as the solution root and switch its score type
- add `CareHub` and the nearby-search helper functions
- replace generated `Employee` and `Shift` fields with transport-safe IDs,
  derived indexes, calendar helpers, skills, availability, and preferences
- add `Plan::rebuild_derived_fields()` so decoded JSON becomes solver-ready
- replace the generated constraint skeletons with the nine scheduling rules
- replace stub data with the deterministic `LARGE` benchmark generator
- split the neutral frontend into schedule, lifecycle, analysis, and view-state
  modules

That is the teaching boundary: the CLI owns repeatable project seams, while the
manual code owns hospital-scheduling semantics.

### Project Shape

The current hospital example is organized as:

```text
solverforge-hospital/
├── Cargo.toml
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
└── static/
    ├── app/
    ├── generated/ui-model.json
    ├── index.html
    └── sf-config.json
```

Read the article for the cross-layer story, then read the comments in each file
for local intent.

---

## The Problem We're Solving

Hospital scheduling asks:

> Given a hospital workforce and a month of shifts, which employee should cover
> each shift?

The current public demo ships one serious deterministic instance:

- 50 employees
- 688 shifts
- one public dataset id: `LARGE`
- two browser views: `By location` and `By employee`
- retained solve lifecycle with status, snapshot, analysis, pause, resume,
  cancel, delete, and SSE

The score model separates feasibility from quality:

| Rule                 | Kind | Meaning                                                         |
| -------------------- | ---- | --------------------------------------------------------------- |
| Assigned shift       | Hard | Every shift should be assigned to someone                       |
| Required skill       | Hard | The assigned employee must have the required skill              |
| Overlapping shift    | Hard | One employee cannot cover overlapping shifts                    |
| Minimum rest         | Hard | At least 10 hours between two shifts                            |
| One shift per day    | Hard | One employee should not work two shifts on the same touched day |
| Unavailable employee | Hard | Unavailable dates are hard violations                           |
| Undesired day        | Soft | Softly penalize assignments on undesired dates                  |
| Desired day          | Soft | Reward assignments on desired dates                             |
| Balance assignments  | Soft | Discourage concentrating too many shifts on one employee        |

Hard constraints define feasibility. Soft constraints define quality among
feasible schedules.

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
  search-facing service-line proximity signal
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
the dense `Employee.index` rebuilt during normalization.

This split matters because APIs need stable human-readable IDs, while hot solver
paths need cheap index comparisons.

### Shift as Planning Entity

`Shift` is the movable thing:

```rust
#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: String,
    #[serde(skip)]
    pub index: usize,
    pub start: NaiveDateTime,
    pub end: NaiveDateTime,
    pub location: String,
    pub required_skill: String,
    #[planning_variable(
        value_range = "employees",
        allows_unassigned = true,
        nearby_value_distance_meter = "shift_to_employee_nearby_distance",
        nearby_entity_distance_meter = "shift_to_shift_nearby_distance"
    )]
    pub employee_idx: Option<usize>,
}
```

`employee_idx` points into `Plan.employees`, not to `Employee.id`. That is the
central scalar-assignment idea in this example.

### Plan as Planning Solution

`Plan` carries the two collections and the score:

```rust
#[planning_solution(
    constraints = "crate::constraints::create_constraints",
    solver_toml = "../../solver.toml"
)]
pub struct Plan {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftDecimalScore>,
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
    pub use plan::{Plan, PlanConstraintStreams, Shift, ShiftUnassignedFilter};
    // @solverforge:end domain-exports
}
```

The `@solverforge` markers are scaffold/codegen boundary markers. You can read
past them while learning the domain; they exist so generated edits know where
managed exports begin and end.

---

## The Demo Dataset

The current app exposes one public dataset:

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
plan is feasible enough to compare. The current constraint modules use one
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

Each sibling file defines one incremental rule. `create_constraints()` assembles
those rules into the scoring model:

```rust
pub fn create_constraints() -> impl ConstraintSet<Plan, HardSoftDecimalScore> {
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

### Required Skill

The required-skill rule is the best first join to read. It matches a shift to
its employee by comparing `shift.employee_idx` with `Some(employee.index)`, then
hard-penalizes missing skills.

That is the scalar index pattern used throughout the app.

### Availability and Preferences

`unavailable_employee` is hard and minute-proportional. If a shift overlaps an
unavailable date by more minutes, the penalty is larger.

`desired_day` and `undesired_day` are soft and date-count based. They shape which
feasible schedule is better, but they do not decide feasibility.

### Balance

`balance_assignments` groups shifts by `employee_idx` and softly penalizes
uneven assignment counts. This is the scheduling meaning behind the compact
`.balance(...)` stream in the code.

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
changing assignments and swapping assignments.

Nearby search is a hint layer, not a rule layer. The `CareHub` meters rank
promising employees and shift pairs before exact scoring. The constraints still
decide feasibility and quality.

---

## Runtime and Browser Surface

The hospital app keeps the stock retained lifecycle and adapts it to its domain.

The public job surface is:

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

`src/solver/service.rs` wraps `SolverManager<Plan>`, stores per-job SSE state,
and translates runtime events into the JSON payloads consumed by the browser.

`src/api/dto.rs` is the transport boundary. `PlanDto::to_domain()` rebuilds the
domain `Plan` from flattened JSON and calls normalization before the solver sees
the schedule.

`static/app/main.mjs` is the browser entrypoint. It loads `sf-config.json`,
loads `static/generated/ui-model.json`, creates the shared `solverforge-ui`
shell, fetches `/demo-data/LARGE`, and renders the current schedule in both
views.

The neutral scaffold has `static/app.js`; the current hospital app uses focused
modules under `static/app/`.

---

## Making Your First Customization

A good first scheduling expansion is a new constraint that touches only the
domain rule layer.

For example, a home-hub preference would be a soft fact join:

```bash
solverforge generate constraint home_hub_match --join --soft
```

Then implement the rule by matching `Shift.employee_idx` to `Employee.index`,
filtering for `employee.home_hub == shift.care_hub`, and rewarding the match.

This is the normal SolverForge growth path:

1. generate the managed seam
2. write the domain rule
3. register it in `src/constraints/mod.rs`
4. run the tests and inspect score analysis

The retained backend and browser contract do not have to change for a pure
constraint addition.

---

## Testing and Validation

Run the foundational checks from the finished app:

```bash
solverforge check
solverforge routes
cargo fmt --check
cargo test
```

`solverforge check` validates the app metadata and model wiring. `solverforge
routes` confirms that the retained lifecycle endpoints are visible from the
generated Axum route surface.

If you are working in the finished example repository, the convenience target is:

```bash
make test
```

That target adds browserless frontend tests and Playwright browser tests.

Run the full example gate before publishing or updating the hosted demo:

```bash
make ci-local
```

The slow acceptance solve is available when you need to prove the public
`LARGE` dataset reaches a hard-feasible terminal state:

```bash
make test-slow
```

---

## Quick Reference

| Need                             | File or directory                          |
| -------------------------------- | ------------------------------------------ |
| App metadata                     | `solverforge.app.toml`                     |
| Solver policy                    | `solver.toml`                              |
| Planning model manifest          | `src/domain/mod.rs`                        |
| Employee fact                    | `src/domain/employee.rs`                   |
| Shift entity and scalar variable | `src/domain/plan.rs`                       |
| Constraint assembly              | `src/constraints/mod.rs`                   |
| One scheduling rule              | `src/constraints/*.rs`                     |
| Public demo-data entrypoints     | `src/data/data_seed/entrypoints.rs`        |
| Published benchmark generator    | `src/data/data_seed/large.rs` and siblings |
| API routes                       | `src/api/routes.rs`                        |
| DTO contract                     | `src/api/dto.rs`                           |
| SSE endpoint                     | `src/api/sse.rs`                           |
| Solver service                   | `src/solver/service.rs`                    |
| Browser controller               | `static/app/main.mjs`                      |
| Schedule views                   | `static/app/schedule/*.mjs`                |

### Common Gotchas

- `employee_idx` is an index into `Plan.employees`; `Employee.id` is API/UI
  identity.
- Nearby meters rank candidates before exact scoring; they do not replace
  constraints.
- `Plan::rebuild_derived_fields()` must run after JSON decoding.
- `/demo-data` must agree with `data::list_demo_data()`.
- The current public dataset is `LARGE` only.
- The current browser app is module-based and starts from `static/app/main.mjs`.

### Additional Resources

- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [solverforge-cli Modeling and Generation](/docs/solverforge-cli/modeling-and-generation/)
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
- [Solver Phases](/docs/solverforge/solver/phases/)
- [Project Overview](/docs/overview/)
