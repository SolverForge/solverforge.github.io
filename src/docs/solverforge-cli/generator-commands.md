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

The `bash` examples on this page run in order in one project, a staffing model
that assigns employees to shifts. Start it with:

```bash
solverforge new staffing
cd staffing
```

### `generate solution`

```text
solverforge generate solution [OPTIONS] <NAME>
```

| Option                 | Meaning                             |
| ---------------------- | ----------------------------------- |
| `--score <SCORE_TYPE>` | Score type; default `HardSoftScore` |

A fresh neutral scaffold's `Plan` can be replaced once by this command. If the
project is already shaped, destroy the existing solution first.

The solution type and its score type are rewritten together across the generated
contract as well as the solution file, so the web/API/MCP DTOs, the solver
service, `lib.rs`, and the MCP files never keep a reference to the previous
solution or score.

```bash
solverforge generate solution schedule --score HardSoftScore
```

### `generate fact`

```text
solverforge generate fact [OPTIONS] <NAME>
```

| Option                | Meaning                                      |
| --------------------- | -------------------------------------------- |
| `--field <NAME:TYPE>` | Add a repeatable extra Rust field            |
| `-f, --force`         | Overwrite the fact file if it already exists |
| `--pretend`           | Preview changes without writing files        |

Creates `src/domain/<name>.rs` with `id` and `name` fields, updates
`src/domain/mod.rs`, wires the collection into the planning solution, and syncs
`solverforge.app.toml`, the generated UI model, and the demo data.

```bash
solverforge generate fact employee --field skill:String
```

`--field` accepts any Rust type. The command rejects `--field id:...` and
`--field name:...`, because it already writes both fields. It imports the
`chrono` types it recognizes (such as `NaiveDate`, `NaiveDateTime`, and
`Weekday`) and adds `chrono` to `Cargo.toml` when one is used. For any other
type that is not defined in `src/domain/`, it prints a warning: define that
type in `src/domain/` and export it from `src/domain/mod.rs` before you build.
Quote a type that contains `<` or `>`, such as `'skills:Vec<String>'`, so the
shell does not read it as a redirection.

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

The entity gets an `id` field; `--field id:...` is rejected.

```bash
solverforge generate entity shift --field required_skill:String
```

`--planning-variable <FIELD>` adds an `Option<usize>` scalar variable with
`#[planning_variable(allows_unassigned = true)]` and no value range. Use
`generate variable` when the variable needs a range or a list element
collection, as below.

### `generate variable`

```text
solverforge generate variable [OPTIONS] --entity <ENTITY_TYPE> --kind <KIND> <FIELD>
```

| Option                         | Meaning |
| ------------------------------ | ------- |
| `--entity <ENTITY_TYPE>`       | Target entity struct name, such as `Shift` |
| `--kind <KIND>`                | Variable kind; valid values are `scalar` and `list` |
| `--range <FACT_COLLECTION>`    | Scalar only; source fact collection; mutually exclusive with `--countable-range` |
| `--countable-range <FROM..TO>` | Scalar only; half-open integer range, such as `0..24`; mutually exclusive with `--range` |
| `--elements <FACT_COLLECTION>` | List only; list element collection |
| `--domain <PROFILE>`           | List only; stock domain profile, currently `cvrp` |
| `--distance-meter <RUST_PATH>` | List only; cross-entity distance meter type/path |
| `--intra-distance-meter <RUST_PATH>` | List only; within-entity distance meter type/path |
| `--route-hooks <MODULE_PATH>`  | List only; route-local get/set/depot/distance/feasible hooks module |
| `--savings-hooks <MODULE_PATH>` | List only; Clarke-Wright depot/distance/feasible hooks module |
| `--savings-metric-class-fn <FN_PATH>` | List only; per-owner savings metric class function |
| `--element-owner-fn <FN_PATH>` | List only; fixed owner for each list element |
| `--construction-element-order-key <FN_PATH>` | List only; construction element ordering |
| `--precedence-duration-fn <FN_PATH>` | List only; precedence duration for a list element |
| `--precedence-successors-fn <FN_PATH>` | List only; precedence successors for a list element |
| `--solution-trait <TRAIT_PATH>` | List only; additional solution trait required by the list metadata |
| `--allows-unassigned`          | Scalar only; generate an optional assignment |
| `--candidate-values <FN_PATH>` | Scalar only; candidate value hook |
| `--nearby-value-candidates <FN_PATH>` | Scalar only; nearby value hook |
| `--nearby-entity-candidates <FN_PATH>` | Scalar only; nearby entity hook |
| `--nearby-value-distance-meter <FN_PATH>` | Scalar only; nearby value distance meter |
| `--nearby-entity-distance-meter <FN_PATH>` | Scalar only; nearby entity distance meter |
| `--construction-entity-order-key <FN_PATH>` | Scalar only; construction entity ordering |
| `--construction-value-order-key <FN_PATH>` | Scalar only; construction value ordering |

Scalar variables are always `Option<usize>` candidate indexes. `--range` and
`--countable-range` choose the candidate domain; `--countable-range` validates a
non-negative `usize` range with `from < to` and projects it into
`solverforge.app.toml` and, for web shells, the generated UI model. The stock
`cvrp` profile owns its meters, route and savings hooks, metric class, and
solution trait, so those entries cannot be overridden alongside `--domain cvrp`.

`standard` is not a variable kind. It is only the default demo data size label
used by `solverforge.app.toml`.

Scalar examples on the `Shift` entity, over the `employees` collection and an
hour of the day:

```bash
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees --allows-unassigned
solverforge generate variable hour --entity Shift --kind scalar --countable-range 0..24
```

A list variable on a new `Route` entity, over a new `Visit` fact:

```bash
solverforge generate fact visit
solverforge generate entity route
solverforge generate variable stops --entity Route --kind list --elements visits
```

Scalar-hook and list-metadata flags such as `--candidate-values` or
`--domain cvrp` only write `#[planning_variable(...)]` or
`#[planning_list_variable(...)]` metadata; they project it into
`solverforge.app.toml` and the web-shell UI model. The project compiles only
after you write the Rust they name: the hook function for
`--candidate-values employee_candidates`, or the `VrpSolution` implementation
on the planning solution that `--domain cvrp` requires.

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
| `--pair`    | Penalize conflicting pairs from a self-join on the entity's first planning variable; each unordered pair appears once |
| `--join`    | Penalize entity-fact mismatch with `for_each + join` |
| `--balance` | Generate a load-balance style soft constraint |
| `--reward`  | Reward matching entities with `for_each + filter + reward` |
| `--runs`    | Generate a grouped consecutive-runs collector skeleton |
| `--presence` | Generate a grouped indexed-presence collector skeleton |
| `--collect-vec` | Generate a grouped `collect_vec` collector skeleton |
| `--group-complement` | Generate a grouped complement skeleton |
| `--projected-group` | Generate a projected join plus grouped collector skeleton |

Write options:

| Option        | Meaning |
| ------------- | ------- |
| `-f, --force` | Overwrite the constraint file if it already exists |
| `--pretend`   | Preview changes without writing files |

Choose at most one pattern flag. If no pattern flag is supplied, the command
scans the current domain and opens an interactive wizard. `--balance` and
`--reward` always score soft.

```bash
solverforge generate constraint max_hours --unary --hard
solverforge generate constraint no_overlap --pair
solverforge generate constraint required_skill --join --hard
```

`max_hours` filters single shifts, `no_overlap` pairs shifts that share an
`employee_idx`, and `required_skill` joins each shift to the employee its
`employee_idx` points at.

Every skeleton compiles, but its rule is a placeholder that panics. A solve
fails with `lifecycleState` `FAILED` until you replace it; the panic message
names the function and file to edit. The
[Getting Started](/docs/solverforge-cli/getting-started/#add-constraints) guide
replaces two of them.

### `generate score`

```text
solverforge generate score [OPTIONS] <SCORE_TYPE>
```

`<SCORE_TYPE>` can be `HardSoftScore`, `HardSoftDecimalScore`,
`HardMediumSoftScore`, or `SoftScore`. `BendableScore` is refused: a planning
solution's score must be parseable, and the runtime parses only those four.
`SimpleScore` is not a score type.

The command rewrites the score type on every surface that carries it — the
solution, every `src/constraints/*.rs` module, and the generated contract files
(`src/solver/service.rs`, `src/api/dto.rs`, `src/lib.rs`, `src/mcp/dto.rs`,
`src/mcp/tasks.rs`) — computing all rewrites before it writes any of them, so a
score change cannot leave the project in a state that does not compile. Asking
for the score type the project already uses is a no-op rather than an error.

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

Other `generate` and `destroy` commands also re-render the seed so it matches
the model, but only while the file still starts with the
`// @generated by solverforge-cli: data v1` header. Remove that line once you
write your own demo data, and later commands leave the file alone;
`generate data` still rewrites it when you ask.

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

A candidate-backed group that moves a shift's employee and hour together:

```bash
solverforge generate scalar-group shift_slot --candidates shift_slot_candidates --target Shift.employee_idx --target Shift.hour
```

An assignment-backed group names one nullable scalar variable instead, for
example `--assignment Shift.employee_idx --required-entity required_shift`. A
variable belongs to at most one group.

The command adds a stub for each hook function to the planning solution file
and its phases to the managed `solver.toml` region. Each stub is a `todo!()`
that panics until you write the function.

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
solverforge generate conflict-repair no_overlap --provider repair_no_overlap
```

The constraint must exist; the provider stub `repair_no_overlap` in the
planning solution file is a `todo!()` until you write it.

## `solverforge destroy`

```text
solverforge destroy [OPTIONS] <COMMAND>
```

Removes generated resources and resyncs the app spec, the generated demo data,
and the UI model; the demo-data seed follows the header rule above. Remove
dependents before what they depend on:

1. constraints that read an entity or fact (`destroy constraint`)
2. conflict repairs and scalar groups that name a constraint or variable
3. planning variables, or the entity that owns them
4. facts whose collection a variable ranges over
5. the solution

`destroy` refuses a resource that something else still references, names the
references, and changes nothing: an entity read by constraint files or
targeted by a scalar group, a fact whose collection a planning variable ranges
over, a constraint named by a conflict repair, or a variable targeted by a
scalar group. For example, after the repair and the group are gone but the
three constraints still read `Shift`:

```text
error: cannot destroy entity 'Shift' because source files still reference it: src/constraints/max_hours.rs, src/constraints/no_overlap.rs, src/constraints/required_skill.rs
```

Destroying the solution does not re-render the seed, because no planning
solution remains to render it against. The confirmation flag belongs to the
`destroy` command itself, so place it before the resource subcommand.

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
solverforge destroy --yes conflict-repair no_overlap
solverforge destroy --yes scalar-group shift_slot
solverforge destroy --yes constraint no_overlap
solverforge destroy --yes constraint max_hours
solverforge destroy --yes constraint required_skill
solverforge destroy -y variable --entity Shift hour
solverforge destroy --yes entity shift
solverforge destroy --yes fact employee
```

Without `--yes`, each command asks for confirmation.

## See Also

- [Modeling & Generation](/docs/solverforge-cli/modeling-and-generation/) - how generated files fit together
- [Operations Commands](/docs/solverforge-cli/operations-commands/) - validation, testing, routes, and config helpers
