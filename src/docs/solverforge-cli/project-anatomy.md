---
title: Project Anatomy
description: >
  Generated file layout, ownership boundaries, managed markers, and advanced
  customization points in solverforge-cli projects.
weight: 2
---

# Project Anatomy

Fresh `solverforge-cli` projects are intentionally small, but they are not just
"hello world" shells. The scaffold already includes:

- an Axum backend
- retained solver-job routes and SSE
- a `solverforge-ui` frontend shell
- generator-managed modeling files
- compiler-owned demo data
- two configuration layers: `solver.toml` and `solverforge.app.toml`

## Top-Level Layout

A new neutral shell looks like this:

```text
my-scheduler/
|- Cargo.toml
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
| `src/constraints/` | Constraint modules plus the shared `create_constraints()` registry |
| `src/data/data_seed.rs` | Compiler-owned demo-data builder rewritten by `solverforge generate data` |
| `src/data/mod.rs` | Stable wrapper around the generated demo-data seed module |
| `src/api/` | Generated retained-job, demo-data, status, analysis, and SSE routes |
| `src/solver/` | Generated solver service wiring |
| `static/app.js` | Neutral frontend built on `solverforge-ui` primitives |
| `static/generated/ui-model.json` | Derived UI metadata generated from `solverforge.app.toml` |
| `static/sf-config.json` | Frontend config payload with title, collections, and constraints |

## Ownership Boundaries

The most important rule is that not every generated file should be treated the
same way.

| Path | Primary owner | Edit guidance |
| ---- | ------------- | ------------- |
| `solver.toml` | You | Safe to edit directly or through `solverforge config set` |
| `src/constraints/*.rs` | You | Generated skeletons are starting points; replace TODOs with real logic |
| `static/app.js` | You | Safe to customize once the shell exists |
| `src/data/mod.rs` | Shared | Keep it if you want to continue delegating to generated demo seeds |
| `src/data/data_seed.rs` | CLI | Rewritten by `solverforge generate data`; do not hand-edit if you plan to regenerate |
| `static/generated/ui-model.json` | CLI | Derived file; do not hand-edit |
| `solverforge.app.toml` | Shared, mostly CLI-owned | Treat structural model sections as generated metadata |
| `src/domain/plan.rs` and generated entity files | Shared | Safe to extend, but keep the managed markers intact |

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

After scaffolding, `solverforge routes` already lists endpoints for:

- health and app info
- demo data listing and retrieval
- retained job creation and status
- exact snapshot retrieval
- score analysis by snapshot revision
- pause, resume, and cancel
- SSE event streaming

Those routes live in `src/api/` and are part of the generated app shell, not an
optional add-on.

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

## Advanced Customization

The CLI currently supports local template overrides for three generator entry
points:

- `.solverforge/templates/entity.rs.tmpl`
- `.solverforge/templates/fact.rs.tmpl`
- `.solverforge/templates/solution.rs.tmpl`

Those overrides are applied before the built-in generator template is used.
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
