---
title: "Scalar Move Selectors"
linkTitle: "Scalar Selectors"
weight: 32
description: >
  Scalar assignment, nearby, pillar, ruin, grouped assignment, and conflict-repair selectors.
---

Scalar selectors operate on non-list planning variables. They are the right
starting point for assignment, bin packing, staffing, matching, and other
models where an entity owns one or more scalar decision fields.

The runtime compiler resolves each configured target to an immutable static or
dynamic scalar slot before local search. Dynamic slots declare legal-value and
lazy nearby-source behavior explicitly; a nearby visitor receives a consumption
limit and is not drained past the engine's requested prefix.

Every concrete leaf can preserve `original` order, use seeded `random` or
`shuffled` order, or use a registered named candidate metric for `sorted` /
`probabilistic` order. Omitted stock leaves use seeded random order.

`value_range_provider` defines the legal domain, including per-entity
`Vec<usize>` domains. `candidate_values` only bounds and orders construction,
change, pillar-change, and ruin-recreate candidates. Swap, nearby-swap, and
pillar-swap families exchange current values and check the receiving domains,
not `candidate_values`. See [Planning Entities](/docs/solverforge/modeling/planning-entities/).

## Baseline Selectors

### `change_move_selector`

Changes one scalar planning variable on one entity to a candidate value.

```toml
[phases.move_selector]
type = "change_move_selector"
variable_name = "employee_idx"
value_candidate_limit = 32
```

Use `value_candidate_limit` when the model exposes a large value range and the
selector should retain a bounded candidate set.

### `swap_move_selector`

Swaps one scalar planning variable between two entities. Use it when preserving
the multiset of assigned values matters or pair exchanges repair a schedule
more cheaply than assigning from scratch.

```toml
[phases.move_selector]
type = "swap_move_selector"
variable_name = "employee_idx"
```

## Guided Enumeration and Lazy Rows

`search_entity_order_key` on `#[planning_variable]` ranks ordinary change and
swap entity traversal; `search_value_order_key` ranks ordinary change values.
Lower keys are tried first and equal keys retain the seeded candidate order.
These are model hooks, not extra TOML selector fields, and do not replace a
leaf's configured `selection_order` or `selection_metric`.

Ordinary change loads a candidate-value row only when traversal reaches that
entity. Nearby change and swap also load only reached rows for both native and
dynamic models. Sequential early forager exit therefore need not call the remaining row
providers. An explicitly supplied empty nearby row remains empty; it is not
replaced with the full range. Ordinary native swap retains its open-time
current-value and legal-row snapshot; lending the live solution does not turn
that into a per-pull rebuild. Parallel evaluation can speculatively reach
providers beyond the eventual forager decision; see
[Local Search](/docs/solverforge/solver/local-search/#parallel-candidate-evaluation).

## Nearby Scalar Selectors

Nearby scalar selectors require model-declared candidate hooks on the matching
`#[planning_variable]`: `nearby_value_candidates` for change moves and
`nearby_entity_candidates` for swap moves. Distance meters rank or filter those
bounded candidates; they do not discover candidates by themselves.

### `nearby_change_move_selector`

```toml
[phases.move_selector]
type = "nearby_change_move_selector"
variable_name = "employee_idx"
max_nearby = 20
```

### `nearby_swap_move_selector`

```toml
[phases.move_selector]
type = "nearby_swap_move_selector"
variable_name = "employee_idx"
max_nearby = 20
```

## Pillar Selectors

Pillar selectors operate on deterministic groups of entities that currently
share a compatible value.

| Selector | Use |
| -------- | --- |
| `pillar_change_move_selector` | reassign a whole group to one candidate value |
| `pillar_swap_move_selector` | swap scalar values between two pillars |

```toml
[phases.move_selector]
type = "pillar_change_move_selector"
variable_name = "team_idx"
value_candidate_limit = 16
```

## Ruin/Recreate

`ruin_recreate_move_selector` clears a bounded set of scalar assignments and
recreates them with a configured value source. Use it to escape local optima in
scalar models where several assignments need to move together before the score
improves.

```toml
[phases.move_selector]
type = "ruin_recreate_move_selector"
variable_name = "employee_idx"
min_ruin_count = 2
max_ruin_count = 8
value_candidate_limit = 32
```

## Grouped Scalar

Use grouped scalar selectors when the legal decision changes several nullable
scalar variables at once. The model provides a named scalar group; construction
and local search both select that group by name.

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
group_name = "task_operator_assignment"
value_candidate_limit = 32
group_candidate_limit = 128

[[phases]]
type = "local_search"

[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "task_operator_assignment"
max_moves_per_step = 256
require_hard_improvement = true
```

The underlying `CompoundScalarMove` applies multiple scalar edits atomically
with exact undo, affected-entity reporting, tabu identity, duplicate filtering,
not-doable filtering, and hard-delta handling.

Assignment-backed groups use the same selector. If the group was declared with
`ScalarGroup::assignment(...)`, the selector emits compound assignment moves
for unassigned required entities, capacity conflicts, bounded reassignments,
and bounded sequence or position rematches.

Use assignment-backed grouped repair when a nullable scalar target has a named
`ScalarGroup::assignment(...)` and local search should repair uncovered
required slots or capacity conflicts.

```toml
[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "required_shift_assignment"
value_candidate_limit = 8
max_moves_per_step = 64
require_hard_improvement = true
```

Assignment-backed grouped repair pairs naturally with a preceding grouped
construction phase that selects the same `group_name`. Assignment-owned slots
stay on this path: plain scalar and generic conflict-repair selectors do not
edit them. This is a configured `grouped_scalar_move_selector`, not a public
`GroupedScalarMoveSelector` type to import from the facade.

The assignment's `max_augmenting_depth` and `max_rematch_size` come from
model-owned `ScalarGroup::with_limits(...)`: defaults are 3 and 4 respectively,
with rematch size clamped to at least 2. They are separate from the configured
`value_candidate_limit` and `max_moves_per_step`; see
[Assignment Limits](/docs/solverforge/solver/construction/#assignment-limits).
Construction completion does not remove assigned occupants from required
augmenting rematches or prevent later local-search assignment adjustments.

### Legality, Enumeration Pressure, and Score

Assignment-backed families enforce structural and declared assignment legality:
value domains, distinct edit targets, required rows retained in the final
assignment, capacity keys, and sequence-edge rules. Compound edits are checked
as one final assignment, so a simultaneous swap can vacate both capacity slots
without an intermediate false conflict. Trial overlays restore the committed
assignment index before another candidate is generated.

Enumeration pressure steers which legal candidates are tried first; it is not
an extra score or a requirement that every move improve a surrogate run/load
measure. The score director, configured acceptor, and forager decide between
legal candidates. `require_hard_improvement = true` explicitly adds a strict
hard-score improvement gate; omit it when the acceptor should be free to accept
legal equal-score or worsening exploration moves.

Assignment families share the per-step move cap through interleaved family
pulls rather than allowing one broad family to consume the whole prefix.
Scarcity guides required assignments; current run/load pressure guides
reassignment roots and target sequence/load pressure guides candidate values.
Value-pair and oriented-triple coordinates are lazy, not an eagerly allocated
Cartesian product. Exact duplicate edit sets are removed independent of edit
order.

Config `max_moves_per_step` overrides the model limit. With neither specified,
assignment-backed groups use the entity count multiplied by the effective
rematch size, clamped to 256–4096; candidate-backed groups use 256. The default
rematch size is 4 and its minimum is 2. These generation limits are separate
from the accepted-count forager's horizon.

## Conflict Repair

Conflict-repair selectors build repair candidates from configured scoring
matches. Use them when the model can explain how to repair a specific
constraint match without fake variables or relaxed hard constraints.

```toml
[phases.move_selector]
type = "compound_conflict_repair_move_selector"
constraints = ["schedule/no_overlapping_operator_assignment"]
max_matches_per_step = 16
max_repairs_per_match = 32
max_moves_per_step = 256
require_hard_improvement = true
```

Available selectors:

| Selector | Use |
| -------- | --- |
| `conflict_repair_move_selector` | expose provider-backed conflict repair candidates |
| `compound_conflict_repair_move_selector` | emit compound scalar repairs from configured constraint matches |

Constraint keys match exact scoring metadata. Use
`ConstraintRef::full_name()` for package-qualified constraints and the short
name for package-less constraints.

## Move Types

| Move type | Selector family |
| --------- | --------------- |
| `ChangeMove` | `change_move_selector`, `nearby_change_move_selector` |
| `SwapMove` | `swap_move_selector`, `nearby_swap_move_selector` |
| `PillarChangeMove` | `pillar_change_move_selector` |
| `PillarSwapMove` | `pillar_swap_move_selector` |
| `RuinRecreateMove` | `ruin_recreate_move_selector` |
| `CompoundScalarMove` | grouped scalar assignment and compound conflict repair |
| `ConflictRepairMove` | conflict-repair selectors |

## See Also

- [List Move Selectors](/docs/solverforge/solver/list-move-selectors/) - selectors for ordered route and sequence variables
- [Composite Move Selectors](/docs/solverforge/solver/composite-move-selectors/) - union, cartesian, and limited neighborhoods
