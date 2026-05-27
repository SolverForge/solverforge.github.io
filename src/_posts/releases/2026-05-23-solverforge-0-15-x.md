---
title: "SolverForge 0.15.x: Constraint Node Sharing and Assignment Search Diagnostics"
date: 2026-05-23
draft: false
description: >
  SolverForge 0.15.0 publishes the solverforge_constraints compiler boundary,
  shared grouped constraint-stream nodes, richer assignment-backed scalar
  neighborhoods, and move-level runtime telemetry.
---

**SolverForge 0.15.0** is the current core runtime line. It is tagged as
[v0.15.0](https://github.com/SolverForge/solverforge/releases/tag/v0.15.0),
published by GitHub Actions on 2026-05-23, and available as
`solverforge 0.15.0` on [crates.io](https://crates.io/crates/solverforge).
crates.io accepted the facade package at `2026-05-23T07:40:59Z`; docs.rs can
briefly remain on the prior Rustdoc build while it processes the new package.

The release is a core runtime release, not a CLI scaffold refresh.
`solverforge-cli 2.0.4` still scaffolds `solverforge 0.11.1`,
`solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4`. The checked-in
`solverforge-usecases` bundle now targets `solverforge 0.15.0`. Direct Cargo
projects and deliberately upgraded generated apps can target the published
`solverforge 0.15.0` crate.

## What Changed

### Constraint functions have a compiler boundary

`#[solverforge_constraints]` is now the canonical attribute for constraint
factory functions that reuse grouped stream work. You still write ordinary
fluent Rust, but the macro can inspect the whole function before type checking
and turn repeated grouped terminals into one shared retained node:

```rust
#[solverforge_constraints]
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    let shifts_by_employee = Streams::new()
        .for_each(Schedule::shifts())
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .group_by(
            |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
            count(),
        );

    (
        shifts_by_employee
            .penalize(|_employee_idx: &usize, count: &usize| {
                HardSoftScore::of_soft((*count as i64 - 5).max(0))
            })
            .named("Too many shifts"),
        shifts_by_employee
            .reward(|_employee_idx: &usize, count: &usize| {
                HardSoftScore::of_soft((*count as i64).min(5))
            })
            .named("Assigned shifts"),
    )
}
```

The shared grouped node owns extraction, filtering, grouping, collector state,
retraction tokens, and dirty-key updates once. Terminal scorers stay separate,
so constraint names, impact direction, hard metadata, authored ordering, and
score-analysis rows do not collapse.

### Shared coverage reaches the grouped families

0.15.0 shares grouped, projected grouped, direct cross grouped, cross
complemented grouped, and projected complemented grouped retained state. The
compiler shares same-binding grouped terminal reuse directly. It can also share
separately written grouped chains when their stream expression is syntax-proved
identical inside the annotated function.

Opaque helper calls and unsupported mixed shapes stay on the ordinary Rust path.
There is no public `share`, `derive`, cache, registry, prefix, or suffix API.
That boundary matters: sharing belongs in the compiler and the shared
node-state engine, not in application-level memoization.

### ConstraintSet composition is typed

Each built-in incremental constraint can now act as a singleton
`ConstraintSet`, and tuples can contain nested typed `ConstraintSet` values.
That lets the compiler combine shared grouped nodes with surrounding ordinary
constraints without guessing from syntax whether an opaque tuple member is one
constraint or a multi-constraint set.

Ordered shared chains preserve authored result order for metadata,
`evaluate_each(...)`, and detailed analysis. The public metadata view still
deduplicates repeated full `ConstraintRef` identities when hardness agrees.

### Diagnostics identify shared nodes

The facade exports a small public diagnostics vocabulary:

- `SharedNodeDiagnostics`
- `SharedNodeId`
- `SharedNodeOperation`

These types describe shared-node ids, operation families, terminal consumers,
update counts, and changed-key counts. They do not expose the internal grouped
node-state structs as modeling API.

### Assignment-backed scalar search is broader

Assignment-backed grouped scalar search gained bounded value-pattern
neighborhoods. The stock grouped assignment cursor can now express:

- short and long value-window swaps
- same-sequence run-gap swaps
- block reassignments
- optional occupant releases
- three-value window cycles

These moves operate on assigned value and sequence structure, check assignment
feasibility before emission, and keep hard assignment constraints intact.

Required assignment construction also has a hard-first batched fill path for
required nullable slots. It can complete required coverage even when an
ordinary time or move budget has already expired, while still respecting
external pause, cancel, and parent-yield control.

### Move telemetry is runtime-owned

Local search now records move-level diagnostics without benchmark-only
instrumentation. Retained telemetry includes per-move-label counts for
generated, evaluated, accepted, applied, not-doable, acceptor-rejected,
forager-ignored, score-improving, score-equal, score-worse, rejected-improving,
and applied score improvement.

The bounded applied-move trace records the selected candidate index,
generated/evaluated/accepted/ignored counts for the step, score before and
after, score delta, and hard feasibility before and after the move. `moves/s`
remains display-only; exact counts and durations are the authoritative runtime
metrics.

## Install And Scaffold Status

For direct Cargo projects:

```toml
solverforge = { version = "0.15.0", features = ["serde", "console"] }
```

The companion workspace crates are published at the same `0.15.0` line:

```toml
solverforge-core = "0.15.0"
solverforge-scoring = "0.15.0"
solverforge-solver = "0.15.0"
```

For generated apps, confirm the installed CLI target:

```bash
solverforge --version
```

`solverforge-cli 2.0.4` still reports:

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
generated app to `solverforge 0.15.0` only when you are deliberately upgrading
that app's runtime dependency and validating the generated code against the
newer core crate.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.15.0` | 2026-05-23 | Adds `#[solverforge_constraints]`, shared grouped/projection/cross grouped node state, typed `ConstraintSet` composition, shared-node diagnostics, assignment value-pattern neighborhoods, hard-first required assignment construction, and move-level runtime telemetry. |

## Documentation Changes

The docs tree now tracks the 0.15.0 runtime surface:

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
  uses `#[solverforge_constraints]` for reusable constraint functions and shows
  repeated grouped terminal sharing.
- [Constraint Node Sharing](/docs/solverforge/constraints/node-sharing/)
  documents the supported grouped sharing shapes and the boundary against
  public share/cache APIs.
- [Score Analysis](/docs/solverforge/constraints/score-analysis/) explains
  that shared nodes do not collapse terminal analysis rows.
- [Construction](/docs/solverforge/solver/construction/) documents the
  hard-first batched required assignment fill path.
- [Local Search](/docs/solverforge/solver/local-search/) and
  [SolverManager](/docs/solverforge/solver/solver-manager/) document
  move-label telemetry and bounded applied-move traces.
- [Status & Roadmap](/docs/status-and-roadmap/) separates the published
  `solverforge 0.15.0` runtime from the still-current
  `solverforge-cli 2.0.4` scaffold target and the checked-in 0.15.0 use-case
  bundle.
- The worked use-case tutorials track the current `solverforge-usecases`
  bundle. In particular, the FSR tutorial now documents the 0.15.0 migration
  from app-local route constraint adapters to route shadow values scored by
  stock `ConstraintFactory` streams.
