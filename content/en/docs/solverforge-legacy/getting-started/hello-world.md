---
title: "Hello World"
linkTitle: "Hello World"
weight: 20
description: >
  Build a school timetabling solver from scratch.
---

In this tutorial, you'll build a school timetabling application that assigns lessons to timeslots and rooms while avoiding conflicts.

## The Problem

A school needs to schedule lessons:

- Each **lesson** has a subject, teacher, and student group
- Available **timeslots** (e.g., Monday 08:30, Monday 09:30, ...)
- Available **rooms** (Room A, Room B, Room C)

**Constraints:**
- **Hard:** No room, teacher, or student group conflicts
- **Soft:** Teachers prefer the same room, consecutive lessons

## Project Structure

Create the following files:

```
hello_world/
├── domain.py       # Data model
├── constraints.py  # Constraint definitions
├── main.py         # Entry point
└── pyproject.toml  # Dependencies
```

## Step 1: Define the Domain Model

Create `domain.py` with the problem facts and planning entities:

```python
from dataclasses import dataclass, field
from datetime import time
from typing import Annotated

from solverforge_legacy.solver.domain import (
    planning_entity,
    planning_solution,
    PlanningId,
    PlanningVariable,
    PlanningEntityCollectionProperty,
    ProblemFactCollectionProperty,
    ValueRangeProvider,
    PlanningScore,
)
from solverforge_legacy.solver.score import HardSoftScore


# Problem facts (immutable data)
@dataclass
class Timeslot:
    day_of_week: str
    start_time: time
    end_time: time

    def __str__(self):
        return f"{self.day_of_week} {self.start_time.strftime('%H:%M')}"


@dataclass
class Room:
    name: str

    def __str__(self):
        return self.name


# Planning entity (modified by the solver)
@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    teacher: str
    student_group: str
    # Planning variables - assigned by the solver
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)


# Planning solution (container for all data)
@planning_solution
@dataclass
class Timetable:
    id: str
    # Problem facts with value range providers
    timeslots: Annotated[list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider]
    rooms: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
    # Planning entities
    lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
    # Score calculated by constraints
    score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```

### Key Concepts

- `@planning_entity` marks `Lesson` as something the solver will modify
- `PlanningVariable` marks `timeslot` and `room` as values to assign
- `@planning_solution` marks `Timetable` as the container
- `ValueRangeProvider` tells the solver which values are available

## Step 2: Define Constraints

Create `constraints.py` with the scoring rules:

```python
from solverforge_legacy.solver.score import (
    constraint_provider,
    ConstraintFactory,
    Constraint,
    Joiners,
    HardSoftScore,
)

from .domain import Lesson


@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory) -> list[Constraint]:
    return [
        # Hard constraints
        room_conflict(constraint_factory),
        teacher_conflict(constraint_factory),
        student_group_conflict(constraint_factory),
        # Soft constraints
        teacher_room_stability(constraint_factory),
    ]


def room_conflict(constraint_factory: ConstraintFactory) -> Constraint:
    """A room can accommodate at most one lesson at the same time."""
    return (
        constraint_factory
        .for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.timeslot),
            Joiners.equal(lambda lesson: lesson.room),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Room conflict")
    )


def teacher_conflict(constraint_factory: ConstraintFactory) -> Constraint:
    """A teacher can teach at most one lesson at the same time."""
    return (
        constraint_factory
        .for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.timeslot),
            Joiners.equal(lambda lesson: lesson.teacher),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Teacher conflict")
    )


def student_group_conflict(constraint_factory: ConstraintFactory) -> Constraint:
    """A student group can attend at most one lesson at the same time."""
    return (
        constraint_factory
        .for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.timeslot),
            Joiners.equal(lambda lesson: lesson.student_group),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Student group conflict")
    )


def teacher_room_stability(constraint_factory: ConstraintFactory) -> Constraint:
    """A teacher prefers to teach in a single room."""
    return (
        constraint_factory
        .for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.teacher),
        )
        .filter(lambda lesson1, lesson2: lesson1.room != lesson2.room)
        .penalize(HardSoftScore.ONE_SOFT)
        .as_constraint("Teacher room stability")
    )
```

### Constraint Stream Pattern

Each constraint follows this pattern:

1. **Select** entities with `for_each()` or `for_each_unique_pair()`
2. **Filter** to matching cases with `Joiners` or `.filter()`
3. **Penalize** (or reward) with a score impact
4. **Name** the constraint with `as_constraint()`

## Step 3: Configure and Run the Solver

Create `main.py`:

```python
from datetime import time

from solverforge_legacy.solver import SolverFactory
from solverforge_legacy.solver.config import (
    SolverConfig,
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
)

from .domain import Timetable, Timeslot, Room, Lesson
from .constraints import define_constraints


def main():
    # Configure the solver
    solver_config = SolverConfig(
        solution_class=Timetable,
        entity_class_list=[Lesson],
        score_director_factory_config=ScoreDirectorFactoryConfig(
            constraint_provider_function=define_constraints
        ),
        termination_config=TerminationConfig(
            spent_limit=Duration(seconds=5)
        ),
    )

    # Create the solver
    solver_factory = SolverFactory.create(solver_config)
    solver = solver_factory.build_solver()

    # Generate a problem
    problem = generate_demo_data()

    # Solve it!
    solution = solver.solve(problem)

    # Print the result
    print_timetable(solution)


def generate_demo_data() -> Timetable:
    """Create a small demo problem."""
    timeslots = [
        Timeslot("MONDAY", time(8, 30), time(9, 30)),
        Timeslot("MONDAY", time(9, 30), time(10, 30)),
        Timeslot("MONDAY", time(10, 30), time(11, 30)),
        Timeslot("TUESDAY", time(8, 30), time(9, 30)),
        Timeslot("TUESDAY", time(9, 30), time(10, 30)),
    ]

    rooms = [
        Room("Room A"),
        Room("Room B"),
        Room("Room C"),
    ]

    lessons = [
        Lesson("1", "Math", "A. Turing", "9th grade"),
        Lesson("2", "Physics", "M. Curie", "9th grade"),
        Lesson("3", "Chemistry", "M. Curie", "9th grade"),
        Lesson("4", "Biology", "C. Darwin", "9th grade"),
        Lesson("5", "History", "I. Jones", "9th grade"),
        Lesson("6", "Math", "A. Turing", "10th grade"),
        Lesson("7", "Physics", "M. Curie", "10th grade"),
        Lesson("8", "Geography", "C. Darwin", "10th grade"),
    ]

    return Timetable("demo", timeslots, rooms, lessons)


def print_timetable(timetable: Timetable) -> None:
    """Print the solution in a readable format."""
    print(f"\nScore: {timetable.score}\n")

    for lesson in timetable.lessons:
        print(f"{lesson.subject} ({lesson.teacher}, {lesson.student_group})")
        print(f"  -> {lesson.timeslot} in {lesson.room}")
        print()


if __name__ == "__main__":
    main()
```

## Step 4: Run It

```bash
python -m hello_world.main
```

You should see output like:

```
Score: 0hard/-3soft

Math (A. Turing, 9th grade)
  -> MONDAY 08:30 in Room A

Physics (M. Curie, 9th grade)
  -> MONDAY 09:30 in Room B

Chemistry (M. Curie, 9th grade)
  -> TUESDAY 08:30 in Room B

...
```

A score of `0hard` means all hard constraints are satisfied (no conflicts). The negative soft score indicates room for optimization of preferences.

## Understanding the Output

- **0hard** = No conflicts (feasible solution!)
- **-3soft** = 3 soft constraint violations (teachers using multiple rooms)

The solver found a valid timetable where:
- No room has two lessons at the same time
- No teacher teaches two lessons at the same time
- No student group has two lessons at the same time

## Next Steps

- [Hello World with FastAPI](hello-world-fastapi.md) - Add a REST API
- [Domain Modeling](../modeling/) - Learn more about entities and variables
- [Constraints](../constraints/) - Explore the full Constraint Streams API
