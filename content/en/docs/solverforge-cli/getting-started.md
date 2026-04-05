---
title: Getting Started
description: >
  Install solverforge-cli, scaffold a neutral app shell, and run the default
  local development server.
weight: 1
---

# Getting Started with solverforge-cli

This guide covers the current onboarding path:

1. install `solverforge-cli`
2. scaffold a project shell
3. run the local server
4. grow the domain with generator commands

## Prerequisites

- Rust stable toolchain
- Cargo (included with Rust)

## Install the CLI

```bash
cargo install solverforge-cli
```

If you already installed it previously, update to the latest published crate:

```bash
cargo install solverforge-cli --force
```

## Create a New Project

The current scaffold command creates a neutral app shell:

```bash
solverforge new my-scheduler
cd my-scheduler
```

Use `solverforge --version` to see the CLI version and the runtime/UI target
versions baked into newly scaffolded projects.

## Run the Local Server

```bash
solverforge server
```

Open `http://localhost:7860` in your browser.

## Grow the Domain

Add facts, entities, variables, and sample data incrementally:

```bash
solverforge generate fact resource --field category:String --field load:i32
solverforge generate entity task --field label:String --field priority:i32
solverforge generate variable resource_idx --entity Task --kind standard --range resources --allows-unassigned
solverforge generate data --size large
```

The scaffold is intentionally neutral. Standard-variable, list-variable, and mixed
modeling shapes are introduced later through generation and `solverforge.app.toml`.

## Next Steps

- Continue with [Getting Started](/docs/getting-started/) for a broader onboarding map.
- Follow the [Employee Scheduling tutorial](/docs/getting-started/employee-scheduling-rust/)
  for a deeper domain-model walkthrough.
- Explore [SolverForge](/docs/solverforge/) API-focused documentation for
  modeling and constraints.
