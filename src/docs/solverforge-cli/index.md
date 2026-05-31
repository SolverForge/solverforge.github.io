---
title: 'solverforge-cli'
linkTitle: 'solverforge-cli'
icon: fa-solid fa-terminal
weight: 9
description: >
  Complete manual for scaffolding, growing, and operating SolverForge
  applications with solverforge-cli.
---

<h1>solverforge-cli</h1>

<%= render Ui::Callout.new do %>
This manual documents the current `solverforge-cli` interface. Fresh projects
use the scaffold targets baked into the binary you have installed; run
`solverforge --version` to confirm the exact runtime, UI, and maps targets.
<% end %>

`solverforge-cli` is the default entry point for new SolverForge projects. It
creates a neutral `web`, `api`, or `cli` shell, then lets you grow that shell
with scalar and list planning variables, or both in one app, using generator
commands and ordinary Rust edits.

The CLI owns project bootstrap and code generation. The generated application
then uses:

- `solverforge` for domain modeling and solving
- `solverforge-ui` for the shipped frontend in web-shell projects
- `solverforge-maps` for map and routing integration in web-shell projects

## Mental Model

Think of the CLI as a project shaper, not as a separate modeling language.

| Layer | Owner | What changes there |
| ----- | ----- | ------------------ |
| Scaffold shell | `solverforge new` | Web, API, or CLI shell, config files, and app metadata |
| Domain model | CLI generators plus Rust edits | facts, entities, scalar variables, list variables, solution type |
| Constraint logic | generated skeletons, then user Rust | real hard and soft scoring rules |
| Runtime search | `solver.toml` | phases, acceptors, selectors, termination, candidate limits |
| App metadata | CLI synchronization | `solverforge.app.toml` and, for web shells, `static/generated/ui-model.json` |

The generated shell is intentionally neutral. You do not choose `scalar`,
`list`, or `mixed` at project creation time. You add scalar and list planning
variables as the domain earns them, and the app metadata follows the Rust model.

## What You Get

- A neutral scaffold that starts runnable instead of forcing a tutorial-shaped
  problem-class choice
- `web`, `api`, and `cli` generated shells selected by `solverforge new --shell`
- A generated Axum backend for web/API shells with retained jobs, typed SSE
  events, snapshots, analysis, pause, resume, cancel, and delete flows
- Generator commands for facts, entities, variables, constraints, solution
  types, score types, scalar groups, conflict repairs, and demo data
- A CLI-maintained app contract in `solverforge.app.toml`
- A frontend that composes shipped `solverforge-ui` assets rather than
  vendoring a template-specific asset pipeline
- A local development flow built around `solverforge server`, `solverforge
  info`, `solverforge check`, `solverforge routes`, and `solverforge test`

## Daily Loop

Use this loop while shaping a generated app:

```bash
solverforge info
solverforge generate fact employee --field skill:String
solverforge generate entity shift --field starts_at:String --field ends_at:String
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees --allows-unassigned
solverforge generate constraint no_overlap --pair --hard
solverforge generate conflict-repair no_overlap --provider repair_no_overlap --skip-solver-config
solverforge generate data --size standard
solverforge check
solverforge test
solverforge server --debug
```

After each generator step, inspect the Rust files it touched. Generated
constraint skeletons are deliberately unfinished; replace placeholder logic
before treating a solve result as meaningful.

## Installation

```bash
cargo install solverforge-cli
```

Update an existing install:

```bash
cargo install solverforge-cli --force
```

Install from a local checkout when you are working on the CLI itself:

```bash
cd solverforge-cli
cargo install --path .
```

Use `solverforge --version` to see:

- the CLI version
- the scaffold runtime target
- the scaffold UI target
- the scaffold maps target
- the exact runtime, UI, and maps sources used by newly generated projects

## Default Workflow

```bash
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

Open `http://localhost:7860` after the server starts.

Then expand the model:

```bash
solverforge generate fact resource --field category:String --field load:i32
solverforge generate entity task --field label:String --field priority:i32
solverforge generate variable resource_idx --entity Task --kind scalar --range resources --allows-unassigned
solverforge generate constraint no_overlap --pair --hard
solverforge generate data --size large
```

The default web shell is intentionally thin. It starts with a neutral `Plan`
solution, solver lifecycle routes, `solverforge-ui`-backed frontend assets, and
no domain-specific assumptions beyond the SolverForge runtime contract.

## When To Use It

Use `solverforge-cli` when you want the fastest path from zero to a running
SolverForge app and you want to shape the model incrementally instead of
starting from a fixed tutorial repository.

Use the long-form use cases after you understand the generic shell. They show
complete app work, data generation, frontend decisions, and deployment shape;
they are not replacements for the CLI-first project model.

## Boundaries

The CLI keeps generated structure coherent, but it does not decide the planning
model for you.

- It scaffolds facts, entities, variables, constraints, scalar groups, conflict
  repairs, demo data, and metadata.
- It keeps managed blocks and `solverforge.app.toml` synchronized.
- It does not infer business rules from field names.
- It does not make generated constraint TODOs correct.
- It does not replace runtime-level `solver.toml` tuning when a model needs a
  different construction, selector, acceptor, or termination policy.

## Sections

- **[Getting Started](/docs/solverforge-cli/getting-started/)** - install the CLI, scaffold a project,
  run the server, and make the first model changes
- **[Project Anatomy](/docs/solverforge-cli/project-anatomy/)** - generated file layout, ownership
  boundaries, and managed markers
- **[Modeling & Generation](/docs/solverforge-cli/modeling-and-generation/)** - facts, entities,
  scalar variables, list variables, constraints, data, and destroy flows
- **[Configuration](/docs/solverforge-cli/configuration/)** - `solver.toml`,
  `solverforge.app.toml`, UI metadata, and scaffold target versioning
- **[Command Reference](/docs/solverforge-cli/command-reference/)** - command groups, version output,
  global options, and focused command-reference subsections

## External References

- [GitHub repository](https://github.com/solverforge/solverforge-cli)
- [API documentation on docs.rs](https://docs.rs/solverforge-cli)
- [Crate on crates.io](https://crates.io/crates/solverforge-cli)
