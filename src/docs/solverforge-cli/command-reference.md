---
title: Command Reference
description: >
  Complete command, flag, and example reference for solverforge-cli 1.1.3.
weight: 5
---

# Command Reference

The top-level CLI surface is:

```text
solverforge [OPTIONS] <COMMAND>
```

## Global Options

These options work with every command:

| Option | Meaning |
| ------ | ------- |
| `-q, --quiet` | Suppress all output except errors |
| `-v, --verbose` | Show extra diagnostic output |
| `--no-color` | Disable colored output and respect `NO_COLOR` |
| `-h, --help` | Print help |
| `-V, --version` | Print the long version report with scaffold targets |

## Top-Level Commands

| Command | Purpose |
| ------- | ------- |
| `new` | Scaffold a new SolverForge project |
| `generate` | Add a generated resource to the current project |
| `destroy` | Remove a generated resource from the current project |
| `server` | Start the generated development server |
| `info` | Summarize entities, facts, constraints, and score type |
| `check` | Validate project structure and configuration |
| `test` | Run `cargo test` with passthrough args |
| `routes` | List routes defined in `src/api/routes.rs` |
| `config` | Show or set values in `solver.toml` |
| `completions` | Generate shell completions |

## `solverforge new`

```text
solverforge new [OPTIONS] <NAME>
```

Arguments:

- `<NAME>` - project directory name

Options:

- `--skip-git` - skip `git init` and the initial commit
- `--skip-readme` - do not generate `README.md`

Example:

```bash
solverforge new my-optimizer
```

## `solverforge server`

```text
solverforge server [OPTIONS]
```

Options:

- `-p, --port <PORT>` - bind a different port, default `7860`
- `--debug` - run `cargo run` instead of `cargo run --release`

Examples:

```bash
solverforge server
solverforge server --port 8080
solverforge server --debug
```

## `solverforge info`

```text
solverforge info
```

Prints:

- project name
- planning solution type
- score type
- facts
- entities
- scalar and list solvable fields
- constraints
- presence of `solver.toml`

## `solverforge check`

```text
solverforge check
```

Checks:

- `src/domain/` exists
- a planning solution can be parsed
- entity modules declared in `src/domain/mod.rs` exist
- constraint modules declared in `src/constraints/mod.rs` exist
- `solver.toml` exists
- entities without planning variables are flagged as warnings

## `solverforge routes`

```text
solverforge routes
```

Parses `src/api/routes.rs` and lists the generated HTTP route table.

## `solverforge test`

```text
solverforge test [EXTRA_ARGS]...
```

Examples:

```bash
solverforge test
solverforge test -- --nocapture
solverforge test integration
```

This is a convenience wrapper around `cargo test`.

## `solverforge generate`

```text
solverforge generate <SUBCOMMAND>
```

### `generate fact`

```text
solverforge generate fact [OPTIONS] <NAME>
```

Options:

- `--field <NAME:TYPE>` - repeatable extra field
- `-f, --force` - overwrite if the fact exists
- `--pretend` - preview only

Example:

```bash
solverforge generate fact employee --field "skill:String"
```

### `generate entity`

```text
solverforge generate entity [OPTIONS] <NAME>
```

Options:

- `--planning-variable <FIELD>` - add the first scalar variable immediately
- `--field <NAME:TYPE>` - repeatable extra field
- `-f, --force` - overwrite if the entity exists
- `--pretend` - preview only

Example:

```bash
solverforge generate entity shift --planning-variable employee_idx
```

### `generate variable`

```text
solverforge generate variable [OPTIONS] --entity <ENTITY_TYPE> --kind <KIND> <FIELD>
```

Options:

- `--entity <ENTITY_TYPE>` - target entity struct
- `--kind <KIND>` - `scalar` or `list`; legacy `standard` is still accepted
- `--range <FACT_COLLECTION>` - scalar value range collection
- `--elements <FACT_COLLECTION>` - list element collection
- `--allows-unassigned` - scalar variables only

Examples:

```bash
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees --allows-unassigned
solverforge generate variable stops --entity Route --kind list --elements visits
```

### `generate constraint`

```text
solverforge generate constraint [OPTIONS] <NAME>
```

Options:

- `--hard` - hard constraint, default
- `--soft` - soft constraint
- `--unary`
- `--pair`
- `--join`
- `--balance`
- `--reward`
- `-f, --force`
- `--pretend`

Examples:

```bash
solverforge generate constraint max_hours --unary --hard
solverforge generate constraint no_overlap --pair
solverforge generate constraint required_skill --join --hard
```

### `generate solution`

```text
solverforge generate solution [OPTIONS] <NAME>
```

Options:

- `--score <SCORE_TYPE>` - default `HardSoftScore`

Example:

```bash
solverforge generate solution schedule --score HardSoftScore
```

### `generate score`

```text
solverforge generate score <SCORE_TYPE>
```

Example:

```bash
solverforge generate score HardMediumSoftScore
```

### `generate data`

```text
solverforge generate data [OPTIONS]
```

Options:

- `--mode <MODE>` - `sample` or `stub`, default `sample`
- `--size <SIZE>` - `small`, `standard`, or `large`

Examples:

```bash
solverforge generate data
solverforge generate data --size large
solverforge generate data --mode stub
```

### `generate scaffold`

```text
solverforge generate scaffold [OPTIONS] <NAME> [FIELDS]...
```

Behavior:

- `<NAME>` is the base entity name
- the first field becomes the planning variable seed

Options:

- `--entity`
- `--constraint <CONSTRAINT_NAME>`
- `--pair`
- `-f, --force`
- `--pretend`

Example:

```bash
solverforge generate scaffold shift employee_idx:usize --entity --constraint no_overlap --pair
```

## `solverforge destroy`

```text
solverforge destroy [OPTIONS] <SUBCOMMAND>
```

Top-level options:

- `-y, --yes` - skip confirmation

Subcommands:

| Subcommand | Purpose |
| ---------- | ------- |
| `destroy solution` | Remove the planning solution struct |
| `destroy entity <NAME>` | Remove an entity |
| `destroy variable --entity <TYPE> <FIELD>` | Remove a planning variable from an entity |
| `destroy fact <NAME>` | Remove a fact |
| `destroy constraint <NAME>` | Remove a constraint |

Examples:

```bash
solverforge destroy entity shift
solverforge destroy constraint no_overlap --yes
```

## `solverforge config`

```text
solverforge config <SUBCOMMAND>
```

Subcommands:

| Subcommand | Purpose |
| ---------- | ------- |
| `config show` | Print `solver.toml` |
| `config set <KEY> <VALUE>` | Set a dotted key path in `solver.toml` |

Examples:

```bash
solverforge config show
solverforge config set termination.seconds_spent_limit 60
```

## `solverforge completions`

```text
solverforge completions <SHELL>
```

Supported shells:

- `bash`
- `elvish`
- `fish`
- `powershell`
- `zsh`

Examples:

```bash
solverforge completions bash >> ~/.bashrc
solverforge completions zsh >> ~/.zshrc
solverforge completions fish > ~/.config/fish/completions/solverforge.fish
```

## Help Pattern

Every command supports `--help`. Examples:

```bash
solverforge --help
solverforge generate --help
solverforge generate variable --help
solverforge destroy --help
```
