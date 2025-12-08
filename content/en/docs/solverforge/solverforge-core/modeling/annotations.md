---
title: "Planning Annotations"
linkTitle: "Annotations"
weight: 20
tags: [concepts, rust]
description: "Configure planning behavior with PlanningAnnotation types"
---

Annotations configure how the solver interprets your domain model.

## Class Annotations

### PlanningEntity

Marks a class as a planning entity - an object whose planning variables are assigned by the solver.

```rust
DomainClass::new("Shift")
    .with_annotation(PlanningAnnotation::PlanningEntity)
```

### PlanningSolution

Marks a class as the planning solution - the container for all problem facts, entities, and the score.

```rust
DomainClass::new("Schedule")
    .with_annotation(PlanningAnnotation::PlanningSolution)
```

## Field Annotations

### PlanningId

Marks a field as the unique identifier for instances of the class.

```rust
FieldDescriptor::new("id", FieldType::Primitive(PrimitiveType::String))
    .with_planning_annotation(PlanningAnnotation::PlanningId)
```

### PlanningVariable

Marks a field whose value is determined by the solver. Must reference value range providers.

```rust
// Basic planning variable
FieldDescriptor::new("employee", FieldType::object("Employee"))
    .with_planning_annotation(
        PlanningAnnotation::planning_variable(vec!["employees".to_string()])
    )

// Planning variable that allows null (unassigned)
FieldDescriptor::new("room", FieldType::object("Room"))
    .with_planning_annotation(
        PlanningAnnotation::planning_variable_unassigned(vec!["rooms".to_string()])
    )
```

**Parameters:**
- `value_range_provider_refs`: List of value range provider IDs that supply valid values
- `allows_unassigned`: If true, the variable can remain unassigned (null)

### PlanningListVariable

Marks a list field where the solver assigns which elements belong to the list.

```rust
FieldDescriptor::new("visits", FieldType::list(FieldType::object("Visit")))
    .with_planning_annotation(
        PlanningAnnotation::planning_list_variable(vec!["visits".to_string()])
    )
```

### PlanningScore

Marks the score field on the solution class.

```rust
// Standard score
FieldDescriptor::new("score", FieldType::Score(ScoreType::HardSoft))
    .with_planning_annotation(PlanningAnnotation::planning_score())

// Bendable score with specific levels
FieldDescriptor::new("score", FieldType::Score(ScoreType::Bendable { hard_levels: 2, soft_levels: 3 }))
    .with_planning_annotation(PlanningAnnotation::planning_score_bendable(2, 3))
```

### ValueRangeProvider

Marks a field that provides valid values for planning variables.

```rust
FieldDescriptor::new("employees", FieldType::list(FieldType::object("Employee")))
    .with_planning_annotation(PlanningAnnotation::value_range_provider("employees"))
```

The ID (`"employees"`) must match the `value_range_provider_refs` in corresponding planning variables.

### ProblemFactCollectionProperty

Marks a collection of problem facts (read-only data) on the solution class.

```rust
FieldDescriptor::new("employees", FieldType::list(FieldType::object("Employee")))
    .with_planning_annotation(PlanningAnnotation::ProblemFactCollectionProperty)
```

### PlanningEntityCollectionProperty

Marks a collection of planning entities on the solution class.

```rust
FieldDescriptor::new("shifts", FieldType::list(FieldType::object("Shift")))
    .with_planning_annotation(PlanningAnnotation::PlanningEntityCollectionProperty)
```

### PlanningPin

Marks a boolean field that pins an entity's assignment (prevents the solver from changing it).

```rust
FieldDescriptor::new("pinned", FieldType::Primitive(PrimitiveType::Bool))
    .with_planning_annotation(PlanningAnnotation::PlanningPin)
```

### InverseRelationShadowVariable

Marks a shadow variable that tracks the inverse of another planning variable.

```rust
FieldDescriptor::new("vehicle", FieldType::object("Vehicle"))
    .with_planning_annotation(PlanningAnnotation::inverse_relation_shadow("visits"))
```

## Annotation Summary

| Annotation | Target | Purpose |
|------------|--------|---------|
| `PlanningEntity` | Class | Mark as planning entity |
| `PlanningSolution` | Class | Mark as solution container |
| `PlanningId` | Field | Unique identifier |
| `PlanningVariable` | Field | Solver-assigned value |
| `PlanningListVariable` | Field | Solver-assigned list |
| `PlanningScore` | Field | Score field on solution |
| `ValueRangeProvider` | Field | Source of valid values |
| `ProblemFactCollectionProperty` | Field | Problem fact collection |
| `PlanningEntityCollectionProperty` | Field | Entity collection |
| `PlanningPin` | Field | Pin entity assignment |
| `InverseRelationShadowVariable` | Field | Shadow inverse relation |

## Helper Methods

```rust
use solverforge_core::domain::PlanningAnnotation;

// Create planning variable
PlanningAnnotation::planning_variable(vec!["rooms".to_string()])
PlanningAnnotation::planning_variable_unassigned(vec!["slots".to_string()])

// Create list variable
PlanningAnnotation::planning_list_variable(vec!["tasks".to_string()])

// Create score annotation
PlanningAnnotation::planning_score()
PlanningAnnotation::planning_score_bendable(2, 3)

// Create value range provider
PlanningAnnotation::value_range_provider("timeslots")

// Create shadow variable
PlanningAnnotation::inverse_relation_shadow("visits")
```

## Multiple Annotations

A field can have multiple annotations:

```rust
FieldDescriptor::new("employees", FieldType::list(FieldType::object("Employee")))
    .with_planning_annotation(PlanningAnnotation::ProblemFactCollectionProperty)
    .with_planning_annotation(PlanningAnnotation::value_range_provider("employees"))
```
