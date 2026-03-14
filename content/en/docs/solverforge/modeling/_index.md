---
title: "Domain Modeling"
linkTitle: "Domain Modeling"
weight: 30
description: >
  Define planning solutions, entities, and problem facts using Rust derive macros.
---

SolverForge uses derive macros to turn your Rust structs into a planning domain. There are three key concepts:

| Concept | Macro | Purpose |
|---------|-------|---------|
| **Planning Solution** | `#[planning_solution]` | The top-level container — holds entities, facts, and the score |
| **Planning Entity** | `#[planning_entity]` | Something the solver changes (assigns variables to) |
| **Problem Fact** | `#[problem_fact]` | Immutable input data the solver reads but doesn't modify |

```
Planning Solution
├── problem_fact_collection  → Vec<ProblemFact>   (inputs)
├── planning_entity_collection → Vec<Entity>      (solver changes these)
├── value_range_provider     → Vec<Value>          (possible values)
└── planning_score           → Option<ScoreType>   (current quality)
```

## How It Works

1. Annotate your structs with the appropriate derive macros
2. Mark fields with attribute macros to tell the solver their role
3. The macros generate trait implementations that the solver uses at runtime

The derive macros generate implementations of `PlanningSolution`, `PlanningEntity`, and `ProblemFact` traits automatically — you never implement these traits by hand.

## Sections

- **[Planning Solutions](planning-solutions/)** — The top-level container struct
- **[Planning Entities](planning-entities/)** — Structs the solver modifies
- **[Problem Facts](problem-facts/)** — Immutable input data
- **[List Variables](list-variables/)** — Ordered sequence variables for routing/sequencing

## See Also

- [docs.rs/solverforge](https://docs.rs/solverforge) — Full API reference
- [Employee Scheduling (Rust)](/docs/getting-started/employee-scheduling-rust/) — Complete worked example
