---
title: Command Reference
description: >
  Complete command, argument, option, and example reference for solverforge-cli.
weight: 5
---

# Command Reference

The public CLI surface is:

```text
solverforge [OPTIONS] <COMMAND>
```

`solverforge-cli` enables Clap subcommand inference, so unambiguous command
prefixes may work. The documented interface uses full command names.

## Global Options

These options are global and can be used with any command:

| Option          | Meaning                                              |
| --------------- | ---------------------------------------------------- |
| `-q, --quiet`   | Suppress all output except errors                    |
| `-v, --verbose` | Show extra diagnostic output                         |
| `--no-color`    | Disable colored output; `NO_COLOR` is also respected |

Top-level help and version options:

| Option          | Meaning                                             |
| --------------- | --------------------------------------------------- |
| `-h, --help`    | Print top-level help                                |
| `-V, --version` | Print the CLI version plus scaffold target versions |

Every subcommand also supports `--help`.

## Top-Level Commands

| Command       | Purpose                                                |
| ------------- | ------------------------------------------------------ |
| `new`         | Scaffold a new neutral SolverForge project             |
| `generate`    | Add a generated resource to the current project        |
| `destroy`     | Remove a generated resource from the current project   |
| `server`      | Start the generated development server                 |
| `info`        | Summarize entities, facts, constraints, and score type |
| `check`       | Validate project structure and configuration           |
| `test`        | Run `cargo test` with passthrough arguments            |
| `routes`      | List HTTP routes defined in `src/api/`                 |
| `config`      | Show or set values in `solver.toml`                    |
| `completions` | Generate shell completions                             |
| `help`        | Print top-level or subcommand help                     |

## Version And Help

```bash
solverforge --version
solverforge --help
solverforge help generate
solverforge generate variable --help
```

`solverforge --version` reports the CLI package version separately from the
crate targets used by newly scaffolded projects:

```text
solverforge solverforge-cli 2.0.1
CLI version: 2.0.1
Scaffold runtime target: SolverForge crate target 0.9.1
Scaffold UI target: solverforge-ui 0.6.3
Scaffold maps target: solverforge-maps 2.1.3
Runtime source: crates.io: solverforge 0.9.1
UI source: crates.io: solverforge-ui 0.6.3
Maps source: crates.io: solverforge-maps 2.1.3
```

That output is versioned with the installed CLI. The current
`solverforge-cli 2.0.1` scaffold starts on the published `solverforge 0.9.1`,
`solverforge-ui 0.6.3`, and `solverforge-maps 2.1.3` crate line.

## `solverforge new`

```text
solverforge new [OPTIONS] <NAME>
```

Creates one neutral project shell. There are no public problem-class flags such
as `--scalar`, `--list`, or `--mixed`; scalar and list planning variables are
created after scaffolding with `solverforge generate ...`.

Arguments:

| Argument | Meaning                     |
| -------- | --------------------------- |
| `<NAME>` | Project directory to create |

Options:

| Option          | Meaning                                |
| --------------- | -------------------------------------- |
| `--skip-git`    | Skip `git init` and the initial commit |
| `--skip-readme` | Do not generate `README.md`            |

Project names must start with an ASCII letter and contain only letters, digits,
hyphens, or underscores. Hyphens are converted to underscores for the generated
Rust crate name, and Rust keywords are rejected.

Unless `--skip-git` is set, the command initializes a Git repository and attempts
an initial commit. Unless `--skip-readme` is set, it writes a generated README.
When not running quiet, it prompts to run `cargo check` after scaffolding.

Example:

```bash
solverforge new my-optimizer
```

## `solverforge generate`

```text
solverforge generate [OPTIONS] <COMMAND>
```

Adds resources to an existing generated project. Generator commands assume the
current project still has the managed `@solverforge:begin ...` /
`@solverforge:end ...` regions used by the current scaffold.

Subcommands:

| Subcommand   | Purpose                                                      |
| ------------ | ------------------------------------------------------------ |
| `constraint` | Add a constraint skeleton to `src/constraints/`              |
| `entity`     | Add a planning entity struct in `src/domain/`                |
| `fact`       | Add a problem fact struct in `src/domain/`                   |
| `solution`   | Add or replace the neutral planning solution struct          |
| `variable`   | Add a scalar or list planning variable to an existing entity |
| `score`      | Change the score type in the existing planning solution      |
| `data`       | Regenerate compiler-owned demo data from the project model   |

### `generate fact`

```text
solverforge generate fact [OPTIONS] <NAME>
```

Arguments:

| Argument | Meaning                                     |
| -------- | ------------------------------------------- |
| `<NAME>` | Fact name in snake_case, such as `employee` |

Options:

| Option                | Meaning                                      |
| --------------------- | -------------------------------------------- |
| `--field <NAME:TYPE>` | Add a repeatable extra Rust field            |
| `-f, --force`         | Overwrite the fact file if it already exists |
| `--pretend`           | Preview changes without writing files        |

Creates `src/domain/<name>.rs`, updates `src/domain/mod.rs`, wires the collection
into the planning solution, and syncs `solverforge.app.toml` plus the generated
UI model.

Example:

```bash
solverforge generate fact employee --field "skill:String"
```

### `generate entity`

```text
solverforge generate entity [OPTIONS] <NAME>
```

Arguments:

| Argument | Meaning                                    |
| -------- | ------------------------------------------ |
| `<NAME>` | Entity name in snake_case, such as `shift` |

Options:

| Option                        | Meaning                                              |
| ----------------------------- | ---------------------------------------------------- |
| `--planning-variable <FIELD>` | Add an optional scalar planning-variable placeholder |
| `--field <NAME:TYPE>`         | Add a repeatable extra Rust field                    |
| `-f, --force`                 | Overwrite the entity file if it already exists       |
| `--pretend`                   | Preview changes without writing files                |

`--planning-variable` emits `#[planning_variable(allows_unassigned = true)]`
with an `Option<usize>` field. Use `generate variable` when you need to add a
variable with an explicit scalar range or list element collection.

Example:

```bash
solverforge generate entity shift --planning-variable employee_idx
```

### `generate variable`

```text
solverforge generate variable [OPTIONS] --entity <ENTITY_TYPE> --kind <KIND> <FIELD>
```

Arguments:

| Argument  | Meaning                           |
| --------- | --------------------------------- |
| `<FIELD>` | Variable field name in snake_case |

Options:

| Option                         | Meaning                                              |
| ------------------------------ | ---------------------------------------------------- |
| `--entity <ENTITY_TYPE>`       | Target entity struct name, such as `Shift`           |
| `--kind <KIND>`                | Variable kind; valid values are `scalar` and `list`  |
| `--range <FACT_COLLECTION>`    | Required for `--kind scalar`; source fact collection |
| `--elements <FACT_COLLECTION>` | Required for `--kind list`; list element collection  |
| `--allows-unassigned`          | Scalar only; generate an optional assignment         |

`standard` is not a variable kind. It is only the default demo data size label
used by `solverforge.app.toml`.

Examples:

```bash
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees --allows-unassigned
solverforge generate variable stops --entity Route --kind list --elements visits
```

### `generate constraint`

```text
solverforge generate constraint [OPTIONS] <NAME>
```

Arguments:

| Argument | Meaning                              |
| -------- | ------------------------------------ |
| `<NAME>` | Constraint module name in snake_case |

Hardness options:

| Option   | Meaning                                                        |
| -------- | -------------------------------------------------------------- |
| `--hard` | Hard constraint; this is the default for hard-capable patterns |
| `--soft` | Soft constraint                                                |

Pattern options:

| Option      | Meaning                                                        |
| ----------- | -------------------------------------------------------------- |
| `--unary`   | Penalize matching entities with `for_each + filter + penalize` |
| `--pair`    | Penalize conflicting pairs with pairwise comparison            |
| `--join`    | Penalize entity-fact mismatch with `for_each + join`           |
| `--balance` | Generate a load-balance style soft constraint                  |
| `--reward`  | Reward matching entities with `for_each + filter + reward`     |

Write options:

| Option        | Meaning                                            |
| ------------- | -------------------------------------------------- |
| `-f, --force` | Overwrite the constraint file if it already exists |
| `--pretend`   | Preview changes without writing files              |

Choose at most one pattern flag. If no pattern flag is supplied, the command
scans the current domain and opens an interactive wizard. `--balance` and
`--reward` imply soft scoring in the current generator.

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

Arguments:

| Argument | Meaning                                         |
| -------- | ----------------------------------------------- |
| `<NAME>` | Solution name in snake_case, such as `schedule` |

Options:

| Option                 | Meaning                             |
| ---------------------- | ----------------------------------- |
| `--score <SCORE_TYPE>` | Score type; default `HardSoftScore` |

A fresh neutral scaffold can be replaced once by this command. If the project is
already shaped, destroy the existing solution first.

Example:

```bash
solverforge generate solution schedule --score HardSoftScore
```

### `generate score`

```text
solverforge generate score [OPTIONS] <SCORE_TYPE>
```

Arguments:

| Argument       | Meaning                                                                                                                                  |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `<SCORE_TYPE>` | Score type, such as `HardSoftScore`, `HardSoftDecimalScore`, `HardMediumSoftScore`, `SoftScore`, `SimpleScore`, or `BendableScore<2, 3>` |

Updates the score type in the existing planning solution and syncs generated
metadata.

Example:

```bash
solverforge generate score HardSoftDecimalScore
```

### `generate data`

```text
solverforge generate data [OPTIONS]
```

Options:

| Option          | Meaning                                                                      |
| --------------- | ---------------------------------------------------------------------------- |
| `--mode <MODE>` | Data generation mode; valid values are `sample` and `stub`; default `sample` |
| `--size <SIZE>` | Default demo size; valid values are `small`, `standard`, and `large`         |

The command rewrites `src/data/data_seed.rs`, ensures the stable
`src/data/mod.rs` wrapper exists, and updates `[demo].default_size` in
`solverforge.app.toml` when `--size` is provided.

Examples:

```bash
solverforge generate data
solverforge generate data --size large
solverforge generate data --mode stub
```

## `solverforge destroy`

```text
solverforge destroy [OPTIONS] <COMMAND>
```

Removes generated resources and resyncs the app spec and UI model. The
confirmation flag belongs to the `destroy` command itself, so place it before
the resource subcommand.

Options:

| Option      | Meaning                      |
| ----------- | ---------------------------- |
| `-y, --yes` | Skip the confirmation prompt |

Subcommands:

| Subcommand   | Usage                                                                   | Purpose                                                     |
| ------------ | ----------------------------------------------------------------------- | ----------------------------------------------------------- |
| `solution`   | `solverforge destroy [OPTIONS] solution`                                | Remove the planning solution struct                         |
| `entity`     | `solverforge destroy [OPTIONS] entity <NAME>`                           | Remove a planning entity and unwire its solution collection |
| `variable`   | `solverforge destroy [OPTIONS] variable --entity <ENTITY_TYPE> <FIELD>` | Remove a planning variable field from an entity             |
| `fact`       | `solverforge destroy [OPTIONS] fact <NAME>`                             | Remove a problem fact and unwire its solution collection    |
| `constraint` | `solverforge destroy [OPTIONS] constraint <NAME>`                       | Remove a constraint module and registry entry               |

Examples:

```bash
solverforge destroy entity shift
solverforge destroy --yes constraint no_overlap
solverforge destroy -y variable --entity Task resource_idx
```

## `solverforge server`

```text
solverforge server [OPTIONS]
```

Options:

| Option              | Meaning                                                                      |
| ------------------- | ---------------------------------------------------------------------------- |
| `-p, --port <PORT>` | Set the `PORT` environment variable for the generated server; default `7860` |
| `--debug`           | Run `cargo run` instead of `cargo run --release`                             |

By default the command runs the generated app with `cargo run --release`.

Examples:

```bash
solverforge server
solverforge server --port 8080
solverforge server --debug
```

## `solverforge info`

```text
solverforge info [OPTIONS]
```

Prints the project name, planning solution type, score type, entities, facts,
scalar and list solvable fields, constraints, and whether `solver.toml` exists.
It requires a generated-style `src/domain/` directory.

## `solverforge check`

```text
solverforge check [OPTIONS]
```

Validates:

| Check                                                | Result                                             |
| ---------------------------------------------------- | -------------------------------------------------- |
| `src/domain/` exists                                 | Errors if missing                                  |
| planning solution parses                             | Errors if no solution is found                     |
| entity modules in `src/domain/mod.rs` exist          | Errors for missing files                           |
| constraint modules in `src/constraints/mod.rs` exist | Errors for missing files                           |
| `solver.toml` exists                                 | Warns if missing                                   |
| entities have solvable fields                        | Warns for entities with no scalar or list variable |

## `solverforge routes`

```text
solverforge routes [OPTIONS]
```

Searches for `src/api/routes.rs`, `src/api/mod.rs`, or `src/api.rs`, then parses
Axum `.route("...", method(handler))` calls and prints a `METHOD / PATH /
HANDLER` table.

## `solverforge test`

```text
solverforge test [OPTIONS] [EXTRA_ARGS]...
```

Arguments:

| Argument          | Meaning                                   |
| ----------------- | ----------------------------------------- |
| `[EXTRA_ARGS]...` | Arguments passed directly to `cargo test` |

Examples:

```bash
solverforge test
solverforge test -- --nocapture
solverforge test integration
```

## `solverforge config`

```text
solverforge config [OPTIONS] <COMMAND>
```

Subcommands:

| Subcommand | Usage                                  | Purpose                                     |
| ---------- | -------------------------------------- | ------------------------------------------- |
| `show`     | `solverforge config show`              | Print the contents of `solver.toml`         |
| `set`      | `solverforge config set <KEY> <VALUE>` | Set a dotted TOML key path in `solver.toml` |

`config set` parses values as integer, float, boolean (`true` or `false`), then
string. Intermediate TOML tables are created when needed.

Examples:

```bash
solverforge config show
solverforge config set termination.seconds_spent_limit 60
solverforge config set phases.acceptor.type late_acceptance
```

## `solverforge completions`

```text
solverforge completions [OPTIONS] <SHELL>
```

Arguments:

| Argument  | Meaning                                                 |
| --------- | ------------------------------------------------------- |
| `<SHELL>` | One of `bash`, `elvish`, `fish`, `powershell`, or `zsh` |

Examples:

```bash
solverforge completions bash >> ~/.bashrc
solverforge completions zsh >> ~/.zshrc
solverforge completions fish > ~/.config/fish/completions/solverforge.fish
```
