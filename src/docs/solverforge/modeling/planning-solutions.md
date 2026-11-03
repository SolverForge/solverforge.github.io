---
title: "Planning Solutions"
linkTitle: "Planning Solutions"
weight: 10
description: >
  The top-level container that holds entities, facts, and the current score.
---

A **planning solution** is the root struct that represents your entire problem
and its current solution state. It owns your entity collections, problem facts,
and score field.

## The `#[planning_solution]` Macro

From `src/domain/schedule.rs` of the model on
[Domain Modeling](/docs/solverforge/modeling/), which also shows the
`planning_model!` manifest every solution needs:

<!-- rust: crate=modeling excerpt -->
```rust
#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

The `constraints` parameter is optional, but it is what enables the generated
`Solvable` and `Analyzable` implementations used by the stock runtime. Other
optional parameters:

- `solver_toml = "../../solver.toml"` embeds that solver configuration file
  at compile time; the path is relative to the source file. Without it, or a `SolverConfig` passed
  at solve time, the solver uses its defaults and does not read a
  `solver.toml` from the working directory.
- `scalar_groups = "crate::domain::scalar_groups"` names the function that
  declares candidate-backed or assignment-backed `ScalarGroup` values for
  grouped construction and grouped scalar local search.

## Field Attributes

### `#[planning_entity_collection]`

Marks a `Vec<T>` field containing planning entities. The solver iterates these
collections to find variables to change.

<!-- rust: crate=modeling excerpt -->
```rust
#[planning_entity_collection]
pub shifts: Vec<Shift>,
```

### `#[problem_fact_collection]`

Marks a `Vec<T>` field containing problem facts. Input data is immutable during
solving; configured list-shadow fields on elements are derived state maintained
by the director, and their generated stream sources react to those updates.

<!-- rust: crate=modeling excerpt -->
```rust
#[problem_fact_collection]
pub employees: Vec<Employee>,
```

### `#[planning_score]`

Marks the field that holds the current solution quality. Must be `Option<ScoreType>`.

<!-- rust: crate=modeling excerpt -->
```rust
#[planning_score]
pub score: Option<HardSoftScore>,
```

Supported score types: `SoftScore`, `HardSoftScore`, `HardMediumSoftScore`, `HardSoftDecimalScore`, `BendableScore`.

## Generated Helpers

When `constraints = "..."` is present, `#[planning_solution]` also generates:

- Collection source methods such as `Schedule::shifts()` and
  `Schedule::employees()`, so constraints can start from
  `factory.for_each(Schedule::shifts())` without ad hoc slice closures
- `Solvable` for retained-job solving through `SolverManager::solve()`, including
  the typed search declaration consumed by the runtime compiler
- `Analyzable` for score breakdowns via `analyze()`

Before candidate work begins, generated solving resolves that declaration and
the model's descriptor/runtime slots into one immutable graph. Missing targets,
capabilities, providers, stable list sources, or invalid selector composition
surface as runtime-build errors instead of being discovered halfway through a
phase.

Generated source methods are the default way to start constraints
over planning entity and problem fact collections. See
[Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/)
for the full method contract and the lower-level `for_each(...)` escape hatch.

For advanced list-shadow workflows, the struct can also carry
`#[shadow_variable_updates(...)]`. When present, the macro generates
`PlanningSolution::update_entity_shadows(...)`, `update_all_shadows()`,
`list_shadow_elements(...)`, `clear_list_shadows(...)`, and `list_shadow_source(...)`
overrides directly on the solution type, and the stock `ScoreDirector` calls
those hooks automatically during solving and score analysis. The update
configuration can maintain `inverse_field`, `index_field`, `previous_field`,
and `next_field` views of the canonical owner list before cascading,
aggregate, compute, and post-update listeners run.

## Requirements

- Must be a named Rust struct
- Must have exactly one `#[planning_score]` field
- Must have at least one `#[planning_entity_collection]` field for stock solving

Common value-range setup lives on the entity side, for example
`#[planning_variable(value_range_provider = "employees")]`.

## See Also

- [Planning Entities](/docs/solverforge/modeling/planning-entities/) — What the solver changes
- [Score Types](/docs/solverforge/constraints/score-types/) — Available score types
