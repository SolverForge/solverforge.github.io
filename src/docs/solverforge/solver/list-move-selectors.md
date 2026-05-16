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

Clarke-Wright construction and k-opt improvement use the same owner-aware
route hook family on `#[planning_list_variable]`: `route_get_fn`,
`route_set_fn`, `route_depot_fn`, `route_distance_fn`, and
`route_feasible_fn`. The owner argument is part of the contract; distance and
feasibility should be evaluated in the vehicle, route, or machine context that
will own the candidate route.

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
| `SublistChangeMove` | sublist change |
| `SublistSwapMove` | sublist swap |
| `ListReverseMove` | list reverse |
| `KOptMove` | K-opt |
| `ListRuinMove` | list ruin |

## See Also

- [List Variables](/docs/solverforge/modeling/list-variables/) - modeling ordered planning variables
- [Composite Move Selectors](/docs/solverforge/solver/composite-move-selectors/) - combining list and scalar neighborhoods
