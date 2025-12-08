---
title: "Solver Configuration"
linkTitle: "Configuration"
weight: 10
tags: [reference, python]
description: >
  Configure the solver with SolverConfig and related classes.
---

Configure the solver using Python dataclasses. This defines what to solve, how to score, and when to stop.

## SolverConfig

The main configuration class:

```python
from solverforge_legacy.solver.config import (
    SolverConfig,
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
)

solver_config = SolverConfig(
    solution_class=Timetable,
    entity_class_list=[Lesson],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(
        spent_limit=Duration(seconds=30)
    ),
)
```

### Required Fields

| Field | Description |
|-------|-------------|
| `solution_class` | The `@planning_solution` class |
| `entity_class_list` | List of `@planning_entity` classes |
| `score_director_factory_config` | How to calculate scores |

### Optional Fields

| Field | Description | Default |
|-------|-------------|---------|
| `termination_config` | When to stop | Never (manual termination) |
| `environment_mode` | Validation level | `REPRODUCIBLE` |
| `random_seed` | For reproducibility | Random |

## ScoreDirectorFactoryConfig

Configures constraint evaluation:

```python
ScoreDirectorFactoryConfig(
    constraint_provider_function=define_constraints
)
```

### With Constraint Provider

```python
from my_app.constraints import define_constraints

ScoreDirectorFactoryConfig(
    constraint_provider_function=define_constraints
)
```

## TerminationConfig

Controls when the solver stops:

### Time Limit

```python
TerminationConfig(
    spent_limit=Duration(seconds=30)
)

# Other duration units
Duration(minutes=5)
Duration(hours=1)
Duration(milliseconds=500)
```

### Score Target

Stop when a target score is reached:

```python
TerminationConfig(
    best_score_limit="0hard/-10soft"
)
```

### Step Limit

Stop after a number of steps:

```python
TerminationConfig(
    step_count_limit=10000
)
```

### Unimproved Time

Stop if no improvement for a duration:

```python
TerminationConfig(
    unimproved_spent_limit=Duration(seconds=30)
)
```

### Combining Conditions

Multiple conditions use OR logic:

```python
TerminationConfig(
    spent_limit=Duration(minutes=5),
    best_score_limit="0hard/0soft",  # OR achieves perfect
    unimproved_spent_limit=Duration(seconds=60)  # OR stuck
)
```

## Environment Mode

Controls validation and reproducibility:

```python
from solverforge_legacy.solver.config import EnvironmentMode

SolverConfig(
    environment_mode=EnvironmentMode.REPRODUCIBLE,
    ...
)
```

| Mode | Description | Use Case |
|------|-------------|----------|
| `NON_REPRODUCIBLE` | Fastest, no validation | Production |
| `REPRODUCIBLE` | Deterministic results | Default |
| `FAST_ASSERT` | Quick validation | Testing |
| `FULL_ASSERT` | Complete validation | Debugging |

### Debugging Score Corruption

Use `FULL_ASSERT` to detect score calculation bugs:

```python
SolverConfig(
    environment_mode=EnvironmentMode.FULL_ASSERT,
    ...
)
```

This validates every score calculation but is slow.

## Reproducibility

For reproducible results, set a random seed:

```python
SolverConfig(
    random_seed=42,
    environment_mode=EnvironmentMode.REPRODUCIBLE,
    ...
)
```

## Configuration Overrides

Override configuration when building a solver:

```python
from solverforge_legacy.solver.config import SolverConfigOverride

solver_factory = SolverFactory.create(solver_config)

# Override termination for this solver instance
override = SolverConfigOverride(
    termination_config=TerminationConfig(spent_limit=Duration(seconds=10))
)
solver = solver_factory.build_solver(override)
```

## Complete Example

```python
from solverforge_legacy.solver import SolverFactory
from solverforge_legacy.solver.config import (
    SolverConfig,
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
    EnvironmentMode,
)

from my_app.domain import Timetable, Lesson
from my_app.constraints import define_constraints


def create_solver():
    config = SolverConfig(
        solution_class=Timetable,
        entity_class_list=[Lesson],
        score_director_factory_config=ScoreDirectorFactoryConfig(
            constraint_provider_function=define_constraints
        ),
        termination_config=TerminationConfig(
            spent_limit=Duration(minutes=5),
            best_score_limit="0hard/0soft",
        ),
        environment_mode=EnvironmentMode.REPRODUCIBLE,
        random_seed=42,
    )

    factory = SolverFactory.create(config)
    return factory.build_solver()
```

## Configuration Best Practices

### Development

```python
SolverConfig(
    environment_mode=EnvironmentMode.FULL_ASSERT,
    termination_config=TerminationConfig(spent_limit=Duration(seconds=10)),
    ...
)
```

### Testing

```python
SolverConfig(
    environment_mode=EnvironmentMode.REPRODUCIBLE,
    random_seed=42,  # Reproducible tests
    termination_config=TerminationConfig(spent_limit=Duration(seconds=5)),
    ...
)
```

### Production

```python
SolverConfig(
    environment_mode=EnvironmentMode.NON_REPRODUCIBLE,
    termination_config=TerminationConfig(
        spent_limit=Duration(minutes=5),
        unimproved_spent_limit=Duration(minutes=1),
    ),
    ...
)
```

## Next Steps

- [Running the Solver](running.md) - Execute solving
- [SolverManager](solver-manager.md) - Async solving
