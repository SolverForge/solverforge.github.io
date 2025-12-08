---
title: "Constraint Satisfaction"
linkTitle: "Constraint Satisfaction"
weight: 20
tags: [concepts, rust]
description: "Core concepts of constraint satisfaction and optimization problems"
---

SolverForge solves constraint satisfaction and optimization problems (CSPs). This page explains the core concepts.

## Problem Structure

Every planning problem has:

### Planning Entities

Objects that the solver modifies. Each entity has one or more **planning variables** that the solver assigns.

```rust
// Shift is a planning entity
DomainClass::new("Shift")
    .with_annotation(PlanningAnnotation::PlanningEntity)
    .with_field(
        // employee is a planning variable - solver decides the value
        FieldDescriptor::new("employee", FieldType::object("Employee"))
            .with_planning_annotation(PlanningAnnotation::planning_variable(vec!["employees"]))
    )
```

### Problem Facts

Objects that provide data but are not modified by the solver.

```rust
// Employee is a problem fact - solver reads but doesn't change it
DomainClass::new("Employee")
    .with_field(FieldDescriptor::new("name", FieldType::Primitive(PrimitiveType::String)))
    .with_field(FieldDescriptor::new("skills", FieldType::list(FieldType::Primitive(PrimitiveType::String))))
```

### Planning Solution

A container that holds all entities and problem facts, plus the score.

```rust
DomainClass::new("Schedule")
    .with_annotation(PlanningAnnotation::PlanningSolution)
    .with_field(/* employees - problem facts */)
    .with_field(/* shifts - planning entities */)
    .with_field(/* score - optimization result */)
```

## Constraints

Constraints define what makes a solution valid and good.

### Hard Constraints

**Must** be satisfied for a solution to be feasible. Violations result in negative hard score.

```rust
// Every shift must have an employee with the required skill
StreamComponent::for_each("Shift"),
StreamComponent::filter(WasmFunction::new("skillMismatch")),
StreamComponent::penalize("1hard/0soft"),
```

### Soft Constraints

**Should** be satisfied for a better solution. Violations result in negative soft score.

```rust
// Prefer balanced shift distribution
StreamComponent::for_each("Shift"),
StreamComponent::group_by(/* ... */),
StreamComponent::penalize("0hard/1soft"),
```

## Score Types

The score measures solution quality. SolverForge supports multiple score types:

| Score Type | Levels | Example |
|------------|--------|---------|
| `SimpleScore` | 1 | `-5` |
| `HardSoftScore` | 2 | `0hard/-10soft` |
| `HardMediumSoftScore` | 3 | `0hard/0medium/-5soft` |
| `BendableScore` | N | Configurable levels |

### Score Interpretation

- **Hard score** = 0: All hard constraints satisfied (feasible)
- **Hard score** < 0: Hard constraints violated (infeasible)
- **Soft score**: Higher is better (less negative = fewer soft violations)

Example: `0hard/-5soft` is feasible but has 5 soft constraint points violated.

## Solving Process

1. **Initial Solution**: Start with planning variables unassigned or randomly assigned
2. **Move Selection**: Choose a move (e.g., assign employee A to shift 1)
3. **Score Calculation**: Evaluate all constraints after the move
4. **Move Acceptance**: Accept or reject based on score improvement
5. **Termination**: Stop when time limit, score limit, or other condition is met

## Constraint Streams

Constraints are expressed as pipelines that:

1. **Select** entities: `for_each("Shift")`
2. **Filter** matches: `filter(predicate)`
3. **Join** with other entities: `join("Employee")`
4. **Group** for aggregation: `group_by(key, collector)`
5. **Penalize/Reward**: `penalize("1hard/0soft")`

Example constraint pipeline:

```
forEach(Shift)
  → filter(unassignedEmployee)
  → penalize(1hard)
```

This penalizes every shift that has no employee assigned.

## Next Steps

- [Domain Modeling](../modeling/) - Define your planning domain
- [Constraints](../constraints/) - Build constraint streams
- [Solver Configuration](../solver/configuration/) - Configure solving behavior
