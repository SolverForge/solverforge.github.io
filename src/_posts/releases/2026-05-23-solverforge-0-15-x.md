---
title: "SolverForge 0.15.x: Directed Projected Joins, Dynamic Bridge, and Node Sharing"
date: 2026-05-23
draft: false
description: >
  SolverForge 0.15.2 publishes directed projected self-joins on top of the
  0.15 line's solverforge_constraints compiler boundary, dynamic bridge crate,
  list precedence hooks, richer assignment-backed scalar neighborhoods, and
  move-level runtime telemetry.
---

**SolverForge 0.15.2** is the current core runtime patch in the 0.15 line. It is
tagged as [v0.15.2](https://github.com/SolverForge/solverforge/releases/tag/v0.15.2),
published by GitHub Actions on 2026-06-10, and available as
`solverforge 0.15.2` on [crates.io](https://crates.io/crates/solverforge).
docs.rs can briefly remain on the prior Rustdoc build while it processes the
new package.

The runtime release line is separate from CLI scaffold publishing. The
CI-green `solverforge-cli 2.2.1` source line targets `solverforge 0.15.1`,
`solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4`. The latest crates.io
package remains `solverforge-cli 2.2.0`, which targets `solverforge 0.15.0`,
until the 2.2.1 package is published. The checked-in `solverforge-usecases`
bundle also remains on `solverforge 0.15.0` until that bundle is explicitly
refreshed.

## What Changed

### 0.15.2 adds directed projected self-joins

Projected scoring rows already supported retained self-joins where both sides
use the same key. 0.15.2 distinguishes that symmetric case from directed
left/right projected joins by carrying the joiner mode in `EqualJoiner`.

Use `equal(...)` when an unordered same-key pair should be considered once.
Use `equal_bi(left_key, right_key)` when both sides have the same projected row
type but the relationship is oriented:

```rust
factory.for_each(Schedule::shifts())
    .project(ShiftWindows)
    .join(equal_bi(
        |left: &WorkWindow| Some(left.shift_id),
        |right: &WorkWindow| right.employee_id,
    ))
    .penalize(hard_weight(|_: &WorkWindow, _: &WorkWindow| {
        HardSoftScore::ONE_HARD
    }))
    .named("Projected directed relationship");
```

The retained projected scorer evaluates oriented pairs where the left key
equals the right key and skips only the same retained row. Reciprocal rows count
as two matches when both directions satisfy the keys. The lower-level public
types are intentionally module-scoped as `stream::projected::DirectedBi` and
`constraint::projected::DirectedBi`; application constraints should use the
fluent `join(equal_bi(...))` surface.

### 0.15.1 adds the dynamic bridge and list-precedence surface

0.15.1 introduced `solverforge-bridge`, a publishable workspace crate for
host-language bindings. It carries stable logical entity, fact, and variable
identifiers, dynamic score-family values, dynamic backend contracts, and
descriptor-resolved scalar/list slots. The solver resolves dynamic logical IDs
to descriptor indexes before construction, local search, and score-director
notifications, so dynamic bindings use the same runtime pipeline as typed Rust
models.

The same patch line added stock list-precedence support. List variables can
declare:

- `element_owner_fn`
- `construction_element_order_key`
- `precedence_duration_fn`
- `precedence_successors_fn`

Those hooks feed fixed-owner placement, ordered list construction,
`ListPrecedenceMakespanConstraint`, `list_permute_move_selector`, and
`list_precedence_move_selector`. The intent is generic list-precedence modeling
through upstream SolverForge APIs, not benchmark-local adapters.

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

The 0.15 line shares grouped, projected grouped, direct cross grouped, cross
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
solverforge = { version = "0.15.2", features = ["serde", "console"] }
```

The companion workspace crates are published at the same `0.15.2` line:

```toml
solverforge-core = "0.15.2"
solverforge-scoring = "0.15.2"
solverforge-solver = "0.15.2"
solverforge-bridge = "0.15.2"
```

For generated apps, confirm the installed CLI target:

```bash
solverforge --version
```

The current `solverforge-cli 2.2.1` source line reports:

```text
CLI version: 2.2.1
Scaffold runtime target: SolverForge crate target 0.15.1
Scaffold UI target: solverforge-ui 0.6.5
Scaffold maps target: solverforge-maps 2.1.4
Runtime source: crates.io: solverforge 0.15.1
UI source: crates.io: solverforge-ui 0.6.5
Maps source: crates.io: solverforge-maps 2.1.4
```

Generated apps created from the CI-green source line start on
`solverforge 0.15.1`; generated apps created from the latest crates.io package
still start on `solverforge 0.15.0` until CLI 2.2.1 is published. Move
generated apps to `solverforge 0.15.2` only when you are deliberately upgrading
that app's runtime dependency and validating the generated code against the
newer core crate.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.15.2` | 2026-06-10 | Adds directed projected self-joins with `equal_bi(left_key, right_key)` for same-output projected rows, keeps symmetric projected joins on `equal(...)`, and scopes ambiguous cross/projected lower-level names under their modules. |
| `0.15.1` | 2026-06-02 | Publishes `solverforge-bridge`, adds logical descriptor identifiers and descriptor-resolved dynamic slots, runs dynamic scalar/list variables through construction and search, adds fixed list-element ownership, list precedence hooks, `ListPrecedenceMakespanConstraint`, precedence-aware list neighborhoods, and release-order fixes for the bridge crate. |
| `0.15.0` | 2026-05-23 | Adds `#[solverforge_constraints]`, shared grouped/projection/cross grouped node state, typed `ConstraintSet` composition, shared-node diagnostics, assignment value-pattern neighborhoods, hard-first required assignment construction, and move-level runtime telemetry. |

## Documentation Changes

The docs tree now tracks the `solverforge 0.15.2` runtime surface:

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
  uses `#[solverforge_constraints]` for reusable constraint functions and shows
  repeated grouped terminal sharing, direct cross grouping, and directed
  projected self-joins.
- [Constraint Node Sharing](/docs/solverforge/constraints/node-sharing/)
  documents the supported grouped sharing shapes and the boundary against
  public share/cache APIs.
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  separates symmetric self-joins from directed `equal_bi(left_key, right_key)`
  projected joins.
- [List Variables](/docs/solverforge/modeling/list-variables/) and
  [List Selectors](/docs/solverforge/solver/list-move-selectors/) document
  fixed element ownership, construction ordering hooks, precedence hooks,
  `list_permute_move_selector`, and `list_precedence_move_selector`.
- [Crate & Runtime Map](/reference/crate-map/) records the `solverforge-bridge`
  crate and the current module-scoped projected/cross lower-level names.
- [Score Analysis](/docs/solverforge/constraints/score-analysis/) explains
  that shared nodes do not collapse terminal analysis rows.
- [Construction](/docs/solverforge/solver/construction/) documents the
  hard-first batched required assignment fill path.
- [Local Search](/docs/solverforge/solver/local-search/) and
  [SolverManager](/docs/solverforge/solver/solver-manager/) document
  move-label telemetry and bounded applied-move traces.
- [Status & Roadmap](/docs/status-and-roadmap/) records the published
  `solverforge 0.15.2` runtime, the CI-green `solverforge-cli 2.2.1` source
  scaffold target, and the still-published 2.2.0 crate/use-case 0.15.0 targets.
