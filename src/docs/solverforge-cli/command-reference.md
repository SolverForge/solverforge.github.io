---
title: Command Reference
description: >
  Command groups, global options, version reporting, and links to focused
  solverforge-cli command pages.
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

Every subcommand also supports `--help`. Command groups also expose Clap's
generated `help` leaf, so `solverforge generate help variable`,
`solverforge destroy help entity`, and `solverforge config help set` are
equivalent to the matching nested `--help` form.

## Command Groups

| Group | Commands | Purpose |
| ----- | -------- | ------- |
| [Scaffold Commands](/docs/solverforge-cli/scaffold-commands/) | `new`, `server` | Create and run a generated app shell |
| [Generator Commands](/docs/solverforge-cli/generator-commands/) | `generate`, `destroy` | Add, remove, and resync generated domain resources |
| [Operations Commands](/docs/solverforge-cli/operations-commands/) | `info`, `check`, `test`, `routes`, `config`, `completions`, `help` | Inspect, validate, test, configure, and integrate the app |

## Version And Help

```bash
solverforge --version
solverforge --help
solverforge help
solverforge help generate
solverforge generate variable --help
```

`solverforge --version` reports the CLI package version separately from the
crate targets used by newly scaffolded projects:

```text
solverforge solverforge-cli 2.0.4
CLI version: 2.0.4
Scaffold runtime target: SolverForge crate target 0.11.1
Scaffold UI target: solverforge-ui 0.6.5
Scaffold maps target: solverforge-maps 2.1.4
Runtime source: crates.io: solverforge 0.11.1
UI source: crates.io: solverforge-ui 0.6.5
Maps source: crates.io: solverforge-maps 2.1.4
```

That output is versioned with the installed CLI. The current
`solverforge-cli 2.0.4` scaffold starts on the published `solverforge 0.11.1`,
`solverforge-ui 0.6.5`, and `solverforge-maps 2.1.4` crate line.

Keep generated-app dependency manifests aligned with the installed CLI. Use the
version output as the source of truth for the scaffold targets carried by that
binary. The current standalone runtime crate is `solverforge 0.13.0`; upgrading
a generated app to that runtime is an app-owned dependency and
`solverforge.app.toml` change until a newer CLI scaffold target is published.

## Top-Level Commands

| Command       | Purpose |
| ------------- | ------- |
| `new`         | Scaffold a new neutral SolverForge project |
| `generate`    | Add a generated resource to the current project |
| `destroy`     | Remove a generated resource from the current project |
| `server`      | Start the generated development server |
| `info`        | Summarize entities, facts, constraints, and score type |
| `check`       | Validate project structure and configuration |
| `test`        | Run `cargo test` with passthrough arguments |
| `routes`      | List HTTP routes defined in `src/api/` |
| `config`      | Show or set values in `solver.toml` |
| `completions` | Generate shell completions |
| `help`        | Print top-level or subcommand help |

## See Also

- [Scaffold Commands](/docs/solverforge-cli/scaffold-commands/) - `new` and `server`
- [Generator Commands](/docs/solverforge-cli/generator-commands/) - `generate` and `destroy`
- [Operations Commands](/docs/solverforge-cli/operations-commands/) - inspection, validation, config, completions, and help
