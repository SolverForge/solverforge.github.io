---
title: Modeling & Generation
description: >
  Facts, entities, scalar variables, list variables, constraints, data
  generation, model-resource generation, and destroy flows in solverforge-cli.
weight: 3
---

# Modeling & Generation

`solverforge-cli` starts with one neutral shell, then grows the actual planning
model through generator commands and normal Rust edits.

The current workflow is:

1. define facts
2. define entities
3. add scalar or list planning variables
4. add or replace constraints
5. declare scalar groups or conflict repairs when the runtime model needs them
6. regenerate demo data
7. iterate on solver behavior and frontend presentation

## Generator Ownership

The CLI writes code, but not every generated line has the same ownership model.

| Surface | CLI behavior | Your responsibility |
| ------- | ------------ | ------------------- |
| `src/domain/*.rs` | creates structs and managed planning-variable blocks | keep real domain fields and semantics coherent |
| `src/domain/mod.rs` | maintains module exports and `planning_model!` wiring | avoid deleting managed exports by hand |
| `src/domain/plan.rs` | patches collections, score field, and solution metadata | keep solution-level custom fields intentional |
| `src/constraints/*.rs` | creates skeleton stream patterns | replace placeholder predicates and weights |
| `solverforge.app.toml` | syncs structural metadata | treat as derived scaffold contract |
| `static/generated/ui-model.json` | rewrites frontend model metadata | do not hand-edit |
| `solver.toml` | starts with defaults and can receive model-resource refs | own search policy explicitly |

When a generator uses managed markers, keep the `@solverforge:begin` and
`@solverforge:end` comments intact. They are the boundary that lets future CLI
operations patch generated regions without taking over the whole file.

## Choosing The Next Generator

| You need... | Command |
| ----------- | ------- |
| immutable input data | `solverforge generate fact ...` |
| a mutable planning record | `solverforge generate entity ...` |
| one selected value per entity | `solverforge generate variable ... --kind scalar ...` |
| an ordered sequence owned by an entity | `solverforge generate variable ... --kind list ...` |
| a hard or soft scoring rule skeleton | `solverforge generate constraint ...` |
| coupled scalar construction or grouped scalar search | `solverforge generate scalar-group ...` |
| constraint-specific repair moves | `solverforge generate conflict-repair ...` |
| deterministic sample data | `solverforge generate data --size ...` |
| a different score type | `solverforge generate score ...` |

## Facts

Create a problem fact:

```bash
solverforge generate fact resource --field category:String --field load:i32
```

What this changes:

- creates `src/domain/resource.rs`
- exports the new type from `src/domain/mod.rs`
- patches the planning solution in `src/domain/plan.rs`
- syncs `solverforge.app.toml`
- refreshes `static/generated/ui-model.json`

Useful flags:

- `--field <NAME:TYPE>` - repeatable extra fields
- `--force` - overwrite an existing fact file
- `--pretend` - preview without writing changes

Generated facts include:

- `#[problem_fact]`
- a `#[planning_id]` field
- a `name` field
- a `new(...)` constructor
- a small construction test

## Entities

Create a planning entity:

```bash
solverforge generate entity task --field label:String --field priority:i32
```

Or create the entity and its first scalar variable together:

```bash
solverforge generate entity shift --planning-variable employee_idx --field start:String --field duration:i32
```

Useful flags:

- `--planning-variable <FIELD>` - create the first scalar variable immediately
- `--field <NAME:TYPE>` - repeatable extra fields
- `--force` - overwrite an existing entity file
- `--pretend` - preview without writing changes

If an entity has no scalar or list variables yet, `solverforge check` warns that
the solver cannot optimize it.

## Scalar Variables

The canonical one-value assignment kind is `scalar`.

```bash
solverforge generate variable resource_idx \
  --entity Task \
  --kind scalar \
  --range resources \
  --allows-unassigned
```

This patches the entity file inside the managed blocks and produces a field like
this:

```rust
#[planning_variable(value_range_provider = "resources", allows_unassigned = true)]
pub resource_idx: Option<usize>,
```

Use scalar variables when each entity holds zero or one selected value from a
problem-fact collection.

Useful flags:

- `--entity <TYPE>` - target entity struct name
- `--kind scalar` - scalar assignment variable
- `--range <FACT_COLLECTION>` - value range collection name
- `--allows-unassigned` - allow `None`
- `--candidate-values <FN_PATH>` - app-owned candidate-value hook
- `--nearby-value-candidates <FN_PATH>` - app-owned nearby value hook
- `--nearby-entity-candidates <FN_PATH>` - app-owned nearby entity hook
- `--nearby-value-distance-meter <FN_PATH>` - app-owned value distance meter
- `--nearby-entity-distance-meter <FN_PATH>` - app-owned entity distance meter
- `--construction-entity-order-key <FN_PATH>` - app-owned construction entity ordering
- `--construction-value-order-key <FN_PATH>` - app-owned construction value ordering

Hook flags only write modeling metadata and keep `solverforge.app.toml`
synchronized. The referenced Rust functions are still application code.

`standard` is not a variable kind in the current CLI. It remains only as the
default demo data size label.

## List Variables

Create a list variable when each entity owns an ordered collection:

```bash
solverforge generate variable stops \
  --entity Route \
  --kind list \
  --elements visits
```

This generates a field like:

```rust
#[planning_list_variable(element_collection = "visits")]
pub stops: Vec<usize>,
```

Use list variables for route-style, sequence, or ordering problems where the
entity holds multiple selected elements in order.

Useful flags:

- `--entity <TYPE>` - target entity struct name
- `--kind list` - list variable
- `--elements <FACT_COLLECTION>` - element collection name

## Models With Both Variable Families

There is no separate third variable kind. A mixed application is simply a
project whose `solverforge.app.toml` ends up with both scalar and list entries
under `[[variables]]`.

That is a core design decision of the CLI:

- scaffold once
- add scalar and list variables when the domain needs them
- keep the generated shell neutral

## Solution and Score

Fresh projects already include a `Plan` solution using `HardSoftScore`.

If you need to regenerate or rename the planning solution:

```bash
solverforge generate solution schedule --score HardSoftScore
```

If the solution exists and you only want to change the score type:

```bash
solverforge generate score HardSoftDecimalScore
```

The current `generate score` command accepts score types such as:

- `HardSoftScore`
- `HardSoftDecimalScore`
- `HardMediumSoftScore`
- `SimpleScore`

## Constraints

Generate a constraint skeleton:

```bash
solverforge generate constraint no_overlap --pair --hard
```

Constraint templates are pattern-based. Pick the shape that matches the logic
you want to write:

| Flag | Pattern | Typical use |
| ---- | ------- | ----------- |
| `--unary` | `for_each + filter + penalize` | single-entity violations |
| `--pair` | pairwise comparison | collisions and overlap checks |
| `--join` | entity-fact comparison | requirement matching |
| `--balance` | balance stream | distribution fairness |
| `--reward` | `for_each + filter + reward` | preferred states |
| `--hard` | hard score impact | must-hold rules |
| `--soft` | soft score impact | optimization preferences |

Useful flags:

- `--force` - overwrite an existing constraint
- `--pretend` - preview without writing changes

Important: generated constraint files are not finished logic. They are
deliberately scaffolded placeholders. Replace the TODO text and placeholder
conditions before you treat the constraint as real.

## Scalar Groups

Scalar groups describe coupled scalar construction and search resources that
the runtime can consume from `solver.toml`.

Assignment-backed group:

```bash
solverforge generate scalar-group required_assignment \
  --assignment Task.resource_idx \
  --required-entity required_task \
  --capacity-key resource_capacity
```

Candidate-backed group:

```bash
solverforge generate scalar-group paired_assignment \
  --candidates paired_candidates \
  --target Task.primary_idx \
  --target Task.secondary_idx
```

Useful flags:

- `--assignment <ENTITY.FIELD>` - declare one nullable scalar assignment target
- `--candidates <FN_PATH>` - app-owned grouped candidate provider
- `--target <ENTITY.FIELD>` - candidate-backed scalar target; repeatable
- `--required-entity <FN_PATH>` - assignment hook for required nullable slots
- `--capacity-key <FN_PATH>` - assignment hook for capacity buckets
- `--assignment-rule <FN_PATH>` - assignment hook for legal pairwise assignments
- `--position-key <FN_PATH>` and `--sequence-key <FN_PATH>` - assignment sequence hooks
- `--entity-order <FN_PATH>` and `--value-order <FN_PATH>` - construction ordering hooks
- `--value-candidate-limit <N>`, `--group-candidate-limit <N>`, and
  `--max-moves-per-step <N>` - generated limit metadata
- `--skip-solver-config` - skip the generated `solver.toml` region

By default the command writes scalar-group metadata to `solverforge.app.toml`,
adds hook stubs and `ScalarGroup` declarations to the planning solution, and
synchronizes grouped construction and search refs in the CLI-managed
`# @solverforge:begin solver-config` region.

## Conflict Repairs

Conflict repairs connect a named constraint to an app-owned repair provider:

```bash
solverforge generate conflict-repair required_assignment \
  --provider repair_required_assignment
```

Useful flags:

- `--provider <FN_PATH>` - required app-owned repair provider
- `--selector compound|conflict` - generated selector kind; default `compound`
- `--max-matches-per-step <N>` - limit matched conflicts
- `--max-repairs-per-match <N>` - limit repair candidates per conflict
- `--max-moves-per-step <N>` - limit emitted repair moves
- `--include-soft-matches` - allow soft-constraint conflicts
- `--skip-solver-config` - skip the generated `solver.toml` phase

Constraint IDs are exact snake_case IDs. Destroy refuses to remove a conflict
repair while user-authored `solver.toml` still references it.

## Demo Data

Generate or refresh compiler-owned demo data:

```bash
solverforge generate data
solverforge generate data --size large
solverforge generate data --mode stub
```

Supported sizes:

- `small`
- `standard`
- `large`

Supported modes:

- `sample` - generated generic deterministic sample values
- `stub` - minimum structural placeholder output

What happens on each run:

- `src/data/data_seed.rs` is rewritten
- `solverforge.app.toml` stores the selected default size
- `static/generated/ui-model.json` is refreshed from the app spec

The generated wrapper in `src/data/mod.rs` keeps the rest of the application
stable while the seed file is regenerated underneath it.

## Destroy Flows

Generators are not one-way only. You can remove scaffolded resources:

```bash
solverforge destroy entity task
solverforge destroy variable --entity Task resource_idx
solverforge destroy fact resource
solverforge destroy constraint no_overlap
solverforge destroy scalar-group required_assignment
solverforge destroy conflict-repair required_assignment
solverforge destroy solution
```

Use `--yes` or `-y` on the `destroy` command to skip the confirmation prompt:

```bash
solverforge destroy --yes constraint no_overlap
```

Destroy operations update the same managed surfaces used by generation:

- domain exports
- planning solution collections
- constraint registry
- synchronized app metadata
- CLI-managed solver config refs for scalar groups and conflict repairs

## Best Practices

- Treat `src/domain/` and `src/constraints/` as the real source of truth.
- Leave the `@solverforge:begin` and `@solverforge:end` markers intact.
- Use `solverforge check` after structural generation changes.
- Use `solverforge info` to verify the model summary after edits.
- Re-run `solverforge generate data` when the model shape changes enough that
  the current demo seed is no longer representative.
