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

The accepted-count forager stops the current selector step after collecting
`limit` accepted candidates, then picks the best candidate inside that finite
horizon. It is the default for broad stock models because it lets streaming
selectors improve incumbents under short budgets. Use `best_score` when you
intentionally want a full-neighborhood greedy scan, and use
`limited_neighborhood` when a selector itself needs a hard pre-scoring cap.

## Move Selector

Move selection lives under `[phases.move_selector]`.

```toml
[phases.move_selector]
type = "union_move_selector"
selection_order = "stratified_random"
weighting = "equal"

[[phases.move_selector.selectors]]
type = "change_move_selector"
value_candidate_limit = 32

[[phases.move_selector.selectors]]
type = "swap_move_selector"
```

For selector details, start with [Moves](/docs/solverforge/solver/moves/).

Union selectors can use `sequential`, `round_robin`,
`rotating_round_robin`, `random`, or `stratified_random` selection order.
`stratified_random` is the default. Union scheduling can weight children
equally, by an explicit fixed vector, or by declared candidate count.

Leaf selectors separately support `original`, seeded `random`, `shuffled`,
`sorted`, and `probabilistic` ordering. Sorted and probabilistic leaves require
a registered named candidate metric. Omitted stock local search uses randomized
leaves; a multi-family default uses a stratified-random union, while a single
family uses sequential union order. The phase's seeded `score_tie_break`
defaults to `random`; choose `first` only when first-equal behavior is part of
the intended policy.

Assignment-backed grouped scalar selectors are regular local-search selectors.
Use them when a model-owned `ScalarGroup::assignment(...)` should repair
uncovered required nullable slots, capacity conflicts, bounded reassignments,
same-sequence run gaps, value-window swaps, block reassignments, optional
occupant releases, or value rotations:

```toml
[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "required_shift_assignment"
max_moves_per_step = 64
require_hard_improvement = true
```

## Telemetry

Retained status and events preserve exact generated, evaluated, accepted,
not-doable, acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
construction-slot, and active-phase counters plus generation and evaluation
durations. `moves_generated` counts candidates actually yielded to the engine;
it does not claim the unrequested tail of a short-circuited cursor.
Per-move-label telemetry reports generated, evaluated, accepted, applied,
not-doable, acceptor-rejected, forager-ignored, score-improving, score-equal,
score-worse, rejected-improving, and applied score-improvement totals. The
bounded applied-move trace records the selected candidate index, per-step
generated/evaluated/accepted/ignored counts, score delta, and hard feasibility
before and after the applied move. Displayed `moves/s` is a human-facing
derived value.

When `[candidate_trace]` is enabled, SolverForge also retains a bounded ordered
prefix of actual pulls with canonical plan/policy/input headers, logical
operation identities, and disposition transitions. Fetch that large diagnostic
payload explicitly with `SolverManager::get_telemetry_detail(...)`; routine
progress events and snapshots intentionally omit it.

## Variable Neighborhood Descent

VND is configured as `local_search_type = "variable_neighborhood_descent"` on a
local-search phase. It uses ordered `neighborhoods` and does not combine with
`acceptor`, `forager`, or `move_selector` in the same phase.

```toml
[[phases]]
type = "local_search"
local_search_type = "variable_neighborhood_descent"

[[phases.neighborhoods]]
type = "change_move_selector"
variable_name = "employee_idx"

[[phases.neighborhoods]]
type = "swap_move_selector"
variable_name = "employee_idx"
```

## See Also

- [Construction](/docs/solverforge/solver/construction/) - creating the first solution
- [Moves](/docs/solverforge/solver/moves/) - selector family guide
- [Termination](/docs/solverforge/solver/termination/) - stopping local search
