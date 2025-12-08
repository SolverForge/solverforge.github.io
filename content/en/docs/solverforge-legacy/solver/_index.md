---
title: "Solver"
linkTitle: "Solver"
weight: 50
tags: [reference, python]
description: >
  Configure and run the solver to find optimal solutions.
---

The solver is the engine that finds optimal solutions to your planning problems. This section covers how to configure and run it.

## Topics

- **[Configuration](configuration.md)** - `SolverConfig`, `TerminationConfig`, and other settings
- **[Running the Solver](running.md)** - Synchronous solving with `Solver.solve()`
- **[Solver Manager](solver-manager.md)** - Asynchronous and concurrent solving
- **[Solution Manager](solution-manager.md)** - Analyze and explain solutions
- **[Benchmarking](benchmarking.md)** - Compare configurations and tune performance

## Quick Example

```python
from solverforge_legacy.solver import SolverFactory
from solverforge_legacy.solver.config import (
    SolverConfig, ScoreDirectorFactoryConfig, TerminationConfig, Duration
)

# Configure the solver
solver_config = SolverConfig(
    solution_class=Timetable,
    entity_class_list=[Lesson],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(
        spent_limit=Duration(seconds=30)
    )
)

# Create and run the solver
solver_factory = SolverFactory.create(solver_config)
solver = solver_factory.build_solver()

problem = load_problem()  # Your problem data
solution = solver.solve(problem)

print(f"Best score: {solution.score}")
```

## Termination

The solver needs to know when to stop. Common termination conditions:

| Condition | Description |
|-----------|-------------|
| `spent_limit` | Stop after a time limit (e.g., 30 seconds) |
| `best_score_limit` | Stop when a target score is reached |
| `unimproved_spent_limit` | Stop if no improvement for a duration |
| `step_count_limit` | Stop after a number of optimization steps |
