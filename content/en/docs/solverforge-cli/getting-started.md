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

- Rust stable toolchain (1.80+)
- Cargo (included with Rust)

## Install the CLI

```bash
cargo install solverforge-cli
```

If you already installed it previously, update to the latest published crate:

```bash
cargo install solverforge-cli --force
```

Verify the installation:

```bash
solverforge --version
```

This shows the CLI version and the runtime/UI target versions baked into newly
scaffolded projects (currently targeting SolverForge 0.8.4, solverforge-ui 0.4.3,
and solverforge-maps 2.1.3).

## Create a New Project

The current scaffold command creates a neutral app shell:

```bash
solverforge new my-scheduler
cd my-scheduler
```

Options:
- `--skip-git` — Skip running `git init` and initial commit
- `--skip-readme` — Skip generating README.md

## Run the Local Server

```bash
solverforge server
```

Options:
- `--port <PORT>` — Port to bind (default: 7860)
- `--debug` — Run in debug mode (faster compilation, slower runtime)

Open `http://localhost:7860` in your browser.

## Grow the Domain

### Add Problem Facts

```bash
solverforge generate fact resource --field category:String --field load:i32
solverforge generate fact employee --field name:String --field skill_level:i32
```

Options:
- `--field "name:Type"` — Add additional fields (repeatable)
- `--force` — Overwrite if fact already exists
- `--pretend` — Preview changes without writing files

### Add Planning Entities

```bash
solverforge generate entity task --field label:String --field priority:i32
solverforge generate entity shift --planning-variable employee_idx --field start:String --field duration:i32
```

Options:
- `--planning-variable <FIELD>` — Add a planning variable field
- `--field "name:Type"` — Add additional fields (repeatable)
- `--force` — Overwrite if entity already exists
- `--pretend` — Preview changes without writing files

### Add Planning Variables to Existing Entities

```bash
solverforge generate variable resource_idx --entity Task --kind standard --range resources --allows-unassigned
solverforge generate variable stops --entity Route --kind list --elements visits
```

Options:
- `--entity <TYPE>` — Entity struct name (required)
- `--kind <standard|list>` — Variable kind (required)
- `--range <COLLECTION>` — Standard-variable value range collection
- `--elements <COLLECTION>` — List-variable element collection
- `--allows-unassigned` — Allow leaving the standard variable unassigned

### Add Constraints

```bash
# Unary constraint (single entity violations)
solverforge generate constraint max_hours --unary --hard

# Pair constraint (conflicting pairs)
solverforge generate constraint no_overlap --pair

# Join constraint (entity-fact mismatch)
solverforge generate constraint required_skill --join --hard

# Balance constraint
solverforge generate constraint fair_distribution --balance

# Reward constraint
solverforge generate constraint preferred_shift --reward
```

Options:
- `--hard` — Hard constraint (default, conflicts with --soft)
- `--soft` — Soft constraint (conflicts with --hard)
- `--unary` — Penalize matching entities
- `--pair` — Penalize conflicting pairs
- `--join` — Penalize entity-fact mismatch
- `--balance` — Balance assignments across entities
- `--reward` — Reward matching entities
- `--force` — Overwrite if constraint already exists
- `--pretend` — Preview changes without writing files

### Generate Demo Data

```bash
solverforge generate data
solverforge generate data --size large
solverforge generate data --mode stub
```

Options:
- `--mode <sample|stub>` — Data generation mode (default: sample)
- `--size <small|standard|large>` — Default dataset size

The `solverforge generate data` command rewrites the compiler-owned sample builders
in `src/generated/data_seed.rs`. The stable wrapper in `src/data/mod.rs` delegates
to that generated seed file by default, so the command can keep regenerating
sample data without clobbering user-owned entrypoints. Dataset size defaults are
persisted in `solverforge.app.toml`.

### Compound Scaffolding

Create entity, constraint, and paired twin entity in one command:

```bash
solverforge generate scaffold shift employee_idx:usize --entity --constraint no_overlap --pair
```

The first field becomes the planning variable. Remaining fields are extra entity
fields.

Options:
- `--entity` — Also generate a planning entity
- `--constraint <NAME>` — Also generate a constraint with this name
- `--pair` — Also generate a paired twin entity named `<name>_pair`
- `--force` — Overwrite if resources already exist
- `--pretend` — Preview changes without writing files

## Project Management Commands

### View Project Info

```bash
solverforge info
```

Shows a summary of entities, facts, constraints, and score type.

### Validate Project

```bash
solverforge check
```

Validates project structure and configuration.

### Run Tests

```bash
solverforge test
solverforge test -- --nocapture
solverforge test integration
```

Runs `cargo test` with optional passthrough arguments.

### List API Routes

```bash
solverforge routes
```

Lists HTTP routes defined in `src/api/`.

### Manage Solver Configuration

```bash
solverforge config show
solverforge config set termination.time_spent_seconds 60
solverforge config set termination.best_score_limit 0hard/0soft
```

### Generate Shell Completions

```bash
solverforge completions bash >> ~/.bashrc
solverforge completions zsh >> ~/.zshrc
solverforge completions fish > ~/.config/fish/completions/solverforge.fish
```

## Remove Resources

All destroy commands support `--yes` (or `-y`) to skip confirmation.

```bash
solverforge destroy entity task --yes
solverforge destroy constraint no_overlap --yes
solverforge destroy variable --entity Task resource_idx --yes
solverforge destroy fact employee --yes
solverforge destroy solution --yes
```

## Global Options

These options work with any command:

- `-q, --quiet` — Suppress all output except errors
- `-v, --verbose` — Show extra diagnostic output
- `--no-color` — Disable colored output (also respects `NO_COLOR` environment variable)

## Next Steps

- Continue with [Getting Started](/docs/getting-started/) for a broader onboarding map.
- Follow the [Employee Scheduling tutorial](/docs/getting-started/employee-scheduling-rust/)
  for a deeper domain-model walkthrough.
- Explore [SolverForge](/docs/solverforge/) API-focused documentation for
  modeling and constraints.
