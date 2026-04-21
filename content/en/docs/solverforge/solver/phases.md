---
title: "Solver Phases"
linkTitle: "Phases"
weight: 20
description: >
  Construction heuristic, local search, exhaustive search, partitioned search, and VND.
---

The solver runs phases in sequence. Each phase uses a different strategy to improve the solution.

## Construction Heuristic

Builds an initial solution by assigning values across scalar, list, or mixed
planning models. Runs first — local search then improves the result.

### Construction Heuristic Types

| Type | Description |
|---|---|
| `first_fit` | Generic first-fit over mixed or list-bearing models; pure scalar matches reuse the descriptor-standard scalar path. |
| `first_fit_decreasing` | Scalar-only first fit, processing entities by difficulty. |
| `weakest_fit` | Scalar-only weakest-fit heuristic. |
| `weakest_fit_decreasing` | Scalar-only weakest fit, processing entities by difficulty. |
| `strongest_fit` | Scalar-only strongest-fit heuristic. |
| `strongest_fit_decreasing` | Scalar-only strongest fit, processing entities by difficulty. |
| `cheapest_insertion` | Generic best-score construction over mixed or list-bearing models; pure scalar matches reuse the descriptor-standard scalar path. |
| `allocate_entity_from_queue` | Scalar-only queue-driven entity allocation. |
| `allocate_to_value_from_queue` | Scalar-only queue-driven value allocation. |
| `list_round_robin` | Specialized list-only even distribution. |
| `list_cheapest_insertion` | Specialized list-only score-minimizing insertion. |
| `list_regret_insertion` | Specialized list-only highest-regret insertion. |
| `list_clarke_wright` | Specialized list-only greedy route merging by savings value. |
| `list_k_opt` | Specialized list-only per-route k-opt polishing. |

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
```

The stock runtime now uses one `ModelContext` for scalar-only, list-only, and
mixed planning models. Generic `first_fit` and `cheapest_insertion` follow that
shared runtime path when list work is present, while specialized scalar and
list heuristics remain explicit opt-ins.

For `Option<T>` variables declared with `allows_unassigned = true`, stock
`first_fit` keeps `None` when it is the best legal baseline instead of forcing
an assignment during construction.

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

`accepted_count_limit` caps how many accepted moves are retained for final
selection. It does **not** stop neighborhood evaluation early; use
`pick_early_type` or a first-improving forager when you want early exit.

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
