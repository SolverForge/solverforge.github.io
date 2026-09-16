---
title: Command Reference
description: >
  Command groups, global options, version reporting, and the full
  solverforge-cli 3.1.0 command surface.
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

| Option          | Meaning                                                     |
| --------------- | ----------------------------------------------------------- |
| `-h, --help`    | Print top-level help                                        |
| `-V, --version` | `-V` prints just the CLI version; `--version` prints the CLI version plus every scaffold target and source |

Every subcommand also supports `--help`. Command groups also expose Clap's
generated `help` leaf, so `solverforge generate help variable`,
`solverforge destroy help entity`, and `solverforge config help set` are
equivalent to the matching nested `--help` form.

Portable preferences come from `.solverforgerc` in the project root and then
`~/.solverforgerc`. The recognized keys are intentionally narrow: `port`,
`no_color`, and `quiet`.

## Command Groups

| Group | Commands | Purpose |
| ----- | -------- | ------- |
| [Scaffold Commands](/docs/solverforge-cli/scaffold-commands/) | `new`, `server` | Create and run generated web, API, CLI, or MCP shells |
| [Generator Commands](/docs/solverforge-cli/generator-commands/) | `generate`, `destroy` | Add, remove, and resync generated domain and model resources |
| [Operations Commands](/docs/solverforge-cli/operations-commands/) | `info`, `check`, `test`, `routes`, `connect`, `config`, `completions`, `help` | Inspect, validate, test, configure, and integrate the app |
| [MCP Shell](/docs/solverforge-cli/mcp-shell/) | `new --shell mcp`, `solverforge connect` | Expose the solver to MCP-capable agent harnesses |

## Top-Level Commands

| Command       | Purpose |
| ------------- | ------- |
| `new`         | Scaffold a new SolverForge project shell |
| `generate`    | Add a generated resource to the current project |
| `destroy`     | Remove a generated resource from the current project |
| `server`      | Start the development server |
| `info`        | Summarize entities, facts, constraints, and score type |
| `check`       | Validate project structure and configuration |
| `test`        | Run `cargo test` with passthrough arguments |
| `routes`      | List HTTP routes defined in `src/api/` (web and API shells) |
| `connect`     | Print MCP client connection configs for an MCP-shell project |
| `config`      | Show or set values in `solver.toml` |
| `completions` | Generate shell completions |
| `help`        | Print top-level or subcommand help |

## Version And Help

```bash
solverforge -V
solverforge --version
solverforge --help
solverforge help generate
solverforge generate variable --help
```

`solverforge -V` prints only the CLI package version:

```text
solverforge 3.1.0
```

`solverforge --version` reports the CLI package version separately from every
crate target and source used by newly scaffolded projects:

```text
solverforge solverforge-cli 3.1.0
CLI version: 3.1.0
Scaffold runtime target: SolverForge crate target 0.19.5
Scaffold UI target: solverforge-ui 0.9.0
Scaffold maps target: solverforge-maps 2.1.4
Scaffold MCP target: rmcp 3.4.0
Runtime source: crates.io: solverforge 0.19.5
UI source: crates.io: solverforge-ui 0.9.0
Maps source: crates.io: solverforge-maps 2.1.4
MCP source: crates.io: rmcp 3.4.0
```

That output is versioned with the installed CLI. The current
`solverforge-cli 3.1.0` line starts new scaffolds on the published
`solverforge 0.19.5` runtime, with `solverforge-ui 0.9.0` and
`solverforge-maps 2.1.4` for the web shell and `rmcp 3.4.0` for the MCP shell.
The core runtime can move ahead of the scaffold target, so registry installs
should always be checked with `solverforge --version`.

Keep generated-app dependency manifests aligned with the installed CLI. Use the
version output as the source of truth for the scaffold targets carried by that
binary. App-specific dependency changes still belong in that generated app's
manifest and `solverforge.app.toml`.

## See Also

- [Scaffold Commands](/docs/solverforge-cli/scaffold-commands/) - `new` and `server`
- [Generator Commands](/docs/solverforge-cli/generator-commands/) - `generate` and `destroy`
- [Operations Commands](/docs/solverforge-cli/operations-commands/) - inspection, validation, connect, config, completions, and help
- [MCP Shell](/docs/solverforge-cli/mcp-shell/) - the `mcp` shell and `connect`
