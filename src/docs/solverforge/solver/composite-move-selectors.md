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
the selected winner by value. This keeps cartesian and union execution
preview-safe without cloning large move payloads.

### Lending Cursor Contract

A public `MoveCursor<S, M>` pulls with `next_candidate(solution: &S)`.
`next_candidate_with_control`, `next_owned_candidate`,
`next_owned_candidate_matching`, and `next_owned_candidate_inspected` likewise
receive the caller's solution. The cursor retains declaration/state and move
ownership, not a solution borrow across evaluation. `candidate(id)` lends a
`MoveCandidateRef`; `take_candidate(id)` transfers that candidate exactly once,
and `release_candidate(id)` drops a loser promptly. Dropping a cursor does not
require exhausting its unrequested tail.

The director-aware pull `next_candidate_with_director(&mut D)` defaults to the
ordinary solution pull; preview-aware cursors and decorators forward it.
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
from `candidate_count`. A zero fixed weight disables its child, which is never
opened and is left out of the union's size; at least one fixed weight must be
positive.

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
solution.

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

Configured selectors cover generated and dynamic models; their entity and value
sources come from the model (`entity_class`, `variable_name`, and
`#[planning_variable]` hooks such as `candidate_values` and
`nearby_value_candidates`), not from separately constructed entity or value
selectors. Leaf ordering is a `selection_order` setting, not a decorator type:
configure random, shuffled, sorted, or probabilistic order on a leaf selector,
and register a metric with `selection_metric` for the sorted and probabilistic
modes.

Custom search writes its own moves and selectors against the traits in
`solverforge::heuristic`: `Move`, `MoveSelector`, `MoveCursor`,
`MoveCandidateRef`, `MoveTabuSignature`, and `SequentialCompositeMoveRef` for
two-move sequences. `solverforge::builder::local_search(...)` turns a selector,
acceptor, and forager into a phase for a `#[planning_solution(search = ...)]`
declaration.

## See Also

- [Scalar Move Selectors](/docs/solverforge/solver/scalar-move-selectors/) - scalar assignment and repair selectors
- [List Move Selectors](/docs/solverforge/solver/list-move-selectors/) - route and sequence selectors
