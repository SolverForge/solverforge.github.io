---
title: Configuration
description: >
  How solverforge-cli manages solver.toml, solverforge.app.toml, UI metadata,
  demo defaults, and scaffold target versioning.
weight: 4
---

# Configuration

`solverforge-cli` generated projects have two distinct configuration layers:

- `solver.toml` - runtime search strategy and termination
- `solverforge.app.toml` - scaffold metadata and UI contract

They serve different purposes and should be treated differently.

## `solver.toml`: Solver Runtime Configuration

Fresh projects start with a default configuration like this:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"
[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400
[phases.forager]
type = "accepted_count"
limit = 4

[termination]
seconds_spent_limit = 30
```

This is the user-owned search layer. Edit it directly or use the CLI helpers.

`solver.toml` should answer operational search questions:

| Question | Config surface |
| -------- | -------------- |
| How long may the solve run? | `[termination]` or `[phases.termination]` |
| How is the initial solution constructed? | `[[phases]] type = "construction_heuristic"` |
| Which neighborhoods are searched? | `[phases.move_selector]` |
| How are candidates accepted? | `[phases.acceptor]` |
| How many accepted candidates form one step horizon? | `[phases.forager]` |
| Is the run deterministic? | `environment_mode`, `random_seed`, `move_thread_count` |

When selector or phase behavior is the question, read the runtime
[configuration docs](/docs/solverforge/solver/configuration/) and
[moves docs](/docs/solverforge/solver/moves/) rather than guessing key names.

### Show the Current Config

```bash
solverforge config show
```

### Set a Value

```bash
solverforge config set termination.seconds_spent_limit 60
solverforge config set phases.acceptor.type late_acceptance
```

`solverforge config set` uses dotted key paths and parses values as:

- integer when possible
- float when possible
- boolean for `true` and `false`
- string otherwise

That makes it convenient for simple changes, but it does not replace learning
the runtime `solver.toml` model. Use the SolverForge runtime docs when you need
deeper phase and move configuration detail.

## `solverforge.app.toml`: Scaffold Metadata and UI Contract

Fresh projects also start with an app spec like this:

```toml
[app]
name = "my-scheduler"
starter = "neutral-shell"
cli_version = "2.0.4"

[runtime]
target = "solverforge 0.11.1"
runtime_source = "crates.io: solverforge 0.11.1"
ui_source = "crates.io: solverforge-ui 0.6.5"

[demo]
default_size = "standard"
available_sizes = ["small", "standard", "large"]

[solution]
name = "Plan"
score = "HardSoftScore"
```

This example reflects the `solverforge-cli 2.0.4` scaffold target. Fresh
generated apps start on the published `solverforge 0.11.1` runtime and the
CLI's `solverforge-ui 0.6.5` scaffold target.

Record any later app-owned runtime-target upgrade explicitly in that app's
dependency manifest and `solverforge.app.toml`. The current standalone
`solverforge` runtime is `0.13.0`, so a manually upgraded generated app should
record `target = "solverforge 0.13.0"` and
`runtime_source = "crates.io: solverforge 0.13.0"`.

As you generate facts, entities, variables, and constraints, the CLI also keeps
these structural arrays in sync:

- `[[facts]]`
- `[[entities]]`
- `[[variables]]`
- `[[constraints]]`

### What the App Spec Is For

`solverforge.app.toml` is not a second modeling language. It is synchronized
metadata used to:

- record scaffold provenance and targets
- store demo defaults
- describe collections and solvable fields for the frontend
- produce `static/generated/ui-model.json`

The primary modeling source still lives in:

- `src/domain/`
- `src/constraints/`

### Manual Edit Guidance

Safe manual edits:

- app name or metadata when you understand the consequences
- demo default size if you want to change the default dataset surfaced by the UI

Use caution with:

- `[[facts]]`
- `[[entities]]`
- `[[variables]]`
- `[[constraints]]`

Those sections are synchronized from the generated code and may be rewritten by
future CLI operations.

## UI Metadata Files

Two frontend-facing files are derived from the app spec.

### `static/generated/ui-model.json`

This is the generated UI model consumed by `static/app.js`. It includes:

- entities
- facts
- enabled constraints
- generated views based on scalar or list variables

Scalar and list variables become different view kinds:

- scalar -> `kind: "scalar"`
- list -> `kind: "list"`

Do not hand-edit this file. It is generated output.

### `static/sf-config.json`

This is a lighter config payload for frontend shell labels such as title and
subtitle. It is part of the shipped generated shell and stays aligned with the
app spec.

## Demo Defaults

`solverforge generate data --size large` does two things:

1. rewrites `src/data/data_seed.rs`
2. updates `[demo].default_size` in `solverforge.app.toml`

That means the selected default dataset is part of the scaffold contract, not
just a one-off command flag.

## Version Targets and Provenance

Run:

```bash
solverforge --version
```

This reports:

- CLI version
- scaffold runtime target
- scaffold UI target
- scaffold maps target
- source labels for each dependency line

In generated apps, the crate versions are pinned in `Cargo.toml`, while the app
spec records the runtime and UI target labels plus their sources. The maps
dependency is pinned in `Cargo.toml` and surfaced in `solverforge --version`,
but it is not currently duplicated into the app spec's `[runtime]` block.

## Practical Rule of Thumb

When you are unsure where a change belongs:

- solver behavior and termination -> `solver.toml`
- domain shape -> `src/domain/`
- constraint logic -> `src/constraints/`
- scaffold metadata and derived UI contract -> `solverforge.app.toml`
- generated frontend views -> `static/generated/ui-model.json`
