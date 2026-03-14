---
title: "Constraints"
linkTitle: "Constraints"
weight: 40
description: >
  Define business rules using constraint streams, joiners, collectors, and score types.
---

Constraints are the business rules that define what makes a good solution. SolverForge uses a **constraint streams API** — a declarative, composable way to express rules that reads like a pipeline of filters and transformations.

## How Constraints Work

1. **Select** entities or facts from your solution using `for_each`
2. **Filter, join, or group** to narrow down the matches
3. **Penalize or reward** to affect the score

```rust
factory.for_each::<Shift>()                              // Select all shifts
    .filter(|s| s.employee.is_none())                    // Keep unassigned ones
    .penalize("Unassigned shift", HardSoftScore::ONE_HARD)  // Penalize each
    .as_constraint()
```

Every constraint produces a `Constraint<S>` that the solver evaluates incrementally as it explores moves.

## Sections

- **[Constraint Streams](constraint-streams/)** — The core stream API
- **[Joiners](joiners/)** — Combining multiple entity streams
- **[Collectors](collectors/)** — Aggregation functions for `group_by`
- **[Score Types](score-types/)** — Available score types and when to use each
- **[Score Analysis](score-analysis/)** — Understanding and explaining scores
