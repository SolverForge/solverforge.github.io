---
title: Getting Started
description: >
  Install solverforge-cli, generate a project, and run the default local
  development server.
weight: 1
---

# Getting Started with solverforge-cli

This guide covers the default onboarding path:

1. install `solverforge-cli`
2. scaffold a project
3. run the local server
4. iterate from a working baseline

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

Use the standard template for assignment-style scheduling problems:

```bash
solverforge new my-scheduler --standard
cd my-scheduler
```

Use the list template for routing or sequencing models:

```bash
solverforge new my-router --list
cd my-router
```

## Run the Local Server

```bash
solverforge server
```

Open `http://localhost:7860` in your browser.

## Next Steps

- Continue with [Getting Started](/docs/getting-started/) for additional
  walkthroughs.
- Follow the [Employee Scheduling tutorial](/docs/getting-started/employee-scheduling-rust/)
  for a full Rust domain-model deep dive.
- Explore [SolverForge](/docs/solverforge/) API-focused documentation for
  modeling and constraints.
