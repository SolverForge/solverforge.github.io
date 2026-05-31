---
title: "SolverForge 0.12.x: Assignment-Backed Scalar Construction"
date: 2026-05-08
draft: false
description: >
  SolverForge 0.12.x publishes assignment-backed grouped scalar construction,
  consecutive run collectors, cleaner generated stream sources, and renamed
  direct runtime assembly contracts.
---

**SolverForge 0.12.x** is the assignment-backed scalar construction runtime
line. It starts with
[0.12.0](https://crates.io/crates/solverforge/0.12.0), published on
2026-05-08. The latest patch is
[0.12.1](https://crates.io/crates/solverforge/0.12.1), with API docs on
[docs.rs](https://docs.rs/solverforge/0.12.1).

Patch releases are folded into this line note. Use the latest 0.12.x patch only
when you are intentionally staying on the 0.12 line, and keep generated-app
scaffold targets explicit by checking the installed `solverforge-cli` output.

## What Changed

### Generated source methods are the public stream root

Current constraints start from generated solution source methods and pass those
sources to `ConstraintFactory::for_each(...)`:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .unassigned()
    .penalize_hard()
    .named("Unassigned shift")
```

That keeps the generated source metadata visible at the model boundary while
leaving `ConstraintFactory` as the zero-state stream builder. Use
`solverforge::stream::vec(...)` only for custom collection surfaces that are not
generated from the planning solution.

### Assignment-backed ScalarGroup is the required-slot path

`ScalarGroup::assignment(...)` declares a required nullable scalar target. The
group can identify required entities, capacity conflicts, sequence/position
metadata, entity order, and value order:

```rust
#[planning_solution(
    constraints = "define_constraints",
    scalar_groups = "scalar_groups"
)]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}

pub(super) fn scalar_groups() -> Vec<ScalarGroup<Schedule>> {
    vec![
        ScalarGroup::assignment(
            "required_shift_assignment",
            Schedule::shifts().scalar("employee_idx"),
        )
        .with_required_entity(required_shift)
        .with_capacity_key(employee_day_capacity)
        .with_entity_order(shift_order)
        .with_value_order(employee_preference),
    ]
}

fn required_shift(_schedule: &Schedule, _shift_idx: usize) -> bool {
    true
}

fn employee_day_capacity(
    schedule: &Schedule,
    shift_idx: usize,
    employee_idx: usize,
) -> Option<usize> {
    let shift = &schedule.shifts[shift_idx];
    shift
        .date
        .checked_mul(schedule.employees.len())
        .and_then(|base| base.checked_add(employee_idx))
}

fn shift_order(schedule: &Schedule, shift_idx: usize) -> i64 {
    i64::try_from(schedule.shifts[shift_idx].date).unwrap_or(i64::MAX)
}

fn employee_preference(
    schedule: &Schedule,
    shift_idx: usize,
    employee_idx: usize,
) -> i64 {
    let preferred = schedule.shifts[shift_idx].date % schedule.employees.len();
    let distance = (employee_idx + schedule.employees.len() - preferred)
        % schedule.employees.len();
    i64::try_from(distance).unwrap_or(i64::MAX)
}
```

The solver policy selects that group from `solver.toml`:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
group_name = "required_shift_assignment"
value_candidate_limit = 8
group_candidate_limit = 64
```

In `0.12.1`, required-slot coverage is no longer a separate coverage-specific
group or phase. It is an assignment-backed `ScalarGroup` routed through the
same grouped construction engine as custom compound candidates.
Required entities are filled before optional entities; required assignments may
displace optional occupants or move required blockers through bounded
augmenting paths.

### Assignment repair uses grouped scalar selectors

Local search repairs the same assignment-backed scalar group:

```toml
[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "required_shift_assignment"
max_moves_per_step = 64
require_hard_improvement = true
```

The selector emits compound scalar moves for unassigned required entities,
capacity conflicts, bounded reassignments, and bounded sequence/position
rematches. The hard-improvement gate is the same one used by grouped scalar,
conflict-repair, cartesian, and VND repair paths.

### Consecutive run collection is built in

The new `consecutive_runs(...)` collector groups integer points into consecutive
runs. It is useful for streak penalties, such as consecutive work days:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .group_by(
        |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
        consecutive_runs(|shift: &Shift| shift.date as i64),
    )
    .penalize_with(|_employee_idx: &usize, runs: &Runs| {
        let excess_days = runs
            .runs()
            .iter()
            .map(|run| run.point_count().saturating_sub(5) as i64)
            .sum();
        HardSoftScore::of_soft(excess_days)
    })
    .named("Long work streaks")
```

`Run` exposes `start()`, `end()`, `point_count()`, and `item_count()`. `Runs`
exposes `runs()`, `point_count()`, `item_count()`, `len()`, and `is_empty()`.

### Grouped weights receive the group key

Grouped stream terminal scoring now passes both the group key and collector
result to dynamic weight closures. Use
`penalize_with(|key, result| ...)`, `reward_with(|key, result| ...)`, and their
hard/soft convenience variants. This is the shape shown by the
`consecutive_runs(...)` example above.

### Direct runtime assembly names are clearer

Advanced direct users of lower-level solver assembly should use the current
runtime names:

- `RuntimeModel`
- `VariableSlot`
- `ScalarVariableSlot`
- `ListVariableSlot`
- `ScalarGroup` and `ScalarGroupBinding`
- `ScalarCandidate`
- `ScalarEdit`
- `ConflictRepair`
- `RepairCandidate`
- `RepairLimits`

Macro-generated applications do not normally name these types. The rename is
for lower-level extension code that assembles runtime plans directly.

### Generated public list helper shims are gone

Generated list mutation helpers such as `list_len_static()`, `element_count()`,
`assign_element()`, owner-prefixed list helpers, and related direct mutation
methods are no longer user-facing model APIs. Application code should stay on
the public modeling, descriptor, constraint-stream, solver, and configuration
surface.

## Install And Scaffold Status

For direct Cargo projects:

```toml
solverforge = { version = "0.12.1", features = ["serde", "console"] }
```

If you write custom incremental constraints that need lower-level identities,
the companion workspace crates are also published at the same 0.12.x patch:

```toml
solverforge-core = "0.12.1"
```

For generated apps, confirm the installed CLI target:

```bash
solverforge --version
```

At the time of this release, `solverforge-cli 2.0.4` reported:

```text
CLI version: 2.0.4
Scaffold runtime target: SolverForge crate target 0.11.1
Scaffold UI target: solverforge-ui 0.6.5
Scaffold maps target: solverforge-maps 2.1.4
Runtime source: crates.io: solverforge 0.11.1
UI source: crates.io: solverforge-ui 0.6.5
Maps source: crates.io: solverforge-maps 2.1.4
```

Generated apps created with that CLI start on `solverforge 0.11.1`. Move a
generated app to `solverforge 0.12.x` only when you are deliberately upgrading
that app's runtime target and validating the generated code against the newer
core crate.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.12.1` | 2026-05-09 | Folds coverage into assignment-backed `ScalarGroup` declarations, routes required nullable assignment construction through grouped scalar construction, and uses `grouped_scalar_move_selector` for assignment repair. |
| `0.12.0` | 2026-05-08 | Adds coverage-first construction, coverage repair, consecutive run collection, generated source-method stream roots, declarative scalar planning contracts, and clearer direct runtime assembly names. |

## Documentation Changes

At the time of this release, the docs tree tracked the 0.12.x runtime surface:

- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/)
  shows `ConstraintFactory::for_each(Schedule::shifts())` as the normal stream
  root.
- [Collectors](/docs/solverforge/constraints/collectors/) documents
  `consecutive_runs(...)`, `Run`, `Runs`, and complemented grouped counts.
- [Construction](/docs/solverforge/solver/construction/) covers
  assignment-backed `ScalarGroup` construction.
- [Scalar Move Selectors](/docs/solverforge/solver/scalar-move-selectors/)
  includes assignment-backed `grouped_scalar_move_selector` repair.
- [List Variables](/docs/solverforge/modeling/list-variables/) removes public
  guidance around generated list mutation helpers.
- [Status & Roadmap](/docs/status-and-roadmap/) separated the published
  `solverforge 0.12.1` runtime from the then-current `solverforge-cli 2.0.4`
  scaffold target.
