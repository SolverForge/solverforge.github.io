---
title: "Moves"
linkTitle: "Moves"
weight: 30
description: >
  Move-selector families and where to start for each planning shape.
---

Moves are the atomic operations the solver uses to explore the search space.
Selectors decide which moves are generated for a phase. Most applications
choose selectors in `solver.toml`; lower-level move structs matter mainly when
extending SolverForge internals or writing a custom runtime path.

## Start by Problem Shape

| Problem shape | Start with |
| ------------- | ---------- |
| one scalar variable per entity | `change_move_selector`, then `swap_move_selector` |
| scalar assignment with nearby domain knowledge | `nearby_change_move_selector` or `nearby_swap_move_selector` |
| nullable scalar variables that must change as one | `grouped_scalar_move_selector` and grouped scalar construction with the same group |
| required nullable scalar coverage | grouped scalar construction, then `grouped_scalar_move_selector` with the same assignment-backed group |
| scalar models stuck behind hard conflicts | `conflict_repair_move_selector` or `compound_conflict_repair_move_selector` |
| vehicle routes, machine sequences, or ordered lists | `nearby_list_change_move_selector`, `nearby_list_swap_move_selector`, `list_reverse_move_selector` |
| routing with 2-opt / 3-opt style improvements | `list_reverse_move_selector`, then `k_opt_move_selector` |
| large-neighborhood search | `ruin_recreate_move_selector` for scalar variables or `list_ruin_move_selector` for lists |
| controlled broad neighborhoods | `limited_neighborhood`, `union_move_selector`, or `cartesian_product_move_selector` |

All selector `entity_class` and `variable_name` fields are optional target
filters. When omitted, the selector uses every compatible variable. When set,
they match canonical model descriptor names, not local Rust aliases.

## Selector Families

<div class="card-grid">
  <%= render Ui::Card.new(title: "Scalar Selectors", href: relative_url('/docs/solverforge/solver/scalar-move-selectors/'), icon: "fa-solid fa-list-check") do %>
Assignment, swap, nearby, pillar, ruin/recreate, grouped scalar assignment, and conflict repair selectors.
  <% end %>
  <%= render Ui::Card.new(title: "List Selectors", href: relative_url('/docs/solverforge/solver/list-move-selectors/'), icon: "fa-solid fa-route") do %>
Route and sequence selectors: list change, list swap, sublist, reverse, K-opt, and list ruin.
  <% end %>
  <%= render Ui::Card.new(title: "Composite Selectors", href: relative_url('/docs/solverforge/solver/composite-move-selectors/'), icon: "fa-solid fa-layer-group") do %>
Move storage, union, cartesian, limited neighborhoods, and lower-level building blocks.
  <% end %>
</div>

## Common Recipes

### Scalar Assignment Baseline

```toml
[phases.move_selector]
type = "union_move_selector"
selection_order = "round_robin"

[[phases.move_selector.selectors]]
type = "change_move_selector"
variable_name = "employee_idx"
value_candidate_limit = 32

[[phases.move_selector.selectors]]
type = "swap_move_selector"
variable_name = "employee_idx"
```

### Route Or Sequence Baseline

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

### Coupled Nullable Scalar Decisions

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
group_name = "task_operator_assignment"
group_candidate_limit = 128

[[phases]]
type = "local_search"

[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "task_operator_assignment"
max_moves_per_step = 256
require_hard_improvement = true
```

### Conflict-Directed Hard Repair

### Required Assignment Repair

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
group_name = "required_shift_assignment"
group_candidate_limit = 64

[[phases]]
type = "local_search"

[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "required_shift_assignment"
max_moves_per_step = 64
require_hard_improvement = true
```

### Conflict-Directed Hard Repair

```toml
[phases.move_selector]
type = "compound_conflict_repair_move_selector"
constraints = ["schedule/no_overlapping_operator_assignment"]
max_matches_per_step = 16
max_repairs_per_match = 32
max_moves_per_step = 256
require_hard_improvement = true
```

Constraint keys match scoring metadata exactly. Package-qualified constraints
use `ConstraintRef::full_name()` values such as `package/name`; package-less
constraints use the short name.

## See Also

- [Configuration](/docs/solverforge/solver/configuration/) - how selectors appear in `solver.toml`
- [Local Search](/docs/solverforge/solver/local-search/) - acceptors, foragers, and selector placement
- [Phases](/docs/solverforge/solver/phases/) - phase sequence and phase types
