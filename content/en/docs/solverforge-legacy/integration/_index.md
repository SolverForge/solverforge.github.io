---
title: "Integration"
linkTitle: "Integration"
weight: 90
tags: [reference, python]
description: >
  Integrate SolverForge with web frameworks and other systems.
---

SolverForge integrates easily with Python web frameworks and data systems.

## Topics

- **[FastAPI Integration](fastapi.md)** - Build REST APIs for your solver
- **[Serialization](serialization.md)** - JSON handling with dataclasses and Pydantic
- **[Logging](logging.md)** - Configure logging for debugging and monitoring

## FastAPI Example

```python
from fastapi import FastAPI
from solverforge_legacy.solver import SolverManager

app = FastAPI()
solver_manager = SolverManager.create(solver_factory)

@app.post("/solve")
async def solve(problem: Timetable) -> str:
    job_id = str(uuid.uuid4())
    solver_manager.solve_and_listen(
        job_id,
        lambda _: problem,
        on_best_solution_changed
    )
    return job_id

@app.get("/solution/{job_id}")
async def get_solution(job_id: str) -> Timetable:
    return solver_manager.get_best_solution(job_id)

@app.delete("/solve/{job_id}")
async def stop_solving(job_id: str):
    solver_manager.terminate_early(job_id)
```

## Serialization

SolverForge domain objects are standard Python dataclasses, making them easy to serialize:

```python
import json
from dataclasses import asdict

# Serialize to JSON
json_str = json.dumps(asdict(solution))

# With Pydantic for validation
from pydantic.dataclasses import dataclass as pydantic_dataclass

@pydantic_dataclass
class TimetableDTO:
    timeslots: list[TimeslotDTO]
    rooms: list[RoomDTO]
    lessons: list[LessonDTO]
```

## Database Integration

Use any Python ORM (SQLAlchemy, Django ORM, etc.) for persistence:

1. Load data from database into domain objects
2. Run the solver
3. Save results back to database

The solver works with in-memory Python objects, so any data source that can produce those objects will work.
