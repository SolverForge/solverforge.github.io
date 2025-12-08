---
title: "Module Builder"
linkTitle: "Module Builder"
weight: 20
description: "Generate WASM modules with WasmModuleBuilder"
---

# Module Builder

The `WasmModuleBuilder` compiles expressions into a WebAssembly module.

## Basic Usage

```rust
use solverforge_core::wasm::{
    Expr, FieldAccessExt, HostFunctionRegistry, PredicateDefinition, WasmModuleBuilder,
};

let wasm_bytes = WasmModuleBuilder::new()
    .with_domain_model(model)
    .with_host_functions(HostFunctionRegistry::with_standard_functions())
    .add_predicate(PredicateDefinition::from_expression(
        "skillMismatch",
        1,
        build_skill_mismatch_expression(),
    ))
    .build()?;
```

## Configuration

### Domain Model

The domain model is required for field access layout:

```rust
let builder = WasmModuleBuilder::new()
    .with_domain_model(model);
```

### Host Functions

Register host functions that can be called from WASM:

```rust
// Standard functions: string_equals, list_contains, ranges_overlap, etc.
let builder = WasmModuleBuilder::new()
    .with_host_functions(HostFunctionRegistry::with_standard_functions());

// Or start with empty registry
let builder = WasmModuleBuilder::new()
    .with_host_functions(HostFunctionRegistry::new());
```

### Memory Configuration

```rust
let builder = WasmModuleBuilder::new()
    .with_initial_memory(16)       // 16 pages (1 MB)
    .with_max_memory(Some(256));   // Max 256 pages (16 MB)
```

## PredicateDefinition

Define predicates to include in the module:

### From Expression

```rust
// Predicate with arity (number of parameters)
PredicateDefinition::from_expression(
    "skillMismatch",  // Name (used in WasmFunction references)
    1,                // Arity (1 parameter: the Shift)
    expression,       // The Expression tree
)

// With explicit parameter types
use wasm_encoder::ValType;

PredicateDefinition::from_expression_with_types(
    "scaleByFloat",
    vec![ValType::F32],  // Float parameter
    expression,
)
```

### Always True/False

```rust
// Predicate that always returns true
PredicateDefinition::always_true("alwaysMatch", 1)
```

### Simple Comparison

```rust
use solverforge_core::wasm::{Comparison, FieldAccess};

// Equal comparison between two fields
PredicateDefinition::equal(
    "sameEmployee",
    FieldAccess::new(0, "Shift", "employee"),
    FieldAccess::new(1, "Shift", "employee"),
)
```

## Adding Predicates

```rust
let builder = WasmModuleBuilder::new()
    .with_domain_model(model)
    .with_host_functions(HostFunctionRegistry::with_standard_functions())
    .add_predicate(skill_mismatch_predicate)
    .add_predicate(shifts_overlap_predicate)
    .add_predicate(same_employee_predicate);
```

## Building the Module

### As Bytes

```rust
let wasm_bytes: Vec<u8> = builder.build()?;
```

### As Base64

```rust
let wasm_base64: String = builder.build_base64()?;
```

## Generated Exports

The builder generates these exports:

| Export | Description |
|--------|-------------|
| `memory` | Linear memory for objects |
| `alloc` | Allocate memory |
| `dealloc` | Deallocate memory |
| `newList` | Create new list |
| `getItem` | Get list item |
| `setItem` | Set list item |
| `size` | Get list size |
| `append` | Append to list |
| `insert` | Insert into list |
| `remove` | Remove from list |
| `get_{Class}_{field}` | Field getter |
| `set_{Class}_{field}` | Field setter (for planning variables) |
| `{predicate_name}` | Your custom predicates |

## Complete Example

```rust
use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use solverforge_core::wasm::{
    Expr, FieldAccessExt, HostFunctionRegistry, PredicateDefinition, WasmModuleBuilder,
};

// Build predicates
let skill_mismatch = {
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

let shifts_overlap = {
    let s1 = Expr::param(0);
    let s2 = Expr::param(1);
    let emp1 = s1.clone().get("Shift", "employee");
    let emp2 = s2.clone().get("Shift", "employee");

    Expr::and(
        Expr::and(
            Expr::is_not_null(emp1.clone()),
            Expr::eq(emp1, emp2)
        ),
        Expr::ranges_overlap(
            s1.clone().get("Shift", "start"),
            s1.get("Shift", "end"),
            s2.clone().get("Shift", "start"),
            s2.get("Shift", "end"),
        )
    )
};

// Build module
let wasm_bytes = WasmModuleBuilder::new()
    .with_domain_model(model)
    .with_host_functions(HostFunctionRegistry::with_standard_functions())
    .with_initial_memory(16)
    .with_max_memory(Some(256))
    .add_predicate(PredicateDefinition::from_expression(
        "skillMismatch", 1, skill_mismatch
    ))
    .add_predicate(PredicateDefinition::from_expression(
        "shiftsOverlap", 2, shifts_overlap
    ))
    .build()?;

// Encode for HTTP request
let wasm_base64 = BASE64.encode(&wasm_bytes);
```

## API Reference

| Method | Description |
|--------|-------------|
| `WasmModuleBuilder::new()` | Create builder |
| `.with_domain_model(model)` | Set domain model |
| `.with_host_functions(registry)` | Set host functions |
| `.with_initial_memory(pages)` | Initial memory pages |
| `.with_max_memory(Some(pages))` | Max memory pages |
| `.add_predicate(def)` | Add predicate |
| `.build()` | Build as `Vec<u8>` |
| `.build_base64()` | Build as base64 string |
