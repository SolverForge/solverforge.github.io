---
title: "Solver Factory"
linkTitle: "Factory"
weight: 20
description: "Create and run solvers with SolverFactory and Solver"
---

# Solver Factory

The solver is executed via HTTP requests to the solver service.

## SolveRequest

Build a request containing all solving inputs:

```rust
use solverforge_core::{
    DomainObjectDto, ListAccessorDto, SolveRequest, TerminationConfig
};
use indexmap::IndexMap;

let request = SolveRequest::new(
    domain,           // IndexMap<String, DomainObjectDto>
    constraints,      // IndexMap<String, Vec<StreamComponent>>
    wasm_base64,      // Base64-encoded WASM module
    "alloc".to_string(),    // Memory allocator function
    "dealloc".to_string(),  // Memory deallocator function
    list_accessor,    // ListAccessorDto
    problem_json,     // JSON-serialized problem
);
```

### Adding Configuration

```rust
let request = SolveRequest::new(/* ... */)
    .with_environment_mode("REPRODUCIBLE")
    .with_termination(
        TerminationConfig::new()
            .with_spent_limit("PT5M")
            .with_best_score_feasible(true)
    );
```

### ListAccessorDto

Define WASM functions for list operations:

```rust
let list_accessor = ListAccessorDto::new(
    "newList",   // Create new list
    "getItem",   // Get item at index
    "setItem",   // Set item at index
    "size",      // Get list size
    "append",    // Append item
    "insert",    // Insert at index
    "remove",    // Remove at index
    "dealloc",   // Deallocate list
);
```

## Sending Requests

### Synchronous Solve

```rust
use reqwest::blocking::Client;
use solverforge_core::SolveResponse;

let client = Client::builder()
    .timeout(std::time::Duration::from_secs(600))
    .build()?;

let response: SolveResponse = client
    .post(&format!("{}/solve", service.url()))
    .header("Content-Type", "application/json")
    .json(&request)
    .send()?
    .json()?;

println!("Score: {}", response.score);
println!("Solution: {}", response.solution);
```

### Response Structure

```rust
pub struct SolveResponse {
    pub score: String,         // e.g., "0hard/-5soft"
    pub solution: String,      // JSON-serialized solution
    pub stats: Option<SolverStats>,
}
```

## SolveResponse Fields

| Field | Type | Description |
|-------|------|-------------|
| `score` | `String` | Final score (e.g., `"0hard/-5soft"`) |
| `solution` | `String` | JSON solution with assignments |
| `stats` | `Option<SolverStats>` | Performance statistics |

## Complete Example

```rust
use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use indexmap::IndexMap;
use reqwest::blocking::Client;
use solverforge_core::{
    DomainObjectDto, ListAccessorDto, SolveRequest, SolveResponse,
    StreamComponent, TerminationConfig, WasmFunction
};
use solverforge_service::{EmbeddedService, ServiceConfig};
use std::time::Duration;

// Start the solver service
let service = EmbeddedService::start(ServiceConfig::new())?;

// Build domain DTO from model
let domain = model.to_dto();

// Build constraints
let mut constraints = IndexMap::new();
constraints.insert("requiredSkill".to_string(), vec![
    StreamComponent::for_each("Shift"),
    StreamComponent::filter(WasmFunction::new("skillMismatch")),
    StreamComponent::penalize("1hard/0soft"),
]);

// Encode WASM
let wasm_base64 = BASE64.encode(&wasm_bytes);

// Build list accessor
let list_accessor = ListAccessorDto::new(
    "newList", "getItem", "setItem", "size",
    "append", "insert", "remove", "dealloc"
);

// Problem data as JSON
let problem_json = r#"{"employees": [...], "shifts": [...]}"#;

// Build request
let request = SolveRequest::new(
    domain,
    constraints,
    wasm_base64,
    "alloc".to_string(),
    "dealloc".to_string(),
    list_accessor,
    problem_json.to_string(),
)
.with_termination(TerminationConfig::new()
    .with_move_count_limit(1000)
);

// Send request
let client = Client::builder()
    .timeout(Duration::from_secs(120))
    .build()?;

let response: SolveResponse = client
    .post(&format!("{}/solve", service.url()))
    .json(&request)
    .send()?
    .json()?;

// Parse result
println!("Score: {}", response.score);

// Parse solution JSON
let solution: serde_json::Value = serde_json::from_str(&response.solution)?;
let shifts = solution.get("shifts").unwrap().as_array().unwrap();

for shift in shifts {
    let id = shift.get("id").unwrap();
    let employee = shift.get("employee");
    println!("Shift {}: {:?}", id, employee);
}
```

## Error Handling

Check HTTP status and handle errors:

```rust
let response = client
    .post(&format!("{}/solve", service.url()))
    .json(&request)
    .send()?;

if !response.status().is_success() {
    let error_text = response.text()?;
    eprintln!("Solver error: {}", error_text);
    return Err(/* error */);
}

let result: SolveResponse = response.json()?;
```

## Interpreting Scores

```rust
// Check if solution is feasible
if result.score.starts_with("0hard") || result.score.starts_with("0/") {
    println!("Solution is feasible!");
} else {
    println!("Solution has hard constraint violations");
}

// Parse score for detailed analysis
let score = solverforge_core::HardSoftScore::parse(&result.score)?;
println!("Hard: {}, Soft: {}", score.hard_score, score.soft_score);
println!("Feasible: {}", score.is_feasible());
```
