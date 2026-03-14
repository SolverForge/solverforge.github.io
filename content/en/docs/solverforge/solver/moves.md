---
title: "Moves"
linkTitle: "Moves"
weight: 30
description: >
  Move types, selectors, and the zero-allocation MoveArena.
---

Moves are the atomic operations the solver uses to explore the search space. Each move modifies one or more planning variables and the solver evaluates whether the change improves the score.

## Basic Moves

| Move | Description |
|---|---|
| `ChangeMove` | Changes one planning variable to a different value |
| `SwapMove` | Swaps planning variable values between two entities |
| `CompositeMove` | Applies multiple moves together as one atomic step |

## List Moves

For [list variables](/docs/solverforge/modeling/list-variables/):

| Move | Description |
|---|---|
| `ListChangeMove` | Moves an element to a different position or list |
| `ListSwapMove` | Swaps two elements between or within lists |
| `ListReverseMove` | Reverses a subsequence within a list (2-opt) |
| `SubListChangeMove` | Moves a contiguous subsequence to another position |
| `SubListSwapMove` | Swaps two contiguous subsequences |

## Advanced Moves

| Move | Description |
|---|---|
| `KOptMove` | K-opt style moves — removes K edges and reconnects. Powerful for routing. |
| `RuinMove` | Removes a set of elements and reinserts them (ruin-and-recreate). Escapes deep local optima. |
| `PillarChangeMove` | Changes the same variable on a group of related entities simultaneously |
| `PillarSwapMove` | Swaps variable values between two groups of related entities |

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

For large problems, nearby selection restricts move generation to entities/values that are "close" to each other according to a distance measure. This focuses the search on promising neighborhoods.

```toml
[[solver.phases]]
type = "local_search"
nearby_selection = true
nearby_distance_type = "euclidean"
```

### Pillar Selector

Groups related entities (e.g., all shifts for the same employee) for pillar moves.

### Mimic Selector

Coordinates multiple selectors to use the same selection, ensuring move components are aligned.

## See Also

- [Phases](../phases/) — How moves are used in solver phases
- [List Variables](/docs/solverforge/modeling/list-variables/) — Domain modeling for list moves
