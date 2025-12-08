---
title: "API Summary"
linkTitle: "API Summary"
weight: 10
description: >
  Quick reference for SolverForge Python API.
---

Quick reference for commonly used SolverForge APIs.

## Domain Decorators

```python
from solverforge_legacy.solver.domain import (
    planning_entity,
    planning_solution,
)
```

| Decorator | Purpose |
|-----------|---------|
| `@planning_entity` | Mark a class as a planning entity |
| `@planning_solution` | Mark a class as the planning solution |

## Type Annotations

```python
from solverforge_legacy.solver.domain import (
    PlanningId,
    PlanningVariable,
    PlanningListVariable,
    PlanningEntityCollectionProperty,
    ProblemFactCollectionProperty,
    ValueRangeProvider,
    PlanningScore,
    PlanningPin,
    PlanningPinToIndex,
)
```

| Annotation | Use With | Purpose |
|------------|----------|---------|
| `PlanningId` | Entity field | Unique identifier |
| `PlanningVariable` | Entity field | Variable to optimize |
| `PlanningListVariable` | Entity field | Ordered list of entities |
| `PlanningEntityCollectionProperty` | Solution field | Collection of entities |
| `ProblemFactCollectionProperty` | Solution field | Immutable input data |
| `ValueRangeProvider` | Solution field | Possible values for variables |
| `PlanningScore` | Solution field | Where score is stored |
| `PlanningPin` | Entity field | Lock entity assignment |
| `PlanningPinToIndex` | Entity field | Lock list position |

### Usage Pattern

```python
from typing import Annotated
from dataclasses import dataclass, field

@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
```

## Shadow Variable Annotations

```python
from solverforge_legacy.solver.domain import (
    InverseRelationShadowVariable,
    PreviousElementShadowVariable,
    NextElementShadowVariable,
    CascadingUpdateShadowVariable,
)
```

| Annotation | Purpose |
|------------|---------|
| `InverseRelationShadowVariable` | Back-reference to list owner |
| `PreviousElementShadowVariable` | Previous element in list |
| `NextElementShadowVariable` | Next element in list |
| `CascadingUpdateShadowVariable` | Computed value that cascades |

## Score Types

```python
from solverforge_legacy.solver.score import (
    SimpleScore,
    HardSoftScore,
    HardMediumSoftScore,
    HardSoftDecimalScore,
)
```

| Type | Levels | Example |
|------|--------|---------|
| `SimpleScore` | 1 | `-5` |
| `HardSoftScore` | 2 | `-2hard/-15soft` |
| `HardMediumSoftScore` | 3 | `-1hard/-3medium/-10soft` |
| `HardSoftDecimalScore` | 2 (decimal) | `-2hard/-15.5soft` |

### Common Operations

```python
score = HardSoftScore.of(-2, -15)
score.hard_score      # -2
score.soft_score      # -15
score.is_feasible     # False (hard_score < 0)

# Constants
HardSoftScore.ZERO
HardSoftScore.ONE_HARD
HardSoftScore.ONE_SOFT
```

## Constraint Streams

```python
from solverforge_legacy.solver.score import (
    constraint_provider,
    ConstraintFactory,
    Constraint,
    Joiners,
    ConstraintCollectors,
)
```

### ConstraintFactory Methods

| Method | Purpose |
|--------|---------|
| `for_each(Class)` | Start stream with all instances |
| `for_each_unique_pair(Class, *Joiners)` | All unique pairs |
| `for_each_including_unassigned(Class)` | Include entities with null variables |

### Stream Operations

| Method | Purpose |
|--------|---------|
| `.filter(predicate)` | Filter elements |
| `.join(Class, *Joiners)` | Join with another class |
| `.if_exists(Class, *Joiners)` | Keep if matching exists |
| `.if_not_exists(Class, *Joiners)` | Keep if no matching exists |
| `.group_by(groupKey, collector)` | Group and aggregate |
| `.flatten_last(mapper)` | Expand collection |
| `.map(mapper)` | Transform elements |
| `.complement(Class, filler)` | Add missing elements |

### Terminal Operations

| Method | Purpose |
|--------|---------|
| `.penalize(Score)` | Add penalty |
| `.penalize(Score, weigher)` | Weighted penalty |
| `.reward(Score)` | Add reward |
| `.reward(Score, weigher)` | Weighted reward |
| `.penalize_decimal(Score, weigher)` | Decimal penalty |
| `.as_constraint(name)` | Name the constraint |

## Joiners

```python
from solverforge_legacy.solver.score import Joiners
```

| Joiner | Purpose |
|--------|---------|
| `Joiners.equal(extractor)` | Match on equality |
| `Joiners.equal(extractorA, extractorB)` | Match properties |
| `Joiners.less_than(extractorA, extractorB)` | A < B |
| `Joiners.less_than_or_equal(extractorA, extractorB)` | A <= B |
| `Joiners.greater_than(extractorA, extractorB)` | A > B |
| `Joiners.greater_than_or_equal(extractorA, extractorB)` | A >= B |
| `Joiners.overlapping(startA, endA, startB, endB)` | Time overlap |
| `Joiners.overlapping(startA, endA)` | Same start/end extractors |
| `Joiners.filtering(predicate)` | Custom filter |

## Collectors

```python
from solverforge_legacy.solver.score import ConstraintCollectors
```

| Collector | Result |
|-----------|--------|
| `count()` | Number of items |
| `count_distinct(mapper)` | Distinct count |
| `sum(mapper)` | Sum of values |
| `min(mapper)` | Minimum value |
| `max(mapper)` | Maximum value |
| `average(mapper)` | Average value |
| `to_list(mapper)` | Collect to list |
| `to_set(mapper)` | Collect to set |
| `load_balance(keyMapper, loadMapper)` | Fairness measure |
| `compose(c1, c2, combiner)` | Combine collectors |

## Solver Configuration

```python
from solverforge_legacy.solver.config import (
    SolverConfig,
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
)
```

### SolverConfig

```python
config = SolverConfig(
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

### TerminationConfig Options

| Property | Type | Purpose |
|----------|------|---------|
| `spent_limit` | Duration | Time limit |
| `unimproved_spent_limit` | Duration | Time without improvement |
| `best_score_limit` | str | Target score |
| `best_score_feasible` | bool | Stop when feasible |

## Solver API

```python
from solverforge_legacy.solver import (
    SolverFactory,
    SolverManager,
    SolutionManager,
    SolverStatus,
)
```

### SolverFactory

```python
solver_factory = SolverFactory.create(config)
solver = solver_factory.build_solver()
solution = solver.solve(problem)
```

### SolverManager

```python
solver_manager = SolverManager.create(solver_factory)

# Async solving
solver_manager.solve_and_listen(
    problem_id,
    problem_finder=lambda _: problem,
    best_solution_consumer=on_best_solution,
)

# Control
solver_manager.terminate_early(problem_id)
status = solver_manager.get_solver_status(problem_id)
solver_manager.close()
```

### SolverStatus

| Status | Meaning |
|--------|---------|
| `NOT_SOLVING` | Not started |
| `SOLVING_ACTIVE` | Currently solving |
| `SOLVING_SCHEDULED` | Queued |

### SolutionManager

```python
solution_manager = SolutionManager.create(solver_factory)
analysis = solution_manager.analyze(solution)
score = solution_manager.update(solution)
```

## Duration

```python
from solverforge_legacy.solver.config import Duration

Duration(seconds=30)
Duration(minutes=5)
Duration(hours=1)
```

## Event Listeners

```python
from solverforge_legacy.solver import BestSolutionChangedEvent

def on_best_solution(event: BestSolutionChangedEvent):
    print(f"Score: {event.new_best_score}")
    print(f"Time: {event.time_spent}")
```

## Problem Changes

```python
from solverforge_legacy.solver import ProblemChange

class AddLessonChange(ProblemChange):
    def __init__(self, lesson: Lesson):
        self.lesson = lesson

    def do_change(self, solution: Timetable, problem_change_director):
        problem_change_director.add_entity(
            self.lesson,
            lambda l: solution.lessons.append(l)
        )
```

## Import Summary

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

# Scores and constraints
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
    SolverStatus,
    BestSolutionChangedEvent,
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
