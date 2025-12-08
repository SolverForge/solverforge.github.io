---
title: "Error Handling"
linkTitle: "Errors"
weight: 20
description: "Handle SolverForgeError types and troubleshoot common issues"
---

# Error Handling

SolverForge uses the `SolverForgeError` enum for all error types.

## SolverForgeError

```rust
use solverforge_core::{SolverForgeError, SolverForgeResult};

fn solve_problem() -> SolverForgeResult<String> {
    // ... operations that may fail
    Ok("solution".to_string())
}

match solve_problem() {
    Ok(solution) => println!("Success: {}", solution),
    Err(e) => eprintln!("Error: {}", e),
}
```

## Error Variants

### Serialization

JSON serialization/deserialization errors:

```rust
SolverForgeError::Serialization(String)
```

**Common causes:**
- Invalid JSON in problem data
- Malformed score strings
- Type mismatches

**Example:**
```rust
let score = HardSoftScore::parse("invalid")?;
// Error: Serialization error: Invalid HardSoftScore format...
```

### Http

HTTP communication errors with the solver service:

```rust
SolverForgeError::Http(String)
```

**Common causes:**
- Service not running
- Network timeout
- Connection refused

### Solver

Errors returned by the solver service:

```rust
SolverForgeError::Solver(String)
```

**Common causes:**
- Invalid constraint configuration
- WASM execution failure
- Memory allocation failure

### WasmGeneration

Errors during WASM module generation:

```rust
SolverForgeError::WasmGeneration(String)
```

**Common causes:**
- Invalid expression tree
- Unknown field access
- Missing domain model

### Bridge

Language binding bridge errors:

```rust
SolverForgeError::Bridge(String)
```

**Common causes:**
- Handle invalidation
- Type conversion failures

### Validation

Domain model validation errors:

```rust
SolverForgeError::Validation(String)
```

**Common causes:**
- Missing `@PlanningSolution` class
- No `@PlanningEntity` classes
- Missing `@PlanningVariable` on entities
- Missing `@PlanningScore` field

**Example:**
```rust
let model = DomainModel::builder()
    .add_class(DomainClass::new("Shift"))  // No annotations!
    .build_validated()?;
// Error: Validation error: No @PlanningSolution class found
```

### Configuration

Configuration errors:

```rust
SolverForgeError::Configuration(String)
```

**Common causes:**
- Invalid termination config
- Invalid environment mode

### Service

Embedded service lifecycle errors:

```rust
SolverForgeError::Service(String)
```

**Common causes:**
- Java not found
- Service startup timeout
- Port already in use

### Io

Standard I/O errors:

```rust
SolverForgeError::Io(std::io::Error)
```

**Common causes:**
- File not found
- Permission denied

### Other

Generic errors:

```rust
SolverForgeError::Other(String)
```

## Error Conversion

`SolverForgeError` automatically converts from common error types:

```rust
// From serde_json::Error
let err: SolverForgeError = serde_json::from_str::<i32>("bad")
    .unwrap_err()
    .into();

// From std::io::Error
let err: SolverForgeError = std::fs::read("nonexistent")
    .unwrap_err()
    .into();
```

## Using SolverForgeResult

The type alias simplifies return types:

```rust
use solverforge_core::SolverForgeResult;

fn build_model() -> SolverForgeResult<DomainModel> {
    let model = DomainModel::builder()
        .add_class(/* ... */)
        .build_validated()?;  // Returns SolverForgeResult
    Ok(model)
}
```

## Error Handling Patterns

### Match on Variants

```rust
match result {
    Ok(solution) => { /* handle success */ }
    Err(SolverForgeError::Validation(msg)) => {
        eprintln!("Model validation failed: {}", msg);
    }
    Err(SolverForgeError::Http(msg)) => {
        eprintln!("Service communication failed: {}", msg);
    }
    Err(e) => {
        eprintln!("Other error: {}", e);
    }
}
```

### Propagate with ?

```rust
fn solve() -> SolverForgeResult<SolveResponse> {
    let model = build_model()?;
    let wasm = build_wasm(&model)?;
    let response = send_request(&wasm)?;
    Ok(response)
}
```

### Convert to String

```rust
let error_message = format!("{}", error);
```

## Troubleshooting

### "Service not running"

```
Error: Http error: connection refused
```

**Fix:** Start the solver service:
```rust
let service = EmbeddedService::start(ServiceConfig::new())?;
```

### "WASM generation failed"

```
Error: WasmGeneration error: Unknown class 'Shift'
```

**Fix:** Ensure domain model is set:
```rust
WasmModuleBuilder::new()
    .with_domain_model(model)  // Required!
```

### "Validation error: No solution class"

```
Error: Validation error: No @PlanningSolution class found
```

**Fix:** Add `PlanningSolution` annotation:
```rust
DomainClass::new("Schedule")
    .with_annotation(PlanningAnnotation::PlanningSolution)
```

### "Invalid score format"

```
Error: Serialization error: Invalid HardSoftScore format
```

**Fix:** Use correct format: `"0hard/-5soft"` not `"0/-5"`
