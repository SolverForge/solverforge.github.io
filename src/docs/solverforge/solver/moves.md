---
title: "Moves"
linkTitle: "Moves"
weight: 30
description: >
  Move types, selectors, and the zero-allocation MoveArena.
---

Moves are the atomic operations the solver uses to explore the search space. Each move modifies one or more planning variables and the solver evaluates whether the change improves the score.

## Basic Moves

| Move            | Description                                         |
| --------------- | --------------------------------------------------- |
| `ChangeMove`    | Changes one planning variable to a different value  |
| `SwapMove`      | Swaps planning variable values between two entities |
| `CompositeMove` | Applies multiple moves together as one atomic step  |

## List Moves

For [list variables](/docs/solverforge/modeling/list-variables/):

| Move                | Description                                        |
| ------------------- | -------------------------------------------------- |
| `ListChangeMove`    | Moves an element to a different position or list   |
| `ListSwapMove`      | Swaps two elements between or within lists         |
| `ListReverseMove`   | Reverses a subsequence within a list (2-opt)       |
| `SubListChangeMove` | Moves a contiguous subsequence to another position |
| `SubListSwapMove`   | Swaps two contiguous subsequences                  |

## Advanced Moves

| Move               | Description                                                                                  |
| ------------------ | -------------------------------------------------------------------------------------------- |
| `KOptMove`         | K-opt style moves — removes K edges and reconnects. Powerful for routing.                    |
| `RuinMove`         | Removes a set of elements and reinserts them (ruin-and-recreate). Escapes deep local optima. |
| `PillarChangeMove` | Changes the same variable on a group of related entities simultaneously                      |
| `PillarSwapMove`   | Swaps variable values between two groups of related entities                                 |

## MoveArena (Zero-Allocation)

SolverForge uses a `MoveArena` for move storage — all moves are allocated in an arena that is cleared in O(1) at the end of each step. This eliminates per-move heap allocations and GC pressure.

Moves are stored inline without boxing:

- `ChangeMove<S, V>` and `SwapMove<S, V>` are concrete generic types
- No dynamic dispatch or trait objects for move evaluation
- Arena allocation provides O(1) per-step cleanup

## Selectors

Selectors control which moves are generated and in what order.

### Entity Selector

Controls which entities are considered for moves.

### Value Selector

Controls which values are tried for assignments.

### Move Selector

Controls which moves are generated from selected entities and values.

### Nearby Selection

For large problems, nearby selection restricts move generation to destinations
that are "close" according to a distance measure. In the config-driven runtime,
you enable this by choosing a nearby selector variant.

```toml
[[phases]]
type = "local_search"

[phases.move_selector]
type = "nearby_list_change_move_selector"
max_nearby = 10
variable_name = "visits"
```

Other selector variants include `change_move_selector`, `swap_move_selector`,
`list_change_move_selector`, `list_swap_move_selector`,
`sub_list_change_move_selector`, `sub_list_swap_move_selector`,
`k_opt_move_selector`, `list_ruin_move_selector`, `union_move_selector`, and
`cartesian_product_move_selector`.

`list_ruin_move_selector` now chooses only list owners that currently contain
elements. Empty routes and sequences can still receive elements through later
insertions, but they no longer spend ruin candidate budget on removing nothing.

### Pillar Selector

Groups related entities for pillar-based moves. This is an advanced lower-level
solver concept rather than part of the stock config-driven selector surface.

### Mimic Selector

Coordinates multiple selectors to use the same selection, ensuring move components are aligned.

## See Also

- [Phases](../phases/) — How moves are used in solver phases
- [List Variables](/docs/solverforge/modeling/list-variables/) — Domain modeling for list moves
