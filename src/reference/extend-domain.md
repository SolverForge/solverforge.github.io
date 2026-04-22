---
title: "Extend the Domain"
description: "Engineer-facing reference for growing a SolverForge domain model after scaffolding."
---

# Extend the Domain

Treat the generated scaffold as a starter shell, not the center of gravity. The
real domain model belongs in your application code: the types, invariants, and
derived helpers that describe the planning problem you actually need to solve.

## What this page is for

- deciding what belongs in facts, entities, solutions, and app-level helpers
- growing beyond the stock scaffold without turning it into a dumping ground
- choosing between scalar planning variables and planning lists
- keeping SolverForge-specific annotations narrow while the domain stays readable

## Keep the boundary crisp

| Put it in the domain model | Put it somewhere else |
|---|---|
| entities the solver changes | HTTP handlers, database code, and CLI orchestration |
| immutable input facts | page components and frontend formatting |
| planning variables and score fields | ad-hoc migration logic |
| derived helpers that explain the model | solver search policy that belongs in `solver.toml` |
| fixtures and validation helpers for this problem | generic runtime internals that should stay in SolverForge crates |

## Choose the right modeling primitive

| Use | When it fits | Typical example |
|---|---|---|
| problem facts | immutable reference data | employees, skills, depots, rooms, vehicles |
| planning entities | records whose assignment or ordering can change | shifts, visits, tasks, jobs |
| standard planning variables | one entity chooses one value from a range | a shift picks an employee |
| list planning variables | order matters and insertion/removal is the core move | route stops, job sequences, task chains |

Use mixed models when the problem really has both assignment and sequencing.
The current runtime builds one `ModelContext` per planning model, and the stock
construction heuristics already understand mixed scalar-plus-list problems.

## A practical growth path

1. Start from the scaffolded shell and keep its generated files thin.
2. Add the real facts, entities, and variables that match production data.
3. Move sample data, validation, and fixtures next to the app modules that own
   the domain.
4. Split large models into app modules once the domain stops fitting cleanly in
   one file.
5. Keep the solver-specific annotations close to the fields they describe, but
   keep problem-specific behavior in ordinary Rust methods and modules.

## Common extensions

| You need to add... | Typical change |
|---|---|
| another planning dimension | add a new fact collection and reference it from entity variables |
| optional assignment | use `allows_unassigned = true` on the standard variable |
| ordering behavior | introduce a planning list and list-aware constraints |
| richer scoring context | add immutable facts or derived helper methods instead of shoving logic into constraints |
| validation or import normalization | add app-side builders or conversion layers before solving |

## Suggested module layout

```text
src/
  domain/
    facts.rs
    entities.rs
    solution.rs
    fixtures.rs
    validation.rs
  constraints/
  solver/
```

That is not a framework requirement. It is a good default when the scaffold is
no longer tiny.

## Rules of thumb

- Keep problem facts immutable.
- Keep entities focused on solver-owned state plus the fields needed to reason
  about that state.
- Prefer derived helper methods over leaking normalization code into
  constraints.
- Treat the scaffold as disposable starter code once the app has a real shape.
- Reach for list variables when order is the point, not when a single scalar
  assignment would do.

## See also

- [Modeling Cheat Sheet](/reference/modeling-cheat-sheet/)
- [Docs: Domain Modeling](/docs/solverforge/modeling/)
- [Employee Scheduling tutorial](/docs/getting-started/employee-scheduling-rust/)
