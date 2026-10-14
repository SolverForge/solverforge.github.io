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

### Lending Cursor Contract

A public `MoveCursor<S, M>` pulls with `next_candidate(solution: &S)`.
`next_candidate_with_control`, `next_owned_candidate`,
`next_owned_candidate_matching`, and `next_owned_candidate_inspected` likewise
receive the caller's solution. The cursor retains declaration/state and move
ownership, not a solution borrow across evaluation. `candidate(id)` lends a
`MoveCandidateRef`; `take_candidate(id)` transfers that candidate exactly once,
and `release_candidate(id)` drops a loser promptly. Dropping a cursor does not
require exhausting its unrequested tail. `CandidateStore::reset()` drops live
candidates while retaining its backing capacities.

The hidden resource-aware runtime boundary lends the mutable score director:
`next_candidate_with_resources(director: &mut D, resources: &mut Resources)`.
The public director-aware pull `next_candidate_with_director(&mut D)` defaults
to the ordinary solution pull; preview-aware cursors and decorators forward it.
Do not retain the lent solution/director between pulls or leave speculative
writes behind when returning a candidate.

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

### Compiled Cartesian Preview

Configured Limited/Union/Cartesian declarations form an immutable indexed arena
with stable node IDs. Retained leaf state moves into the cursor and returns to
the solve-owned state on drop. Union nodes share the canonical scheduler;
flat extensions remain concrete generic types rather than boxed erased leaves.

A Cartesian right child opens only after the left candidate is applied on the
live director. Every right pull reinstates that row's left preview, generates
and checks the right candidate, then undoes the preview and restores the
snapshotted score state before returning. Nested Cartesian rows compose the
same transaction. Compiled Cartesian discovery does not clone a preview
solution. The ordinary public Cartesian selector uses its separately owned
preview director; it is not the compiled implementation.

Sequential candidate evaluation uses
`Move::is_doable_with_working_preview(&mut D)`, so later legs see earlier legs'
effects. A rejected preview leaves the working solution and committed score
state unchanged.

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

Leaf ordering is not a public decorator type. Configure random, shuffled, sorted,
or probabilistic order through `selection_order` on a leaf selector, and register
a metric with `selection_metric` for the sorted and probabilistic modes.

## Move Unions

| Move union | Purpose |
| ---------- | ------- |
| `ScalarMoveUnion` | change, swap, pillar, ruin, and related scalar moves |
| `ListMoveUnion` | list change, list swap, reverse, K-opt, and list ruin moves |
| `DescriptorMoveUnion` | descriptor-targeted moves |

## See Also

- [Scalar Move Selectors](/docs/solverforge/solver/scalar-move-selectors/) - scalar assignment and repair selectors
- [List Move Selectors](/docs/solverforge/solver/list-move-selectors/) - route and sequence selectors
