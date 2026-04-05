---
title: 'solverforge-cli'
linkTitle: 'solverforge-cli'
icon: fa-solid fa-terminal
weight: 9
description: >
  Default onboarding CLI for scaffolding, running, and iterating on SolverForge
  applications.
---

`solverforge-cli` is the default way to start a new SolverForge application. It
scaffolds a runnable neutral app shell and provides generator commands so you can
shape the domain incrementally.

## What It Provides

- **Project scaffolding** via `solverforge new <name>`
- **Local runtime** with `solverforge server`
- **Domain growth** through `solverforge generate ...`
- **Generator-owned app metadata** in `solverforge.app.toml`
- **CLI-first onboarding** that complements deeper Rust and domain tutorials

## Installation

```bash
cargo install solverforge-cli
```

## Minimal Workflow

```bash
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

Open `http://localhost:7860` after the server starts.

## Build Out the App

```bash
solverforge generate fact resource --field category:String --field load:i32
solverforge generate entity task --field label:String --field priority:i32
solverforge generate variable resource_idx --entity Task --kind standard --range resources --allows-unassigned
solverforge generate data --size large
```

The generated shell is intentionally neutral. Standard-variable, list-variable,
and mixed apps are shaped after scaffolding rather than chosen as separate starter
families.

## When To Use It

Use `solverforge-cli` when you want the fastest path from zero to a running
SolverForge app and plan to evolve the generated project with your own model,
constraints, and API surface.

## Sections

- **[Getting Started](getting-started/)** — Install the CLI, scaffold an app,
  run the local server, and grow the domain

## External References

- [GitHub repository](https://github.com/solverforge/solverforge-cli)
- [Crate on crates.io](https://crates.io/crates/solverforge-cli)
