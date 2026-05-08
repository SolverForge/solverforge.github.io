---
title: "Local Search"
linkTitle: "Local Search"
weight: 14
description: >
  Local-search acceptors, foragers, move selectors, and score-level annealing.
---

Local search repeatedly generates candidate moves, scores them, accepts or
rejects them, and commits one accepted candidate. It is the normal improvement
phase after construction.

```toml
[[phases]]
type = "local_search"

[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[phases.forager]
type = "accepted_count"
limit = 4

[phases.move_selector]
type = "change_move_selector"
value_candidate_limit = 32
```

## Acceptor

The acceptor decides whether a scored candidate can be accepted.

| Acceptor | Use |
| -------- | --- |
| `hill_climbing` | accept only improving moves |
| `simulated_annealing` | allow controlled regressions while cooling |
| `tabu_search` | avoid recently visited entities, values, or moves |
| `late_acceptance` | compare against a historical score window |
| `great_deluge` | compare against a decaying score boundary |
| `step_counting_hill_climbing` | hold a boundary for a fixed step interval |
| `diversified_late_acceptance` | late acceptance with diversification pressure |

## Score-Level Simulated Annealing

Simulated annealing supports per-score-level temperatures and hard-regression
policy.

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

`level_temperatures` are ordered from highest-priority score level to
lowest-priority score level. `hard_regression_policy` decides whether hard-score
regressions can be temperature-controlled or are never accepted.

## Forager

The forager decides which accepted candidate is committed.

```toml
[phases.forager]
type = "accepted_count"
limit = 4
```

`accepted_count_limit` and the accepted-count forager retain the best accepted
candidates for final selection. They do not cap candidate generation. Use
`limited_neighborhood` when a selector itself is too broad before scoring.

## Move Selector

Move selection lives under `[phases.move_selector]`.

```toml
[phases.move_selector]
type = "union_move_selector"
selection_order = "round_robin"

[[phases.move_selector.selectors]]
type = "change_move_selector"
value_candidate_limit = 32

[[phases.move_selector.selectors]]
type = "swap_move_selector"
```

For selector details, start with [Moves](/docs/solverforge/solver/moves/).

Coverage repair selectors are regular local-search selectors. Use them when a
model-owned `CoverageGroup` should repair uncovered required nullable slots or
capacity conflicts:

```toml
[phases.move_selector]
type = "coverage_repair_move_selector"
group_name = "required_shift_assignment"
max_moves_per_step = 64
require_hard_improvement = true
```

## Telemetry

Retained status and events preserve exact generated, evaluated, accepted,
not-doable, acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
and construction-slot counters plus generation and evaluation durations.
Displayed `moves/s` is a human-facing derived value.

## See Also

- [Construction](/docs/solverforge/solver/construction/) - creating the first solution
- [Moves](/docs/solverforge/solver/moves/) - selector family guide
- [Termination](/docs/solverforge/solver/termination/) - stopping local search
