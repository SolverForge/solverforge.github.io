---
title: Scaffold Commands
description: >
  Create a neutral generated project shell and run its development server.
weight: 6
---

# Scaffold Commands

Scaffold commands create and run the generated app shell. They do not choose a
problem class; scalar and list planning variables are added later through
generator commands.

## `solverforge new`

```text
solverforge new [OPTIONS] <NAME>
```

Creates one neutral project shell. There are no public problem-class flags such
as `--scalar`, `--list`, or `--mixed`; scalar and list planning variables are
created after scaffolding with `solverforge generate ...`.

Arguments:

| Argument | Meaning |
| -------- | ------- |
| `<NAME>` | Project directory to create |

Options:

| Option          | Meaning                                |
| --------------- | -------------------------------------- |
| `--skip-git`    | Skip `git init` and the initial commit |
| `--skip-readme` | Do not generate `README.md`            |

Project names must start with an ASCII letter and contain only letters, digits,
hyphens, or underscores. Hyphens are converted to underscores for the generated
Rust crate name, and Rust keywords are rejected.

Unless `--skip-git` is set, the command initializes a Git repository and
attempts an initial commit. Unless `--skip-readme` is set, it writes a generated
README. When not running quiet, it prompts to run `cargo check` after
scaffolding.

Example:

```bash
solverforge new my-optimizer
```

## `solverforge server`

```text
solverforge server [OPTIONS]
```

Options:

| Option              | Meaning |
| ------------------- | ------- |
| `-p, --port <PORT>` | Set the `PORT` environment variable for the generated server; default `7860` |
| `--debug`           | Run `cargo run` instead of `cargo run --release` |

By default the command runs the generated app with `cargo run --release`.

Examples:

```bash
solverforge server
solverforge server --port 8080
solverforge server --debug
```

## See Also

- [Generator Commands](/docs/solverforge-cli/generator-commands/) - grow the neutral shell into a domain model
- [Project Anatomy](/docs/solverforge-cli/project-anatomy/) - understand the files created by `solverforge new`
