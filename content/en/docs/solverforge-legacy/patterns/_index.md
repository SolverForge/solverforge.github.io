---
title: "Design Patterns"
linkTitle: "Patterns"
weight: 80
tags: [concepts, python]
description: >
  Common patterns for handling real-world planning scenarios.
---

Real-world planning problems often require more than basic optimization. This section covers patterns for common scenarios.

## Topics

- **[Real-Time Planning](real-time-planning.md)** - Handle changes while the solver is running
- **[Continuous Planning](continuous-planning.md)** - Rolling horizon and replanning strategies
- **[Repeated Planning](repeated-planning.md)** - Batch optimization patterns

## Real-Time Planning

Handle dynamic changes during solving:

```python
from solverforge_legacy.solver import ProblemChange

class AddLessonChange(ProblemChange[Timetable]):
    def __init__(self, lesson: Lesson):
        self.lesson = lesson

    def do_change(self, working_solution: Timetable, score_director):
        # Add the new lesson to the working solution
        working_solution.lessons.append(self.lesson)
        score_director.after_entity_added(self.lesson)

# Apply change while solver is running
solver.add_problem_change(AddLessonChange(new_lesson))
```

## Continuous Planning

For problems that span long time periods, use a rolling horizon:

1. **Plan Window** - Only optimize a subset of the timeline
2. **Published Window** - Lock decisions that are being executed
3. **Draft Window** - Future decisions that can still change

## When to Use These Patterns

| Scenario | Pattern |
|----------|---------|
| New orders arrive during planning | Real-Time Planning |
| Plan extends into the future | Continuous Planning |
| Daily/weekly batch optimization | Repeated Planning |
| Vehicle breakdowns, cancellations | Real-Time Planning |
| Rolling weekly schedules | Continuous Planning |
