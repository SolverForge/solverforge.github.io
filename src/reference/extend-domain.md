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

| Put it in the domain model                       | Put it somewhere else                                            |
| ------------------------------------------------ | ---------------------------------------------------------------- |
| entities the solver changes                      | HTTP handlers, database code, and CLI orchestration              |
| immutable input facts                            | page components and frontend formatting                          |
| planning variables and score fields              | ad-hoc migration logic                                           |
| derived helpers that explain the model           | solver search policy that belongs in `solver.toml`               |
| fixtures and validation helpers for this problem | generic runtime internals that should stay in SolverForge crates |

## Choose the right modeling primitive

| Use                       | When it fits                                         | Typical example                            |
| ------------------------- | ---------------------------------------------------- | ------------------------------------------ |
| problem facts             | immutable reference data                             | employees, skills, depots, rooms, vehicles |
| planning entities         | records whose assignment or ordering can change      | shifts, visits, tasks, jobs                |
| scalar planning variables | one entity chooses one value from a range            | a shift picks an employee                  |
| list planning variables   | order matters and insertion/removal is the core move | route stops, job sequences, task chains    |

Use mixed models when the problem really has both assignment and sequencing.
The current runtime builds one `RuntimeModel` per planning model, and the stock
construction heuristics already understand mixed scalar-plus-list problems.
List variables are the planning primitive for an
owned sequence; do not encode ordered work as a chained scalar predecessor.

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

| You need to add...                 | Typical change                                                                                       |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------- |
| another planning dimension         | add a new fact collection and reference it from entity variables                                     |
| optional assignment                | use `allows_unassigned = true` on the scalar variable                                                |
| ordering behavior                  | introduce a planning list and list-aware constraints                                                 |
| bounded scalar neighborhoods       | declare `candidate_values`, `nearby_value_candidates`, or `nearby_entity_candidates` on the variable |
| scalar construction ordering       | declare `construction_entity_order_key` or `construction_value_order_key` on the variable            |
| required nullable-slot coverage    | declare an assignment-backed `ScalarGroup` and select it from `solver.toml`                          |
| stock CVRP route ownership         | declare `domain = "cvrp"` on the list variable instead of repeating stock hook paths                 |
| richer scoring context             | add immutable facts or derived helper methods instead of shoving logic into constraints              |
| validation or import normalization | add app-side builders or conversion layers before solving                                            |

## Legal Domains Versus Search Hints

`value_range_provider` names a solution collection for a shared legal range or
an entity `Vec<usize>` field for that entity's allowed indexes. Construction and
every scalar move family, including swap, nearby swap, and pillar swap, enforce
the receiving entity's domain. Use `#[planning_pin]` to preserve an input value;
a one-value domain is not a pin.

`candidate_values` supplies an ordered bounded neighborhood for construction,
change, pillar change, and ruin-recreate. It does not narrow legality: swap
families exchange current values and can receive a value outside this hint.
Express forbidden assignments in the legal domain, not in `candidate_values`.
See [Planning Entities](/docs/solverforge/modeling/planning-entities/) for a
per-entity domain declaration.

Configured list-element shadows are derived mutations, even when elements live
in a fact collection. Generated sources retain their change metadata so rules
reading owner, index, previous, next, or cascading state score incrementally.
Keep custom edits on the director's paired notification path; see
[List Shadows](/docs/solverforge/modeling/list-variables/#shadow-updates).

## Assignment-Backed Scalar Groups

Register a model-owned `Vec<ScalarGroup<Schedule>>` provider with
`#[planning_solution(scalar_groups = "scalar_groups")]`. Declare an assignment
using `ScalarGroup::assignment("shift_assignment",
Schedule::shifts().scalar("employee_idx"))`; add `with_required_entity` for
mandatory rows, `with_capacity_key` for shared resource capacity, and ordering
hooks when the selected heuristic requires them.

Field-level `allows_unassigned` permits `None`; the group's required-row
predicate separately determines which rows must be assigned before publication.
Assignment-owned slots use named grouped construction and the configured
`grouped_scalar_move_selector`, not generic scalar or conflict-repair selectors.
Keeping an optional row unassigned completes its exact group-slot decision,
not the optional pass. Completed roots are skipped before candidate-domain reads
or move generation, so later rows retain their budget. Assigned occupants remain
available for required augmenting rematches.

Model-owned `ScalarGroup::with_limits(...)` separates value candidates, grouped
candidates, per-step moves, augmenting depth, and rematch size. The assignment
defaults are depth 3 and rematch size 4, with rematch size clamped to at least 2.
See [Construction](/docs/solverforge/solver/construction/) for the complete model
and config example.

## Filter Nullable Sources Before Equality Joins

On the first unary keyed equality cross-join, put a unary
`.filter(|row| row.employee_idx.is_some())` before `.join(...)` on every unary
input whose key requires an assignment. Left membership is checked before key
extraction and pair creation; a filtered unary right target retains its own
membership. Original indexes and incremental change metadata remain intact.
A pair filter after the join cannot protect key extraction.

This left-source pushdown does not apply to comparison, overlap,
composed-condition, predicate, or same-source self-join dispatch. Fluent right
join targets implement `CollectionExtract`; arbitrary compatible derived
producers instead feed low-level `JoinNode` inputs. See
[Constraint Streams](/docs/solverforge/constraints/constraint-streams/) for
examples and the cross-Penta continuation filter limitation.

## Guided Local Search Hooks

Use `search_entity_order_key = "fn_name"` to rank ordinary scalar change/swap
entities and `search_value_order_key = "fn_name"` to rank ordinary change
values. Their signatures mirror construction keys: `fn(&S, &Entity) -> i64`
and `fn(&S, &Entity, value: usize) -> i64`. Lower keys come first; ties preserve
the seeded enumeration order. Variables without the hooks retain their unguided
walk. Construction-order keys remain construction-only, while nearby hooks
shape bounded neighborhoods and candidate metrics order complete leaf streams.

Candidate, ordering, legality, and ownership callbacks may read all of `S`.
Their entity arguments do not establish row-local dependencies. A committed
change elsewhere may change their outputs; keep callback behavior deterministic
for the same input state and seed.

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
- Derive owner, index, previous, and next lookup fields from the owner list;
  do not store a second route topology.
- Treat nearby scalar hooks, scalar candidate hooks, and construction-order keys
  as model capabilities. Solver config consumes them; it does not infer them.
- Use `#[planning_list_variable(element_collection = "...", domain = "cvrp")]`
  for stock CVRP route lists. Omit the profile and wire `route_hooks` /
  `savings_hooks` explicitly only when the route domain or construction pruning
  policy is genuinely custom.
- Keep solver config targets on canonical descriptor names even if the Rust
  manifest uses public aliases.

## See also

- [Modeling Cheat Sheet](/reference/modeling-cheat-sheet/)
- [Docs: Domain Modeling](/docs/solverforge/modeling/)
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/) for a concrete end-to-end example
