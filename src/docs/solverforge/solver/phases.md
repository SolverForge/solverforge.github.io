---
title: "Solver Phases"
linkTitle: "Phases"
weight: 20
description: >
  Construction heuristic, local search, VND, typed exact search, and partitioned search.
---

The solver runs phases in sequence. Each phase uses a different strategy to improve the solution.

## Construction Heuristic

Builds an initial solution by assigning values to all planning variables. Runs first — local search then improves the result.

### Construction Heuristic Types

| Type                           | Description                                                                                                                                                            |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `first_fit`                    | Default generic first-fit construction. Mixed or list-bearing models use the shared runtime construction engine; pure scalar matches reuse the descriptor-scalar path. |
| `first_fit_decreasing`         | Specialized scalar-only first fit, processing entities by difficulty.                                                                                                  |
| `weakest_fit`                  | Assigns the value that leaves the most room for future assignments.                                                                                                    |
| `weakest_fit_decreasing`       | Weakest fit, processing entities by difficulty.                                                                                                                        |
| `strongest_fit`                | Assigns the value that uses resources most aggressively.                                                                                                               |
| `strongest_fit_decreasing`     | Strongest fit, processing entities by difficulty.                                                                                                                      |
| `cheapest_insertion`           | Generic best-score construction over mixed or list-bearing models; pure scalar matches reuse the descriptor-scalar path.                                               |
| `allocate_entity_from_queue`   | Queue-driven entity allocation.                                                                                                                                        |
| `allocate_to_value_from_queue` | Queue-driven value allocation.                                                                                                                                         |
| `list_round_robin`             | Distributes elements evenly across entities (list variables).                                                                                                          |
| `list_cheapest_insertion`      | Inserts each element at the score-minimizing position (list variables).                                                                                                |
| `list_regret_insertion`        | Inserts elements in order of highest placement regret (list variables).                                                                                                |
| `list_clarke_wright`           | Greedy route merging by savings value (list variables).                                                                                                                |
| `list_k_opt`                   | Per-route k-opt polishing (list variables).                                                                                                                            |

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
```

The stock runtime now builds one `RuntimeModel` per planning model. Generic
construction heuristics work over that shared runtime context instead of
splitting scalar-variable and list-variable solve paths.

Scalar-only construction heuristics validate their model-owned hooks before
phase build. `first_fit_decreasing` and `allocate_entity_from_queue` require
`construction_entity_order_key`; `weakest_fit`, `strongest_fit`, and
`allocate_to_value_from_queue` require `construction_value_order_key`;
decreasing weakest/strongest fit require both. Those keys are evaluated against
the live working solution at each construction step.

Nullable scalar construction defaults to
`construction_obligation = "preserve_unassigned"`, so an optional variable may
keep `None` when that is the best legal baseline. Use
`assign_when_candidate_exists` only when construction must assign any doable
candidate instead.

When `group_name` selects an assignment-backed `ScalarGroup`, grouped scalar
construction also uses `construction_obligation`: with
`assign_when_candidate_exists`, every required nullable scalar slot that has a
doable candidate is treated as a construction obligation.

## Local Search

Iteratively improves the solution by applying moves and accepting improvements (and sometimes worse moves to escape local optima).

Current local-search telemetry emits `phase_start` after the starting score is
known. With console output enabled, the phase-start line includes that score,
making it clear what construction handed to local search before the first move
is evaluated.

### Acceptors

Local search uses an **acceptor** to decide whether to keep a move. In the
stock config surface, the acceptor is configured as a nested object:

| Acceptor              | Description                                                                  |
| --------------------- | ---------------------------------------------------------------------------- |
| `hill_climbing`       | Only accepts improving moves. Fast but gets stuck in local optima.           |
| `simulated_annealing` | Accepts worse moves with decreasing probability. Good exploration.           |
| `tabu_search`         | Remembers recent moves and forbids reversing them. Strong for many problems. |
| `late_acceptance`     | Accepts moves better than N steps ago. Simple and effective.                 |
| `great_deluge`        | Accepts moves above a rising water level. Steady improvement.                |

```toml
[[phases]]
type = "local_search"
[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[phases.termination]
unimproved_step_count_limit = 10000
```

### Move Selector and Forager

Local search phases can also specify a selector and forager:

```toml
[[phases]]
type = "local_search"

[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[phases.move_selector]
type = "change_move_selector"
variable_name = "employee_id"

[phases.forager]
type = "accepted_count"
limit = 32
```

The accepted-count forager stops the current selector step after collecting
`limit` accepted candidates, then picks the best candidate inside that step
horizon. Use `best_score` when you intentionally want a full-neighborhood scan.

Assignment-backed scalar repair is configured through the grouped scalar move
selector:

```toml
[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "required_shift_assignment"
max_moves_per_step = 64
require_hard_improvement = true
```

The selector consumes the same named assignment-backed `ScalarGroup` used by
construction, then emits compound scalar repair moves for uncovered required
slots, capacity conflicts, bounded reassignments, and sequence/position
rematches.

### Acceptor-Specific Configuration

**Simulated Annealing:**

```toml
[phases.acceptor]
type = "simulated_annealing"
level_temperatures = [5.0, 500.0]
hard_regression_policy = "temperature_controlled"

[phases.acceptor.calibration]
sample_size = 64
target_acceptance_probability = 0.75
fallback_temperature = 2.0
```

Simulated annealing is score-level aware. `level_temperatures` are ordered from
highest-priority score level to lowest; if they are omitted, calibration can
sample candidate deltas and derive temperatures per level. Once the configured
temperature cools to the hill-climbing threshold, worsening moves are rejected
deterministically.

**Tabu Search:**

```toml
[phases.acceptor]
type = "tabu_search"
entity_tabu_size = 7
# or value_tabu_size, move_tabu_size
```

**Late Acceptance:**

```toml
[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400
```

## Variable Neighborhood Descent

Variable Neighborhood Descent is an ordered-neighborhood local-search type. It
runs several neighborhoods in sequence and restarts from the first neighborhood
whenever an improvement is found.

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

When one neighborhood needs a hard move cap, wrap that neighborhood itself with
`limited_neighborhood` rather than decorating a broader selector tree:

```toml
[[phases.neighborhoods]]
type = "limited_neighborhood"
selected_count_limit = 48

[phases.neighborhoods.selector]
type = "change_move_selector"
variable_name = "employee_id"
```

## Typed Exact Search

Exact tree search exists as a typed extension point for small finite spaces.
It is not a stock `solver.toml` phase that can be built from generated scalar
slots alone. Register exact search as a named custom phase through
`#[planning_solution(search = "...")]`, then order that compiled-in phase from
config.

The lower-level API exposes `ExhaustiveSearchPhase`, `ExhaustiveSearchConfig`,
`ExplorationType`, and `SimpleDecider` for applications that own the concrete
decider. Use this path only when the domain can provide a real exact-search
state expansion and pruning strategy.

```toml
[[phases]]
type = "custom"
name = "small_exact_search"
```

## Partitioned Search

Partitioned search is available when the application provides a typed
`SolutionPartitioner` that splits and merges independent subproblems. SolverForge
does not infer safe partitions from a count.

```toml
[[phases]]
type = "partitioned_search"
partitioner = "by_vehicle"
thread_count = "auto"
log_progress = true
```

Partition children inherit cancellation, remaining time, environment mode,
in-phase limits, and deterministic child seeds. Retained-job publication stays
on the parent full-solution scope; pause checkpoints are emitted only by the
parent.

## Typical Phase Configuration

Most problems work well with construction heuristic + local search:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"
[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400
```

For better results, try tabu search or simulated annealing as the acceptor.

## See Also

- [Construction](/docs/solverforge/solver/construction/) — Initial solution policy
- [Local Search](/docs/solverforge/solver/local-search/) — Acceptors, foragers, selector placement, and VND
- [Moves](/docs/solverforge/solver/moves/) — Move types used by local search
- [Termination](/docs/solverforge/solver/termination/) — Stopping conditions for phases
- [Configuration](/docs/solverforge/solver/configuration/) — Runtime configuration format
