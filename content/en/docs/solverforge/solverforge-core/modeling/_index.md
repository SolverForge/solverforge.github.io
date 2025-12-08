---
title: "Domain Modeling"
linkTitle: "Modeling"
weight: 30
tags: [concepts, rust]
description: "Define your planning domain with DomainModel, classes, and fields"
---

This section covers how to define your planning domain using SolverForge's domain modeling API.

## In This Section

- [Domain Model](domain-model/) - Build domain models with `DomainModel`, `DomainClass`, and `FieldDescriptor`
- [Planning Annotations](annotations/) - Configure planning behavior with `PlanningAnnotation` types
- [Field Types](field-types/) - Supported field types including primitives, objects, collections, and scores

## Overview

A domain model describes the structure of your planning problem:

```rust
use solverforge_core::domain::{
    DomainClass, DomainModel, FieldDescriptor, FieldType,
    PlanningAnnotation, PrimitiveType, ScoreType,
};

let model = DomainModel::builder()
    .add_class(
        DomainClass::new("Shift")
            .with_annotation(PlanningAnnotation::PlanningEntity)
            .with_field(/* ... */)
    )
    .add_class(
        DomainClass::new("Schedule")
            .with_annotation(PlanningAnnotation::PlanningSolution)
            .with_field(/* ... */)
    )
    .build();
```

## Key Concepts

| Concept | Purpose | Annotation |
|---------|---------|------------|
| Planning Entity | Object modified by solver | `@PlanningEntity` |
| Planning Variable | Field assigned by solver | `@PlanningVariable` |
| Planning Solution | Container for all data | `@PlanningSolution` |
| Problem Fact | Read-only data | (no annotation needed) |
| Value Range Provider | Source of variable values | `@ValueRangeProvider` |

## Model Validation

Use `build_validated()` to catch configuration errors early:

```rust
let model = DomainModel::builder()
    .add_class(/* ... */)
    .build_validated()?;  // Returns SolverForgeError on invalid model
```

Validation checks:
- Solution class exists with `@PlanningSolution`
- At least one entity class with `@PlanningEntity`
- Each entity has at least one `@PlanningVariable`
- Solution class has a `@PlanningScore` field
