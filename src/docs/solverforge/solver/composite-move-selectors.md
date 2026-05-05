---
title: "Composite Move Selectors"
linkTitle: "Composite Selectors"
weight: 36
description: >
  Move storage, selector composition, limits, and lower-level building blocks.
---

Composite selectors combine or constrain other selectors. Use them when one
selector family is not enough, or when a broad selector needs an explicit cap.

## Move Storage

SolverForge stores generated moves in a `MoveArena` during a selector step.
Selectors expose cursor-scoped candidates so search phases can evaluate borrowed
candidates and materialize ownership only for the selected winner. This is what
keeps cartesian and composite neighborhoods preview-safe without cloning large
move payloads.

## `union_move_selector`

`union_move_selector` combines multiple selectors and yields candidates from
each child selector according to `selection_order`.

```toml
[phases.move_selector]
type = "union_move_selector"
selection_order = "round_robin"

[[phases.move_selector.selectors]]
type = "change_move_selector"
variable_name = "employee_idx"

[[phases.move_selector.selectors]]
type = "swap_move_selector"
variable_name = "employee_idx"
```

Use union when the solver should search several independent neighborhoods in
one local-search phase.

## `cartesian_product_move_selector`

`cartesian_product_move_selector` composes one move from each child selector
into a sequential composite candidate.

```toml
[phases.move_selector]
type = "cartesian_product_move_selector"

[[phases.move_selector.selectors]]
type = "change_move_selector"
variable_name = "employee_idx"

[[phases.move_selector.selectors]]
type = "change_move_selector"
variable_name = "room_idx"
```

Use cartesian composition only when the real move is "do A and B together". Do
not use it as a substitute for grouped scalar search; grouped scalar carries
model-owned coupled-decision semantics.

## `limited_neighborhood`

Use `limited_neighborhood` when a selector is useful but too broad before
scoring.

```toml
[phases.move_selector]
type = "limited_neighborhood"
selected_count_limit = 100

[phases.move_selector.selector]
type = "nearby_change_move_selector"
variable_name = "employee_idx"
max_nearby = 20
```

`selected_count_limit` caps emitted candidates before scoring. It is different
from `accepted_count_limit`, which controls how many accepted candidates the
forager retains for final selection.

## Lower-Level Building Blocks

### Entity Selectors

Entity selectors decide which entities are visited by a move selector. Most app
configs target entities through optional `entity_class` and `variable_name`
fields instead of constructing entity selectors directly.

### Value Selectors

Value selectors provide candidate scalar values. In generated apps, scalar
value neighborhoods come from `#[planning_variable]` hooks such as
`candidate_values`, `nearby_value_candidates`, or a bounded range selected by
config.

### Descriptor Scalar Selectors

Descriptor scalar selectors target variables through model descriptors rather
than hand-written field access. They are the explicit descriptor engine used by
generated scalar runtime paths.

### Selector Decorators

| Decorator | Purpose |
| --------- | ------- |
| `FilteringMoveSelector` | filter borrowable candidates without reopening cartesian children |
| `ShufflingMoveSelector` | randomize selector order |
| `SortingMoveSelector` | sort borrowable candidates |
| `ProbabilityMoveSelector` | probabilistically keep candidates by weight |

## Move Unions

| Move union | Purpose |
| ---------- | ------- |
| `ScalarMoveUnion` | change, swap, pillar, ruin, and related scalar moves |
| `ListMoveUnion` | list change, list swap, reverse, K-opt, and list ruin moves |
| `DescriptorScalarMoveUnion` | descriptor-targeted scalar moves |

## See Also

- [Scalar Move Selectors](/docs/solverforge/solver/scalar-move-selectors/) - scalar assignment and repair selectors
- [List Move Selectors](/docs/solverforge/solver/list-move-selectors/) - route and sequence selectors
