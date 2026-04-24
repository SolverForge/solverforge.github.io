---
title: "Modeling Cheat Sheet"
description: "Quick lookup for SolverForge macros, field roles, and modeling decisions."
---

# Modeling Cheat Sheet

Use this page when you need the shortest path from "what am I modeling?" to the
right SolverForge annotation or structure.

## Core macros and field roles

| Item | Use it for | Notes |
|---|---|---|
| `#[planning_solution]` | top-level container | owns facts, entities, and the score |
| `#[planning_entity]` | solver-mutated records | tasks, shifts, visits, jobs |
| `#[problem_fact]` | immutable input data | workers, depots, skills, rooms |
| `#[planning_id]` | stable identity | put on facts and entities that need identity |
| `#[planning_variable(...)]` | scalar assignment decision | references a value range by solution-field name |
| `#[problem_fact_collection]` | fact collections on the solution | usually `Vec<T>` |
| `#[planning_entity_collection]` | entity collections on the solution | the main search space |
| `#[planning_score]` | current score field | typically `Option<ScoreType>` |

## Scalar Variable or List Variable?

| Choose | When the decision is... | Example |
|---|---|---|
| scalar variable | one entity picks one value | a shift picks an employee |
| list variable | order or insertion position matters | a vehicle route or task sequence |
| model with both | both assignment and ordering matter | route planning with assigned operators |

The current runtime builds one `ModelContext` per planning model, so mixed
models are first-class. Generic `FirstFit` and `CheapestInsertion` already
handle matching list work, while specialized list heuristics stay explicit
opt-in phases.

## Fast rules of thumb

- facts are immutable reference data
- entities are the records the solver changes
- the score lives on the solution, not on each entity
- `value_range = "field_name"` points at a solution collection
- use `allows_unassigned = true` when `None` is a legitimate state
- keep domain-specific helper methods in ordinary Rust impl blocks

## Optional assignment

With `allows_unassigned = true`, the stock runtime keeps optional-assignment
semantics all the way through construction and local search:

- construction can keep `None` when it is the best legal baseline
- later moves can revisit previously completed optional slots
- local search can both assign and unassign those variables

## Minimal shape

```text
PlanningSolution
├── problem_fact_collection
├── planning_entity_collection
└── planning_score

PlanningEntity
└── planning_variable(value_range = "facts_or_values")
```

## When to leave the cheat sheet

- Go to [Docs: Domain Modeling](/docs/solverforge/modeling/) for full examples.
- Go to [Extend the Domain](/reference/extend-domain/) when the scaffold stops
  matching your real app.
- Go to [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
  for one concrete worked example built on top of `solverforge-cli`.
