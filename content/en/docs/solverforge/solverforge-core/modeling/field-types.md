---
title: "Field Types"
linkTitle: "Field Types"
weight: 30
tags: [concepts, rust]
description: "Supported field types including primitives, objects, collections, and scores"
---

SolverForge supports various field types for domain modeling.

## Primitive Types

Basic value types:

```rust
use solverforge_core::domain::{FieldType, PrimitiveType};

// Boolean
FieldType::Primitive(PrimitiveType::Bool)

// Integers
FieldType::Primitive(PrimitiveType::Int)    // 32-bit
FieldType::Primitive(PrimitiveType::Long)   // 64-bit

// Floating point
FieldType::Primitive(PrimitiveType::Float)  // 32-bit
FieldType::Primitive(PrimitiveType::Double) // 64-bit

// String
FieldType::Primitive(PrimitiveType::String)

// Date/Time (stored as epoch values)
FieldType::Primitive(PrimitiveType::Date)     // LocalDate - epoch day (i64)
FieldType::Primitive(PrimitiveType::DateTime) // LocalDateTime - epoch second (i64)
```

### Date and Time Handling

Dates and times are stored as integers:

- `Date` (LocalDate): Epoch day (days since 1970-01-01)
- `DateTime` (LocalDateTime): Epoch second (seconds since 1970-01-01T00:00:00)

```rust
// Field definition
FieldDescriptor::new("start", FieldType::Primitive(PrimitiveType::DateTime))

// JSON representation
// "start": "2025-01-15T08:00:00" is converted to epoch seconds
```

## Object Types

References to other domain classes:

```rust
// Reference to Employee class
FieldType::object("Employee")

// Usage in field descriptor
FieldDescriptor::new("employee", FieldType::object("Employee"))
```

## Collection Types

### List

Ordered collection (most common):

```rust
// List of strings
FieldType::list(FieldType::Primitive(PrimitiveType::String))

// List of objects
FieldType::list(FieldType::object("Shift"))
```

### Array

Fixed-size array (similar to List in behavior):

```rust
FieldType::array(FieldType::Primitive(PrimitiveType::Int))
```

### Set

Unordered unique elements:

```rust
FieldType::set(FieldType::object("Skill"))
```

### Map

Key-value mapping:

```rust
FieldType::map(
    FieldType::Primitive(PrimitiveType::String),  // Key type
    FieldType::object("Employee")                  // Value type
)
```

## Score Types

Score types for the planning solution:

```rust
use solverforge_core::domain::ScoreType;

// Single dimension
FieldType::Score(ScoreType::Simple)
FieldType::Score(ScoreType::SimpleDecimal)

// Two dimensions (hard/soft)
FieldType::Score(ScoreType::HardSoft)
FieldType::Score(ScoreType::HardSoftDecimal)

// Three dimensions (hard/medium/soft)
FieldType::Score(ScoreType::HardMediumSoft)
FieldType::Score(ScoreType::HardMediumSoftDecimal)

// Configurable dimensions
FieldType::Score(ScoreType::Bendable { hard_levels: 2, soft_levels: 3 })
FieldType::Score(ScoreType::BendableDecimal { hard_levels: 2, soft_levels: 3 })
```

## Type String Conversion

`FieldType::to_type_string()` converts to Java-compatible type strings:

| Rust Type | Java Type String |
|-----------|------------------|
| `PrimitiveType::Bool` | `boolean` |
| `PrimitiveType::Int` | `int` |
| `PrimitiveType::Long` | `long` |
| `PrimitiveType::Float` | `float` |
| `PrimitiveType::Double` | `double` |
| `PrimitiveType::String` | `String` |
| `PrimitiveType::Date` | `LocalDate` |
| `PrimitiveType::DateTime` | `LocalDateTime` |
| `FieldType::object("Foo")` | `Foo` |
| `FieldType::list(...)` | `...[]` |
| `ScoreType::HardSoft` | `HardSoftScore` |

## Examples

### Employee Class

```rust
DomainClass::new("Employee")
    .with_field(
        FieldDescriptor::new("name", FieldType::Primitive(PrimitiveType::String))
            .with_planning_annotation(PlanningAnnotation::PlanningId),
    )
    .with_field(FieldDescriptor::new(
        "skills",
        FieldType::list(FieldType::Primitive(PrimitiveType::String)),
    ))
    .with_field(FieldDescriptor::new(
        "unavailableDates",
        FieldType::list(FieldType::Primitive(PrimitiveType::Date)),
    ))
```

### Shift Class

```rust
DomainClass::new("Shift")
    .with_annotation(PlanningAnnotation::PlanningEntity)
    .with_field(
        FieldDescriptor::new("id", FieldType::Primitive(PrimitiveType::String))
            .with_planning_annotation(PlanningAnnotation::PlanningId),
    )
    .with_field(
        FieldDescriptor::new("employee", FieldType::object("Employee"))
            .with_planning_annotation(PlanningAnnotation::planning_variable(vec!["employees"])),
    )
    .with_field(FieldDescriptor::new(
        "start",
        FieldType::Primitive(PrimitiveType::DateTime),
    ))
    .with_field(FieldDescriptor::new(
        "end",
        FieldType::Primitive(PrimitiveType::DateTime),
    ))
    .with_field(FieldDescriptor::new(
        "requiredSkill",
        FieldType::Primitive(PrimitiveType::String),
    ))
```

### Schedule Class

```rust
DomainClass::new("Schedule")
    .with_annotation(PlanningAnnotation::PlanningSolution)
    .with_field(
        FieldDescriptor::new("employees", FieldType::list(FieldType::object("Employee")))
            .with_planning_annotation(PlanningAnnotation::ProblemFactCollectionProperty)
            .with_planning_annotation(PlanningAnnotation::value_range_provider("employees")),
    )
    .with_field(
        FieldDescriptor::new("shifts", FieldType::list(FieldType::object("Shift")))
            .with_planning_annotation(PlanningAnnotation::PlanningEntityCollectionProperty),
    )
    .with_field(
        FieldDescriptor::new("score", FieldType::Score(ScoreType::HardSoft))
            .with_planning_annotation(PlanningAnnotation::planning_score()),
    )
```

## Collection Checks

```rust
let list_type = FieldType::list(FieldType::object("Shift"));
assert!(list_type.is_collection()); // true

let object_type = FieldType::object("Employee");
assert!(!object_type.is_collection()); // false
```
