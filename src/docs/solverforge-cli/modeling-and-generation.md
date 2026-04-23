---
title: Modeling & Generation
description: >
  Facts, entities, scalar variables, list variables, constraints, data
  generation, compound scaffolds, and destroy flows in solverforge-cli.
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
5. regenerate demo data
6. iterate on solver behavior and frontend presentation

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
#[planning_variable(value_range = "resources", allows_unassigned = true)]
pub resource_idx: Option<usize>,
```

Use scalar variables when each entity holds zero or one selected value from a
problem-fact collection.

Useful flags:

- `--entity <TYPE>` - target entity struct name
- `--kind scalar` - scalar assignment variable
- `--range <FACT_COLLECTION>` - value range collection name
- `--allows-unassigned` - allow `None`

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

## Mixed Apps

There is no separate "mixed starter". A mixed application is simply a project
whose `solverforge.app.toml` ends up with both scalar and list entries under
`[[variables]]`.

That is a core design decision of the CLI:

- scaffold once
- choose scalar, list, or mixed later
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

## Compound Scaffolding

When you already know the first entity, first field, and first constraint, use
the compound generator:

```bash
solverforge generate scaffold shift employee_idx:usize --entity --constraint no_overlap --pair
```

Behavior:

- `<NAME>` is the entity name
- the first `name:Type` field becomes the planning variable seed

Options:

- `--entity`
- `--constraint <CONSTRAINT_NAME>`
- `--pair`
- `--force`
- `--pretend`

## Destroy Flows

Generators are not one-way only. You can remove scaffolded resources:

```bash
solverforge destroy entity task
solverforge destroy variable --entity Task resource_idx
solverforge destroy fact resource
solverforge destroy constraint no_overlap
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

## Best Practices

- Treat `src/domain/` and `src/constraints/` as the real source of truth.
- Leave the `@solverforge:begin` and `@solverforge:end` markers intact.
- Use `solverforge check` after structural generation changes.
- Use `solverforge info` to verify the model summary after edits.
- Re-run `solverforge generate data` when the model shape changes enough that
  the current demo seed is no longer representative.
