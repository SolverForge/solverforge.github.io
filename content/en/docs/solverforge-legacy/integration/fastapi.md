---
title: "FastAPI Integration"
linkTitle: "FastAPI"
weight: 10
tags: [reference, python]
description: >
  Build REST APIs for your solver with FastAPI.
---

FastAPI is a modern Python web framework that works well with SolverForge. This guide shows common patterns for building solver APIs.

## Basic Setup

```python
from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager
import uuid

from solverforge_legacy.solver import SolverFactory, SolverManager
from solverforge_legacy.solver.config import (
    SolverConfig, ScoreDirectorFactoryConfig, TerminationConfig, Duration
)


# Global state
solver_manager: SolverManager | None = None
solutions: dict[str, Solution] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize solver on startup, cleanup on shutdown."""
    global solver_manager

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

    yield

    if solver_manager:
        solver_manager.close()


app = FastAPI(
    title="Solver API",
    description="Planning optimization API",
    lifespan=lifespan,
)
```

## API Endpoints

### Submit Problem

```python
@app.post("/solve", response_model=str)
async def submit_problem(request: ProblemRequest) -> str:
    """Submit a problem for solving. Returns job ID."""
    job_id = str(uuid.uuid4())
    problem = request.to_domain()

    def on_best_solution(solution):
        solutions[job_id] = solution

    solver_manager.solve_and_listen(
        job_id,
        problem_finder=lambda _: problem,
        best_solution_consumer=on_best_solution,
    )

    return job_id
```

### Get Solution

```python
@app.get("/solution/{job_id}", response_model=SolutionResponse)
async def get_solution(job_id: str) -> SolutionResponse:
    """Get the current best solution."""
    if job_id not in solutions:
        raise HTTPException(404, "Job not found")

    solution = solutions[job_id]
    status = solver_manager.get_solver_status(job_id)

    return SolutionResponse.from_domain(solution, status)
```

### Stop Solving

```python
@app.delete("/solve/{job_id}")
async def stop_solving(job_id: str):
    """Stop solving early."""
    solver_manager.terminate_early(job_id)
    return {"status": "terminating"}
```

### Get Score Analysis

```python
@app.get("/analysis/{job_id}")
async def get_analysis(job_id: str):
    """Get detailed score analysis."""
    if job_id not in solutions:
        raise HTTPException(404, "Job not found")

    solution = solutions[job_id]
    analysis = solution_manager.analyze(solution)

    return {
        "score": str(analysis.score),
        "is_feasible": analysis.score.is_feasible,
        "constraints": [
            {
                "name": c.constraint_name,
                "score": str(c.score),
                "matches": c.match_count,
            }
            for c in analysis.constraint_analyses()
        ],
    }
```

## Request/Response Models

Use Pydantic for validation:

```python
from pydantic import BaseModel
from datetime import time


class TimeslotDTO(BaseModel):
    day: str
    start_time: str
    end_time: str

    def to_domain(self) -> Timeslot:
        return Timeslot(
            self.day,
            time.fromisoformat(self.start_time),
            time.fromisoformat(self.end_time),
        )

    @classmethod
    def from_domain(cls, timeslot: Timeslot) -> "TimeslotDTO":
        return cls(
            day=timeslot.day,
            start_time=timeslot.start_time.isoformat(),
            end_time=timeslot.end_time.isoformat(),
        )


class ProblemRequest(BaseModel):
    timeslots: list[TimeslotDTO]
    rooms: list[RoomDTO]
    lessons: list[LessonDTO]

    def to_domain(self) -> Timetable:
        timeslots = [t.to_domain() for t in self.timeslots]
        rooms = [r.to_domain() for r in self.rooms]
        lessons = [l.to_domain(timeslots, rooms) for l in self.lessons]
        return Timetable("api", timeslots, rooms, lessons)


class SolutionResponse(BaseModel):
    status: str
    score: str | None
    is_feasible: bool | None
    lessons: list[LessonDTO]

    @classmethod
    def from_domain(cls, solution: Timetable, status) -> "SolutionResponse":
        return cls(
            status=status.name,
            score=str(solution.score) if solution.score else None,
            is_feasible=solution.score.is_feasible if solution.score else None,
            lessons=[LessonDTO.from_domain(l) for l in solution.lessons],
        )
```

## Real-Time Updates

### Problem Changes

```python
@app.post("/solve/{job_id}/lessons")
async def add_lesson(job_id: str, lesson: LessonDTO):
    """Add a lesson to an active job."""
    new_lesson = lesson.to_domain()

    solver_manager.add_problem_change(
        job_id,
        AddLessonChange(new_lesson)
    )

    return {"status": "added", "id": new_lesson.id}
```

### WebSocket Updates

```python
from fastapi import WebSocket

@app.websocket("/ws/{job_id}")
async def websocket_updates(websocket: WebSocket, job_id: str):
    await websocket.accept()

    async def send_update(solution):
        await websocket.send_json({
            "score": str(solution.score),
            "timestamp": datetime.now().isoformat(),
        })

    # Register listener
    # (Implementation depends on your event system)

    try:
        while True:
            await asyncio.sleep(1)
            if job_id in solutions:
                await send_update(solutions[job_id])
    except WebSocketDisconnect:
        pass
```

## Error Handling

```python
from fastapi import HTTPException
from fastapi.responses import JSONResponse

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"error": str(exc)},
    )


@app.get("/solution/{job_id}")
async def get_solution(job_id: str):
    if job_id not in solutions:
        raise HTTPException(
            status_code=404,
            detail=f"Job {job_id} not found"
        )
    # ...
```

## Testing

```python
from fastapi.testclient import TestClient

def test_submit_and_get():
    client = TestClient(app)

    # Submit problem
    response = client.post("/solve", json=problem_data)
    assert response.status_code == 200
    job_id = response.json()

    # Wait for solving
    time.sleep(5)

    # Get solution
    response = client.get(f"/solution/{job_id}")
    assert response.status_code == 200
    assert response.json()["is_feasible"]
```

## Deployment

### Docker

```dockerfile
FROM python:3.11-slim

# Install JDK
RUN apt-get update && apt-get install -y openjdk-17-jdk

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Running

```bash
# Development
uvicorn main:app --reload

# Production
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

## Next Steps

- [Serialization](serialization.md) - JSON handling patterns
- [SolverManager](../solver/solver-manager.md) - Concurrent solving
