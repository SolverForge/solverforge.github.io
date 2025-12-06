---
title: "Dataclasses vs Pydantic in Constraint Solvers"
date: 2025-12-06
description: >
  Architectural guidance for Python constraint solvers: when to use dataclasses vs Pydantic for optimal performance.
---

When building constraint solvers in Python, one architectural decision shapes everything else: should domain models use Pydantic (convenient for APIs) or dataclasses (minimal overhead)?

Both tools are excellent at what they're designed for. The question is which fits the specific demands of constraint solving—where the same objects get evaluated millions of times per solve.

We ran benchmarks across meeting scheduling and vehicle routing problems to understand the performance characteristics of each approach.

**Note:** These benchmarks were run on small problems (50 meetings, 25-77 customers) using JPype to bridge Python and Java. The findings about relative performance between dataclasses and Pydantic hold regardless of scale, though absolute timings will vary with problem size and infrastructure.

---

## Two Architectural Approaches

### Unified Models (Pydantic Throughout)

```python
class Person(BaseModel):
    id: str
    full_name: str
    # Single model for API and constraint solving

class MeetingAssignment(BaseModel):
    id: str
    meeting: Meeting
    starting_time_grain: TimeGrain | None = None
    room: Room | None = None
```

One model structure handles everything: JSON parsing, validation, API docs, and constraint evaluation. This is appealing for its simplicity.

### Separated Models (Dataclasses for Solving)

```python
# Domain model (constraint solving)
@dataclass
class Person:
    id: Annotated[str, PlanningId]
    full_name: str

# API model (serialization)
class PersonModel(BaseModel):
    id: str
    full_name: str
```

Domain models are simple dataclasses. Pydantic handles API boundaries. Converters translate between them.

---

## Benchmark Setup

We tested three configurations across 60 scenarios (10 iterations × 6 configurations):

- **Pydantic domain models**: Unified approach with Pydantic throughout
- **Dataclass domain models**: Separated approach with dataclasses for solving
- **Java reference**: Timefold v1.24.0

Each solve ran for 30 seconds on identical problem instances.

**Test problems:**
- Meeting scheduling (50 meetings, 18 rooms, 20 people)
- Vehicle routing (25 customers, 6 vehicles)

---

## Results: Meeting Scheduling

| Configuration | Iterations Completed | Consistency |
|---------------|---------------------|-------------|
| Dataclass models | 60/60 | High |
| Java reference | 60/60 | High |
| Pydantic models | 46-58/60 | Variable |

### What We Observed

**Iteration throughput**: The dataclass configuration completed all optimization iterations within the time limit, matching the Java reference. The Pydantic configuration sometimes hit the time limit before finishing.

**Object equality behavior**: We noticed some unexpected constraint evaluation differences when using Pydantic models with Python-generated test data. The same constraint logic produced different results depending on how `Person` objects were compared during conflict detection.

---

## Results: Vehicle Routing

| Configuration | Iterations Completed | Consistency |
|---------------|---------------------|-------------|
| Dataclass models | 60/60 | High |
| Java reference | 60/60 | High |
| Pydantic models | 57-59/60 | Variable |

The pattern was consistent across problem domains.

---

## Understanding the Difference

### Object Equality in Hot Paths

Constraint evaluation happens millions of times during solving. Meeting scheduling detects conflicts by comparing `Person` objects to find double-bookings.

**Dataclass equality:**
```python
@dataclass
class Person:
    id: str
    full_name: str
    # __eq__ generated from field values
    # Simple, predictable, fast
```

Python generates straightforward comparison based on fields.

**Pydantic equality:**
```python
class Person(BaseModel):
    id: str
    full_name: str
    # __eq__ involves model internals
    # Designed for API validation, not hot-path comparison
```

Pydantic wasn't designed for millions of equality checks per second—it's optimized for API validation, where this overhead is negligible.

### The Right Tool for Each Job

Pydantic excels at API boundaries: parsing JSON, validating input, generating OpenAPI schemas. These operations happen once per request.

Dataclasses excel at internal computation: simple field access, predictable equality, minimal overhead. These characteristics matter when operations repeat millions of times.

---

## Practical Examples

The quickstart guides demonstrate this pattern in action:

### Employee Scheduling
[Employee Scheduling Guide](/docs/getting-started/employee-scheduling/) shows:
- Hard/soft constraint separation with `HardSoftDecimalScore`
- Load balancing constraints using dataclass aggregation
- Date-based filtering with simple set membership

**Key pattern:** Domain uses `set[date]` for `unavailable_dates`—fast membership testing during constraint evaluation.

### Meeting Scheduling
[Meeting Scheduling Guide](/docs/getting-started/meeting-scheduling/) demonstrates:
- Multi-variable planning entities (time + room)
- Three-tier scoring (`HardMediumSoftScore`)
- Complex joining patterns across attendance records

**Key pattern:** Separate `Person`, `RequiredAttendance`, `PreferredAttendance` dataclasses keep joiner operations simple.

### Vehicle Routing
[Vehicle Routing Guide](/docs/getting-started/vehicle-routing/) illustrates:
- Shadow variable chains (`PreviousElementShadowVariable`, `NextElementShadowVariable`)
- Cascading updates for arrival time calculations
- List variables with `PlanningListVariable`

**Key pattern:** The `arrival_time` shadow variable cascades through the route chain. Dataclass field assignments keep these updates lightweight.

---

## The Recommended Architecture

Based on our experience, we recommend separating concerns:

```
src/meeting_scheduling/
├── domain.py        # @dataclass models for solver
├── rest_api.py      # Pydantic models for API
└── converters.py    # Boundary translation
```

### Domain Layer

```python
@planning_entity
@dataclass
class MeetingAssignment:
    id: Annotated[str, PlanningId]
    meeting: Meeting
    starting_time_grain: Annotated[TimeGrain | None, PlanningVariable] = None
    room: Annotated[Room | None, PlanningVariable] = None
```

Simple structures optimized for solver manipulation.

### API Layer

```python
class MeetingAssignmentModel(BaseModel):
    id: str
    meeting: MeetingModel
    starting_time_grain: TimeGrainModel | None = None
    room: RoomModel | None = None
```

Pydantic handles what it's designed for: request validation, JSON serialization, OpenAPI documentation.

### Boundary Conversion

```python
def assignment_to_model(a: MeetingAssignment) -> MeetingAssignmentModel:
    return MeetingAssignmentModel(
        id=a.id,
        meeting=meeting_to_model(a.meeting),
        starting_time_grain=timegrain_to_model(a.starting_time_grain),
        room=room_to_model(a.room)
    )
```

Translation happens exactly twice per solve: on ingestion and serialization.

---

## Additional Benefits

### Optional Validation Mode

```python
# Production: fast dataclass domain
solver.solve(problem)

# Development: validate before solving
validated = ProblemModel.model_validate(problem_dict)
solver.solve(validated.to_domain())
```

Get validation during testing. Run at full speed in production.

### Clear Debugging Boundaries

The separation makes debugging easier—you know exactly what objects the solver sees versus what the API exposes.

---

## Guidelines

### When to Use Pydantic

- API request/response validation
- Configuration file parsing
- Data serialization for storage
- OpenAPI schema generation
- Development-time validation

### When to Use Dataclasses

- Solver domain models
- Objects compared in tight loops
- Entities with frequent equality checks
- Performance-critical data structures
- Internal solver state

### The Hybrid Pattern

```python
@app.post("/schedules")
def create_schedule(request: ScheduleRequest) -> ScheduleResponse:
    # Validate once at API boundary
    problem = request.to_domain()

    # Solve with fast dataclasses
    solution = solver.solve(problem)

    # Serialize once for response
    return ScheduleResponse.from_domain(solution)
```

Validation where it matters. Performance where it counts.

---

## Trade-offs

### More Code

Separated models mean additional files and conversion logic. For simple APIs or prototypes, unified Pydantic might be fine to start with.

### Performance at Scale

The overhead difference grows with problem size. Small problems might not show much difference; larger problems will.

---

## Summary

Both Pydantic and dataclasses are excellent tools. The key insight is matching each to its strengths:

- **Dataclasses** for solver internals—simple, predictable, optimized for repeated operations
- **Pydantic** for API boundaries—rich validation, serialization, documentation generation

This separation lets each tool do what it does best.

Full benchmark code and results: [SolverForge Quickstarts Benchmarks](https://github.com/solverforge/solverforge-quickstarts/tree/main/benchmarks)
