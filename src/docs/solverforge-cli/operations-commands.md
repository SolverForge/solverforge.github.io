---
title: Operations Commands
description: >
  Inspect, validate, test, configure, and integrate generated SolverForge apps.
weight: 8
---

# Operations Commands

Operations commands do not change the domain model structure. They inspect the
generated app, validate the working tree, run tests, show routes, edit runtime
configuration, or emit shell integration files.

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

| Check                                                | Result |
| ---------------------------------------------------- | ------ |
| `src/domain/` exists                                 | Errors if missing |
| planning solution parses                             | Errors if no solution is found |
| entity modules in `src/domain/mod.rs` exist          | Errors for missing files |
| constraint modules in `src/constraints/mod.rs` exist | Errors for missing files |
| `solver.toml` exists                                 | Warns if missing |
| entities have solvable fields                        | Warns for entities with no scalar or list variable |

## `solverforge routes`

```text
solverforge routes [OPTIONS]
```

Searches for `src/api/routes.rs`, `src/api/mod.rs`, or `src/api.rs`, then
parses Axum `.route("...", method(handler))` calls and prints a
`METHOD / PATH / HANDLER` table.

## `solverforge test`

```text
solverforge test [OPTIONS] [EXTRA_ARGS]...
```

Arguments:

| Argument          | Meaning |
| ----------------- | ------- |
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

| Subcommand | Usage                                  | Purpose                             |
| ---------- | -------------------------------------- | ----------------------------------- |
| `show`     | `solverforge config show`              | Print the contents of `solver.toml` |
| `set`      | `solverforge config set <KEY> <VALUE>` | Set a dotted TOML key path in `solver.toml` |

`config set` parses values as integer, float, boolean (`true` or `false`), then
string. Intermediate TOML tables are created when needed.

Examples:

```bash
solverforge config show
solverforge config set termination.seconds_spent_limit 60
solverforge config set phases.acceptor.type late_acceptance
```

### `config show`

```text
solverforge config show [OPTIONS]
```

Prints the current `solver.toml` contents. The command has no local arguments
or local options beyond the global flags.

### `config set`

```text
solverforge config set [OPTIONS] <KEY> <VALUE>
```

Arguments:

| Argument  | Meaning                          |
| --------- | -------------------------------- |
| `<KEY>`   | Dotted key path in `solver.toml` |
| `<VALUE>` | New value                        |

For example, `termination.seconds_spent_limit` addresses the solver termination
limit. Values are parsed as integer, float, boolean, then string. Intermediate
TOML tables are created when needed.

## `solverforge completions`

```text
solverforge completions [OPTIONS] <SHELL>
```

Arguments:

| Argument  | Meaning |
| --------- | ------- |
| `<SHELL>` | One of `bash`, `elvish`, `fish`, `powershell`, or `zsh` |

Examples:

```bash
solverforge completions bash >> ~/.bashrc
solverforge completions zsh >> ~/.zshrc
solverforge completions fish > ~/.config/fish/completions/solverforge.fish
```

## `solverforge help`

```text
solverforge help [COMMAND]...
```

Prints the same help text exposed by `--help`. With no argument, it prints
top-level help. With one or more command names, it prints help for that nested
command:

```bash
solverforge help
solverforge help generate
solverforge help generate variable
solverforge help config set
```

## See Also

- [Configuration](/docs/solverforge-cli/configuration/) - what the CLI writes into `solver.toml` and `solverforge.app.toml`
- [Solver Configuration](/docs/solverforge/solver/configuration/) - runtime phase, selector, acceptor, and termination options
