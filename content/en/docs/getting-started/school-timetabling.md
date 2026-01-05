---
title: "School Timetabling"
linkTitle: "School Timetabling"
icon: fa-brands fa-python
date: 2025-11-26
weight: 40
draft: true
description: "A comprehensive quickstart guide to understanding and building intelligent school timetabling with SolverForge"
categories: [Quickstarts]
tags: [quickstart, python]
---

{{% pageinfo color="warning" %}}
**Legacy Implementation Guide**

This guide uses **solverforge-legacy**, a fork of Timefold 1.24 that bridges Python to Java via JPype. This legacy implementation is **already archived** and will no longer be maintained once SolverForge's native Python bindings are production-ready.

SolverForge has been **completely rewritten as a native constraint solver in Rust**. This guide is preserved for educational purposes and constraint modeling concepts.
{{% /pageinfo %}}

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [Understanding the Data Model](#understanding-the-data-model)
5. [How Optimization Works](#how-optimization-works)
6. [Writing Constraints: The Business Rules](#writing-constraints-the-business-rules)
7. [The Solver Engine](#the-solver-engine)
8. [Running and Analyzing Solutions](#running-and-analyzing-solutions)
9. [Making Your First Customization](#making-your-first-customization)
10. [Quick Reference](#quick-reference)

---

## Introduction

### What You'll Learn

This guide walks you through a complete school timetabling application built with **SolverForge**, a constraint-based optimization framework. You'll learn:

- How to model real-world scheduling problems as **optimization problems**
- How to express business rules as **constraints** that guide the solution
- How optimization algorithms find high-quality solutions automatically
- How to customize the system for your specific needs

**No optimization background required** — we'll explain concepts as we encounter them in the code.

### Prerequisites

- Basic Python knowledge (classes, functions, type annotations)
- Familiarity with dataclasses
- Comfort with command-line operations

### What is Constraint-Based Optimization?

Traditional programming: You write explicit logic that says "do this, then that."

**Constraint-based optimization**: You describe what a good solution looks like and the solver figures out how to achieve it.

Think of it like describing what puzzle pieces you have and what rules they must follow — then having a computer try millions of arrangements per second to find the best fit.

---

## Getting Started

### Running the Application

1. **Download and navigate to the project directory:**
   ```bash
   git clone https://github.com/SolverForge/solverforge-quickstarts
   cd ./solverforge-quickstarts/legacy/school-timetabling
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the solver:**
   ```bash
   python main.py
   ```

You'll see output showing the solver assigning lessons to timeslots and rooms while respecting all constraints.

### File Structure Overview

```
school-timetabling/
├── domain.py              # Data classes (Timeslot, Room, Lesson, Timetable)
├── constraints.py         # Business rules (90% of customization happens here)
├── main.py                # Solver configuration and entry point
└── demo_data.py           # Sample data generation
```

---

## The Problem We're Solving

### The Real-World Challenge

A school needs to create a weekly timetable:

- **Lessons** need to be assigned to **timeslots** and **rooms**
- **Teachers** can only teach one class at a time
- **Student groups** can only attend one lesson at a time
- **Rooms** can only host one lesson at a time
- Teachers prefer to stay in the same room (less walking)
- Teachers prefer consecutive lessons (no awkward gaps)
- Students prefer variety (not the same subject twice in a row)

### The Optimization Model

| Concept | In Our Model | Description |
|---------|--------------|-------------|
| **Planning Entity** | `Lesson` | What we're scheduling |
| **Planning Variables** | `timeslot`, `room` | What the solver assigns |
| **Problem Facts** | `Timeslot`, `Room` | Fixed input data |
| **Hard Constraints** | Conflicts | Must never be violated |
| **Soft Constraints** | Preferences | Minimize violations |

---

## Understanding the Data Model

### Problem Facts

Problem facts are immutable data that constrain the solution. They don't change during solving.

#### Timeslot

```python
from dataclasses import dataclass
from datetime import time

@dataclass
class Timeslot:
    day_of_week: str
    start_time: time
    end_time: time

    def __str__(self):
        return f"{self.day_of_week} {self.start_time.strftime('%H:%M')}"
```

Each timeslot represents a specific time period on a day when a lesson can be scheduled.

#### Room

```python
@dataclass
class Room:
    name: str

    def __str__(self):
        return f"{self.name}"
```

Rooms are the physical spaces where lessons take place.

### Planning Entity: Lesson

The `Lesson` is the **planning entity** — the thing being planned. Each lesson must be assigned a timeslot and room by the solver.

```python
from solverforge_legacy.solver.domain import (
    planning_entity,
    PlanningId,
    PlanningVariable,
)
from typing import Annotated
from dataclasses import dataclass, field

@planning_entity
@dataclass
class Lesson:
    id: Annotated[str, PlanningId]
    subject: str
    teacher: str
    student_group: str
    timeslot: Annotated[Timeslot | None, PlanningVariable] = field(default=None)
    room: Annotated[Room | None, PlanningVariable] = field(default=None)
```

**Key elements:**

| Element | Purpose |
|---------|---------|
| `@planning_entity` | Marks the class as a planning entity |
| `PlanningId` | Unique identifier for the entity |
| `PlanningVariable` | Variables the solver assigns values to |
| Default `None` | Variables start unassigned |

### Planning Solution: Timetable

The `Timetable` wraps the entire problem and solution:

```python
from solverforge_legacy.solver.domain import (
    planning_solution,
    PlanningEntityCollectionProperty,
    ProblemFactCollectionProperty,
    ValueRangeProvider,
    PlanningScore,
)
from solverforge_legacy.solver.score import HardSoftScore

@planning_solution
@dataclass
class Timetable:
    id: str
    timeslots: Annotated[
        list[Timeslot], ProblemFactCollectionProperty, ValueRangeProvider
    ]
    rooms: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
    lessons: Annotated[list[Lesson], PlanningEntityCollectionProperty]
    score: Annotated[HardSoftScore, PlanningScore] = field(default=None)
```

**Key annotations:**

| Annotation | Purpose |
|------------|---------|
| `@planning_solution` | Marks the class as the solution container |
| `ProblemFactCollectionProperty` | Immutable input data |
| `ValueRangeProvider` | Possible values for planning variables |
| `PlanningEntityCollectionProperty` | Collection of entities to plan |
| `PlanningScore` | Where the score is stored |

---

## How Optimization Works

### The Solving Process

1. **Construction Phase**: Build an initial solution (may violate constraints)
2. **Local Search Phase**: Iteratively improve by making small changes
3. **Termination**: Stop after time limit, score threshold, or no improvement

### Score Calculation

Every solution has a **score** that measures how good it is:

```
Score: 0hard/-4soft
       ↑        ↑
       │        └── Soft constraint penalties
       └── Hard constraint violations (must be 0 for feasible solution)
```

- **Hard constraints**: Must be satisfied (conflicts, overlaps)
- **Soft constraints**: Should be satisfied (preferences)

The solver tries to find the solution with the best score.

---

## Writing Constraints: The Business Rules

### Constraint Provider

Define all constraints in a single function decorated with `@constraint_provider`:

```python
from solverforge_legacy.solver.score import (
    constraint_provider,
    HardSoftScore,
    Joiners,
    ConstraintFactory,
    Constraint,
)

from .domain import Lesson

@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # Hard constraints
        room_conflict(constraint_factory),
        teacher_conflict(constraint_factory),
        student_group_conflict(constraint_factory),
        # Soft constraints
        teacher_room_stability(constraint_factory),
        teacher_time_efficiency(constraint_factory),
        student_group_subject_variety(constraint_factory),
    ]
```

### Hard Constraints

Hard constraints must **never** be violated — they define what makes a solution feasible.

#### Room Conflict

A room can only host one lesson at a time:

```python
def room_conflict(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory
        # Select each pair of 2 different lessons ...
        .for_each_unique_pair(
            Lesson,
            # ... in the same timeslot ...
            Joiners.equal(lambda lesson: lesson.timeslot),
            # ... in the same room ...
            Joiners.equal(lambda lesson: lesson.room),
        )
        # ... and penalize each pair with a hard weight.
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Room conflict")
    )
```

#### Teacher Conflict

A teacher can teach at most one lesson at a time:

```python
def teacher_conflict(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.timeslot),
            Joiners.equal(lambda lesson: lesson.teacher),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Teacher conflict")
    )
```

#### Student Group Conflict

A student group can attend at most one lesson at a time:

```python
def student_group_conflict(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda lesson: lesson.timeslot),
            Joiners.equal(lambda lesson: lesson.student_group),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Student group conflict")
    )
```

### Soft Constraints

Soft constraints define preferences — violations are allowed but minimized.

#### Teacher Room Stability

Teachers prefer to stay in the same room (less walking between classes):

```python
def teacher_room_stability(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each_unique_pair(
            Lesson, Joiners.equal(lambda lesson: lesson.teacher)
        )
        .filter(lambda lesson1, lesson2: lesson1.room != lesson2.room)
        .penalize(HardSoftScore.ONE_SOFT)
        .as_constraint("Teacher room stability")
    )
```

#### Teacher Time Efficiency

Teachers prefer consecutive lessons without gaps:

```python
from datetime import time

def to_minutes(moment: time) -> int:
    return moment.hour * 60 + moment.minute

def is_between(lesson1: Lesson, lesson2: Lesson) -> bool:
    difference = to_minutes(lesson1.timeslot.end_time) - to_minutes(
        lesson2.timeslot.start_time
    )
    return 0 <= difference <= 30

def teacher_time_efficiency(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each(Lesson)
        .join(
            Lesson,
            Joiners.equal(lambda lesson: lesson.teacher),
            Joiners.equal(lambda lesson: lesson.timeslot.day_of_week),
        )
        .filter(is_between)
        .reward(HardSoftScore.ONE_SOFT)
        .as_constraint("Teacher time efficiency")
    )
```

#### Student Group Subject Variety

Students prefer not to have the same subject twice in a row:

```python
def student_group_subject_variety(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        (
            constraint_factory.for_each(Lesson)
            .join(
                Lesson,
                Joiners.equal(lambda lesson: lesson.subject),
                Joiners.equal(lambda lesson: lesson.student_group),
                Joiners.equal(lambda lesson: lesson.timeslot.day_of_week),
            )
            .filter(is_between)
        ).penalize(HardSoftScore.ONE_SOFT)
    ).as_constraint("Student group subject variety")
```

### Understanding Constraint Patterns

| Pattern | When to Use |
|---------|-------------|
| `for_each_unique_pair` | Compare all pairs without duplicates |
| `for_each` + `join` | When you need direction or different filters |
| `filter` | Python-based filtering after initial selection |
| `Joiners.equal` | Match on property equality |

---

## The Solver Engine

### Solver Configuration

```python
from solverforge_legacy.solver import SolverFactory
from solverforge_legacy.solver.config import (
    SolverConfig,
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
)

from .domain import Timetable, Lesson
from .constraints import define_constraints

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

solver_factory = SolverFactory.create(config)
solver = solver_factory.build_solver()
```

### Configuration Options

| Option | Purpose |
|--------|---------|
| `solution_class` | The planning solution class |
| `entity_class_list` | List of planning entity classes |
| `constraint_provider_function` | Function that defines constraints |
| `spent_limit` | Maximum solving time |

---

## Running and Analyzing Solutions

### Basic Solving

```python
from .domain import create_demo_data

# Create the problem
problem = create_demo_data()

print(f"Solving timetable with {len(problem.lessons)} lessons...")

# Solve
solution = solver.solve(problem)

print(f"Score: {solution.score}")
```

### Printing the Timetable

```python
def print_timetable(timetable: Timetable):
    # Group lessons by timeslot
    by_timeslot = {}
    for lesson in timetable.lessons:
        if lesson.timeslot:
            key = str(lesson.timeslot)
            if key not in by_timeslot:
                by_timeslot[key] = []
            by_timeslot[key].append(lesson)

    # Print
    print(f"\nTimetable (Score: {timetable.score})")
    print("-" * 60)

    for timeslot_str in sorted(by_timeslot.keys()):
        print(f"\n{timeslot_str}:")
        for lesson in by_timeslot[timeslot_str]:
            room = lesson.room.name if lesson.room else "Unassigned"
            print(f"  {lesson.subject} ({lesson.teacher}) - {room}")

print_timetable(solution)
```

### Score Analysis

Use `SolutionManager` to understand the score breakdown:

```python
from solverforge_legacy.solver import SolutionManager

solution_manager = SolutionManager.create(solver_factory)
analysis = solution_manager.analyze(solution)

print(f"\nScore Analysis")
print(f"Total: {analysis.score}")
print(f"Feasible: {analysis.score.is_feasible}")
print()

for constraint_analysis in analysis.constraint_analyses():
    print(f"{constraint_analysis.constraint_name}:")
    print(f"  Score: {constraint_analysis.score}")
    print(f"  Matches: {constraint_analysis.match_count}")
```

### Sample Output

```
Solving timetable with 8 lessons...

============================================================
Solution found!
Score: 0hard/-4soft
Feasible: True
============================================================

MONDAY 08:30:
  Math (A. Turing) -> Room A
  Physics (M. Curie) -> Room B

MONDAY 09:30:
  Math (A. Turing) -> Room A
  Chemistry (M. Curie) -> Room B

MONDAY 10:30:
  Biology (C. Darwin) -> Room A
  History (I. Newton) -> Room B

TUESDAY 08:30:
  English (P. Cruz) -> Room A

TUESDAY 09:30:
  Spanish (P. Cruz) -> Room A

Constraint Breakdown:
  Room conflict: 0hard
  Teacher conflict: 0hard
  Student group conflict: 0hard
  Teacher room stability: 0soft
  Teacher time efficiency: -2soft
  Student group subject variety: -2soft
```

---

## Making Your First Customization

### Add a New Hard Constraint

Let's add a constraint that certain rooms can only host certain subjects (e.g., labs for science):

```python
def room_subject_compatibility(constraint_factory: ConstraintFactory) -> Constraint:
    # Define which subjects require special rooms
    lab_subjects = {"Physics", "Chemistry", "Biology"}
    lab_rooms = {"Lab A", "Lab B"}

    return (
        constraint_factory.for_each(Lesson)
        .filter(lambda lesson: (
            lesson.subject in lab_subjects and
            lesson.room.name not in lab_rooms
        ))
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Lab subject in non-lab room")
    )
```

### Add a New Soft Constraint

Let's add a preference for morning lessons for certain subjects:

```python
def morning_math(constraint_factory: ConstraintFactory) -> Constraint:
    return (
        constraint_factory.for_each(Lesson)
        .filter(lambda lesson: (
            lesson.subject == "Math" and
            lesson.timeslot.start_time.hour >= 10
        ))
        .penalize(HardSoftScore.ONE_SOFT)
        .as_constraint("Math prefers morning")
    )
```

### Register Your Constraints

Add them to the constraint provider:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # Hard constraints
        room_conflict(constraint_factory),
        teacher_conflict(constraint_factory),
        student_group_conflict(constraint_factory),
        room_subject_compatibility(constraint_factory),  # NEW
        # Soft constraints
        teacher_room_stability(constraint_factory),
        teacher_time_efficiency(constraint_factory),
        student_group_subject_variety(constraint_factory),
        morning_math(constraint_factory),  # NEW
    ]
```

---

## Quick Reference

### Domain Modeling Annotations

| Annotation | Usage |
|------------|-------|
| `@planning_entity` | Mark a class as a planning entity |
| `@planning_solution` | Mark a class as the solution container |
| `PlanningId` | Unique identifier annotation |
| `PlanningVariable` | Variable the solver assigns |
| `ProblemFactCollectionProperty` | Immutable input collection |
| `ValueRangeProvider` | Possible values for variables |
| `PlanningEntityCollectionProperty` | Entities to be planned |
| `PlanningScore` | Where the score is stored |

### Constraint Stream Operations

| Operation | Description |
|-----------|-------------|
| `for_each(Class)` | Start stream with all instances |
| `for_each_unique_pair(Class, ...)` | All unique pairs matching joiners |
| `join(Class, ...)` | Join with another class |
| `filter(lambda)` | Filter by Python predicate |
| `penalize(score)` | Add penalty for matches |
| `reward(score)` | Add reward for matches |
| `as_constraint("name")` | Name the constraint |

### Joiner Types

| Joiner | Description |
|--------|-------------|
| `Joiners.equal(fn)` | Match when values are equal |
| `Joiners.less_than(fn)` | Match when left < right |
| `Joiners.overlapping(start_fn, end_fn)` | Match when ranges overlap |

### Score Types

| Score | When to Use |
|-------|-------------|
| `HardSoftScore` | Most problems (hard/soft distinction) |
| `HardMediumSoftScore` | Three priority levels |
| `HardSoftDecimalScore` | When you need decimal precision |

---

## Next Steps

- [Employee Scheduling](employee-scheduling/) — Learn about skill matching and load balancing
- [Vehicle Routing](vehicle-routing/) — Learn about list variables and shadow variables
- [Meeting Scheduling](meeting-scheduling/) — Learn about time grain modeling
- [Constraint Streams](/docs/solverforge-legacy/constraints/constraint-streams/) — Deep dive into constraints
- [FastAPI Integration](/docs/solverforge-legacy/integration/fastapi/) — Build a REST API for your solver
