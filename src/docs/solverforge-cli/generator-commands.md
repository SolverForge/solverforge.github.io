---
title: Generator Commands
description: >
  Add and remove facts, entities, variables, constraints, scores, solutions,
  model resources, and demo data in generated SolverForge apps.
weight: 7
---

# Generator Commands

Generator commands synchronize Rust domain files, app metadata, and generated
frontend model files. They expect the current project to retain the managed
`@solverforge:begin ...` / `@solverforge:end ...` regions emitted by the
current scaffold.

## `solverforge generate`

```text
solverforge generate [OPTIONS] <COMMAND>
```

Subcommands:

| Subcommand   | Purpose |
| ------------ | ------- |
| `constraint` | Add a constraint skeleton to `src/constraints/` |
| `entity`     | Add a planning entity struct in `src/domain/` |
| `fact`       | Add a problem fact struct in `src/domain/` |
| `solution`   | Add or replace the neutral planning solution struct |
| `variable`   | Add a scalar or list planning variable to an existing entity |
| `score`      | Change the score type in the existing planning solution |
| `data`       | Regenerate compiler-owned demo data from the project model |
| `scalar-group` | Declare a SolverForge scalar group for coupled scalar construction/search |
| `conflict-repair` | Declare a conflict repair provider for a constraint |

### `generate fact`

```text
solverforge generate fact [OPTIONS] <NAME>
```

| Option                | Meaning                                      |
| --------------------- | -------------------------------------------- |
| `--field <NAME:TYPE>` | Add a repeatable extra Rust field            |
| `-f, --force`         | Overwrite the fact file if it already exists |
| `--pretend`           | Preview changes without writing files        |

Creates `src/domain/<name>.rs`, updates `src/domain/mod.rs`, wires the
collection into the planning solution, and syncs `solverforge.app.toml` plus the
generated UI model.

```bash
solverforge generate fact employee --field "skill:String"
```

### `generate entity`

```text
solverforge generate entity [OPTIONS] <NAME>
```

| Option                        | Meaning                                              |
| ----------------------------- | ---------------------------------------------------- |
| `--planning-variable <FIELD>` | Add an optional scalar planning-variable placeholder |
| `--field <NAME:TYPE>`         | Add a repeatable extra Rust field                    |
| `-f, --force`                 | Overwrite the entity file if it already exists       |
| `--pretend`                   | Preview changes without writing files                |

`--planning-variable` emits `#[planning_variable(allows_unassigned = true)]`
with an `Option<usize>` field. Use `generate variable` when you need an explicit
scalar range or list element collection.

```bash
solverforge generate entity shift --planning-variable employee_idx
```

### `generate variable`

```text
solverforge generate variable [OPTIONS] --entity <ENTITY_TYPE> --kind <KIND> <FIELD>
```

| Option                         | Meaning |
| ------------------------------ | ------- |
| `--entity <ENTITY_TYPE>`       | Target entity struct name, such as `Shift` |
| `--kind <KIND>`                | Variable kind; valid values are `scalar` and `list` |
| `--range <FACT_COLLECTION>`    | Required for `--kind scalar`; source fact collection |
| `--elements <FACT_COLLECTION>` | Required for `--kind list`; list element collection |
| `--allows-unassigned`          | Scalar only; generate an optional assignment |
| `--candidate-values <FN_PATH>` | Scalar only; candidate value hook |
| `--nearby-value-candidates <FN_PATH>` | Scalar only; nearby value hook |
| `--nearby-entity-candidates <FN_PATH>` | Scalar only; nearby entity hook |
| `--nearby-value-distance-meter <FN_PATH>` | Scalar only; nearby value distance meter |
| `--nearby-entity-distance-meter <FN_PATH>` | Scalar only; nearby entity distance meter |
| `--construction-entity-order-key <FN_PATH>` | Scalar only; construction entity ordering |
| `--construction-value-order-key <FN_PATH>` | Scalar only; construction value ordering |

`standard` is not a variable kind. It is only the default demo data size label
used by `solverforge.app.toml`.

```bash
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees --allows-unassigned
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees --candidate-values employee_candidates
solverforge generate variable stops --entity Route --kind list --elements visits
```

### `generate constraint`

```text
solverforge generate constraint [OPTIONS] <NAME>
```

Hardness options:

| Option   | Meaning |
| -------- | ------- |
| `--hard` | Hard constraint; this is the default for hard-capable patterns |
| `--soft` | Soft constraint |

Pattern options:

| Option      | Meaning |
| ----------- | ------- |
| `--unary`   | Penalize matching entities with `for_each + filter + penalize` |
| `--pair`    | Penalize conflicting pairs with pairwise comparison |
| `--join`    | Penalize entity-fact mismatch with `for_each + join` |
| `--balance` | Generate a load-balance style soft constraint |
| `--reward`  | Reward matching entities with `for_each + filter + reward` |

Write options:

| Option        | Meaning |
| ------------- | ------- |
| `-f, --force` | Overwrite the constraint file if it already exists |
| `--pretend`   | Preview changes without writing files |

Choose at most one pattern flag. If no pattern flag is supplied, the command
scans the current domain and opens an interactive wizard. `--balance` and
`--reward` imply soft scoring in the current generator.

```bash
solverforge generate constraint max_hours --unary --hard
solverforge generate constraint no_overlap --pair
solverforge generate constraint required_skill --join --hard
```

### `generate solution`

```text
solverforge generate solution [OPTIONS] <NAME>
```

| Option                 | Meaning                             |
| ---------------------- | ----------------------------------- |
| `--score <SCORE_TYPE>` | Score type; default `HardSoftScore` |

A fresh neutral scaffold can be replaced once by this command. If the project
is already shaped, destroy the existing solution first.

```bash
solverforge generate solution schedule --score HardSoftScore
```

### `generate score`

```text
solverforge generate score [OPTIONS] <SCORE_TYPE>
```

`<SCORE_TYPE>` can be `HardSoftScore`, `HardSoftDecimalScore`,
`HardMediumSoftScore`, `SoftScore`, `SimpleScore`, or a concrete bendable score
such as `BendableScore<2, 3>`.

```bash
solverforge generate score HardSoftDecimalScore
```

### `generate data`

```text
solverforge generate data [OPTIONS]
```

| Option          | Meaning |
| --------------- | ------- |
| `--mode <MODE>` | Data generation mode; valid values are `sample` and `stub`; default `sample` |
| `--size <SIZE>` | Default demo size; valid values are `small`, `standard`, and `large` |

The command rewrites `src/data/data_seed.rs`, ensures the stable
`src/data/mod.rs` wrapper exists, and updates `[demo].default_size` in
`solverforge.app.toml` when `--size` is provided.

```bash
solverforge generate data
solverforge generate data --size large
solverforge generate data --mode stub
```

### `generate scalar-group`

```text
solverforge generate scalar-group [OPTIONS] <NAME>
```

Scalar groups are opt-in runtime model resources for coupled scalar
construction and search.

Target options:

| Option | Meaning |
| ------ | ------- |
| `--assignment <ENTITY.FIELD>` | Assignment-backed scalar target; the target must allow unassigned values |
| `--candidates <FN_PATH>` | Candidate-backed provider function |
| `--target <ENTITY.FIELD>` | Candidate-backed scalar target; repeat for multi-target groups |

Assignment hook options:

| Option | Meaning |
| ------ | ------- |
| `--required-entity <FN_PATH>` | Decide whether an entity must be assigned |
| `--capacity-key <FN_PATH>` | Return a capacity bucket for entity/value pairs |
| `--assignment-rule <FN_PATH>` | Filter legal pairwise assignments |
| `--position-key <FN_PATH>` | Return sequence position for an entity |
| `--sequence-key <FN_PATH>` | Return sequence key for entity/value pairs |
| `--entity-order <FN_PATH>` | Rank entity construction order |
| `--value-order <FN_PATH>` | Rank candidate value order |

Limit and write options:

| Option | Meaning |
| ------ | ------- |
| `--value-candidate-limit <N>` | Limit candidate values per scalar target |
| `--group-candidate-limit <N>` | Limit grouped construction candidates |
| `--max-moves-per-step <N>` | Limit grouped scalar local-search moves per step |
| `--max-augmenting-depth <N>` | Limit augmenting-path depth for assignment groups |
| `--max-rematch-size <N>` | Limit rematch size for assignment groups |
| `--skip-solver-config` | Do not add matching `solver.toml` phases |

Examples:

```bash
solverforge generate scalar-group required_assignment --assignment Task.resource_idx --required-entity required_task
solverforge generate scalar-group paired_assignment --candidates paired_candidates --target Task.primary_idx --target Task.secondary_idx
```

### `generate conflict-repair`

```text
solverforge generate conflict-repair [OPTIONS] --provider <FN_PATH> <CONSTRAINT>
```

| Option | Meaning |
| ------ | ------- |
| `--provider <FN_PATH>` | Repair provider function path |
| `--selector <SELECTOR>` | Move selector kind to add to `solver.toml`; `compound` or `conflict`, default `compound` |
| `--max-matches-per-step <N>` | Limit conflict matches per step |
| `--max-repairs-per-match <N>` | Limit repairs per matched conflict |
| `--max-moves-per-step <N>` | Limit emitted repair moves per step |
| `--include-soft-matches` | Allow selectors to match soft-constraint conflicts |
| `--skip-solver-config` | Do not add a matching `solver.toml` phase |

Example:

```bash
solverforge generate conflict-repair required_assignment --provider repair_required_assignment
```

## `solverforge destroy`

```text
solverforge destroy [OPTIONS] <COMMAND>
```

Removes generated resources and resyncs the app spec and UI model. The
confirmation flag belongs to the `destroy` command itself, so place it before
the resource subcommand.

| Option      | Meaning                      |
| ----------- | ---------------------------- |
| `-y, --yes` | Skip the confirmation prompt |

Subcommands:

| Subcommand   | Usage | Purpose |
| ------------ | ----- | ------- |
| `solution`   | `solverforge destroy [OPTIONS] solution` | Remove the planning solution struct |
| `entity`     | `solverforge destroy [OPTIONS] entity <NAME>` | Remove a planning entity and unwire its solution collection |
| `variable`   | `solverforge destroy [OPTIONS] variable --entity <ENTITY_TYPE> <FIELD>` | Remove a planning variable field from an entity |
| `fact`       | `solverforge destroy [OPTIONS] fact <NAME>` | Remove a problem fact and unwire its solution collection |
| `constraint` | `solverforge destroy [OPTIONS] constraint <NAME>` | Remove a constraint module and registry entry |
| `scalar-group` | `solverforge destroy [OPTIONS] scalar-group <NAME>` | Remove a scalar group declaration |
| `conflict-repair` | `solverforge destroy [OPTIONS] conflict-repair <NAME>` | Remove a conflict repair declaration |

```bash
solverforge destroy entity shift
solverforge destroy --yes constraint no_overlap
solverforge destroy -y variable --entity Task resource_idx
solverforge destroy --yes scalar-group required_assignment
solverforge destroy --yes conflict-repair required_assignment
```

## See Also

- [Modeling & Generation](/docs/solverforge-cli/modeling-and-generation/) - how generated files fit together
- [Operations Commands](/docs/solverforge-cli/operations-commands/) - validation, testing, routes, and config helpers
