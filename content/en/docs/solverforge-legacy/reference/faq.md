---
title: "FAQ"
linkTitle: "FAQ"
weight: 20
tags: [reference, python]
description: >
  Frequently asked questions about SolverForge.
---

## General

### What is SolverForge?

SolverForge is a Python constraint solver for planning and scheduling optimization problems. It uses constraint streams to define rules and metaheuristic algorithms to find high-quality solutions.

### What problems can SolverForge solve?

SolverForge excels at:
- **Employee scheduling**: Shift assignment with skills, availability, fairness
- **Vehicle routing**: Route optimization with capacity, time windows
- **School timetabling**: Class scheduling with room and teacher constraints
- **Meeting scheduling**: Room booking with attendee conflicts
- **Task assignment**: Job shop, bin packing, resource allocation

### How is SolverForge licensed?

SolverForge is open source software released under the Apache License 2.0. This allows commercial use, modification, and distribution.

## Installation

### What are the requirements?

- Python 3.10 or later
- JDK 17 or later (SolverForge uses the JVM for solving)

### Why does SolverForge need Java?

SolverForge's solving engine runs on the JVM for performance. The Python API communicates with the JVM transparently via JPype.

### How do I install it?

```bash
pip install solverforge-legacy
```

Make sure `JAVA_HOME` is set or Java is on your PATH.

## Modeling

### What's the difference between problem facts and planning entities?

| Type | Changes During Solving | Example |
|------|----------------------|---------|
| **Problem facts** | No (input data) | Rooms, Timeslots, Employees |
| **Planning entities** | Yes (variables assigned) | Lessons, Shifts, Visits |

### When should I use `PlanningVariable` vs `PlanningListVariable`?

| Type | Use Case | Example |
|------|----------|---------|
| `PlanningVariable` | Assign one value | Lesson → Timeslot |
| `PlanningListVariable` | Ordered list of entities | Vehicle → list of Visits |

### Can I use Pydantic instead of dataclasses?

Yes. Both dataclasses and Pydantic models work. The quickstart examples show both patterns.

### How do I pin (lock) an assignment?

Add `PlanningPin` to a boolean field:

```python
@planning_entity
class Lesson:
    pinned: Annotated[bool, PlanningPin] = False
```

Set `pinned=True` to prevent the solver from changing that entity's variables.

## Constraints

### What's the difference between hard and soft constraints?

| Type | Meaning | Example |
|------|---------|---------|
| **Hard** | Must not violate | No room conflicts |
| **Soft** | Prefer to satisfy | Teacher prefers certain room |

Hard constraints define feasibility. Soft constraints define quality.

### Why use `for_each_unique_pair` instead of `for_each` + `join`?

`for_each_unique_pair` is more efficient and avoids counting conflicts twice:

```python
# Good - each pair counted once
constraint_factory.for_each_unique_pair(
    Lesson,
    Joiners.equal(lambda l: l.timeslot),
    Joiners.equal(lambda l: l.room),
)

# Less efficient - (A,B) and (B,A) both matched
constraint_factory.for_each(Lesson).join(Lesson, ...)
```

### How do I debug a constraint?

1. Use `SolutionManager.analyze()` to see the score breakdown:

```python
analysis = solution_manager.analyze(solution)
for c in analysis.constraint_analyses():
    print(f"{c.constraint_name}: {c.score}")
```

2. Examine individual matches:

```python
for match in constraint_analysis.matches():
    print(f"  {match.justification}")
```

### Why is my score always infeasible?

Common causes:
- Not enough resources (rooms, timeslots, employees) for entities
- Conflicting hard constraints that can't all be satisfied
- Uninitialized entities (variables still `None`)

Try:
- Increasing termination time
- Relaxing some hard constraints to soft
- Adding more resources

## Solving

### How long should I let the solver run?

Depends on problem size and complexity:

| Problem Size | Typical Time |
|--------------|--------------|
| Small (< 100 entities) | 10-60 seconds |
| Medium (100-1000 entities) | 1-10 minutes |
| Large (> 1000 entities) | 10+ minutes |

Use benchmarking to find the optimal time for your problem.

### Why isn't the score improving?

Possible causes:
- Stuck in local optimum (try different algorithm)
- All hard constraints satisfied (now optimizing soft)
- Constraints are too restrictive

Try:
- Simulated Annealing or Late Acceptance instead of Tabu Search
- Longer termination time
- Review constraint design

### How do I stop solving early?

With `Solver`:

```python
# External termination (from another thread)
solver.terminate_early()
```

With `SolverManager`:

```python
solver_manager.terminate_early(problem_id)
```

### Can I get progress updates during solving?

Yes, use `SolverManager` with a listener:

```python
solver_manager.solve_and_listen(
    problem_id,
    problem_finder=lambda _: problem,
    best_solution_consumer=lambda solution: print(f"Score: {solution.score}"),
)
```

## Performance

### How do I make constraints faster?

1. **Use Joiners** instead of `filter()`:

```python
# Fast - indexing
Joiners.equal(lambda lesson: lesson.timeslot)

# Slower - Python filter
.filter(lambda l1, l2: l1.timeslot == l2.timeslot)
```

2. **Cache computed values** in entity fields
3. **Avoid expensive operations** in lambdas

### How do I scale to larger problems?

- Increase termination time
- Use more efficient constraints
- Consider partitioning large problems
- Use `PlanningListVariable` for routing problems

### Should I use multiple threads?

The solver is single-threaded by design for score calculation consistency. Use `SolverManager` to solve multiple problems concurrently.

## Integration

### Can I use SolverForge with FastAPI?

Yes! See the [FastAPI Integration](../integration/fastapi.md) guide. Key pattern:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    global solver_manager
    solver_manager = SolverManager.create(solver_factory)
    yield
    solver_manager.close()
```

### How do I serialize solutions to JSON?

Use Pydantic models or `dataclasses.asdict()`:

```python
# With dataclasses
import json
from dataclasses import asdict

json.dumps(asdict(solution))

# With Pydantic
solution.model_dump_json()
```

See [Serialization](../integration/serialization.md) for handling references.

### Can I save and load solutions?

Yes, serialize to JSON and deserialize back:

```python
# Save
with open("solution.json", "w") as f:
    json.dump(solution_to_dict(solution), f)

# Load
with open("solution.json") as f:
    problem = dict_to_solution(json.load(f))
```

## Troubleshooting

### "No JVM shared library file (libjvm.so) found"

Java isn't installed or `JAVA_HOME` isn't set:

```bash
# Check Java
java -version

# Set JAVA_HOME (example for Linux)
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
```

### "Score corruption detected"

A constraint is producing inconsistent scores. Common causes:
- Non-deterministic lambdas
- External state changes
- Incorrect shadow variable updates

Run with `RUST_LOG=debug` to see details.

### "OutOfMemoryError" in the JVM

Increase JVM heap:

```bash
export JAVA_TOOL_OPTIONS="-Xmx4g"
```

## More Help

- [GitHub Issues](https://github.com/solverforge/solverforge/issues) - Bug reports and feature requests
- [Quickstarts](../quickstarts/) - Working examples
- [API Summary](api-summary.md) - Quick reference
