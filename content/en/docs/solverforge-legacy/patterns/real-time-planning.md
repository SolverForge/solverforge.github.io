---
title: "Real-Time Planning"
linkTitle: "Real-Time Planning"
weight: 10
description: >
  Handle changes while the solver is running.
---

**Real-time planning** allows you to modify the problem while the solver is running. This is essential for handling dynamic changes like new orders, cancellations, or resource changes.

## Problem Changes

Use `ProblemChange` to modify the working solution:

```python
from solverforge_legacy.solver import ProblemChange

class AddLessonChange(ProblemChange[Timetable]):
    def __init__(self, lesson: Lesson):
        self.lesson = lesson

    def do_change(self, working_solution: Timetable, score_director):
        # Add to solution
        working_solution.lessons.append(self.lesson)
        # Notify score director
        score_director.after_entity_added(self.lesson)
```

### Applying Changes

```python
# With Solver
new_lesson = Lesson("new-1", "Art", "S. Dali", "Group A")
solver.add_problem_change(AddLessonChange(new_lesson))

# With SolverManager
solver_manager.add_problem_change(job_id, AddLessonChange(new_lesson))
```

## Common Change Types

### Add Entity

```python
class AddVisitChange(ProblemChange[RoutePlan]):
    def __init__(self, visit: Visit):
        self.visit = visit

    def do_change(self, solution: RoutePlan, score_director):
        solution.visits.append(self.visit)
        score_director.after_entity_added(self.visit)
```

### Remove Entity

```python
class RemoveVisitChange(ProblemChange[RoutePlan]):
    def __init__(self, visit_id: str):
        self.visit_id = visit_id

    def do_change(self, solution: RoutePlan, score_director):
        visit = next(v for v in solution.visits if v.id == self.visit_id)

        # Remove from vehicle if assigned
        if visit.vehicle:
            score_director.before_list_variable_changed(
                visit.vehicle, "visits", visit.vehicle.visits
            )
            visit.vehicle.visits.remove(visit)
            score_director.after_list_variable_changed(
                visit.vehicle, "visits", visit.vehicle.visits
            )

        # Remove from solution
        score_director.before_entity_removed(visit)
        solution.visits.remove(visit)
        score_director.after_entity_removed(visit)
```

### Modify Entity

```python
class UpdateVisitDemandChange(ProblemChange[RoutePlan]):
    def __init__(self, visit_id: str, new_demand: int):
        self.visit_id = visit_id
        self.new_demand = new_demand

    def do_change(self, solution: RoutePlan, score_director):
        visit = next(v for v in solution.visits if v.id == self.visit_id)

        score_director.before_problem_property_changed(visit)
        visit.demand = self.new_demand
        score_director.after_problem_property_changed(visit)
```

### Add Problem Fact

```python
class AddVehicleChange(ProblemChange[RoutePlan]):
    def __init__(self, vehicle: Vehicle):
        self.vehicle = vehicle

    def do_change(self, solution: RoutePlan, score_director):
        solution.vehicles.append(self.vehicle)
        score_director.after_problem_fact_added(self.vehicle)
```

## Score Director Notifications

Always notify the score director of changes:

| Method | When to Use |
|--------|-------------|
| `after_entity_added()` | Added planning entity |
| `before/after_entity_removed()` | Removing planning entity |
| `before/after_variable_changed()` | Changed planning variable |
| `before/after_list_variable_changed()` | Changed list variable |
| `before/after_problem_property_changed()` | Changed entity property |
| `after_problem_fact_added()` | Added problem fact |
| `before/after_problem_fact_removed()` | Removing problem fact |

### Order Matters

For removals and changes, call `before_*` first:

```python
score_director.before_entity_removed(entity)
# Actually remove
solution.entities.remove(entity)
score_director.after_entity_removed(entity)
```

## Real-Time API Example

```python
from fastapi import FastAPI
from solverforge_legacy.solver import SolverManager, ProblemChange

app = FastAPI()
solver_manager: SolverManager


@app.post("/visits")
async def add_visit(visit: VisitRequest, job_id: str):
    """Add a visit to an active solving job."""
    new_visit = Visit(
        id=str(uuid.uuid4()),
        location=visit.location,
        demand=visit.demand,
    )

    solver_manager.add_problem_change(
        job_id,
        AddVisitChange(new_visit)
    )

    return {"id": new_visit.id, "status": "added"}


@app.delete("/visits/{visit_id}")
async def remove_visit(visit_id: str, job_id: str):
    """Remove a visit from an active solving job."""
    solver_manager.add_problem_change(
        job_id,
        RemoveVisitChange(visit_id)
    )

    return {"status": "removed"}
```

## Change Ordering

Changes are applied in the order they're submitted:

```python
solver.add_problem_change(change1)  # Applied first
solver.add_problem_change(change2)  # Applied second
solver.add_problem_change(change3)  # Applied third
```

## Best Practices

### Do

- Keep changes small and focused
- Notify score director of all modifications
- Use `before_*` methods for removals/changes
- Test changes in isolation

### Don't

- Make changes without notifying score director
- Modify multiple entities in one complex change
- Forget to handle entity relationships

## Debugging Changes

```python
class DebugChange(ProblemChange[Solution]):
    def __init__(self, inner: ProblemChange):
        self.inner = inner

    def do_change(self, solution, score_director):
        print(f"Before: {len(solution.entities)} entities")
        self.inner.do_change(solution, score_director)
        print(f"After: {len(solution.entities)} entities")
```

## Next Steps

- [Continuous Planning](continuous-planning.md) - Rolling horizon patterns
- [SolverManager](../solver/solver-manager.md) - Managing concurrent jobs
