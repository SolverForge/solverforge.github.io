---
title: "Scalar Move Selectors"
linkTitle: "Scalar Selectors"
weight: 32
description: >
  Scalar assignment, nearby, pillar, ruin, grouped, coverage, and conflict-repair selectors.
---

Scalar selectors operate on non-list planning variables. They are the right
starting point for assignment, bin packing, staffing, matching, and other
models where an entity owns one or more scalar decision fields.

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
ruin_size = 8
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

## Conflict Repair

## Coverage Repair

Use coverage repair when a nullable scalar target has a named `CoverageGroup`
and local search should repair uncovered required slots or capacity conflicts.
The selector emits compound scalar moves from that coverage model, and can use
the same hard-improvement gate as other compound repair paths.

```toml
[phases.move_selector]
type = "coverage_repair_move_selector"
group_name = "required_shift_assignment"
value_candidate_limit = 8
max_moves_per_step = 64
require_hard_improvement = true
```

Coverage repair pairs naturally with a preceding `coverage_first_fit`
construction phase that selects the same `group_name`.

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
| `RuinMove` / `RuinRecreateMove` | `ruin_recreate_move_selector` |
| `CompoundScalarMove` | grouped scalar, coverage repair, and compound conflict repair |
| `ConflictRepairMove` | conflict-repair selectors |

## See Also

- [List Move Selectors](/docs/solverforge/solver/list-move-selectors/) - selectors for ordered route and sequence variables
- [Composite Move Selectors](/docs/solverforge/solver/composite-move-selectors/) - union, cartesian, and limited neighborhoods
