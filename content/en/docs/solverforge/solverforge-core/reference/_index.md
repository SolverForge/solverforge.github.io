---
title: "Reference"
linkTitle: "Reference"
weight: 70
description: "API reference and quick lookup guides"
---

# Reference

Quick reference guides and API documentation.

## In This Section

- [API Quick Reference](api-quick-reference/) - Cheat sheet for common SolverForge APIs
- [Error Handling](error-handling/) - Handle SolverForgeError types and troubleshoot issues

## Import Summary

```rust
// Domain modeling
use solverforge_core::domain::{
    DomainClass, DomainModel, FieldDescriptor, FieldType,
    PlanningAnnotation, PrimitiveType, ScoreType,
};

// Constraints
use solverforge_core::{
    Collector, Constraint, ConstraintSet, Joiner,
    StreamComponent, WasmFunction,
};

// Scores
use solverforge_core::{
    HardSoftScore, HardMediumSoftScore, SimpleScore, BendableScore,
    Score,  // trait
};

// Solver
use solverforge_core::{
    SolveRequest, SolveResponse, SolverConfig, TerminationConfig,
    EnvironmentMode, MoveThreadCount,
};

// WASM
use solverforge_core::wasm::{
    Expr, FieldAccessExt, Expression,
    WasmModuleBuilder, PredicateDefinition, HostFunctionRegistry,
};

// Errors
use solverforge_core::{SolverForgeError, SolverForgeResult};

// Service
use solverforge_service::{EmbeddedService, ServiceConfig};
```

## Crate Structure

```
solverforge_core
├── domain           # Domain model definitions
│   ├── DomainModel
│   ├── DomainClass
│   ├── FieldDescriptor
│   ├── FieldType
│   ├── PlanningAnnotation
│   └── PrimitiveType
├── constraints      # Constraint streams
│   ├── StreamComponent
│   ├── Collector
│   ├── Joiner
│   └── WasmFunction
├── score           # Score types
│   ├── Score (trait)
│   ├── HardSoftScore
│   ├── HardMediumSoftScore
│   └── BendableScore
├── solver          # Solver configuration
│   ├── SolverConfig
│   ├── TerminationConfig
│   └── EnvironmentMode
├── wasm            # WASM generation
│   ├── Expression
│   ├── Expr
│   ├── WasmModuleBuilder
│   └── PredicateDefinition
└── error           # Error types
    ├── SolverForgeError
    └── SolverForgeResult
```
