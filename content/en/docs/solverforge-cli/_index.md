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

Update to the latest version:

```bash
cargo install solverforge-cli --force
```

## Version Information

Use `solverforge --version` to see:

- CLI version
- Scaffold runtime target (currently SolverForge crate target 0.8.5)
- Runtime source (crates.io: solverforge 0.8.5)
- UI source (crates.io: solverforge-ui 0.4.3)
- Maps source (crates.io: solverforge-maps 2.1.3)

## Minimal Workflow

```bash
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

Open `http://localhost:7860` after the server starts.

## Build Out the App

### Add Domain Elements

```bash
# Problem facts
solverforge generate fact resource --field category:String --field load:i32

# Planning entities
solverforge generate entity task --field label:String --field priority:i32

# Planning variables
solverforge generate variable resource_idx --entity Task --kind standard --range resources --allows-unassigned

# Or combine entity + variable in one command
solverforge generate entity shift --planning-variable employee_idx --field start:String --field duration:i32

# Constraints
solverforge generate constraint no_overlap --pair --hard
solverforge generate constraint max_hours --unary

# Solution (if not already present)
solverforge generate solution schedule --score HardSoftScore
```

### Compound Scaffolding

Scaffold entity, constraint, and paired twin in one command:

```bash
solverforge generate scaffold shift employee_idx:usize --entity --constraint no_overlap --pair
```

### Generate Demo Data

```bash
solverforge generate data
solverforge generate data --size large
solverforge generate data --mode stub
```

Dataset sizes: `small`, `standard`, `large`. Modes: `sample` (default), `stub`.

## Available Commands

### Project Commands

| Command | Description |
|---------|-------------|
| `solverforge new <name>` | Scaffold a new SolverForge project |
| `solverforge server` | Start the development server (default port 7860) |
| `solverforge info` | Show project summary: entities, facts, constraints, score type |
| `solverforge check` | Validate project structure and configuration |
| `solverforge test [args...]` | Run `cargo test` with optional passthrough arguments |
| `solverforge routes` | List HTTP routes defined in `src/api/` |

### Generate Commands

| Command | Description |
|---------|-------------|
| `solverforge generate constraint <name>` | Add a constraint skeleton to `src/constraints/` |
| `solverforge generate entity <name>` | Scaffold a planning entity in `src/domain/` |
| `solverforge generate fact <name>` | Scaffold a problem fact in `src/domain/` |
| `solverforge generate solution <name>` | Scaffold a planning solution in `src/domain/` |
| `solverforge generate variable <field>` | Add a planning variable field to an existing entity |
| `solverforge generate score <type>` | Change the score type in the existing solution |
| `solverforge generate data` | Regenerate compiler-owned demo data |
| `solverforge generate scaffold <name>` | Compound: entity + optional constraint + optional twin |

### Destroy Commands

| Command | Description |
|---------|-------------|
| `solverforge destroy solution` | Remove the planning solution struct |
| `solverforge destroy entity <name>` | Remove a planning entity |
| `solverforge destroy variable --entity <E> <field>` | Remove a variable from an entity |
| `solverforge destroy fact <name>` | Remove a problem fact |
| `solverforge destroy constraint <name>` | Remove a constraint |

### Configuration Commands

| Command | Description |
|---------|-------------|
| `solverforge config show` | Print the contents of `solver.toml` |
| `solverforge config set <key> <value>` | Set a key in `solver.toml` (e.g., `termination.time_spent_seconds 60`) |

### Utility Commands

| Command | Description |
|---------|-------------|
| `solverforge completions <shell>` | Generate shell completions (bash, zsh, fish) |

### Global Options

| Option | Description |
|--------|-------------|
| `-q, --quiet` | Suppress all output except errors |
| `-v, --verbose` | Show extra diagnostic output |
| `--no-color` | Disable colored output (also respects `NO_COLOR` env var) |

## Constraint Types

When generating constraints, choose the pattern that matches your logic:

| Flag | Pattern | Use Case |
|------|---------|----------|
| `--unary` | `for_each + filter + penalize` | Single entity violations |
| `--pair` | `for_each_unique_pair` | Conflicting pairs of entities |
| `--join` | `for_each + join` | Entity-fact mismatch |
| `--balance` | Balance assignments | Distribute work evenly |
| `--reward` | `for_each + filter + reward` | Reward matching entities |
| `--hard` | Hard constraint (default) | Must be satisfied |
| `--soft` | Soft constraint | Should be optimized |

## When To Use It

Use `solverforge-cli` when you want the fastest path from zero to a running
SolverForge app and plan to evolve the generated project with your own model,
constraints, and API surface.

The generated shell is intentionally neutral. Standard-variable, list-variable,
and mixed apps are shaped after scaffolding rather than chosen as separate starter
families.

## Sections

- **[Getting Started](getting-started/)** — Install the CLI, scaffold an app,
  run the local server, and grow the domain

## External References

- [GitHub repository](https://github.com/solverforge/solverforge-cli)
- [Crate on crates.io](https://crates.io/crates/solverforge-cli)
