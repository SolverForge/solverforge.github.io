---
title: "SolutionManager"
linkTitle: "SolutionManager"
weight: 40
tags: [reference, python]
description: >
  Analyze and explain solutions with SolutionManager.
---

`SolutionManager` provides utilities for analyzing solutions without running the solver.

## Creating a SolutionManager

```python
from solverforge_legacy.solver import SolverFactory, SolutionManager

solver_factory = SolverFactory.create(config)
solution_manager = SolutionManager.create(solver_factory)
```

Or from a SolverManager:

```python
solver_manager = SolverManager.create(solver_factory)
solution_manager = SolutionManager.create(solver_manager)
```

## Score Calculation

Calculate the score of a solution without solving:

```python
# Update score in place
solution_manager.update(solution)
print(f"Score: {solution.score}")
```

This is useful for:
- Validating manually created solutions
- Comparing before/after changes
- Testing constraint configurations

## Score Analysis

Get a detailed breakdown of the score:

```python
analysis = solution_manager.analyze(solution)

print(f"Overall score: {analysis.score}")

# Per-constraint breakdown
for constraint in analysis.constraint_analyses():
    print(f"\n{constraint.constraint_name}:")
    print(f"  Score: {constraint.score}")
    print(f"  Matches: {constraint.match_count}")
```

### Constraint Matches

See exactly which entities triggered each constraint:

```python
for constraint in analysis.constraint_analyses():
    print(f"\n{constraint.constraint_name}:")
    for match in constraint.matches():
        print(f"  - {match.justification}: {match.score}")
```

### Indictments

Find which entities are responsible for score impacts:

```python
for indictment in analysis.indictments():
    print(f"\nEntity: {indictment.indicted_object}")
    print(f"  Total impact: {indictment.score}")
    for match in indictment.matches():
        print(f"  - {match.constraint_name}: {match.score}")
```

## Use Cases

### Validate User Input

```python
def validate_schedule(schedule: Schedule) -> list[str]:
    """Validate a manually created schedule."""
    solution_manager.update(schedule)

    if schedule.score.is_feasible:
        return []

    # Collect violations
    violations = []
    analysis = solution_manager.analyze(schedule)

    for constraint in analysis.constraint_analyses():
        if constraint.score.hard_score < 0:
            for match in constraint.matches():
                violations.append(str(match.justification))

    return violations
```

### Compare Solutions

```python
def compare_solutions(old: Schedule, new: Schedule) -> dict:
    """Compare two solutions."""
    old_analysis = solution_manager.analyze(old)
    new_analysis = solution_manager.analyze(new)

    return {
        "old_score": str(old_analysis.score),
        "new_score": str(new_analysis.score),
        "improved": new_analysis.score > old_analysis.score,
        "changes": get_constraint_changes(old_analysis, new_analysis),
    }


def get_constraint_changes(old, new):
    old_scores = {c.constraint_name: c.score for c in old.constraint_analyses()}
    changes = []

    for constraint in new.constraint_analyses():
        old_score = old_scores.get(constraint.constraint_name)
        if old_score != constraint.score:
            changes.append({
                "constraint": constraint.constraint_name,
                "old": str(old_score),
                "new": str(constraint.score),
            })

    return changes
```

### Explain to Users

```python
def explain_score(schedule: Schedule) -> dict:
    """Generate user-friendly score explanation."""
    analysis = solution_manager.analyze(schedule)

    hard_violations = []
    soft_penalties = []

    for constraint in analysis.constraint_analyses():
        if constraint.score.hard_score < 0:
            for match in constraint.matches():
                hard_violations.append({
                    "rule": constraint.constraint_name,
                    "details": str(match.justification),
                })
        elif constraint.score.soft_score < 0:
            soft_penalties.append({
                "rule": constraint.constraint_name,
                "impact": constraint.match_count,
            })

    return {
        "is_valid": schedule.score.is_feasible,
        "hard_violations": hard_violations,
        "soft_penalties": soft_penalties,
        "summary": generate_summary(analysis),
    }
```

### API Endpoint

```python
from fastapi import FastAPI

@app.get("/analysis/{job_id}")
async def get_analysis(job_id: str):
    solution = solutions.get(job_id)
    if not solution:
        raise HTTPException(404)

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

## Debugging

### Finding Score Corruption

```python
def debug_score(solution):
    """Debug score calculation."""
    # Calculate fresh
    solution_manager.update(solution)
    fresh_score = solution.score

    # Analyze
    analysis = solution_manager.analyze(solution)
    analyzed_score = analysis.score

    if fresh_score != analyzed_score:
        print(f"Score mismatch: {fresh_score} vs {analyzed_score}")

    # Check each constraint
    total_hard = 0
    total_soft = 0
    for c in analysis.constraint_analyses():
        total_hard += c.score.hard_score
        total_soft += c.score.soft_score
        print(f"{c.constraint_name}: {c.score}")

    print(f"\nCalculated: {total_hard}hard/{total_soft}soft")
    print(f"Reported: {analyzed_score}")
```

### Finding Unexpected Matches

```python
def find_unexpected_matches(solution, constraint_name):
    """Debug why a constraint is matching."""
    analysis = solution_manager.analyze(solution)

    for c in analysis.constraint_analyses():
        if c.constraint_name == constraint_name:
            print(f"\n{constraint_name} matches ({c.match_count}):")
            for match in c.matches():
                print(f"  - {match.justification}")
            return

    print(f"Constraint '{constraint_name}' not found")
```

## Performance Notes

- `update()` is fast (incremental calculation)
- `analyze()` is slower (collects all match details)
- Cache analysis results if calling repeatedly
- Don't analyze every solution during solving

## Next Steps

- [Benchmarking](benchmarking.md) - Compare configurations
- [Score Analysis](../constraints/score-analysis.md) - Constraint debugging
