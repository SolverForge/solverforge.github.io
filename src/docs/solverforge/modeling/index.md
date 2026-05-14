---
title: "Domain Modeling"
linkTitle: "Domain Modeling"
weight: 30
description: >
  Define planning solutions, entities, and problem facts using Rust derive macros.
---

SolverForge uses derive macros to turn your Rust structs into a planning domain. There are three key concepts:

| Concept               | Macro                  | Purpose                                                        |
| --------------------- | ---------------------- | -------------------------------------------------------------- |
| **Planning Solution** | `#[planning_solution]` | The top-level container — holds entities, facts, and the score |
| **Planning Entity**   | `#[planning_entity]`   | Something the solver changes (assigns variables to)            |
| **Problem Fact**      | `#[problem_fact]`      | Immutable input data the solver reads but doesn't modify       |

```
Planning Solution
├── problem_fact_collection  → Vec<ProblemFact>   (inputs)
├── planning_entity_collection → Vec<Entity>      (solver changes these)
└── planning_score           → Option<ScoreType>   (current quality)

Planning Entity
└── planning_variable(value_range_provider = "facts")       (decision field)
```

## How It Works

1. Annotate your structs with the appropriate derive macros
2. Mark fields with attribute macros to tell the solver their role
3. The macros generate trait implementations that the solver uses at runtime

The derive macros generate implementations of `PlanningSolution`,
`PlanningEntity`, and `ProblemFact` automatically. In the common stock runtime,
planning variables name their value source with `value_range_provider = "solution_field"`
and `#[planning_solution]` generates typed stream source methods such as
`factory.for_each(Schedule::shifts())`.

Current generated domains also declare the model boundary with
`solverforge::planning_model!` in `src/domain/mod.rs`:

```rust
solverforge::planning_model! {
    root = "src/domain";

    mod employee;
    mod shift;
    mod schedule;

    pub use employee::Employee;
    pub use shift::Shift;
    pub use schedule::Schedule;
}
```

That manifest is the canonical place where the runtime validates the model and
derives scalar/list metadata across separate Rust files. Public Rust aliases are
accepted at the manifest boundary, including `type Alias = Type;` and
`pub use module::Type as Alias;`, but solver configuration still targets the
canonical descriptor type name such as `Task.worker`.

Scalar runtime metadata is descriptor-addressed. The generated compact
`variable_index` remains an internal getter/setter dispatch index, while runtime
hook attachment and ordering use the descriptor index plus variable name. That
means Rust module declaration order is not a modeling contract.

## Sections

- **[Planning Solutions](/docs/solverforge/modeling/planning-solutions/)** — The top-level container struct
- **[Planning Entities](/docs/solverforge/modeling/planning-entities/)** — Structs the solver modifies
- **[Problem Facts](/docs/solverforge/modeling/problem-facts/)** — Immutable input data
- **[List Variables](/docs/solverforge/modeling/list-variables/)** — Ordered sequence variables for routing/sequencing

## See Also

- [docs.rs/solverforge](https://docs.rs/solverforge) — Full API reference
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/) — Concrete worked example built on the generic CLI scaffold
- [SolverForge Lessons Use Case](/docs/getting-started/solverforge-lessons-use-case/) — Two scalar planning variables on one lesson entity
