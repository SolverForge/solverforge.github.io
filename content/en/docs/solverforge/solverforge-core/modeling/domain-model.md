---
title: "Domain Model"
linkTitle: "Domain Model"
weight: 10
tags: [concepts, rust]
description: "Build domain models with DomainModel, DomainClass, and FieldDescriptor"
---

The `DomainModel` is the central data structure that describes your planning domain.

## Building a Model

Use the builder pattern to construct a domain model:

```rust
use solverforge_core::domain::{
    DomainClass, DomainModel, FieldDescriptor, FieldType,
    PlanningAnnotation, PrimitiveType, ScoreType,
};

let model = DomainModel::builder()
    .add_class(DomainClass::new("Employee")/* ... */)
    .add_class(DomainClass::new("Shift")/* ... */)
    .add_class(DomainClass::new("Schedule")/* ... */)
    .build();
```

## DomainClass

Each class in your domain is defined with `DomainClass`:

```rust
let shift = DomainClass::new("Shift")
    .with_annotation(PlanningAnnotation::PlanningEntity)
    .with_field(
        FieldDescriptor::new("id", FieldType::Primitive(PrimitiveType::String))
            .with_planning_annotation(PlanningAnnotation::PlanningId),
    )
    .with_field(
        FieldDescriptor::new("employee", FieldType::object("Employee"))
            .with_planning_annotation(
                PlanningAnnotation::planning_variable(vec!["employees".to_string()])
            ),
    )
    .with_field(FieldDescriptor::new(
        "start",
        FieldType::Primitive(PrimitiveType::DateTime),
    ))
    .with_field(FieldDescriptor::new(
        "end",
        FieldType::Primitive(PrimitiveType::DateTime),
    ));
```

### Class Methods

| Method | Purpose |
|--------|---------|
| `DomainClass::new(name)` | Create a new class |
| `.with_annotation(ann)` | Add a class-level annotation |
| `.with_field(field)` | Add a field |
| `.is_planning_entity()` | Check if `@PlanningEntity` |
| `.is_planning_solution()` | Check if `@PlanningSolution` |
| `.get_planning_variables()` | Iterator over planning variable fields |

## FieldDescriptor

Each field is defined with `FieldDescriptor`:

```rust
let employee_field = FieldDescriptor::new("employee", FieldType::object("Employee"))
    .with_planning_annotation(PlanningAnnotation::planning_variable(vec!["employees"]))
    .with_accessor(DomainAccessor::new("getEmployee", "setEmployee"));
```

### Field Methods

| Method | Purpose |
|--------|---------|
| `FieldDescriptor::new(name, type)` | Create a new field |
| `.with_planning_annotation(ann)` | Add a planning annotation |
| `.with_shadow_annotation(ann)` | Add a shadow variable annotation |
| `.with_accessor(acc)` | Override default accessor names |
| `.is_planning_variable()` | Check if `@PlanningVariable` |

## Complete Example

```rust
let model = DomainModel::builder()
    // Problem fact: Employee (not modified by solver)
    .add_class(
        DomainClass::new("Employee")
            .with_field(
                FieldDescriptor::new("name", FieldType::Primitive(PrimitiveType::String))
                    .with_planning_annotation(PlanningAnnotation::PlanningId),
            )
            .with_field(FieldDescriptor::new(
                "skills",
                FieldType::list(FieldType::Primitive(PrimitiveType::String)),
            )),
    )
    // Planning entity: Shift (employee assignment decided by solver)
    .add_class(
        DomainClass::new("Shift")
            .with_annotation(PlanningAnnotation::PlanningEntity)
            .with_field(
                FieldDescriptor::new("id", FieldType::Primitive(PrimitiveType::String))
                    .with_planning_annotation(PlanningAnnotation::PlanningId),
            )
            .with_field(
                FieldDescriptor::new("employee", FieldType::object("Employee"))
                    .with_planning_annotation(
                        PlanningAnnotation::planning_variable(vec!["employees".to_string()])
                    ),
            )
            .with_field(FieldDescriptor::new(
                "requiredSkill",
                FieldType::Primitive(PrimitiveType::String),
            )),
    )
    // Planning solution: Schedule (container)
    .add_class(
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
            ),
    )
    .build_validated()?;
```

## Converting to DTO

Convert the model to a DTO for the solver request:

```rust
let domain_dto = model.to_dto();
```

The `to_dto()` method:
- Generates accessor names matching WASM exports: `get_{Class}_{field}`, `set_{Class}_{field}`
- Adds setters for planning variables and collection properties
- Adds mapper for the solution class (`parseSchedule`, `scheduleString`)

## DomainModel Methods

| Method | Purpose |
|--------|---------|
| `DomainModel::builder()` | Create a builder |
| `.add_class(class)` | Add a class |
| `.build()` | Build without validation |
| `.build_validated()` | Build with validation |
| `model.get_class(name)` | Get a class by name |
| `model.get_solution_class()` | Get the solution class |
| `model.get_entity_classes()` | Iterator over entity classes |
| `model.to_dto()` | Convert to solver DTO |
| `model.validate()` | Validate the model |
