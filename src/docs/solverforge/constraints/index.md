---
title: "Constraints"
linkTitle: "Constraints"
weight: 40
description: >
  Define business rules using constraint streams, joiners, collectors, and score types.
---

Constraints are the business rules that define what makes a good solution.
SolverForge uses a **constraint streams API** - a declarative, composable way to
express rules that reads like a pipeline of filters and transformations.

## How Constraints Work

1. **Select** entities or facts from your solution using generated source methods
2. **Filter, project, join, or group** to narrow down the matches
3. **Penalize or reward** to affect the score
4. **Name** the constraint with `.named()`

```rust
let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

factory.for_each(Schedule::shifts())                              // Select all shifts
    .filter(|s| s.employee_idx.is_none())     // Keep unassigned ones
    .penalize(HardSoftScore::ONE_HARD)        // Penalize each
    .named("Unassigned shift")                // Finalize
```

Constraints are returned as a tuple implementing `ConstraintSet<S, Sc>`, which
the solver evaluates incrementally as it explores moves. Generated solution
sources such as `Schedule::shifts()` preserve source metadata for localized
incremental updates. Projected streams can emit retained scoring rows from one
source or one joined pair, grouped streams can use collectors such as
`consecutive_runs(...)`, `collect_vec(...)`, and `indexed_presence(...)`, and
direct cross joins can group joined pairs without projecting them first. Direct
cross-join groups can also call `complement(...)` against generated target
sources, and filtered keyed joins retain the filter contract on both sides of
the join.

Annotate reusable constraint functions with `#[solverforge_constraints]` when
the same grouped stream feeds multiple named terminal constraints. SolverForge
then shares the retained grouped node work while keeping each terminal
constraint's name, ordering, metadata, and explanation independent. The
lower-level constraint metadata borrows full `ConstraintRef` identity from the
owning constraint. Package-qualified constraints use
`ConstraintRef::full_name()` as the configured key; package-less constraints use
the short name.

## Sections

- **[Constraint Streams](/docs/solverforge/constraints/constraint-streams/)** - The core stream API
- **[Constraint Node Sharing](/docs/solverforge/constraints/node-sharing/)** - `#[solverforge_constraints]` and repeated grouped terminal sharing
- **[Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/)** - `ConstraintFactory`, generated collection sources, and lower-level `for_each`
- **[Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)** - Scoring-only rows from `Projection` types or joined-pair `.project(...)`
- **[Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/)** - `if_exists`, `if_not_exists`, and `flatten_last`
- **[Joiners](/docs/solverforge/constraints/joiners/)** - Combining multiple entity streams
- **[Collectors](/docs/solverforge/constraints/collectors/)** - Aggregation functions for `group_by`
- **[Score Types](/docs/solverforge/constraints/score-types/)** - Available score types and when to use each
- **[Score Analysis](/docs/solverforge/constraints/score-analysis/)** - Understanding and explaining scores
