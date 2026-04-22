---
title: "Solver Phases"
linkTitle: "Phases"
weight: 20
description: >
  Construction heuristic, local search, exhaustive search, partitioned search, and VND.
---

The solver runs phases in sequence. Each phase uses a different strategy to improve the solution.

## Construction Heuristic

Builds an initial solution by assigning values to all planning variables. Runs first — local search then improves the result.

### Construction Heuristic Types

| Type | Description |
|---|---|
| `first_fit` | Default generic first-fit construction. Mixed or list-bearing models use the shared runtime construction engine; pure scalar matches reuse the descriptor-standard path. |
| `first_fit_decreasing` | Specialized scalar-only first fit, processing entities by difficulty. |
| `weakest_fit` | Assigns the value that leaves the most room for future assignments. |
| `weakest_fit_decreasing` | Weakest fit, processing entities by difficulty. |
| `strongest_fit` | Assigns the value that uses resources most aggressively. |
| `strongest_fit_decreasing` | Strongest fit, processing entities by difficulty. |
| `cheapest_insertion` | Generic best-score construction over mixed or list-bearing models; pure scalar matches reuse the descriptor-standard path. |
| `allocate_entity_from_queue` | Queue-driven entity allocation. |
| `allocate_to_value_from_queue` | Queue-driven value allocation. |
| `list_round_robin` | Distributes elements evenly across entities (list variables). |
| `list_cheapest_insertion` | Inserts each element at the score-minimizing position (list variables). |
| `list_regret_insertion` | Inserts elements in order of highest placement regret (list variables). |
| `list_clarke_wright` | Greedy route merging by savings value (list variables). |
| `list_k_opt` | Per-route k-opt polishing (list variables). |

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
```

The stock runtime now builds one `ModelContext` per planning model. Generic
construction heuristics work over that shared runtime context instead of
splitting standard-variable and list-variable solve paths.

## Local Search

Iteratively improves the solution by applying moves and accepting improvements (and sometimes worse moves to escape local optima).

### Acceptors

Local search uses an **acceptor** to decide whether to keep a move. In the
stock config surface, the acceptor is configured as a nested object:

| Acceptor | Description |
|---|---|
| `hill_climbing` | Only accepts improving moves. Fast but gets stuck in local optima. |
| `simulated_annealing` | Accepts worse moves with decreasing probability. Good exploration. |
| `tabu_search` | Remembers recent moves and forbids reversing them. Strong for many problems. |
| `late_acceptance` | Accepts moves better than N steps ago. Simple and effective. |
| `great_deluge` | Accepts moves above a rising water level. Steady improvement. |

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
accepted_count_limit = 32
pick_early_type = "never"
```

`accepted_count_limit` now caps how many accepted candidates the forager retains
for final selection. It does not imply early neighborhood exit. Early stop is
still controlled by `pick_early_type` or by explicit first-improving search
policies.

### Acceptor-Specific Configuration

**Simulated Annealing:**
```toml
[phases.acceptor]
type = "simulated_annealing"
starting_temperature = "0hard/500soft"
```

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

VND runs several neighborhoods in sequence and restarts from the first
neighborhood whenever an improvement is found.

```toml
[[phases]]
type = "vnd"

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

## Exhaustive Search

Explores the entire search space systematically. Only practical for small problems.

### Branch and Bound

```toml
[[phases]]
type = "exhaustive_search"
exhaustive_search_type = "branch_and_bound"
```

| Type | Description |
|---|---|
| `branch_and_bound` | Prunes branches that can't improve — memory efficient, finds solutions quickly |
| `brute_force` | Explores every possibility |

### Score Bounder

Use a `ScoreBounder` to prune branches that can't improve on the best known solution, dramatically reducing the search space.

## Partitioned Search

Partitioned search exists in the lower-level solver API as
`PartitionedSearchPhase`. It splits the problem into independent partitions and
solves them in parallel, and the low-level phase now reuses the canonical
scoring lifecycle for child scopes and merged results.

The stock `solver.toml` runtime does **not** expose `partitioned_search` as a
declarative phase today. Use the lower-level Rust API when you need custom
partitioning strategies or explicit partition-thread control.

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

- [Moves](../moves/) — Move types used by local search
- [Termination](../termination/) — Stopping conditions for phases
- [Configuration](../configuration/) — Runtime configuration format
