---
title: Project Anatomy
description: >
  Generated file layout, ownership boundaries, managed markers, and advanced
  customization points in solverforge-cli projects.
weight: 2
---

# Project Anatomy

Fresh `solverforge-cli` projects are intentionally small, but they are not just
"hello world" shells. The default web scaffold already includes:

- an Axum backend
- retained solver-job routes and SSE
- a `solverforge-ui` frontend shell
- generator-managed modeling files
- compiler-owned demo data
- two configuration layers: `solver.toml` and `solverforge.app.toml`

## Top-Level Layout

A new neutral web shell looks like this:

```text
my-scheduler/
|- .gitignore
|- Cargo.toml
|- README.md
|- solver.toml
|- solverforge.app.toml
|- src/
|  |- api/
|  |- constraints/
|  |- data/
|  |- domain/
|  |- solver/
|  |- lib.rs
|  `- main.rs
`- static/
   |- app.js
   |- generated/ui-model.json
   |- index.html
   `- sf-config.json
```

## What Each Part Does

| Path | Purpose |
| ---- | ------- |
| `Cargo.toml` | Generated crate manifest pinned to the CLI's current runtime, UI, and maps targets |
| `solver.toml` | Solver search strategy and termination settings |
| `solverforge.app.toml` | CLI-maintained app metadata, model summary, demo defaults, and UI contract |
| `src/domain/` | Planning solution, facts, entities, and generator-managed insertion points |
| `src/constraints/mod.rs` | Constraint module declarations in the managed `constraint-modules` block, `mod assemble;`, and the `create_constraints` re-export; no code |
| `src/constraints/assemble.rs` | `create_constraints()`, whose managed `constraint-calls` block calls each module as `super::<id>::constraint()` |
| `src/constraints/<id>.rs` | One constraint per module, each exposing `pub fn constraint()` |
| `src/data/data_seed.rs` | Compiler-owned demo-data builder rewritten by `solverforge generate data` |
| `src/data/mod.rs` | Stable wrapper around the generated demo-data seed module |
| `src/api/` | Generated retained-job, demo-data, status, analysis, and SSE routes |
| `src/solver/` | Generated solver service wiring |
| `static/app.js` | Neutral frontend built on `solverforge-ui` primitives |
| `static/generated/ui-model.json` | Derived UI metadata generated from `solverforge.app.toml` |
| `static/sf-config.json` | Lightweight frontend config payload with app title and subtitle |

`solverforge new --shell api` keeps the Axum API and omits `static/`,
`solverforge-ui`, and `solverforge-maps`. `solverforge new --shell cli` emits a
command-line app without Axum, static frontend assets, UI, or maps
dependencies. `solverforge new --shell mcp` emits an MCP server without the
frontend, UI, or maps dependencies. Only the web shell generates `static/`,
`static/generated/ui-model.json`, and `ui_source`; the other shells keep that
boundary intact through later `generate` and `destroy` commands.

## Ownership Boundaries

The most important rule is that not every generated file should be treated the
same way.

| Path | Primary owner | Edit guidance |
| ---- | ------------- | ------------- |
| `solver.toml` | You | Safe to edit directly or through `solverforge config set` |
| `src/constraints/<id>.rs` | You | Generated skeletons are starting points; replace the placeholders with real logic |
| `src/constraints/mod.rs` and `assemble.rs` | Shared | `generate constraint` and `destroy constraint` rewrite their managed blocks; keep the markers intact |
| `static/app.js` | You | Safe to customize once the shell exists |
| `src/data/mod.rs` | Shared | Keep it if you want to continue delegating to generated demo seeds |
| `src/data/data_seed.rs` | CLI | Rewritten by `solverforge generate data`; do not hand-edit if you plan to regenerate |
| `static/generated/ui-model.json` | CLI | Derived file; do not hand-edit |
| `solverforge.app.toml` | Shared, mostly CLI-owned | Treat structural model sections as generated metadata |
| `src/domain/plan.rs` and generated entity files | Shared | Safe to extend, but keep the managed markers intact |
| `solver.toml` generated resource region | CLI | Keep the `# @solverforge:begin solver-config` region intact when model-resource generators own it |

## Managed Markers

The CLI keeps future generation and destroy operations working by patching
specific managed blocks instead of replacing entire files. Those blocks look
like this:

```rust
// @solverforge:begin solution-collections
// @solverforge:end solution-collections
```

You will also see markers like:

- `entity-variables`
- `entity-variable-init`
- `solution-imports`
- `solution-constructor-params`
- `solution-constructor-init`
- `domain-exports`
- `constraint-modules`
- `constraint-calls`

Do not delete or duplicate those markers if you want the CLI to keep patching
the file correctly.

`constraint-modules` lives in `src/constraints/mod.rs` and holds the `mod`
lines in rustfmt's sorted order. `constraint-calls` lives in
`src/constraints/assemble.rs` and keeps insertion order, because it is the
order in which the constraint set evaluates. Every module in one block needs
its call in the other. A helper module such as `mod shared;` or
`#[cfg(test)] mod tests;` goes outside the `constraint-modules` block, so it is
not counted as a constraint.

## Module Roots Hold Declarations Only

Every `mod.rs` and `lib.rs` under `src/` contains only module declarations,
`use` items, and, in `src/domain/mod.rs`, the `planning_model!` manifest.
`solverforge check` rejects a module root that holds a function, type, impl,
constant, static, macro definition, inline `mod name { ... }` body, or an inner
attribute other than documentation, and `generate constraint` and
`destroy constraint` refuse to edit a `src/constraints/mod.rs` that holds any of
them. Put that code in its own file and declare it with `mod`.

After the [Getting Started](/docs/solverforge-cli/getting-started/) project
runs `generate constraint task_assigned` and then
`generate constraint balanced_duration`, the two files read as follows, with
the leading doc comments left out:

```rust
// src/constraints/mod.rs
// @solverforge:begin constraint-modules
mod balanced_duration;
mod task_assigned;
// @solverforge:end constraint-modules

mod assemble;

pub use assemble::create_constraints;
```

```rust
// src/constraints/assemble.rs
use crate::domain::Plan;
use solverforge::prelude::*;

/// Builds the constraint set the solver scores every solution against.
pub fn create_constraints() -> impl ConstraintSet<Plan, HardSoftScore> {
    // @solverforge:begin constraint-calls
    (
        super::task_assigned::constraint(),
        super::balanced_duration::constraint(),
    )
    // @solverforge:end constraint-calls
}
```

## The Neutral Shell

Before you add any domain content, the neutral shell already includes:

- a `Plan` planning solution in `src/domain/plan.rs`
- retained lifecycle API routes in `src/api/routes.rs`
- lifecycle-aware frontend wiring in `static/app.js`
- demo data endpoints backed by `src/data/mod.rs`
- typed UI metadata derived from `solverforge.app.toml`

That is why the project can boot immediately even before you add facts or
entities.

## Generated API Surface

After scaffolding a web or API shell, `solverforge routes` already lists
endpoints for:

- health and app info
- demo data listing and retrieval
- retained job creation and status
- exact snapshot retrieval
- score analysis by snapshot revision
- pause, resume, and cancel
- terminal retained-job deletion with `DELETE /jobs/{id}`
- SSE event streaming

Those routes live in `src/api/` and are part of the generated app shell, not an
optional add-on.

### Telemetry Contract

`src/api/telemetry.rs` projects the runtime's compact telemetry for status,
snapshots, and typed SSE. The `phases` array contains every started phase in
execution order; it is not a single current-phase object. Run totals and each
phase expose `movesSpeculative`. Detailed candidate traces remain separate and
label discarded ahead-of-decision work as `discarded_speculative`. Selector
and move breakdowns do not invent their own speculative counters.

## `src/data/mod.rs` vs `src/data/data_seed.rs`

The scaffold intentionally splits demo-data ownership:

- `src/data/data_seed.rs` is generator-owned
- `src/data/mod.rs` is the stable user-facing wrapper

If you keep the wrapper in place, you can regenerate sample datasets without
rewiring the rest of the app. Replace the wrapper only if you want to stop
using the generated seed flow entirely.

## Frontend Assets

The scaffold frontend does not vendor a separate npm app. Instead, it:

- serves `static/index.html`
- boots the neutral UI from `static/app.js`
- consumes `static/sf-config.json`
- consumes `static/generated/ui-model.json`
- mounts the shipped `solverforge-ui` assets

This keeps the default generated project thin while still shipping a usable UI.
API, CLI, and MCP shells deliberately omit these frontend files.

## Advanced Customization

The CLI currently supports local template overrides for three generator entry
points:

- `.solverforge/templates/entity.rs.tmpl`
- `.solverforge/templates/fact.rs.tmpl`
- `.solverforge/templates/solution.rs.tmpl`

Those overrides are applied before the built-in generator template is used.
An override must keep the managed block markers of the built-in template it
replaces; the CLI refuses a template that drops or duplicates them.
They are for advanced teams that want opinionated internal defaults while still
using the stock CLI workflow.

## Practical Rule of Thumb

Treat these as the primary modeling source:

- `src/domain/`
- `src/constraints/`
- `solver.toml`

Treat these as synchronized metadata or generated views:

- `solverforge.app.toml`
- `static/generated/ui-model.json`
- `src/data/data_seed.rs`
