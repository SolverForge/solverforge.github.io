---
title: "SolverForge 0.11.x: Clone-Free Projected Scoring and Facade Exports"
date: 2026-05-05
draft: false
description: >
  SolverForge 0.11.x publishes clone-free projected scoring rows, joined-pair
  projection, borrowed constraint metadata, and facade-level configuration
  exports while keeping generated CLI scaffold targets explicit.
---

**SolverForge 0.11.x** is the previous projected-scoring runtime line. The line starts with
clone-free projected scoring in
[0.11.0](https://crates.io/crates/solverforge/0.11.0) and ends at
[0.11.1](https://crates.io/crates/solverforge/0.11.1) before the 0.12.x
runtime line.

Patch releases are folded into this line note. Use the latest 0.11.x patch only
when you are intentionally staying on the 0.11 line, and keep generated-app
targets explicit by checking the installed `solverforge-cli` output.

## What Changed

### Joined pairs can project retained scoring rows

Single-source projections still use named `Projection<A>` types with
`ProjectionSink` and `MAX_EMITS`. Cross joins now also support retained
scoring-only rows with the existing `.project(...)` verb:

```rust
type Streams = ConstraintFactory<Plan, HardSoftScore>;

Streams::new()
    .assignments()
    .join((
        Streams::new().capacities(),
        equal_bi(
            |assignment: &Assignment| assignment.bucket,
            |capacity: &Capacity| capacity.bucket,
        ),
    ))
    .project(|assignment: &Assignment, capacity: &Capacity| AssignmentCapacity {
        assignment_id: assignment.id,
        demand: assignment.demand,
        capacity: capacity.amount,
    })
    .penalize_hard_with(|row: &AssignmentCapacity| {
        HardSoftScore::of_hard((row.demand - row.capacity).max(0))
    })
    .named("Assignment capacity shortage");
```

The projected row is a scoring row, not a planning entity, fact, value range, or
move target. It exists because the scoring rule needs a joined shape that is
clearer than either source object alone.

### Projected scoring paths are clone-free

Projected outputs, projected self-join keys, and grouped collector values no
longer need to implement `Clone`. Retained projected state owns the row/key data
that scoring needs instead of cloning it through hot paths.

This is a runtime contract improvement, not a modeling change. Existing
single-source `.project(NamedProjection)` code keeps the same public shape.

### Projected self-joins keep coordinate-stable order

Projected rows are retained by source ownership and emit index, not by sparse
storage row IDs. Self-joins over projected rows therefore keep stable pair
orientation even when storage rows are reused after incremental updates.

### Constraint metadata borrows identity from the owner

Score analysis and lower-level scoring metadata preserve package-qualified
`ConstraintRef` identity without cloning the reference into public reporting
types. Package-qualified constraints still use `ConstraintRef::full_name()`
keys such as `package/name`; package-less constraints use the short name.

### Configuration controls are exported from `solverforge`

Since 0.11.1, application code can import the standard configuration controls
directly from the facade crate:

```rust
use solverforge::{
    AcceptorConfig, ConstructionHeuristicType, ConstructionObligation,
    EnvironmentMode, ForagerConfig, HardRegressionPolicyConfig,
    MoveSelectorConfig, MoveThreadCount, PhaseConfig, RecreateHeuristicType,
    SolverConfig, SolverConfigOverride, UnionSelectionOrder,
};
```

Apps can keep using `solverforge::SolverConfig::load(...)`,
`SolverConfig::from_toml_str(...)`, and `SolverConfig::from_yaml_str(...)`
without depending on `solverforge-config` just to name phase, selector,
acceptor, forager, or environment-mode types.

### `RecordingDirector` is exported from the facade

`RecordingDirector` is available from `solverforge` beside `Director` and
`ScoreDirector`:

```rust
use solverforge::{Director, RecordingDirector, ScoreDirector};
```

That matters for extension code that wraps a score director, records reversible
trial moves, and rolls them back without depending on the lower-level scoring
crate directly.

### Runtime crate publishing is workspace-only

The release workflow publishes SolverForge runtime workspace crates in
dependency order. The CLI remains its own repository and release line, so the
runtime release process no longer treats a CLI package as part of the
`solverforge` workspace publish sequence.

## Install And Scaffold Status

For direct Cargo projects:

```toml
solverforge = { version = "0.11.1", features = ["serde", "console"] }
```

If you write custom incremental constraints that need lower-level identities,
the companion workspace crates are also published at the same 0.11.x patch:

```toml
solverforge-core = "0.11.1"
```

For generated apps, confirm the installed CLI target:

```bash
solverforge --version
```

`solverforge-cli 2.0.4` reports:

```text
CLI version: 2.0.4
Scaffold runtime target: SolverForge crate target 0.11.1
Scaffold UI target: solverforge-ui 0.6.5
Scaffold maps target: solverforge-maps 2.1.4
Runtime source: crates.io: solverforge 0.11.1
UI source: crates.io: solverforge-ui 0.6.5
Maps source: crates.io: solverforge-maps 2.1.4
```

Generated apps created with `solverforge-cli 2.0.4` start on
`solverforge 0.11.1`. Move an older generated app to `solverforge 0.11.x` only
when you are deliberately upgrading that app's runtime target and validating the
generated code against the newer core crate.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.11.1` | 2026-05-05 | Exports configuration controls and `RecordingDirector` from the facade; keeps CLI scaffold target reporting explicit. |
| `0.11.0` | 2026-05-05 | Introduces clone-free projected scoring rows, joined-pair projection, projected self-join ordering, and borrowed constraint metadata. |

## Documentation Changes

At the time of this release, the docs tree was split so the 0.11.x source
surface was easier to scan:

- [Configuration](/docs/solverforge/solver/configuration/) documents the facade
  imports for `SolverConfig`, phase config, selector config, acceptor config,
  forager config, and overrides.
- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  covers single-source and joined-pair projection.
- [Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/)
  separates `if_exists`, `if_not_exists`, and `flatten_last` from the main
  constraint-stream page.
- [Scalar Move Selectors](/docs/solverforge/solver/scalar-move-selectors/),
  [List Move Selectors](/docs/solverforge/solver/list-move-selectors/), and
  [Composite Move Selectors](/docs/solverforge/solver/composite-move-selectors/)
  split the previous monolithic move-selector reference.
- [Crate & Runtime Map](/reference/crate-map/) lists configuration controls and
  `RecordingDirector` as facade-level exports.
- The CLI command reference now links to scaffold, generator, and operations
  command pages instead of forcing every command into one long section.
