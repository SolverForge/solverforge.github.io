---
title: Getting Started
description: >
  Install solverforge-cli, scaffold a web app, grow it into a small task
  assignment model, replace the generated placeholders, and solve it.
weight: 1
---

# Getting Started with solverforge-cli

Working with a coding agent? Install the CLI, then the
[`solverforge-modeling` agent skill](/docs/solverforge-cli/agent-skill/#quick-start),
and describe your problem: the agent runs the steps below for you. The
[maintenance planning walkthrough](/docs/getting-started/maintenance-planning-with-the-agent-skill/)
shows one complete run.

This guide walks the same path by hand, from an empty directory to a solved
plan:

1. install the CLI and read the scaffold targets it carries
2. scaffold a web app and solve its empty plan
3. add a resource fact, a task entity, and a planning variable
4. generate two constraints and replace their placeholders
5. build the app and solve the task plan

Every command runs from a terminal; the solve steps use `curl`.

## Prerequisites

- Rust `1.95` or newer with Cargo. The CLI and every app it generates declare
  `rust-version = "1.95"`. Check your toolchain:

  ```bash
  rustc --version
  ```

- A C toolchain for native Rust dependencies (`cc` on Linux and macOS, the MSVC
  build tools on Windows).
- `curl`, to send the solve requests below.

## Install the CLI

```bash
cargo install solverforge-cli --locked
solverforge --version
```

`cargo install` builds the newest `solverforge-cli` from crates.io. The version
output names the CLI and every crate a new project depends on:

```text
solverforge solverforge-cli 4.0.4
CLI version: 4.0.4
Scaffold runtime target: SolverForge crate target 0.26.1
Scaffold UI target: solverforge-ui 0.9.1
Scaffold maps target: solverforge-maps 2.3.3
Scaffold MCP target: rmcp 3.9.0
Runtime source: crates.io: solverforge 0.26.1
UI source: crates.io: solverforge-ui 0.9.1
Maps source: crates.io: solverforge-maps 2.3.3
MCP source: crates.io: rmcp 3.9.0
```

To update an existing install, add `--force` to the same `cargo install`
command.

## Create a Project

```bash
solverforge new my-scheduler
cd my-scheduler
```

`solverforge new` writes a neutral web shell and runs `git init`. In an
interactive terminal it then asks whether to run `cargo check`; either answer
works, because the server step below compiles the app anyway. Pass
`--shell api`, `--shell cli`, or `--shell mcp` for the other shells; see
[Scaffold Commands](/docs/solverforge-cli/scaffold-commands/). The web shell
contains:

- an Axum backend with retained job routes, typed SSE events, snapshots, and
  score analysis
- a `solverforge-ui` frontend in `static/`
- `solverforge.app.toml`, the scaffold contract the CLI keeps in sync
- `solver.toml`, the search configuration; it starts with a 30-second
  termination limit and the runtime's default phases

## Solve the Empty Plan

Start the server:

```bash
solverforge server
```

The first start compiles the app in release mode, which takes a few minutes.
When the server prints `listening on http://0.0.0.0:7860`, open
`http://localhost:7860` in a browser, or send a solve from a second terminal
in the same directory:

```bash
curl -s localhost:7860/demo-data/STANDARD > plan.json
curl -s -X POST -H 'content-type: application/json' --data @plan.json localhost:7860/jobs
curl -s localhost:7860/jobs/0
```

The `POST` answers `{"id":"0"}`. The new project has no facts, entities, or
constraints yet, so the job finishes at once with `"lifecycleState":"COMPLETED"`
and `"bestScore":"0hard/0soft"`. Stop the server with `Ctrl+C`.

`solverforge server` binds port `7860` unless you pass `--port <PORT>` or set
the `PORT` environment variable.

## Grow the Domain

This guide models a small assignment problem: every task needs one resource,
and the total task duration should be spread evenly across the resources.

Add the problem fact and the planning entity:

```bash
solverforge generate fact resource
solverforge generate entity task --field duration:u32
```

`generate fact` writes `src/domain/resource.rs` with an `id` and a `name`
field. `generate entity` writes `src/domain/task.rs` with an `id` and the
extra `duration` field. Do not pass `--field id:...` or `--field name:...`: the
CLI already writes those fields and rejects duplicates. A field type from
`chrono` makes the CLI add `chrono` to `Cargo.toml`; a type the CLI does not
know, such as an enum of your own, must be defined in `src/domain/` before the
app compiles, and the CLI prints a warning until it is.

Give each task a resource to choose:

```bash
solverforge generate variable resource_idx --entity Task --kind scalar --range resources --allows-unassigned
```

`resource_idx` is an `Option<usize>` index into the plan's `resources`
collection. `--allows-unassigned` lets the solver leave a task without a
resource, which the first constraint below makes a hard violation.

Every generator also updates `src/domain/mod.rs`, the planning solution in
`src/domain/plan.rs`, `solverforge.app.toml`, the generated UI model, and the
demo data in `src/data/data_seed.rs`.

## Add Constraints

```bash
solverforge generate constraint task_assigned --unary --hard
solverforge generate constraint balanced_duration --balance
```

Each command writes a module in `src/constraints/`, declares it in
`src/constraints/mod.rs`, and adds its `constraint()` call to
`create_constraints` in `src/constraints/assemble.rs`. The stream wiring is
complete, but the rule itself is a placeholder that panics. Until you replace it, every solve fails at once
with `"lifecycleState":"FAILED"`, and the server log names the file:

```text
replace placeholder condition in `unary_condition` (src/constraints/task_assigned.rs) before enabling this constraint
```

Replace every placeholder before you solve.

### Every task needs a resource

`task_assigned` streams tasks from the generated `Plan::tasks()` accessor,
keeps the ones that match `unary_condition`, and penalizes each with one hard
point. Replace the placeholder condition with "the task has no resource". The
complete `src/constraints/task_assigned.rs`:

```rust
use crate::domain::{Plan, Task};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: every task needs a resource.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::tasks())
        .filter(unary_condition)
        .penalize(hard_weight(unary_weight))
        .named("task_assigned")
}

/// Selects each Task that has no resource yet.
fn unary_condition(entity: &Task) -> bool {
    entity.resource_idx.is_none()
}

/// Penalty for one Task selected by `unary_condition`.
fn unary_weight(_entity: &Task) -> HardSoftScore {
    <HardSoftScore as Score>::one_hard()
}
```

### Spread the work evenly

`balanced_duration` groups all tasks into one scope and collects a load per
resource with `load_balance`. The generated metric counts each task as `1`;
count its duration instead, and replace the placeholder condition and weight
with one soft point per unit of the collector's unfairness, the square root
of the summed squared deviation from the mean load. The complete
`src/constraints/balanced_duration.rs`:

```rust
use crate::domain::{Plan, Task};
use solverforge::prelude::*;
use solverforge::stream::collector::LoadBalance;
use solverforge::IncrementalConstraint;

/// SOFT: spread task duration evenly across resources.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::tasks())
        .group_by(
            balance_scope,
            load_balance(balance_group_key, balance_metric),
        )
        .penalize(balance_weight)
        .named("balanced_duration")
}

/// Every task belongs to one balancing scope.
fn balance_scope(_entity: &Task) -> usize {
    0
}

/// Load is counted per resource.
fn balance_group_key(entity: &Task) -> Option<usize> {
    entity.resource_idx
}

/// Each task adds its duration to its resource's load.
fn balance_metric(entity: &Task) -> i64 {
    i64::from(entity.duration)
}

/// One soft point per unit of unfairness across the resource loads.
fn balance_weight(_scope: &usize, load: &LoadBalance<Option<usize>>) -> HardSoftScore {
    HardSoftScore::of_soft(load.unfairness())
}
```

## Build and Solve

Inspect the model the CLI sees, then compile it:

```bash
solverforge info
solverforge check
cargo build
```

`solverforge info` lists the `Plan` solution, the `Task` entity with its
`resource_idx` scalar variable, the `Resource` fact, and both constraints.
`solverforge check` validates the managed blocks, the domain model, and
`solver.toml`; it does not compile the project, so `cargo build` is the step
that proves the Rust is correct.

Start the server again and solve the standard demo data, which holds 4
resources and 9 tasks with durations 1 through 9:

```bash
solverforge server
```

```bash
curl -s localhost:7860/demo-data/STANDARD > plan.json
curl -s -X POST -H 'content-type: application/json' --data @plan.json localhost:7860/jobs
curl -s localhost:7860/jobs/0
curl -s localhost:7860/jobs/0/analysis
```

The solve runs for the 30 seconds set in `solver.toml`. Read the job again
after that: it reports `"lifecycleState":"COMPLETED"` and a `bestScore` of
`0hard` with a soft part of zero or below. `0hard` means every task has a
resource; the soft part is the remaining imbalance. The analysis lists the
score of `task_assigned` and `balanced_duration` separately.

## Inspect and Test

```bash
solverforge routes
solverforge test
```

`solverforge routes` lists the HTTP routes in `src/api/routes.rs`, including
the job lifecycle, snapshot, analysis, pause, resume, cancel, and SSE routes.
`solverforge test` runs `cargo test`; arguments before `--` go to Cargo and
arguments after it go to the test binaries, as in
`solverforge test -- --nocapture`.

## Next Steps

- Read [Project Anatomy](/docs/solverforge-cli/project-anatomy/) before you
  start heavy manual edits.
- Read [Modeling & Generation](/docs/solverforge-cli/modeling-and-generation/)
  for list variables, scalar groups, conflict repairs, demo data, and
  removing resources.
- Read [Configuration](/docs/solverforge-cli/configuration/) before you change
  `solver.toml` or `solverforge.app.toml`.
- Keep the [Command Reference](/docs/solverforge-cli/command-reference/) open
  while working.
- Continue with a worked use case:
  [Hospital](/docs/getting-started/solverforge-hospital-use-case/),
  [Lessons](/docs/getting-started/solverforge-lessons-use-case/),
  [Deliveries](/docs/getting-started/solverforge-deliveries-use-case/), or
  [FSR](/docs/getting-started/solverforge-fsr-use-case/).
- Continue with [SolverForge](/docs/solverforge/) for runtime-level modeling
  and solver detail.
