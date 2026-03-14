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

### Forager Types

| Forager Type | Description |
|---|---|
| `first_fit` | Assigns the first feasible value found. Fast. |
| `best_fit` | Tries all values, picks the best. Better quality, slower. |
| `first_feasible` | Assigns the first value that doesn't break hard constraints. |
| `weakest_fit` | Assigns the value that leaves the most room for future assignments. |
| `strongest_fit` | Assigns the value that uses resources most aggressively. |

```toml
[[solver.phases]]
type = "construction_heuristic"
forager_type = "best_fit"
```

## Local Search

Iteratively improves the solution by applying moves and accepting improvements (and sometimes worse moves to escape local optima).

### Acceptors

Local search uses an **acceptor** to decide whether to keep a move:

| Acceptor | Description |
|---|---|
| `hill_climbing` | Only accepts improving moves. Fast but gets stuck in local optima. |
| `simulated_annealing` | Accepts worse moves with decreasing probability. Good exploration. |
| `tabu_search` | Remembers recent moves and forbids reversing them. Strong for many problems. |
| `late_acceptance` | Accepts moves better than N steps ago. Simple and effective. |
| `great_deluge` | Accepts moves above a rising water level. Steady improvement. |
| `step_counting_hill_climbing` | Hill climbing with periodic restarts based on step count. |
| `diversified_late_acceptance` | Late acceptance with diversification to escape plateaus. |

```toml
[[solver.phases]]
type = "local_search"
acceptor = "late_acceptance"
late_acceptance_size = 400

[solver.phases.termination]
unimproved_step_count_limit = 10000
```

### Acceptor-Specific Configuration

**Simulated Annealing:**
```toml
acceptor = "simulated_annealing"
starting_temperature = "0hard/500soft"
```

**Tabu Search:**
```toml
acceptor = "tabu_search"
entity_tabu_size = 7
# or value_tabu_size, move_tabu_size
```

**Late Acceptance:**
```toml
acceptor = "late_acceptance"
late_acceptance_size = 400
```

### Forager Types (Local Search)

| Forager Type | Description |
|---|---|
| `accepted_count` | Evaluate a fixed number of moves per step (default) |
| `first_improving` | Accept the first improving move found |

## Exhaustive Search

Explores the entire search space systematically. Only practical for small problems.

### Branch and Bound

```toml
[[solver.phases]]
type = "exhaustive_search"
exploration_type = "depth_first"
```

| Exploration Type | Description |
|---|---|
| `depth_first` | DFS — memory efficient, finds solutions quickly |
| `breadth_first` | BFS — explores level by level |
| `score_first` | Explores most promising branches first |

### Score Bounder

Use a `ScoreBounder` to prune branches that can't improve on the best known solution, dramatically reducing the search space.

## Partitioned Search

Splits the problem into independent partitions and solves them in parallel on separate threads.

```toml
[[solver.phases]]
type = "partitioned_search"
```

Requires implementing the `SolutionPartitioner` trait to define how the problem is split.

## VND (Variable Neighborhood Descent)

Cycles through different move types, switching neighborhoods when no improvement is found.

```toml
[[solver.phases]]
type = "vnd"
```

## Typical Phase Configuration

Most problems work well with construction heuristic + local search:

```toml
[[solver.phases]]
type = "construction_heuristic"
forager_type = "first_fit"

[[solver.phases]]
type = "local_search"
acceptor = "late_acceptance"
late_acceptance_size = 400
```

For better results, try tabu search or simulated annealing as the acceptor.

## See Also

- [Moves](../moves/) — Move types used by local search
- [Termination](../termination/) — Stopping conditions for phases
- [Configuration](../configuration/) — TOML configuration format
