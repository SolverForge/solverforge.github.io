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
This manual is aligned with `solverforge-cli` <strong>v1.1.3</strong>. Fresh
projects currently target `solverforge 0.9.0`, `solverforge-ui 0.5.1`, and
`solverforge-maps 2.1.3`. Run `solverforge --version` to confirm the exact
targets baked into the binary you have installed.
<% end %>

`solverforge-cli` is the default entry point for new SolverForge projects. It
creates one neutral app shell, then lets you grow that shell into a scalar,
list, or mixed planning application with generator commands and ordinary Rust
edits.

The CLI owns project bootstrap and code generation. The generated application
then uses:

- `solverforge` for domain modeling and solving
- `solverforge-ui` for the shipped frontend and retained-job lifecycle
- `solverforge-maps` for map and routing integration in generated projects

## What You Get

- A neutral scaffold that starts runnable instead of forcing a tutorial-shaped
  starter family
- A generated Axum backend with retained jobs, typed SSE events, snapshots,
  analysis, pause, resume, cancel, and delete flows
- Generator commands for facts, entities, variables, constraints, solution
  types, score types, and demo data
- A CLI-maintained app contract in `solverforge.app.toml`
- A frontend that composes shipped `solverforge-ui` assets rather than
  vendoring a template-specific asset pipeline
- A local development flow built around `solverforge server`, `solverforge
  info`, `solverforge check`, `solverforge routes`, and `solverforge test`

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

The generated shell is intentionally thin. It starts with a neutral `Plan`
solution, solver lifecycle routes, `solverforge-ui`-backed frontend assets, and
no domain-specific assumptions beyond the SolverForge runtime contract.

## When To Use It

Use `solverforge-cli` when you want the fastest path from zero to a running
SolverForge app and you want to shape the model incrementally instead of
starting from a fixed tutorial repository.

## Sections

- **[Getting Started](getting-started/)** - install the CLI, scaffold a project,
  run the server, and make the first model changes
- **[Project Anatomy](project-anatomy/)** - generated file layout, ownership
  boundaries, and managed markers
- **[Modeling & Generation](modeling-and-generation/)** - facts, entities,
  scalar variables, list variables, constraints, data, and destroy flows
- **[Configuration](configuration/)** - `solver.toml`,
  `solverforge.app.toml`, UI metadata, and scaffold target versioning
- **[Command Reference](command-reference/)** - complete command, flag, and
  example reference

## External References

- [GitHub repository](https://github.com/solverforge/solverforge-cli)
- [API documentation on docs.rs](https://docs.rs/solverforge-cli)
- [Crate on crates.io](https://crates.io/crates/solverforge-cli)
