---
title: "Composite Move Selectors"
linkTitle: "Composite Selectors"
weight: 36
description: >
  Candidate ownership, selector composition, limits, and lower-level building blocks.
---

Composite selectors combine or constrain other selectors. Use them when one
selector family is not enough, or when a broad selector needs an explicit cap.

## Candidate Ownership

Selectors expose cursor-scoped candidates with stable candidate IDs. Search
phases evaluate borrowed candidates, release losers promptly, and transfer only
the selected winner by value. `MoveArena` remains a reusable-capacity owner for
the concrete APIs and composite storage that need it; it is not the universal
runtime owner for every selector step. This keeps cartesian and union execution
preview-safe without cloning large move payloads.

## `union_move_selector`

`union_move_selector` combines multiple selectors and yields candidates from
each child selector according to `selection_order`.

```toml
[phases.move_selector]
type = "union_move_selector"
selection_order = "stratified_random"
weighting = "equal"

[[phases.move_selector.selectors]]
type = "change_move_selector"
variable_name = "employee_idx"

[[phases.move_selector.selectors]]
type = "swap_move_selector"
variable_name = "employee_idx"
```

Use union when the solver should search several independent neighborhoods in
one local-search phase. Available union orders are `sequential`, `round_robin`,
`rotating_round_robin`, `random`, and the default `stratified_random`. Child
weights can be `equal`, `fixed` through a parallel `weights` vector, or derived
from `candidate_count`.

Union scheduling and leaf candidate ordering are separate policies. Each leaf
can preserve `original` order, use seeded `random` or `shuffled` order, or use a
registered `selection_metric` for `sorted` / `probabilistic` ordering. The
runtime compiler resolves and freezes both layers before the phase starts.

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
from the accepted-count forager `limit`, which stops a selector step after that
many accepted candidates and then picks the best candidate inside that finite
horizon.

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
than hand-written field access. They remain a standalone opt-in selector API.
Generated and dynamic configured solves use the immutable runtime compiler;
descriptor selectors do not create a second construction or configured-search
engine.

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
