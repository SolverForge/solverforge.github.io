---
title: "Testing Constraints"
linkTitle: "Testing"
weight: 70
description: >
  Test constraints in isolation for correctness.
---

Testing constraints ensures they behave correctly before integrating with the full solver. This catches bugs early and documents expected behavior.

## Basic Constraint Testing

Test individual constraints with minimal data:

```python
import pytest
from solverforge_legacy.solver import SolverFactory
from solverforge_legacy.solver.config import (
    SolverConfig, ScoreDirectorFactoryConfig, TerminationConfig, Duration
)
from datetime import time

from my_app.domain import Timetable, Timeslot, Room, Lesson
from my_app.constraints import define_constraints


@pytest.fixture
def solution_manager():
    config = SolverConfig(
        solution_class=Timetable,
        entity_class_list=[Lesson],
        score_director_factory_config=ScoreDirectorFactoryConfig(
            constraint_provider_function=define_constraints
        ),
        termination_config=TerminationConfig(spent_limit=Duration(seconds=1))
    )
    factory = SolverFactory.create(config)
    return SolutionManager.create(factory)


def test_room_conflict(solution_manager):
    """Two lessons in the same room at the same time should penalize."""
    timeslot = Timeslot("MONDAY", time(8, 30), time(9, 30))
    room = Room("Room A")

    # Two lessons in same room and timeslot
    lesson1 = Lesson("1", "Math", "Teacher A", "Group 1", timeslot, room)
    lesson2 = Lesson("2", "Physics", "Teacher B", "Group 2", timeslot, room)

    problem = Timetable(
        id="test",
        timeslots=[timeslot],
        rooms=[room],
        lessons=[lesson1, lesson2]
    )

    analysis = solution_manager.analyze(problem)

    # Should have -1 hard for the room conflict
    assert analysis.score.hard_score == -1


def test_no_room_conflict(solution_manager):
    """Two lessons in different rooms should not conflict."""
    timeslot = Timeslot("MONDAY", time(8, 30), time(9, 30))
    room_a = Room("Room A")
    room_b = Room("Room B")

    lesson1 = Lesson("1", "Math", "Teacher A", "Group 1", timeslot, room_a)
    lesson2 = Lesson("2", "Physics", "Teacher B", "Group 2", timeslot, room_b)

    problem = Timetable(
        id="test",
        timeslots=[timeslot],
        rooms=[room_a, room_b],
        lessons=[lesson1, lesson2]
    )

    analysis = solution_manager.analyze(problem)

    # Should have no hard constraint violations
    assert analysis.score.hard_score == 0
```

## Testing Constraint Weight

Verify the magnitude of penalties:

```python
def test_teacher_room_stability_weight(solution_manager):
    """Teacher using multiple rooms should incur soft penalty per extra room."""
    timeslot1 = Timeslot("MONDAY", time(8, 30), time(9, 30))
    timeslot2 = Timeslot("MONDAY", time(9, 30), time(10, 30))
    room_a = Room("Room A")
    room_b = Room("Room B")

    # Same teacher, different rooms
    lesson1 = Lesson("1", "Math", "Teacher A", "Group 1", timeslot1, room_a)
    lesson2 = Lesson("2", "Math", "Teacher A", "Group 2", timeslot2, room_b)

    problem = Timetable(
        id="test",
        timeslots=[timeslot1, timeslot2],
        rooms=[room_a, room_b],
        lessons=[lesson1, lesson2]
    )

    analysis = solution_manager.analyze(problem)

    # Should have soft penalty for room instability
    assert analysis.score.soft_score < 0

    # Verify specific constraint triggered
    room_stability = next(
        ca for ca in analysis.constraint_analyses()
        if ca.constraint_name == "Teacher room stability"
    )
    assert room_stability.match_count == 1
```

## Testing with Fixtures

Create reusable test fixtures:

```python
@pytest.fixture
def timeslots():
    return [
        Timeslot("MONDAY", time(8, 30), time(9, 30)),
        Timeslot("MONDAY", time(9, 30), time(10, 30)),
        Timeslot("TUESDAY", time(8, 30), time(9, 30)),
    ]


@pytest.fixture
def rooms():
    return [Room("A"), Room("B"), Room("C")]


@pytest.fixture
def empty_problem(timeslots, rooms):
    return Timetable(
        id="test",
        timeslots=timeslots,
        rooms=rooms,
        lessons=[]
    )


def test_empty_problem_is_feasible(solution_manager, empty_problem):
    """Empty problem should have zero score."""
    analysis = solution_manager.analyze(empty_problem)
    assert analysis.score == HardSoftScore.ZERO
```

## Testing Edge Cases

### Unassigned Variables

```python
def test_unassigned_lesson(solution_manager):
    """Unassigned lessons should not cause conflicts."""
    timeslot = Timeslot("MONDAY", time(8, 30), time(9, 30))
    room = Room("Room A")

    # One assigned, one not
    lesson1 = Lesson("1", "Math", "Teacher A", "Group 1", timeslot, room)
    lesson2 = Lesson("2", "Physics", "Teacher B", "Group 2", None, None)

    problem = Timetable(
        id="test",
        timeslots=[timeslot],
        rooms=[room],
        lessons=[lesson1, lesson2]
    )

    analysis = solution_manager.analyze(problem)

    # Should not have room conflict (lesson2 is unassigned)
    assert analysis.score.hard_score == 0
```

### Multiple Violations

```python
def test_multiple_conflicts(solution_manager):
    """Three lessons in same room/time should create multiple conflicts."""
    timeslot = Timeslot("MONDAY", time(8, 30), time(9, 30))
    room = Room("Room A")

    lesson1 = Lesson("1", "Math", "A", "G1", timeslot, room)
    lesson2 = Lesson("2", "Physics", "B", "G2", timeslot, room)
    lesson3 = Lesson("3", "Chemistry", "C", "G3", timeslot, room)

    problem = Timetable(
        id="test",
        timeslots=[timeslot],
        rooms=[room],
        lessons=[lesson1, lesson2, lesson3]
    )

    analysis = solution_manager.analyze(problem)

    # 3 lessons create 3 unique pairs: (1,2), (1,3), (2,3)
    assert analysis.score.hard_score == -3
```

## Feasibility Testing

Test that the solver can find a feasible solution:

```python
def test_feasible_solution():
    """Solver should find a feasible solution for small problems."""
    config = SolverConfig(
        solution_class=Timetable,
        entity_class_list=[Lesson],
        score_director_factory_config=ScoreDirectorFactoryConfig(
            constraint_provider_function=define_constraints
        ),
        termination_config=TerminationConfig(spent_limit=Duration(seconds=5))
    )

    factory = SolverFactory.create(config)
    solver = factory.build_solver()

    problem = generate_small_problem()
    solution = solver.solve(problem)

    assert solution.score.is_feasible, f"Solution infeasible: {solution.score}"
```

## Parameterized Tests

Test multiple scenarios efficiently:

```python
@pytest.mark.parametrize("num_lessons,expected_conflicts", [
    (1, 0),  # Single lesson: no conflicts
    (2, 1),  # Two lessons: one pair
    (3, 3),  # Three lessons: three pairs
    (4, 6),  # Four lessons: six pairs
])
def test_all_in_same_room_timeslot(solution_manager, num_lessons, expected_conflicts):
    """n lessons in same room/time should create n*(n-1)/2 conflicts."""
    timeslot = Timeslot("MONDAY", time(8, 30), time(9, 30))
    room = Room("Room A")

    lessons = [
        Lesson(str(i), f"Subject{i}", f"Teacher{i}", "Group", timeslot, room)
        for i in range(num_lessons)
    ]

    problem = Timetable(
        id="test",
        timeslots=[timeslot],
        rooms=[room],
        lessons=lessons
    )

    analysis = solution_manager.analyze(problem)
    assert analysis.score.hard_score == -expected_conflicts
```

## Testing Justifications

```python
def test_constraint_justification(solution_manager):
    """Constraint should provide meaningful justification."""
    timeslot = Timeslot("MONDAY", time(8, 30), time(9, 30))
    room = Room("Room A")

    lesson1 = Lesson("1", "Math", "Teacher A", "Group 1", timeslot, room)
    lesson2 = Lesson("2", "Physics", "Teacher B", "Group 2", timeslot, room)

    problem = Timetable(
        id="test",
        timeslots=[timeslot],
        rooms=[room],
        lessons=[lesson1, lesson2]
    )

    analysis = solution_manager.analyze(problem)

    room_conflict_ca = next(
        ca for ca in analysis.constraint_analyses()
        if ca.constraint_name == "Room conflict"
    )

    match = next(room_conflict_ca.matches())
    assert "Room A" in str(match.justification)
    assert "MONDAY" in str(match.justification)
```

## Best Practices

### Do

- Test each constraint in isolation
- Test both positive and negative cases
- Test edge cases (empty, unassigned, maximum)
- Use descriptive test names

### Don't

- Skip constraint testing
- Only test happy paths
- Use production data sizes in unit tests
- Ignore constraint weights

## Next Steps

- [Solver Configuration](../solver/configuration.md) - Configure the solver
- [Score Analysis](score-analysis.md) - Debug score issues
