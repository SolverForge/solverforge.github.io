---
title: "SolverManager"
linkTitle: "SolverManager"
weight: 30
description: >
  Manage concurrent and asynchronous solving jobs.
---

`SolverManager` handles concurrent solving jobs, making it ideal for web applications and services.

## Creating a SolverManager

```python
from solverforge_legacy.solver import SolverFactory, SolverManager
from solverforge_legacy.solver.config import (
    SolverConfig, ScoreDirectorFactoryConfig, TerminationConfig, Duration
)

config = SolverConfig(
    solution_class=Timetable,
    entity_class_list=[Lesson],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(spent_limit=Duration(minutes=5)),
)

solver_factory = SolverFactory.create(config)
solver_manager = SolverManager.create(solver_factory)
```

## Basic Solving

### solve()

Non-blocking solve that returns a future:

```python
import uuid

job_id = str(uuid.uuid4())

# Start solving (non-blocking)
future = solver_manager.solve(job_id, problem)

# ... do other work ...

# Get result (blocks until done)
solution = future.get_final_best_solution()
print(f"Score: {solution.score}")
```

### solve_and_listen()

Solve with progress callbacks:

```python
def on_best_solution_changed(solution: Timetable):
    print(f"New best: {solution.score}")
    # Update UI, save to database, etc.

def on_exception(error):
    print(f"Solving failed: {error}")

solver_manager.solve_and_listen(
    job_id,
    problem_finder=lambda _: problem,
    best_solution_consumer=on_best_solution_changed,
    exception_handler=on_exception,
)
```

## Managing Jobs

### Check Job Status

```python
status = solver_manager.get_solver_status(job_id)
# Returns: NOT_SOLVING, SOLVING_ACTIVE, SOLVING_ENDED
```

### Get Current Best Solution

```python
solution = solver_manager.get_best_solution(job_id)
if solution:
    print(f"Current best: {solution.score}")
```

### Terminate Early

```python
solver_manager.terminate_early(job_id)
```

## FastAPI Integration

```python
from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager
import uuid

solver_manager: SolverManager | None = None
solutions: dict[str, Timetable] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    global solver_manager

    config = SolverConfig(...)
    factory = SolverFactory.create(config)
    solver_manager = SolverManager.create(factory)

    yield

    solver_manager.close()


app = FastAPI(lifespan=lifespan)


@app.post("/solve")
async def start_solving(problem: TimetableRequest) -> str:
    job_id = str(uuid.uuid4())

    def on_best_solution(solution: Timetable):
        solutions[job_id] = solution

    solver_manager.solve_and_listen(
        job_id,
        problem_finder=lambda _: problem.to_domain(),
        best_solution_consumer=on_best_solution,
    )

    return job_id


@app.get("/solution/{job_id}")
async def get_solution(job_id: str):
    if job_id not in solutions:
        raise HTTPException(404, "Job not found")

    solution = solutions[job_id]
    status = solver_manager.get_solver_status(job_id)

    return {
        "status": status.name,
        "score": str(solution.score),
        "solution": TimetableResponse.from_domain(solution),
    }


@app.delete("/solve/{job_id}")
async def stop_solving(job_id: str):
    solver_manager.terminate_early(job_id)
    return {"status": "terminating"}
```

## Concurrent Jobs

SolverManager handles multiple jobs concurrently:

```python
# Start multiple jobs
job1 = solver_manager.solve("job1", problem1)
job2 = solver_manager.solve("job2", problem2)
job3 = solver_manager.solve("job3", problem3)

# Each runs in its own thread
# Results available when ready
solution1 = job1.get_final_best_solution()
```

### Resource Limits

By default, jobs run with no limit on concurrent execution. For resource management:

```python
# Limit concurrent solvers
solver_manager = SolverManager.create(
    solver_factory,
    parallel_solver_count=4,  # Max 4 concurrent jobs
)
```

## Problem Changes During Solving

Add changes to running jobs:

```python
from solverforge_legacy.solver import ProblemChange

class AddEntity(ProblemChange[Timetable]):
    def __init__(self, entity):
        self.entity = entity

    def do_change(self, working_solution, score_director):
        working_solution.lessons.append(self.entity)
        score_director.after_entity_added(self.entity)

# Add change to running job
solver_manager.add_problem_change(job_id, AddEntity(new_lesson))
```

## Cleanup

Always close the SolverManager when done:

```python
# Using context manager
with SolverManager.create(factory) as manager:
    # ... use manager ...
# Automatically closed

# Manual cleanup
try:
    # ... use manager ...
finally:
    solver_manager.close()
```

## Error Handling

```python
def on_exception(job_id: str, exception: Exception):
    logger.error(f"Job {job_id} failed: {exception}")
    # Clean up, notify user, etc.

solver_manager.solve_and_listen(
    job_id,
    problem_finder=lambda _: problem,
    best_solution_consumer=on_solution,
    exception_handler=on_exception,
)
```

## Best Practices

### Do

- Use `solve_and_listen()` for progress updates
- Store solutions externally (database, cache)
- Handle exceptions properly
- Close SolverManager on shutdown

### Don't

- Block the main thread waiting for results
- Store solutions only in memory (lose on restart)
- Forget to handle job cleanup

## Next Steps

- [SolutionManager](solution-manager.md) - Analyze solutions
- [Real-Time Planning](../patterns/real-time-planning.md) - Problem changes
