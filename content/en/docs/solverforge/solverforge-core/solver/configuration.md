---
title: "Solver Configuration"
linkTitle: "Configuration"
weight: 10
description: "Configure solver behavior with SolverConfig and TerminationConfig"
---

# Solver Configuration

Configure how the solver runs with `SolverConfig` and `TerminationConfig`.

## SolverConfig

Configure overall solver behavior:

```rust
use solverforge_core::{SolverConfig, TerminationConfig, EnvironmentMode, MoveThreadCount};

let config = SolverConfig::new()
    .with_solution_class("Schedule")
    .with_entity_class("Shift")
    .with_environment_mode(EnvironmentMode::Reproducible)
    .with_random_seed(42)
    .with_move_thread_count(MoveThreadCount::Auto)
    .with_termination(TerminationConfig::new()
        .with_spent_limit("PT5M")
    );
```

### SolverConfig Methods

| Method | Description |
|--------|-------------|
| `with_solution_class(class)` | Set the solution class name |
| `with_entity_class(class)` | Add an entity class |
| `with_entity_classes(classes)` | Set all entity classes |
| `with_environment_mode(mode)` | Set environment mode |
| `with_random_seed(seed)` | Set random seed for reproducibility |
| `with_move_thread_count(count)` | Set parallel thread count |
| `with_termination(config)` | Set termination configuration |

### Environment Modes

| Mode | Description |
|------|-------------|
| `Reproducible` | Same seed = same solution (default) |
| `NonReproducible` | Random behavior each run |
| `NoAssert` | Minimal validation (fastest) |
| `PhaseAssert` | Validate after each phase |
| `StepAssert` | Validate after each step |
| `FullAssert` | Maximum validation (slowest) |
| `TrackedFullAssert` | Full validation with tracking |

### Move Thread Count

| Option | Description |
|--------|-------------|
| `MoveThreadCount::Auto` | Use available CPUs |
| `MoveThreadCount::None` | Single-threaded |
| `MoveThreadCount::Count(n)` | Specific thread count |

## TerminationConfig

Define when the solver should stop:

```rust
let termination = TerminationConfig::new()
    .with_spent_limit("PT5M")                    // Max 5 minutes
    .with_unimproved_spent_limit("PT30S")       // Stop if no improvement for 30s
    .with_best_score_feasible(true)             // Stop when feasible
    .with_move_count_limit(10000);              // Max 10,000 moves
```

### Time-Based Termination

Use ISO-8601 duration format:

```rust
// Duration format: PT{hours}H{minutes}M{seconds}S
.with_spent_limit("PT5M")           // 5 minutes
.with_spent_limit("PT1H30M")        // 1 hour 30 minutes
.with_spent_limit("PT10S")          // 10 seconds
.with_unimproved_spent_limit("PT30S")  // No improvement timeout
```

### Score-Based Termination

```rust
// Stop when feasible (hard score >= 0)
.with_best_score_feasible(true)

// Stop at specific score
.with_best_score_limit("0hard/-100soft")
```

### Count-Based Termination

```rust
.with_step_count_limit(1000)           // Max solver steps
.with_move_count_limit(10000)          // Max moves
.with_unimproved_step_count(100)       // Steps without improvement
.with_score_calculation_count_limit(1000000)  // Score calculations
```

### Diminished Returns

Stop when improvements become too small:

```rust
use solverforge_core::DiminishedReturnsConfig;

let dr = DiminishedReturnsConfig::new()
    .with_minimum_improvement_ratio("0.001")
    .with_slow_improvement_limit("PT30S");

let termination = TerminationConfig::new()
    .with_diminished_returns(dr);
```

## TerminationConfig Methods

| Method | Description |
|--------|-------------|
| `with_spent_limit(duration)` | Maximum solving time |
| `with_unimproved_spent_limit(duration)` | Timeout without improvement |
| `with_unimproved_step_count(count)` | Steps without improvement |
| `with_best_score_limit(score)` | Target score to reach |
| `with_best_score_feasible(bool)` | Stop when hard >= 0 |
| `with_step_count_limit(count)` | Maximum steps |
| `with_move_count_limit(count)` | Maximum moves |
| `with_score_calculation_count_limit(count)` | Max score calculations |
| `with_diminished_returns(config)` | Diminishing returns config |

## Complete Example

```rust
let config = SolverConfig::new()
    .with_solution_class("Schedule")
    .with_entity_class("Shift")
    .with_environment_mode(EnvironmentMode::Reproducible)
    .with_random_seed(42)
    .with_termination(
        TerminationConfig::new()
            .with_spent_limit("PT10M")              // Max 10 minutes
            .with_unimproved_spent_limit("PT1M")   // No improvement for 1 min
            .with_best_score_feasible(true)        // Stop if feasible
    );
```

This configuration:
1. Solves for up to 10 minutes
2. Stops early if no improvement for 1 minute
3. Stops immediately when a feasible solution is found
4. Uses seed 42 for reproducible results
