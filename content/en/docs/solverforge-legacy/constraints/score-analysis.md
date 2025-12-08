---
title: "Score Analysis"
linkTitle: "Score Analysis"
weight: 50
description: >
  Understand why a solution has its score.
---

**Score analysis** helps you understand why a solution received its score. This is essential for debugging constraints and explaining results to users.

## SolutionManager

Use `SolutionManager` to analyze solutions:

```python
from solverforge_legacy.solver import SolverFactory, SolutionManager

solver_factory = SolverFactory.create(solver_config)
solution_manager = SolutionManager.create(solver_factory)

# Analyze a solution
analysis = solution_manager.analyze(solution)
```

## Score Explanation

Get a breakdown of constraint scores:

```python
analysis = solution_manager.analyze(solution)

# Overall score
print(f"Score: {analysis.score}")

# Per-constraint breakdown
for constraint_analysis in analysis.constraint_analyses():
    print(f"{constraint_analysis.constraint_name}: {constraint_analysis.score}")
    print(f"  Match count: {constraint_analysis.match_count}")
```

Example output:
```
Score: -2hard/-15soft
Room conflict: -2hard
  Match count: 2
Teacher room stability: -10soft
  Match count: 10
Teacher time efficiency: -5soft
  Match count: 5
```

## Constraint Matches

See exactly which entities triggered each constraint:

```python
for constraint_analysis in analysis.constraint_analyses():
    print(f"\n{constraint_analysis.constraint_name}:")
    for match in constraint_analysis.matches():
        print(f"  Match: {match.justification}")
        print(f"  Score: {match.score}")
```

## Indictments

Find which entities are causing problems:

```python
# Get indictments (entities blamed for score impact)
for indictment in analysis.indictments():
    print(f"\nEntity: {indictment.indicted_object}")
    print(f"Total score impact: {indictment.score}")
    for match in indictment.matches():
        print(f"  - {match.constraint_name}: {match.score}")
```

Example output:
```
Entity: Lesson(id=1, subject='Math')
Total score impact: -1hard/-3soft
  - Room conflict: -1hard
  - Teacher room stability: -3soft
```

## Custom Justifications

Add explanations to your constraints:

```python
@dataclass
class RoomConflictJustification:
    lesson1: Lesson
    lesson2: Lesson
    timeslot: Timeslot
    room: Room

    def __str__(self):
        return (f"{self.lesson1.subject} and {self.lesson2.subject} "
                f"both scheduled in {self.room} at {self.timeslot}")

def room_conflict(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each_unique_pair(
            Lesson,
            Joiners.equal(lambda l: l.timeslot),
            Joiners.equal(lambda l: l.room),
        )
        .penalize(HardSoftScore.ONE_HARD)
        .justify_with(lambda l1, l2, score: RoomConflictJustification(
            l1, l2, l1.timeslot, l1.room
        ))
        .as_constraint("Room conflict")
    )
```

## Debugging Constraints

### Verify Score Calculation

```python
# Calculate score without solving
score = solution_manager.update(solution)
print(f"Calculated score: {score}")
```

### Find Missing Constraints

If a constraint isn't firing when expected:

```python
# Check if specific entities match
for constraint_analysis in analysis.constraint_analyses():
    if constraint_analysis.constraint_name == "Room conflict":
        if constraint_analysis.match_count == 0:
            print("No room conflicts detected!")
            # Check your joiners and filters
```

### Verify Feasibility

```python
if not solution.score.is_feasible:
    print("Solution is infeasible!")
    for ca in analysis.constraint_analyses():
        if ca.score.hard_score < 0:
            print(f"Hard constraint broken: {ca.constraint_name}")
            for match in ca.matches():
                print(f"  {match.justification}")
```

## Integration with FastAPI

Expose score analysis in your API:

```python
from fastapi import FastAPI

@app.get("/analysis/{job_id}")
async def get_analysis(job_id: str):
    solution = solutions.get(job_id)
    if not solution:
        raise HTTPException(404, "Job not found")

    analysis = solution_manager.analyze(solution)

    return {
        "score": str(analysis.score),
        "is_feasible": analysis.score.is_feasible,
        "constraints": [
            {
                "name": ca.constraint_name,
                "score": str(ca.score),
                "match_count": ca.match_count,
            }
            for ca in analysis.constraint_analyses()
        ]
    }
```

## Best Practices

### Do

- Use `justify_with()` for user-facing explanations
- Check score analysis when debugging constraints
- Expose score breakdown in your UI

### Don't

- Analyze every solution during solving (performance)
- Ignore indictments when troubleshooting
- Forget to handle infeasible solutions

## Score Comparison

Compare two solutions:

```python
def compare_solutions(old: Timetable, new: Timetable):
    old_analysis = solution_manager.analyze(old)
    new_analysis = solution_manager.analyze(new)

    print(f"Score improved: {old.score} -> {new.score}")

    old_constraints = {ca.constraint_name: ca for ca in old_analysis.constraint_analyses()}
    new_constraints = {ca.constraint_name: ca for ca in new_analysis.constraint_analyses()}

    for name in old_constraints:
        old_ca = old_constraints[name]
        new_ca = new_constraints.get(name)
        if new_ca and old_ca.score != new_ca.score:
            print(f"  {name}: {old_ca.score} -> {new_ca.score}")
```

## Next Steps

- [Performance](performance.md) - Optimize constraint evaluation
- [Testing](testing.md) - Test constraints in isolation
