---
title: "List Move Selectors"
linkTitle: "List Selectors"
weight: 34
description: >
  Route and sequence selectors for list planning variables.
---

List selectors operate on ordered list planning variables. They are the normal
surface for vehicle routing, machine sequences, visit ordering, task queues,
and other domains where position matters.

## Baseline Route Selectors

For most route or sequence models, start with nearby relocation, nearby swap,
and reverse:

```toml
[phases.move_selector]
type = "union_move_selector"
selection_order = "round_robin"

[[phases.move_selector.selectors]]
type = "nearby_list_change_move_selector"
variable_name = "visits"
max_nearby = 16

[[phases.move_selector.selectors]]
type = "nearby_list_swap_move_selector"
variable_name = "visits"
max_nearby = 16

[[phases.move_selector.selectors]]
type = "list_reverse_move_selector"
variable_name = "visits"
```

## Relocation And Swap

| Selector | Move type | Use |
| -------- | --------- | --- |
| `list_change_move_selector` | `ListChangeMove` | move one list element to another position |
| `nearby_list_change_move_selector` | `ListChangeMove` | distance-pruned relocation |
| `list_swap_move_selector` | `ListSwapMove` | swap two list elements |
| `nearby_list_swap_move_selector` | `ListSwapMove` | distance-pruned swaps |

```toml
[phases.move_selector]
type = "nearby_list_change_move_selector"
variable_name = "visits"
max_nearby = 20
```

Nearby list selectors use list distance meters and stable tie ordering so seeded
local search remains reproducible.

## Sublist Selectors

Sublist selectors move or swap contiguous list segments. They are useful when a
run of adjacent visits or tasks should stay together while moving elsewhere.

| Selector | Move type |
| -------- | --------- |
| `sublist_change_move_selector` | `SublistChangeMove` |
| `sublist_swap_move_selector` | `SublistSwapMove` |

```toml
[phases.move_selector]
type = "sublist_change_move_selector"
variable_name = "visits"
max_sublist_size = 4
```

## Permutation and Precedence

`list_permute_move_selector` permutes a contiguous window within one list. Use
it when small reorderings matter but full k-opt routing semantics are not the
right model.

```toml
[phases.move_selector]
type = "list_permute_move_selector"
variable_name = "operations"
min_window_size = 2
max_window_size = 5
```

`list_precedence_move_selector` is for list variables that expose
`precedence_duration_fn` and `precedence_successors_fn` through
`#[planning_list_variable]`. It generates critical-path, singleton critical-node,
and critical-sublist support moves for precedence makespan models, while normal
list change, swap, reverse, sublist, ruin, and k-opt selectors use the same
precedence graph to reject cycle-forming same-route candidates.

```toml
[phases.move_selector]
type = "list_precedence_move_selector"
entity_class = "Route"
variable_name = "operations"
```

## Route Improvement

### `list_reverse_move_selector`

Reverses a contiguous segment. Use it as the basic 2-opt style improvement for
routes and ordered sequences.

```toml
[phases.move_selector]
type = "list_reverse_move_selector"
variable_name = "visits"
```

### `k_opt_move_selector`

Performs K-opt route reconnection for routing-style list variables.

```toml
[phases.move_selector]
type = "k_opt_move_selector"
variable_name = "visits"
k = 3
```

K-opt improvement uses the route-local hook bundle declared on
`#[planning_list_variable]`. Stock CVRP lists can use `domain = "cvrp"`; that
profile wires strict `solverforge::cvrp::route_hooks` so k-opt rejects candidate
routes that violate stock capacity, time-window feasibility, or reachable-leg
requirements. Stock distance hooks clamp unreachable or extreme route distances
into the solver's scoring domain instead of panicking or overflowing. Custom
route domains can wire `route_hooks` explicitly. That module exports `get`,
`set`, `depot`, `distance`, and `feasible`, and the owner argument is part of
the contract: distance and feasibility should be evaluated in the vehicle,
route, or machine context that will own the candidate route. Clarke-Wright
construction stays on the separate `savings_hooks` module plus optional
`savings_metric_class_fn`, so construction savings can share a metric class
without collapsing route-local assignment semantics.

## List Ruin

`list_ruin_move_selector` removes a bounded number of list elements and
reinserts them. Use it for large-neighborhood search when small route edits are
not enough.

```toml
[phases.move_selector]
type = "list_ruin_move_selector"
variable_name = "visits"
ruin_size = 8
```

The current runtime skips empty owners during list-ruin sampling, so empty
routes or sequences do not consume ruin attempts.

## Move Types

| Move type | Selector family |
| --------- | --------------- |
| `ListChangeMove` | list change and nearby list change |
| `ListSwapMove` | list swap and nearby list swap |
| `ListPermuteMove` | list permute |
| `SublistChangeMove` | sublist change |
| `SublistSwapMove` | sublist swap |
| `ListReverseMove` | list reverse |
| `KOptMove` | K-opt |
| `ListRuinMove` | list ruin |
| `ListMoveUnion` support moves | list precedence |

## See Also

- [List Variables](/docs/solverforge/modeling/list-variables/) - modeling ordered planning variables
- [Composite Move Selectors](/docs/solverforge/solver/composite-move-selectors/) - combining list and scalar neighborhoods
