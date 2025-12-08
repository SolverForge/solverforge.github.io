---
title: "Hello World with FastAPI"
linkTitle: "Hello World (FastAPI)"
weight: 30
tags: [quickstart, python]
description: >
  Add a REST API to your school timetabling solver.
---

This tutorial extends the [Hello World](hello-world.md) example by adding a REST API using FastAPI. This is closer to how you'd deploy a solver in production.

## Prerequisites

- Completed the [Hello World](hello-world.md) tutorial
- FastAPI and Uvicorn installed:

```bash
pip install fastapi uvicorn
```

## Project Structure

Extend your project:

```
hello_world/
├── domain.py           # Same as before
├── constraints.py      # Same as before
├── main.py             # CLI version (optional)
├── rest_api.py         # NEW: FastAPI application
└── pyproject.toml      # Add fastapi, uvicorn
```

## Step 1: Update Dependencies

Add FastAPI to your `pyproject.toml`:

```toml
[project]
dependencies = [
    "solverforge-legacy == 1.24.1",
    "fastapi >= 0.100.0",
    "uvicorn >= 0.23.0",
    "pytest == 8.2.2",
]
```

## Step 2: Create the REST API

Create `rest_api.py`:

```python
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import time

from solverforge_legacy.solver import SolverFactory, SolverManager
from solverforge_legacy.solver.config import (
    SolverConfig,
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
)

from .domain import Timetable, Timeslot, Room, Lesson
from .constraints import define_constraints


# Pydantic models for API validation
class TimeslotDTO(BaseModel):
    day_of_week: str
    start_time: str
    end_time: str

    def to_domain(self) -> Timeslot:
        return Timeslot(
            self.day_of_week,
            time.fromisoformat(self.start_time),
            time.fromisoformat(self.end_time),
        )


class RoomDTO(BaseModel):
    name: str

    def to_domain(self) -> Room:
        return Room(self.name)


class LessonDTO(BaseModel):
    id: str
    subject: str
    teacher: str
    student_group: str
    timeslot: TimeslotDTO | None = None
    room: RoomDTO | None = None

    def to_domain(self, timeslots: list[Timeslot], rooms: list[Room]) -> Lesson:
        ts = None
        if self.timeslot:
            ts = next(
                (t for t in timeslots if t.day_of_week == self.timeslot.day_of_week
                 and t.start_time.isoformat() == self.timeslot.start_time),
                None
            )
        rm = None
        if self.room:
            rm = next((r for r in rooms if r.name == self.room.name), None)

        return Lesson(self.id, self.subject, self.teacher, self.student_group, ts, rm)


class TimetableDTO(BaseModel):
    id: str
    timeslots: list[TimeslotDTO]
    rooms: list[RoomDTO]
    lessons: list[LessonDTO]
    score: str | None = None

    def to_domain(self) -> Timetable:
        timeslots = [ts.to_domain() for ts in self.timeslots]
        rooms = [r.to_domain() for r in self.rooms]
        lessons = [l.to_domain(timeslots, rooms) for l in self.lessons]
        return Timetable(self.id, timeslots, rooms, lessons)

    @classmethod
    def from_domain(cls, timetable: Timetable) -> "TimetableDTO":
        return cls(
            id=timetable.id,
            timeslots=[
                TimeslotDTO(
                    day_of_week=ts.day_of_week,
                    start_time=ts.start_time.isoformat(),
                    end_time=ts.end_time.isoformat(),
                )
                for ts in timetable.timeslots
            ],
            rooms=[RoomDTO(name=r.name) for r in timetable.rooms],
            lessons=[
                LessonDTO(
                    id=l.id,
                    subject=l.subject,
                    teacher=l.teacher,
                    student_group=l.student_group,
                    timeslot=TimeslotDTO(
                        day_of_week=l.timeslot.day_of_week,
                        start_time=l.timeslot.start_time.isoformat(),
                        end_time=l.timeslot.end_time.isoformat(),
                    ) if l.timeslot else None,
                    room=RoomDTO(name=l.room.name) if l.room else None,
                )
                for l in timetable.lessons
            ],
            score=str(timetable.score) if timetable.score else None,
        )


# Global solver manager
solver_manager: SolverManager | None = None
solutions: dict[str, Timetable] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize solver manager on startup."""
    global solver_manager

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

    solver_factory = SolverFactory.create(solver_config)
    solver_manager = SolverManager.create(solver_factory)

    yield

    # Cleanup on shutdown
    if solver_manager:
        solver_manager.close()


app = FastAPI(
    title="School Timetabling API",
    description="Optimize school timetables using SolverForge",
    lifespan=lifespan,
)


@app.post("/timetables", response_model=str)
async def submit_problem(timetable_dto: TimetableDTO) -> str:
    """Submit a timetabling problem for solving."""
    job_id = str(uuid.uuid4())
    problem = timetable_dto.to_domain()

    def on_best_solution(solution: Timetable):
        solutions[job_id] = solution

    solver_manager.solve_and_listen(
        job_id,
        lambda _: problem,
        on_best_solution,
    )

    return job_id


@app.get("/timetables/{job_id}", response_model=TimetableDTO)
async def get_solution(job_id: str) -> TimetableDTO:
    """Get the current best solution for a job."""
    if job_id not in solutions:
        raise HTTPException(status_code=404, detail="Job not found")

    return TimetableDTO.from_domain(solutions[job_id])


@app.delete("/timetables/{job_id}")
async def stop_solving(job_id: str):
    """Stop solving a problem early."""
    solver_manager.terminate_early(job_id)
    return {"status": "terminated"}


@app.get("/demo-data", response_model=TimetableDTO)
async def get_demo_data() -> TimetableDTO:
    """Get demo problem data for testing."""
    timeslots = [
        Timeslot("MONDAY", time(8, 30), time(9, 30)),
        Timeslot("MONDAY", time(9, 30), time(10, 30)),
        Timeslot("TUESDAY", time(8, 30), time(9, 30)),
        Timeslot("TUESDAY", time(9, 30), time(10, 30)),
    ]
    rooms = [Room("Room A"), Room("Room B")]
    lessons = [
        Lesson("1", "Math", "A. Turing", "9th grade"),
        Lesson("2", "Physics", "M. Curie", "9th grade"),
        Lesson("3", "History", "I. Jones", "9th grade"),
        Lesson("4", "Math", "A. Turing", "10th grade"),
    ]

    return TimetableDTO.from_domain(Timetable("demo", timeslots, rooms, lessons))
```

## Step 3: Run the API

```bash
uvicorn hello_world.rest_api:app --reload
```

The API is now running at `http://localhost:8000`.

## Step 4: Test the API

### Get Demo Data

```bash
curl http://localhost:8000/demo-data
```

### Submit a Problem

```bash
# Get demo data and submit it for solving
curl http://localhost:8000/demo-data | curl -X POST \
  -H "Content-Type: application/json" \
  -d @- \
  http://localhost:8000/timetables
```

This returns a job ID like `"a1b2c3d4-..."`.

### Check the Solution

```bash
curl http://localhost:8000/timetables/{job_id}
```

### Stop Solving Early

```bash
curl -X DELETE http://localhost:8000/timetables/{job_id}
```

## API Documentation

FastAPI automatically generates interactive API docs:

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

## Architecture Notes

### SolverManager

`SolverManager` handles concurrent solving jobs:
- Each job runs in its own thread
- Multiple problems can be solved simultaneously
- Solutions are updated as the solver improves them

### Pydantic Models

We use separate Pydantic DTOs for:
- API request/response validation
- JSON serialization
- Decoupling API schema from domain model

### Production Considerations

For production deployments:

1. **Persistence:** Store solutions in a database
2. **Scaling:** Use a message queue for distributed solving
3. **Monitoring:** Add logging and metrics
4. **Security:** Add authentication and rate limiting

## Next Steps

- [SolverManager](../solver/solver-manager.md) - Learn more about async solving
- [Integration](../integration/) - Database and deployment patterns
- [Quickstarts](../quickstarts/) - More complete examples
