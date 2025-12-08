---
title: "WASM Generation"
linkTitle: "WASM"
weight: 60
tags: [reference, rust]
description: "Generate WASM modules for constraint predicates"
---

This section covers generating WebAssembly modules for constraint predicates.

## In This Section

- [Expressions](expressions/) - Build predicate expressions with the Expression API
- [Module Builder](module-builder/) - Generate WASM modules with WasmModuleBuilder

## Overview

Constraint predicates (filter conditions, joiners, weighers) are compiled to WebAssembly. The WASM module is sent to the solver service along with your domain model and constraints.

```rust
use solverforge_core::wasm::{
    Expr, FieldAccessExt, WasmModuleBuilder, PredicateDefinition,
    HostFunctionRegistry,
};

// Build predicate: employee assigned but missing required skill
let predicate = {
    let shift = Expr::param(0);
    let employee = shift.clone().get("Shift", "employee");
    Expr::and(
        Expr::is_not_null(employee.clone()),
        Expr::not(Expr::list_contains(
            employee.get("Employee", "skills"),
            shift.get("Shift", "requiredSkill"),
        ))
    )
};

// Build WASM module
let wasm = WasmModuleBuilder::new()
    .with_domain_model(model)
    .with_host_functions(HostFunctionRegistry::with_standard_functions())
    .add_predicate(PredicateDefinition::from_expression("skillMismatch", 1, predicate))
    .build()?;
```

## Why WASM?

WebAssembly provides:

- **Portability**: Same predicates work across platforms
- **Safety**: Sandboxed execution
- **Performance**: Near-native speed
- **No JNI**: Clean HTTP interface instead of complex native bindings

## Components

| Component | Purpose |
|-----------|---------|
| `Expression` | AST for predicate logic |
| `Expr` | Fluent builder for expressions |
| `PredicateDefinition` | Named predicate with arity |
| `WasmModuleBuilder` | Compiles expressions to WASM |
| `HostFunctionRegistry` | Registers host function imports |
