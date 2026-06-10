---
title: "Configuration"
linkTitle: "Configuration"
weight: 10
description: >
  Runtime configuration with SolverConfig, solver.toml, and parsing helpers.
---

The stock generated runtime loads `solver.toml` automatically when you call
`SolverManager::solve(...)`. In the current release, the `solverforge` facade
also exports the normal configuration API directly, so app code can stay on one
public dependency when it needs to inspect or build configs directly.

```rust
use solverforge::{
    AcceptorConfig, ForagerConfig, MoveSelectorConfig, PhaseConfig,
    SolverConfig, SolverConfigOverride,
};
```

Configuration has three levels:

| Level | Scope | Typical owner |
| ----- | ----- | ------------- |
| Global config | environment mode, random seed, thread count, top-level termination | app/operator |
| Phase config | construction, local search, VND via `local_search_type`, partitioned search, custom phase names, phase-specific termination | app/operator |
| Model hooks | candidate providers, nearby hooks, construction order keys, scalar groups | Rust domain model |

The important rule is that config selects declared capabilities. It does not
invent model hooks. If a selector asks for nearby scalar candidates, grouped
scalar candidates, assignment-backed scalar groups, or conflict repair
providers, the model must expose those capabilities through the generated model
support layer.

## Loading Configuration

### From a TOML file

```rust
use solverforge::SolverConfig;

let config = SolverConfig::load("solver.toml").unwrap();
```

### From a TOML string

```rust
use solverforge::SolverConfig;

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
use solverforge::SolverConfig;

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
construction_obligation = "preserve_unassigned"
value_candidate_limit = 32

[[phases]]
type = "local_search"

[phases.acceptor]
type = "simulated_annealing"
level_temperatures = [5.0, 500.0]
hard_regression_policy = "never_accept_hard_regression"

[phases.move_selector]
type = "change_move_selector"
variable_name = "employee_id"
value_candidate_limit = 32

[phases.termination]
step_count_limit = 100000
```

## Configuration Options

### Environment Mode

Controls reproducibility and assertion levels.

| Mode               | Description                                                         |
| ------------------ | ------------------------------------------------------------------- |
| `reproducible`     | Deterministic — same input always produces the same output. Slower. |
| `non_reproducible` | Non-deterministic — fastest mode for production use                 |
| `fast_assert`      | Enables light assertions for debugging                              |
| `full_assert`      | Enables all assertions — slowest, for development only              |

```toml
environment_mode = "non_reproducible"
```

### Move Thread Count

Controls multi-threaded move evaluation.

```toml
move_thread_count = 4        # Fixed thread count
move_thread_count = "auto"   # Use available cores (default)
move_thread_count = "none"   # Single-threaded
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

See [Phases](/docs/solverforge/solver/phases/) for all phase types and their options.

### Phase Anatomy

Most production configs have this shape:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "preserve_unassigned"
value_candidate_limit = 32

[[phases]]
type = "local_search"

[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[phases.forager]
type = "accepted_count"
limit = 4

[phases.move_selector]
type = "union_move_selector"
selection_order = "round_robin"

[[phases.move_selector.selectors]]
type = "change_move_selector"
value_candidate_limit = 32

[[phases.move_selector.selectors]]
type = "swap_move_selector"

[phases.termination]
step_count_limit = 100000
```

Construction creates the first workable solution. Local search improves it.
The acceptor decides whether a scored candidate can be accepted. The forager
decides which accepted candidate is committed. The move selector decides which
candidate moves are generated.

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

Nearby scalar selectors require model-declared candidate hooks on the matching
`#[planning_variable]`: `nearby_value_candidates` for
`nearby_change_move_selector` and `nearby_entity_candidates` for
`nearby_swap_move_selector`. Distance meters only rank or filter those bounded
candidates.

List selectors likewise select declared list capabilities. `list_permute_move_selector`
permutes a bounded window in one list. `list_precedence_move_selector` targets
list variables that expose `precedence_duration_fn` and
`precedence_successors_fn` hooks through `#[planning_list_variable]`; it streams
critical-path support moves for generic precedence makespan models.

```toml
[phases.move_selector]
type = "list_permute_move_selector"
variable_name = "operations"
min_window_size = 2
max_window_size = 5
```

```toml
[phases.move_selector]
type = "list_precedence_move_selector"
entity_class = "Route"
variable_name = "operations"
```

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

That cap applies to the wrapped neighborhood itself. It is separate from the
accepted-count forager `limit`, which stops a selector step after that many
accepted candidates and then picks the best candidate inside that step horizon.

Scalar `change_move_selector`, `nearby_change_move_selector`,
`pillar_change_move_selector`, and `ruin_recreate_move_selector` accept
`value_candidate_limit`. Scalar `cheapest_insertion` requires a bounded
candidate source: either `candidate_values` on the model or this config limit.

Grouped scalar construction and grouped scalar local search use `group_name`
when the model provides a scalar group through the generated model support
surface. Grouped local search also supports `require_hard_improvement` when a
compound candidate must improve the hard score before it can be accepted.

Assignment-backed scalar construction and repair use the same `group_name`
surface. The model declares `ScalarGroup::assignment(...)`; construction
generates stock nullable scalar assignment candidates and local search repairs
uncovered required entities, capacity conflicts, bounded reassignments, and
sequence/position rematches:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
group_name = "required_shift_assignment"
value_candidate_limit = 8
group_candidate_limit = 64

[[phases]]
type = "local_search"

[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "required_shift_assignment"
max_moves_per_step = 64
require_hard_improvement = true
```

Grouped construction example:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
group_name = "task_operator_assignment"
value_candidate_limit = 32
group_candidate_limit = 128
```

Grouped local-search example:

```toml
[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "task_operator_assignment"
value_candidate_limit = 32
max_moves_per_step = 256
require_hard_improvement = true
```

Conflict-repair selectors configure `constraints` by exact scoring metadata
identity. Use `ConstraintRef::full_name()` for package-qualified constraints and
the short name for package-less constraints. With `include_soft_matches = false`,
soft constraints are rejected before providers run; setting it to `true`
explicitly allows soft repair providers. Conflict repair operates on
non-assignment-owned scalar variables; assignment-backed scalar slots stay on
their owning grouped scalar selector path.

Compound repair example:

```toml
[phases.move_selector]
type = "compound_conflict_repair_move_selector"
constraints = ["schedule/no_overlapping_operator_assignment"]
max_matches_per_step = 16
max_repairs_per_match = 32
max_moves_per_step = 256
require_hard_improvement = true
```

### Variable Neighborhood Descent

VND is a local-search type, not a standalone `type = "vnd"` phase:

```toml
[[phases]]
type = "local_search"
local_search_type = "variable_neighborhood_descent"

[[phases.neighborhoods]]
type = "change_move_selector"
variable_name = "employee_id"

[[phases.neighborhoods]]
type = "swap_move_selector"
variable_name = "employee_id"
```

The `variable_neighborhood_descent` mode uses ordered `neighborhoods` and rejects
`acceptor`, `forager`, and `move_selector`. The default `acceptor_forager`
local-search mode uses `acceptor`, `forager`, and `move_selector`.

### Partitioned And Custom Search

`partitioned_search` requires a named partitioner compiled into the solution's
typed search surface. SolverForge does not infer partitions from a count:

```toml
[[phases]]
type = "partitioned_search"
partitioner = "by_vehicle"
thread_count = "auto"
log_progress = true
```

Custom phases are also compiled into the solution with
`#[planning_solution(search = "...")]` and selected by name:

```toml
[[phases]]
type = "custom"
name = "weekend_repair"
```

There is no arbitrary `custom_phase_class` loader or erased plugin registry.

### Construction Obligation

Nullable scalar variables default to `preserve_unassigned`: construction may
leave `None` in place when that is legal and scores best. Use
`assign_when_candidate_exists` when construction should assign a doable value
whenever one exists:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
```

### Termination

Controls when the solver stops. See [Termination](/docs/solverforge/solver/termination/) for all options.

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

- [Construction](/docs/solverforge/solver/construction/) — Construction policy and grouped scalar construction
- [Local Search](/docs/solverforge/solver/local-search/) — Acceptors, foragers, and move selectors
- [Moves](/docs/solverforge/solver/moves/) — Selector families and move behavior
- [Termination](/docs/solverforge/solver/termination/) — Termination conditions
- [SolverManager](/docs/solverforge/solver/solver-manager/) — Running the solver
