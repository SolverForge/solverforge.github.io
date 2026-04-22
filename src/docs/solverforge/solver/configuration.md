---
title: "Configuration"
linkTitle: "Configuration"
weight: 10
description: >
  Runtime configuration with SolverConfig, solver.toml, and parsing helpers.
---

The stock generated runtime loads `solver.toml` automatically when you call
`SolverManager::solve(...)`. The `solverforge-config` crate also exposes parsing
helpers for TOML and YAML when you want to inspect or build configs directly.

## Loading Configuration

### From a TOML file

```rust
let config = SolverConfig::load("solver.toml").unwrap();
```

### From a TOML string

```rust
let config = SolverConfig::from_toml_str(r#"
    environment_mode = "reproducible"
    move_thread_count = 4

    [termination]
    seconds_spent_limit = 120

    [[phases]]
    type = "construction_heuristic"
    construction_heuristic_type = "first_fit"

    [[phases]]
    type = "local_search"
    [phases.acceptor]
    type = "late_acceptance"
    late_acceptance_size = 400
"#).unwrap();
```

### From YAML

```rust
let config = SolverConfig::from_yaml_str(r#"
environment_mode: reproducible
termination:
  seconds_spent_limit: 120
phases:
  - type: construction_heuristic
    construction_heuristic_type: first_fit
"#).unwrap();
```

## Example TOML File

```toml
environment_mode = "non_reproducible"
move_thread_count = "auto"

[termination]
seconds_spent_limit = 300
unimproved_seconds_spent_limit = 60

[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"

[phases.acceptor]
type = "simulated_annealing"
starting_temperature = "0hard/500soft"

[phases.move_selector]
type = "change_move_selector"
variable_name = "employee_id"

[phases.termination]
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
environment_mode = "non_reproducible"
```

### Move Thread Count

Controls multi-threaded move evaluation.

```toml
move_thread_count = 4        # Fixed thread count
move_thread_count = "auto"   # Use available cores
move_thread_count = "none"   # Single-threaded (default)
```

### Random Seed

Set a fixed seed when you want reproducible runs:

```toml
random_seed = 42
```

### Phases

Phases run in sequence. A typical configuration uses a construction heuristic
followed by local search:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"
[phases.acceptor]
type = "tabu_search"
entity_tabu_size = 7
```

See [Phases](../phases/) for all phase types and their options.

### Move Selectors

For config-driven local search, move selection lives under
`[phases.move_selector]`.

```toml
[phases.move_selector]
type = "nearby_list_change_move_selector"
max_nearby = 12
variable_name = "visits"
```

Nearby selection is configured by choosing a nearby selector variant, not by
top-level `nearby_selection = true` flags.

When you need to cap one neighborhood deliberately, use the
`limited_neighborhood` selector variant and wrap the concrete selector inside
it:

```toml
[phases.move_selector]
type = "limited_neighborhood"
selected_count_limit = 24

[phases.move_selector.selector]
type = "change_move_selector"
variable_name = "employee_id"
```

That cap applies to the wrapped neighborhood itself. It is not a replacement
for `accepted_count_limit`, which only controls how many accepted moves the
forager retains for final selection.

### Termination

Controls when the solver stops. See [Termination](../termination/) for all options.

```toml
[termination]
seconds_spent_limit = 300
```

### Programmatic Builders

`SolverConfig` also exposes simple builder helpers:

```rust
let config = SolverConfig::new()
    .with_random_seed(42)
    .with_termination_seconds(30);
```

## Per-Solution Overlays

Macro-generated retained solves can layer runtime policy on top of the loaded
`solver.toml` by using `config = "..."` on `#[planning_solution]`:

```rust
#[planning_solution(
    constraints = "define_constraints",
    config = "solver_config_for_solution"
)]
pub struct Schedule {
    #[planning_score]
    pub score: Option<HardSoftScore>,
    pub time_limit_secs: u64,
}

fn solver_config_for_solution(solution: &Schedule, config: SolverConfig) -> SolverConfig {
    config.with_termination_seconds(solution.time_limit_secs)
}
```

The callback receives the already loaded `solver.toml` config, so it should
decorate that base config rather than replace it from scratch.

## See Also

- [Phases](../phases/) — Phase types and configuration
- [Termination](../termination/) — Termination conditions
- [SolverManager](../solver-manager/) — Running the solver
