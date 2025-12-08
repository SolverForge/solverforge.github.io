---
title: "Reference"
linkTitle: "Reference"
weight: 100
tags: [reference, python]
description: >
  API reference and frequently asked questions.
---

Quick reference guides and answers to common questions.

## Topics

- **[API Summary](api-summary.md)** - Quick reference for key classes and functions
- **[FAQ](faq.md)** - Frequently asked questions

## Key Imports

```python
# Domain modeling
from solverforge_legacy.solver.domain import (
    planning_entity,
    planning_solution,
    PlanningId,
    PlanningVariable,
    PlanningListVariable,
    PlanningEntityCollectionProperty,
    ProblemFactCollectionProperty,
    ValueRangeProvider,
    PlanningScore,
    PlanningPin,
    InverseRelationShadowVariable,
    PreviousElementShadowVariable,
    NextElementShadowVariable,
    CascadingUpdateShadowVariable,
)

# Constraints
from solverforge_legacy.solver.score import (
    constraint_provider,
    ConstraintFactory,
    Constraint,
    Joiners,
    ConstraintCollectors,
    HardSoftScore,
    HardMediumSoftScore,
    SimpleScore,
)

# Solver
from solverforge_legacy.solver import (
    SolverFactory,
    SolverManager,
    SolutionManager,
    ProblemChange,
)

# Configuration
from solverforge_legacy.solver.config import (
    SolverConfig,
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
)
```

## Score Types

| Score Type | Levels | Use Case |
|------------|--------|----------|
| `SimpleScore` | 1 | Single optimization objective |
| `HardSoftScore` | 2 | Feasibility (hard) + optimization (soft) |
| `HardMediumSoftScore` | 3 | Hard + important preferences + nice-to-have |
| `BendableScore` | N | Custom number of levels |
| `*DecimalScore` | - | Decimal precision variants |
