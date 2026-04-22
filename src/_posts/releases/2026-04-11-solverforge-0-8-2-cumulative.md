---
title: 'SolverForge 0.8.2: CLI and Runtime Convergence'
date: 2026-04-11
draft: false
description: >
  SolverForge 0.7.0 through 0.8.2 bring CLI scaffolding, config-driven runtime,
  and a retained SolverManager lifecycle—one coherent toolchain from first install
  to production operations.
---

**SolverForge 0.8.2** is a cumulative update spanning the 0.7.x and 0.8.x lines.
If you last checked in at 0.6.0, the main change is that `solverforge-cli` and
`solverforge` now form one coherent developer experience.

## Why this release matters

Building a solver application previously required piecing together scaffolding,
generated code, manual solver loops, and lifecycle management. Starting with
0.7.0 and solidifying through 0.8.2, that boundary has collapsed into one
pipeline:

1. **Scaffold** a project with `solverforge new`
2. **Model** your domain with derive macros
3. **Configure** behavior via `solver.toml` and per-solution overlays
4. **Run** with `SolverManager` handling job lifecycle, pause/resume, and
   event streaming
5. **Operate** with exact checkpoint semantics and snapshot-bound analysis

The same types flow from generated code through to the retained runtime. The
same configuration drives both the scaffolded server and your custom extensions.
The same event stream powers both console output and production telemetry.

## CLI-first onboarding

`solverforge-cli` is now the primary entry point for new projects:

```bash
cargo install solverforge-cli
solverforge new my-scheduler --standard
cd my-scheduler
solverforge server
```

The CLI scaffolds complete applications—domain model, constraints, solver
configuration, and a working web interface. Templates cover standard-variable
and list-heavy planning models, and the generated code targets the same unified
runtime you extend.

Use `solverforge generate` to add entities, facts, and constraints.

## Cleaner generated APIs

The `#[planning_solution]` macro now generates a `{Name}ConstraintStreams`
trait with typed accessors for each collection field. Instead of manual
extractors like `factory.for_each(|s| &s.shifts)`, you write `factory.shifts()`:

```rust
#[planning_solution]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

// Generated trait enables:
let constraints = ConstraintFactory::<Schedule, HardSoftScore>::new()
    .shifts()                    // No manual extractor
    .join(equal(|s| s.employee))
    .filter(|a, b| /* ... */)
    .penalize_hard()
    .named("No overlap");
```

Entity types with `Option` planning variables get a generated `{Entity}Unassigned`
filter. The `.named("...")` method is now the sole constraint finalizer, replacing
the older `as_constraint` naming.

## Config-driven runtime

Solver behavior is now controlled through `solver.toml`:

```toml
[termination]
seconds_spent_limit = 30
unimproved_seconds_spent_limit = 5
step_count_limit = 10000
```

The runtime loads this automatically. For per-solution overrides—useful when
different problem instances need different budgets—use the `config` attribute:

```rust
#[planning_solution(
    constraints = "define_constraints",
    config = "solver_config_for_solution"
)]
pub struct Schedule {
    // ...
}

fn solver_config_for_solution(
    solution: &Schedule,
    config: SolverConfig
) -> SolverConfig {
    config.with_termination_seconds(solution.time_limit_secs)
}
```

The callback receives the loaded `solver.toml` configuration and should decorate
it, not replace it. This keeps environment-specific settings (hardware limits,
deployment profiles) separate from instance-specific adjustments (customer
SLAs, dynamic deadlines).

## Retained lifecycle: jobs, snapshots, and checkpoints

`SolverManager` now owns the full retained lifecycle. When you solve, you get a
job ID and an event receiver:

```rust
static MANAGER: SolverManager<Schedule> = SolverManager::new();

let (job_id, mut receiver) = MANAGER.solve(schedule).unwrap();

while let Some(event) = receiver.blocking_recv() {
    match event {
        SolverEvent::Progress { metadata } => {
            println!("step {} score {:?}",
                metadata.telemetry.step_count,
                metadata.telemetry.best_score);
        }
        SolverEvent::BestSolution { metadata, .. } => {
            if let Some(rev) = metadata.snapshot_revision {
                let analysis = MANAGER
                    .analyze_snapshot(job_id, Some(rev))
                    .unwrap();
                // Snapshot-bound analysis
            }
        }
        SolverEvent::Paused { metadata } => {
            // Exact pause semantics: solver state is checkpointed
            MANAGER.resume(job_id).unwrap();
        }
        SolverEvent::Completed { .. } => break,
        _ => {}
    }
}
```

The lifecycle speaks in neutral terms: **jobs**, **snapshots**, and
**checkpoints**. Every event carries `job_id`, monotonic `event_sequence`, and
`snapshot_revision`. Progress events include telemetry—step count, moves per
second, score calculation rate, acceptance rate—so your UI or monitoring stack
has structured data to work with.

### Exact pause and resume

`pause()` requests settlement at a runtime-owned safe boundary. The runtime
transitions through `PauseRequested` to `Paused` only when the checkpoint is
exact and resumable. `resume()` continues from that in-process checkpoint,
not from a fresh solve seeded with the best solution.

Termination budgets (`seconds_spent_limit`, `step_count_limit`, and friends)
are preserved across pause/resume. Paused wall-clock time does not consume
active solve budgets.

### Lifecycle-complete events

The retained runtime emits a complete event vocabulary:

- `Progress` — periodic telemetry during solving
- `BestSolution` — new best solution with snapshot revision
- `PauseRequested` — pause is settling
- `Paused` — checkpoint is ready, resumable
- `Resumed` — continued from checkpoint
- `Completed` — normal termination
- `Cancelled` — explicit cancellation
- `Failed` — unrecoverable error

Each event carries authoritative lifecycle state. Your application does not
infer completion from transport behavior or analysis availability; it responds
to explicit terminal reasons.

### Snapshot-bound analysis

Analysis is always revision-specific. You analyze a retained `snapshot_revision`,
never the live mutable job directly. This means analysis is available while
solving, while paused, and after completion—but availability does not imply
terminal state. Your UI can render constraint breakdowns without accidentally
collapsing a live job into an idle state.

## Responsive operational control

Built-in search phases now poll retained-runtime control during large
neighborhood generation and evaluation. This means `pause()`, `cancel()`, and
config-driven termination unwind promptly without application-side watchdogs.

Interruptible retained phases and serialized pause lifecycle publication ensure
that `PauseRequested` remains authoritative before later pause-state events. If
construction is interrupted by a pause, placements are retried correctly after
resume.

## List-variable improvements

List-heavy planning models (vehicle routing, task sequences) receive ongoing
attention. The `#[planning_list_variable]` macro supports a `solution_trait`
attribute when routing helpers or distance meters need extra solution-side
contracts:

```rust
#[planning_list_variable(solution_trait = "routing::VrpSolution")]
pub routes: Vec<Vec<Visit>>,
```

This keeps generated code compatible with custom domain extensions without
requiring local macro forks.

## Console and runtime polish

The console output—enabled with `features = ["console"]`—displays an emerald
truecolor banner matching the build tooling presentation.

Telemetry includes step count, moves per second, score calculations per second,
acceptance rate, phase timing, and score trajectory. The `verbose-logging`
feature adds DEBUG-level updates approximately once per second during local
search.

## Upgrade notes

- **Rust version**: The current crate line targets Rust 1.92+.
- **Breaking in 0.8.0**: `Solvable::solve` now takes `SolverRuntime<Self>`
  instead of manual terminate/sender plumbing. `SolverManager::solve` returns
  `Result<(job_id, receiver), SolverManagerError>`. Manual retained-runtime
  implementations need to update their entrypoints.
- **Generated accessors**: Prefer `factory.shifts()` over manual `for_each`
  extractors in new code.
- **Config decoration**: Use `#[planning_solution(config = "...")]` to layer
  per-solution adjustments on top of `solver.toml`, not to replace it.
- **Neutral terminology**: Update any code or docs using schedule-specific
  lifecycle terms to the job/snapshot/checkpoint vocabulary.

## What's next

Planned work includes:

- Expanded documentation for retained lifecycle orchestration in service and UI
  contexts
- More list-heavy planning examples and routing domain helpers
- Refined scaffold extension workflows for custom phases and selectors
