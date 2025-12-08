---
title: "Solver"
linkTitle: "Solver"
weight: 50
tags: [reference, rust]
description: "Configure and run the constraint solver"
---

This section covers solver configuration and execution.

## In This Section

- [Configuration](configuration/) - Configure solver behavior with `SolverConfig` and `TerminationConfig`
- [Factory](factory/) - Create and run solvers with `SolverFactory` and `Solver`
- [Scores](scores/) - Understand `SimpleScore`, `HardSoftScore`, `HardMediumSoftScore`, and `BendableScore`

## Overview

Running a solver involves:

1. **Configure** - Set termination conditions, environment mode, and threading
2. **Build Request** - Combine domain, constraints, WASM, and problem data
3. **Execute** - Send to solver service and receive solution
4. **Interpret** - Parse score and solution

```rust
use solverforge_core::{SolveRequest, SolveResponse, TerminationConfig};

// Build request with termination
let request = SolveRequest::new(
    domain, constraints, wasm_base64,
    "alloc", "dealloc", list_accessor, problem_json
)
.with_termination(TerminationConfig::new()
    .with_spent_limit("PT5M")
    .with_best_score_feasible(true)
);

// Send to solver
let response: SolveResponse = client
    .post(&format!("{}/solve", service.url()))
    .json(&request)
    .send()?
    .json()?;

// Check result
println!("Score: {}", response.score);
if response.score.starts_with("0hard") {
    println!("Solution is feasible!");
}
```

## Termination Conditions

The solver continues until a termination condition is met:

| Condition | Description |
|-----------|-------------|
| `spent_limit` | Maximum solving time (e.g., `"PT5M"`) |
| `best_score_feasible` | Stop when feasible |
| `best_score_limit` | Stop at target score |
| `move_count_limit` | Maximum moves |
| `step_count_limit` | Maximum steps |

Multiple conditions can be combined - the solver stops when any is satisfied.
