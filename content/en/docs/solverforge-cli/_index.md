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
scaffolds a runnable project layout and provides a conventional local server
command so you can begin modeling quickly.

## What It Provides

- **Project scaffolding** via `solverforge new <name> ...`
- **Template selection** for assignment-style or sequence-style models
- **Local runtime** with `solverforge server`
- **CLI-first onboarding** that complements deeper Rust and domain tutorials

## Installation

```bash
cargo install solverforge-cli
```

## Minimal Workflow

```bash
solverforge new my-scheduler --standard
cd my-scheduler
solverforge server
```

Open `http://localhost:7860` after the server starts.

For sequence-heavy models, use the list template:

```bash
solverforge new my-router --list
```

## When To Use It

Use `solverforge-cli` when you want the fastest path from zero to a running
SolverForge app and plan to evolve the generated project with your own model,
constraints, and API surface.

## Sections

- **[Getting Started](getting-started/)** — Install the CLI, scaffold an app,
  and run the local server

## External References

- [GitHub repository](https://github.com/solverforge/solverforge-cli)
- [Crate on crates.io](https://crates.io/crates/solverforge-cli)
