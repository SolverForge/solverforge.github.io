---
title: 'The Current SolverForge Architecture: CLI-First, Rust-Native, Explicit'
date: 2026-04-23
draft: false
tags: [rust, cli, architecture]
description: >
  SolverForge's current architecture is CLI-first without being opaque: one
  neutral project shell, generator-driven model growth, scalar and list planning
  variables, retained jobs, and explicit Rust code.
---

SolverForge is no longer primarily a collection of quickstarts, roadmap essays,
or separate starter families. The current architecture is simpler and stricter:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

`solverforge-cli` is the default entry point. It creates one neutral application
shell, then grows that shell with generators and ordinary Rust edits. Fresh
projects carry scaffold target metadata from the installed CLI binary; run
`solverforge --version` to see the exact runtime, UI, and maps targets your
binary will generate.

That is the product shape to understand first.

## The CLI Is The Front Door

The CLI owns project bootstrap and project maintenance:

- `solverforge new` creates a runnable app shell.
- `solverforge generate` adds domain facts, planning entities, planning
  variables, constraints, scores, solution types, demo data, and compound
  scaffold slices.
- `solverforge destroy` removes generated resources from managed regions.
- `solverforge server` runs the generated application locally.
- `solverforge info`, `solverforge check`, `solverforge routes`, and
  `solverforge test` inspect and validate the project.
- `solverforge config` manages `solver.toml`.
- `solverforge completions` emits shell completions.

The important part is what `solverforge new` does not ask.

It does not ask whether this is a hospital scheduling app, a vehicle routing
app, a warehouse app, or a manufacturing app. It also does not expose starter
flags such as `--scalar`, `--list`, or `--mixed`.

The generated project starts neutral. The domain becomes concrete after
scaffolding.

```bash
solverforge generate fact employee --field skill:String
solverforge generate entity shift --field starts_at:String --field ends_at:String
solverforge generate variable employee_idx \
  --entity Shift \
  --kind scalar \
  --range employees \
  --allows-unassigned
solverforge generate constraint no_overlap --pair --hard
solverforge generate data --size standard
```

That workflow is intentional. New projects should begin from a small runnable
application, not from a copied demo that has to be deleted back into shape.

## Scalar And List Are The Planning Shapes

Current SolverForge uses two public planning-variable families:

- `scalar` for a field that chooses one value from a range, optionally allowing
  `None` when the domain permits unassigned work.
- `list` for an ordered collection of elements, as in routing, sequencing, and
  list-assignment problems.

Those are the words the CLI accepts:

```bash
solverforge generate variable resource_idx --entity Task --kind scalar --range resources
solverforge generate variable stops --entity Route --kind list --elements visits
```

`standard` is not a variable kind. It can appear as a demo data size label, as
in `solverforge generate data --size standard`, but it is not the opposite of
`list` and it is not a current modeling term.

This matters because older SolverForge writing used different model-shape names
while the architecture was still moving. Current documentation should say
`scalar`, `list`, or `mixed` when it describes model shape.

## The Generated App Is Explicit Rust

SolverForge uses generation to remove repetition, not to hide the application.

A generated project contains normal Rust modules for:

- domain types
- constraints
- demo data
- solver configuration
- HTTP routes
- retained solve jobs
- frontend metadata and static assets

The CLI maintains generated regions where it can safely update code. User-owned
Rust stays visible. The generated app is not a black box and it is not a runtime
DSL interpreter.

That design matches the solver core. SolverForge's runtime is Rust-native and
type-preserving. The hot paths stay compiled as concrete Rust code, while macros
and generators provide the repetitive structure around domain metadata,
constraint streams, value ranges, and app wiring.

## The Runtime Is Retained

The current generated app is built around retained solve jobs rather than a
single blocking request.

At the runtime layer, `SolverManager` owns jobs, snapshots, events, analysis,
and lifecycle control. At the generated-app layer, the scaffold exposes that as
ordinary application behavior:

- start a solve
- stream progress over SSE
- inspect the latest or historical snapshot
- analyze score breakdowns
- pause, resume, cancel, or delete a job
- keep the UI synchronized with typed solve events

In the current scaffold, that surface is visible as ordinary HTTP routes:

```text
POST   /jobs
GET    /jobs/{id}
DELETE /jobs/{id}
GET    /jobs/{id}/status
GET    /jobs/{id}/snapshot
GET    /jobs/{id}/analysis
POST   /jobs/{id}/pause
POST   /jobs/{id}/resume
POST   /jobs/{id}/cancel
GET    /jobs/{id}/events
```

This is the current shape of SolverForge as an application framework. The CLI
does not just create a Rust library crate with a `main.rs`; it creates a
running service boundary around the retained solver lifecycle.

## The UI Is Shipped Infrastructure, Not A Copied Demo

Older quickstart repositories carried their own frontend code because examples
were the primary onboarding surface. Current CLI-generated apps instead compose
the shipped SolverForge frontend assets and metadata contract.

That keeps generic UI behavior in `solverforge-ui` and keeps generated projects
focused on the planning domain. The app still has concrete files, routes, and
static assets, but it does not vendor a separate tutorial frontend stack as the
starting point for every user.

The result is a clearer division of ownership:

- SolverForge owns reusable runtime, UI, and generator machinery.
- The generated app owns domain code and project configuration.
- The developer owns the planning model, constraints, data shape, and solver
  tuning.

## Quickstarts Are References, Not The Default Start

Worked examples still matter. A complete scheduling or routing example is useful
when you want to study modeling patterns, constraint structure, or UI behavior in
a real domain.

But quickstarts are no longer the default starting point for a new project. The
default start is:

```bash
solverforge new my-project
```

Then generators and Rust edits shape the app. Tutorials and examples sit beside
that workflow as references.

This distinction prevents a common onboarding failure: cloning an example,
deleting most of it, and trying to guess which files were essential framework
structure and which files were only demo residue.

## What Older Articles May Get Wrong

Some older SolverForge articles are still useful as historical context, but they
should not be read as the current architecture.

If an article says the CLI is only a later direction, that is stale. The CLI is
the default entry point.

If an article says users choose a problem class or preset up front, that
is stale. `solverforge new` creates one neutral shell.

If an article uses an older non-list model-shape name, that is stale. The
current term is `scalar`.

If an article frames SolverForge mainly as broad positioning, read that as old
positioning, not as the product contract. The current contract is more concrete:
a Rust-native solver runtime plus a CLI that creates and maintains explicit
SolverForge applications.

## The Current Mental Model

The shortest accurate description is this:

SolverForge is a Rust constraint-solving runtime with a CLI-first application
workflow. The CLI creates one neutral app shell. Generators add scalar and list
planning models. The generated service exposes retained solve jobs, SSE
progress, snapshots, analysis, and UI integration. The code remains explicit
Rust.

That is the architecture users should start from now.

## Next Steps

- [Install the CLI](/docs/solverforge-cli/getting-started/)
- [Continue with the Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
- [Read the complete CLI command reference](/docs/solverforge-cli/command-reference/)
- [Review generated project anatomy](/docs/solverforge-cli/project-anatomy/)
- [Study the SolverForge runtime overview](/docs/overview/)
