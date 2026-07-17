---
title: "Modeling Cheat Sheet"
description: "Quick lookup for SolverForge macros, field roles, and modeling decisions."
---

# Modeling Cheat Sheet

Use this page when you need the shortest path from "what am I modeling?" to the
right SolverForge annotation or structure.

## Core macros and field roles

| Item                            | Use it for                         | Notes                                                                 |
| ------------------------------- | ---------------------------------- | --------------------------------------------------------------------- |
| `#[planning_solution]`          | top-level container                | owns facts, entities, and the score                                   |
| `#[planning_entity]`            | solver-mutated records             | tasks, shifts, visits, jobs                                           |
| `#[problem_fact]`               | immutable input data               | workers, depots, skills, rooms                                        |
| `#[planning_id]`                | stable identity                    | put on facts and entities that need identity                          |
| `#[planning_variable(...)]`     | scalar assignment decision         | references a value range by solution-field name                       |
| `#[planning_list_variable(...)]` | ordered assignment decision       | owner stores element indexes in canonical sequence order              |
| `#[problem_fact_collection]`    | fact collections on the solution   | usually `Vec<T>`                                                      |
| `#[planning_entity_collection]` | entity collections on the solution | the main search space                                                 |
| `#[planning_score]`             | current score field                | typically `Option<ScoreType>`                                         |
| `solverforge::planning_model!`  | model manifest                     | keeps separate Rust modules while owning deterministic model metadata |

## Scalar Variable or List Variable?

| Choose          | When the decision is...             | Example                                |
| --------------- | ----------------------------------- | -------------------------------------- |
| scalar variable | one entity picks one value          | a shift picks an employee              |
| list variable   | order or insertion position matters | a vehicle route or task sequence       |
| model with both | both assignment and ordering matter | route planning with assigned operators |

In SolverForge 0.19, an ordered sequence is always a list variable. Scalar
variables are direct one-slot assignments and do not have a chained mode.

The current runtime resolves one `RuntimeModel` per planning model, then
validates and freezes construction, selector, provider, and source bindings into
one immutable search graph before solving. Scalar-only, list-only, mixed, and
dynamic models therefore use the same compiled lifecycle. Generic `FirstFit`
and `CheapestInsertion` handle matching list work, while specialized list
heuristics remain explicit opt-in phases.

## Fast rules of thumb

- facts are immutable reference data
- entities are the records the solver changes
- the score lives on the solution, not on each entity
- `value_range_provider = "field_name"` points at a solution collection
- use `allows_unassigned = true` when `None` is a legitimate state
- use `candidate_values` or `value_candidate_limit` when scalar value
  neighborhoods must be bounded
- use `nearby_value_candidates` or `nearby_entity_candidates` before configuring
  nearby scalar selectors
- use `construction_entity_order_key` and `construction_value_order_key` only
  for construction-phase ordering
- use `ScalarGroup::assignment(...)` when nullable scalar construction must
  cover required slots and respect capacity keys
- derive inverse, index, previous, and next views from a list variable instead
  of storing a second sequence topology
- keep domain-specific helper methods in ordinary Rust impl blocks

## Optional assignment

With `allows_unassigned = true`, the stock runtime keeps optional-assignment
semantics all the way through construction and local search:

- construction can keep `None` when it is the best legal baseline
- later moves can revisit previously completed optional slots
- local search can both assign and unassign those variables

## Scalar Hooks

Scalar runtime metadata is descriptor-addressed by descriptor index and variable
name. Public Rust aliases can exist at the `planning_model!` boundary, but
solver configuration targets canonical descriptor names such as `Task.worker`.

Nearby scalar distance meters rank or filter bounded candidates; they are not
candidate-discovery hooks. Construction order keys are evaluated against the
live working solution during construction and do not change local-search order.

## Minimal shape

```text
PlanningSolution
├── problem_fact_collection
├── planning_entity_collection
└── planning_score

PlanningEntity
└── planning_variable(value_range_provider = "facts_or_values")
```

## When to leave the cheat sheet

- Go to [Docs: Domain Modeling](/docs/solverforge/modeling/) for full examples.
- Go to [Extend the Domain](/reference/extend-domain/) when the scaffold stops
  matching your real app.
- Go to [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
  for one concrete worked example built on top of `solverforge-cli`.
- Go to [SolverForge Lessons Use Case](/docs/getting-started/solverforge-lessons-use-case/)
  for a scalar model with two planning variables on one entity.
- Go to [SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/)
  for a list-variable routing example with maps and retained jobs.
