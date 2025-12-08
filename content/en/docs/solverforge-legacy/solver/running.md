---
title: "Running the Solver"
linkTitle: "Running"
weight: 20
description: >
  Execute the solver synchronously with Solver.solve().
---

The simplest way to solve a problem is with `Solver.solve()`, which blocks until termination.

## Basic Usage

```python
from solverforge_legacy.solver import SolverFactory
from solverforge_legacy.solver.config import (
    SolverConfig, ScoreDirectorFactoryConfig, TerminationConfig, Duration
)

# Configure
config = SolverConfig(
    solution_class=Timetable,
    entity_class_list=[Lesson],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(spent_limit=Duration(seconds=30)),
)

# Create factory and solver
factory = SolverFactory.create(config)
solver = factory.build_solver()

# Load problem
problem = load_problem()

# Solve (blocks until done)
solution = solver.solve(problem)

# Use solution
print(f"Score: {solution.score}")
```

## Event Listeners

Monitor progress with event listeners:

```python
from solverforge_legacy.solver import BestSolutionChangedEvent

def on_best_solution_changed(event: BestSolutionChangedEvent):
    print(f"New best score: {event.new_best_score}")
    print(f"Time spent: {event.time_spent}")

solver.add_event_listener(on_best_solution_changed)
solution = solver.solve(problem)
```

### BestSolutionChangedEvent Properties

| Property | Description |
|----------|-------------|
| `new_best_score` | The new best score |
| `new_best_solution` | The new best solution |
| `time_spent` | Duration since solving started |
| `is_new_best_solution_initialized` | True if all variables are assigned |

### Removing Listeners

```python
solver.add_event_listener(listener)
# ... later ...
solver.remove_event_listener(listener)
```

## Early Termination

Stop solving before the termination condition:

```python
import threading

def timeout_termination(solver, timeout_seconds):
    """Terminate after timeout."""
    time.sleep(timeout_seconds)
    solver.terminate_early()

# Start termination thread
thread = threading.Thread(target=timeout_termination, args=(solver, 60))
thread.start()

solution = solver.solve(problem)
```

### Manual Termination

```python
# From another thread
solver.terminate_early()

# Check if termination was requested
if solver.is_terminate_early():
    print("Termination was requested")
```

## Checking Solver State

```python
# Is the solver currently running?
if solver.is_solving():
    print("Solver is running")

# Was early termination requested?
if solver.is_terminate_early():
    print("Termination requested")
```

## Problem Changes (Real-Time)

Modify the problem while solving:

```python
from solverforge_legacy.solver import ProblemChange

class AddLessonChange(ProblemChange[Timetable]):
    def __init__(self, lesson: Lesson):
        self.lesson = lesson

    def do_change(self, working_solution: Timetable, score_director):
        # Add to working solution
        working_solution.lessons.append(self.lesson)
        # Notify score director
        score_director.after_entity_added(self.lesson)

# Add change while solving
new_lesson = Lesson("new", "Art", "S. Dali", "Group A")
solver.add_problem_change(AddLessonChange(new_lesson))
```

See [Real-Time Planning](../patterns/real-time-planning.md) for more details.

## Solver Reuse

Don't reuse a solver instance—create a new one for each solve:

```python
# Correct: New solver each time
solver1 = factory.build_solver()
solution1 = solver1.solve(problem1)

solver2 = factory.build_solver()
solution2 = solver2.solve(problem2)

# Incorrect: Reusing solver
solver = factory.build_solver()
solution1 = solver.solve(problem1)
solution2 = solver.solve(problem2)  # Don't do this!
```

## Threading

`Solver.solve()` blocks the calling thread. For non-blocking operation, use:

1. **Background thread:**
   ```python
   thread = threading.Thread(target=lambda: solver.solve(problem))
   thread.start()
   ```

2. **SolverManager** (recommended for production):
   See [SolverManager](solver-manager.md)

## Error Handling

```python
try:
    solution = solver.solve(problem)
except Exception as e:
    print(f"Solving failed: {e}")
    # Handle error (log, retry, etc.)
```

## Complete Example

```python
from solverforge_legacy.solver import SolverFactory, BestSolutionChangedEvent
from solverforge_legacy.solver.config import (
    SolverConfig, ScoreDirectorFactoryConfig, TerminationConfig, Duration
)
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("solver")


def solve_timetable(problem: Timetable) -> Timetable:
    config = SolverConfig(
        solution_class=Timetable,
        entity_class_list=[Lesson],
        score_director_factory_config=ScoreDirectorFactoryConfig(
            constraint_provider_function=define_constraints
        ),
        termination_config=TerminationConfig(
            spent_limit=Duration(minutes=5),
            unimproved_spent_limit=Duration(seconds=60),
        ),
    )

    factory = SolverFactory.create(config)
    solver = factory.build_solver()

    # Log progress
    def on_progress(event: BestSolutionChangedEvent):
        logger.info(f"Score: {event.new_best_score} at {event.time_spent}")

    solver.add_event_listener(on_progress)

    # Solve
    logger.info("Starting solver...")
    solution = solver.solve(problem)
    logger.info(f"Solving finished. Final score: {solution.score}")

    return solution


if __name__ == "__main__":
    problem = load_problem()
    solution = solve_timetable(problem)
    save_solution(solution)
```

## Next Steps

- [SolverManager](solver-manager.md) - Async and concurrent solving
- [Solution Manager](solution-manager.md) - Analyze solutions
