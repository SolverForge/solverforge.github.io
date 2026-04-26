---
title: Getting Started
description: >
  Install solverforge-cli, scaffold a neutral app shell, and take the first
  generated project from empty shell to real model edits.
weight: 1
---

# Getting Started with solverforge-cli

This guide walks the default CLI-first onboarding path:

1. install the CLI
2. verify the scaffold targets baked into your binary
3. scaffold a fresh project shell
4. boot the generated backend and frontend
5. grow the domain with the first generator commands
6. inspect and validate the generated application

If you want a concrete app after that generic shell, continue with the
[SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
or the
[SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/).

## Prerequisites

- Rust stable `1.80+` to build the CLI itself
- The Rust toolchain required by the scaffolded runtime target reported by
  `solverforge --version`
- Cargo
- A working C toolchain for Rust dependencies on your platform

The CLI crate itself declares `rust-version = "1.80"`. Generated applications
compile against the scaffolded SolverForge crate targets reported by
`solverforge --version`; use the runtime crate metadata as the source of truth
for the generated app's Rust version requirement.

## Install or Update the CLI

```bash
cargo install solverforge-cli
```

Update an existing install:

```bash
cargo install solverforge-cli --force
```

Install from a checkout when you are iterating on the CLI itself:

```bash
cd solverforge-cli
cargo install --path .
```

## Verify the Installed Targets

The CLI version is only one part of what matters. The binary also carries the
current scaffold targets for the runtime, UI, and maps crates.

```bash
solverforge --version
```

The output includes:

- CLI version
- scaffold runtime target
- scaffold UI target
- scaffold maps target
- explicit source labels for each dependency line used in new projects

## Create a New Project

The `new` command always creates a neutral shell:

```bash
solverforge new my-scheduler
cd my-scheduler
```

Useful options:

- `--skip-git` - do not run `git init` or create the initial commit
- `--skip-readme` - do not generate `README.md`

Fresh output includes a short "next steps" block and reminds you that the
generated shell already contains:

- one neutral app shell for scalar and list modeling
- retained lifecycle routes and UI wiring
- typed SSE events
- `solverforge.app.toml` as the scaffold contract
- `solver.toml` as the solver search configuration layer

## Run the Local Server

```bash
solverforge server
```

By default, `solverforge server` runs the generated project in release mode via
`cargo run --release`. That makes first boot slower, but it keeps the default
behavior close to the production runtime path.

Useful options:

- `--port <PORT>` - bind a different port instead of the default `7860`
- `--debug` - run the generated app in debug mode for faster local iteration

Open `http://localhost:7860` in your browser.

The generated project serves:

- the `solverforge-ui` asset bundle
- a neutral frontend in `static/app.js`
- retained job routes under `/jobs/*`
- demo data endpoints under `/demo-data/*`

## Inspect the Scaffold Before You Change It

Right after scaffolding, these commands are useful:

```bash
solverforge info
solverforge check
solverforge routes
```

`solverforge info` summarizes the current planning solution, facts, entities,
constraints, and solver-owned fields. `solverforge check` validates the project
structure. `solverforge routes` lists the HTTP routes defined in `src/api/`.

In a brand-new shell, the generated route surface already includes health,
info, demo data, retained job lifecycle, snapshot analysis, pause, resume,
cancel, and SSE events.

## Grow the Domain

The normal build-out flow is:

1. add facts
2. add entities
3. add scalar or list variables
4. add constraints
5. regenerate demo data
6. replace placeholder constraint logic with real domain rules

### Add Problem Facts

```bash
solverforge generate fact resource --field category:String --field load:i32
solverforge generate fact employee --field name:String --field skill_level:i32
```

This creates `src/domain/<fact>.rs`, exports the new type from
`src/domain/mod.rs`, patches the planning solution collections, and syncs
`solverforge.app.toml`.

### Add Planning Entities

```bash
solverforge generate entity task --field label:String --field priority:i32
solverforge generate entity shift --planning-variable employee_idx --field start:String --field duration:i32
```

`--planning-variable` lets you create the entity and its first scalar planning
variable in one step. If you omit it, the entity starts with no solvable field
yet and `solverforge check` will warn until you add one.

### Add Planning Variables to Existing Entities

```bash
solverforge generate variable resource_idx --entity Task --kind scalar --range resources --allows-unassigned
solverforge generate variable stops --entity Route --kind list --elements visits
```

Use `scalar` for single-value assignment variables and `list` for sequence
variables. The only valid `--kind` values are `scalar` and `list`; `standard` is
only the default demo data size label.

Scalar example:

```bash
solverforge generate variable resource_idx \
  --entity Task \
  --kind scalar \
  --range resources \
  --allows-unassigned
```

List example:

```bash
solverforge generate variable stops \
  --entity Route \
  --kind list \
  --elements visits
```

### Add Constraints

```bash
# Unary constraint: penalize one entity at a time
solverforge generate constraint max_hours --unary --hard

# Pair constraint: compare pairs of entities
solverforge generate constraint no_overlap --pair

# Join constraint: entity-fact mismatch
solverforge generate constraint required_skill --join --hard

# Balance assignments
solverforge generate constraint fair_distribution --balance

# Reward preferred states
solverforge generate constraint preferred_shift --reward
```

Constraint generation writes a skeleton into `src/constraints/` and updates
`src/constraints/mod.rs`. Generated skeletons include placeholder TODOs, and
pair templates intentionally panic inside the placeholder filter until you
replace them with real domain logic.

### Generate Demo Data

```bash
solverforge generate data
solverforge generate data --size large
solverforge generate data --mode stub
```

The `solverforge generate data` command rewrites the compiler-owned sample
builders in `src/data/data_seed.rs`. The stable wrapper in `src/data/mod.rs`
delegates to that generated seed file by default, so the command can keep
regenerating sample data without clobbering user-owned entrypoints. Dataset size
defaults are persisted in `solverforge.app.toml`.

`sample` mode generates generic deterministic values. `stub` mode keeps the
shape but minimizes content so you can take over manually.

## Project Management Commands

### View Project Summary

```bash
solverforge info
```

Shows a summary of entities, facts, constraints, and score type.

### Validate Project

```bash
solverforge check
```

This validates the structure of `src/domain/`, `src/constraints/`, and
`solver.toml`. It warns when an entity exists but still has no scalar or list
planning variables.

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

This parses `src/api/routes.rs`, `src/api/mod.rs`, or `src/api.rs` and lists the
generated routes. It is a quick way to verify whether your app still exposes the
retained lifecycle and demo data surface you expect.

### Manage Solver Configuration

```bash
solverforge config show
solverforge config set termination.seconds_spent_limit 60
```

### Generate Shell Completions

```bash
solverforge completions bash >> ~/.bashrc
solverforge completions zsh >> ~/.zshrc
solverforge completions fish > ~/.config/fish/completions/solverforge.fish
```

## Remove Resources

All destroy commands support `--yes` (or `-y`) to skip confirmation. Place it on
the `destroy` command before the resource subcommand.

```bash
solverforge destroy --yes entity task
solverforge destroy --yes constraint no_overlap
solverforge destroy --yes variable --entity Task resource_idx
solverforge destroy --yes fact employee
solverforge destroy --yes solution
```

## Global Options

These options work with any command:

- `-q, --quiet` - suppress all output except errors
- `-v, --verbose` - show extra diagnostic output
- `--no-color` - disable colored output (also respects `NO_COLOR` environment
  variable)

## Next Steps

- Read [Project Anatomy](../project-anatomy/) before you start heavy manual
  edits.
- Read [Modeling & Generation](../modeling-and-generation/) for the full
  generator workflow.
- Read [Configuration](../configuration/) before changing the solver or UI
  metadata layers.
- Keep [Command Reference](../command-reference/) open while working.
- Continue with [SolverForge](/docs/solverforge/) when you need runtime-level
  domain modeling and solver API detail.
