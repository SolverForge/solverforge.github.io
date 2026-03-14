---
title: "Configuration"
linkTitle: "Configuration"
weight: 10
description: >
  TOML-based solver configuration with SolverConfig.
---

SolverForge uses TOML for solver configuration. You can load configuration from a file or build it from a string.

## Loading Configuration

### From a TOML file

```rust
let config = SolverConfig::load("solver-config.toml").unwrap();
```

### From a TOML string

```rust
let config = SolverConfig::from_toml_str(r#"
    [solver]
    environment_mode = "non_reproducible"
    move_thread_count = 4

    [solver.termination]
    seconds_spent_limit = 120

    [[solver.phases]]
    type = "construction_heuristic"
    forager_type = "best_fit"

    [[solver.phases]]
    type = "local_search"
    acceptor = "late_acceptance"
    late_acceptance_size = 400
"#).unwrap();
```

## Example TOML File

```toml
[solver]
environment_mode = "non_reproducible"
move_thread_count = "auto"

[solver.termination]
seconds_spent_limit = 300
unimproved_seconds_spent_limit = 60

[[solver.phases]]
type = "construction_heuristic"
forager_type = "first_fit"

[[solver.phases]]
type = "local_search"
acceptor = "simulated_annealing"
starting_temperature = "0hard/500soft"

[solver.phases.termination]
step_count_limit = 100000
```

## Configuration Options

### Environment Mode

Controls reproducibility and assertion levels.

| Mode | Description |
|---|---|
| `reproducible` | Deterministic — same input always produces the same output. Slower. |
| `non_reproducible` | Non-deterministic — fastest mode for production use |
| `fast_assert` | Enables light assertions for debugging |
| `full_assert` | Enables all assertions — slowest, for development only |

```toml
[solver]
environment_mode = "non_reproducible"
```

### Move Thread Count

Controls multi-threaded move evaluation.

```toml
[solver]
move_thread_count = 4        # Fixed thread count
move_thread_count = "auto"   # Use available cores
move_thread_count = "none"   # Single-threaded (default)
```

### Phases

Phases run in sequence. A typical configuration uses construction heuristic followed by local search:

```toml
[[solver.phases]]
type = "construction_heuristic"
forager_type = "best_fit"

[[solver.phases]]
type = "local_search"
acceptor = "tabu_search"
entity_tabu_size = 7
```

See [Phases](../phases/) for all phase types and their options.

### Termination

Controls when the solver stops. See [Termination](../termination/) for all options.

```toml
[solver.termination]
seconds_spent_limit = 300
```

## See Also

- [Phases](../phases/) — Phase types and configuration
- [Termination](../termination/) — Termination conditions
- [SolverManager](../solver-manager/) — Running the solver
