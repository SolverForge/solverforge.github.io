---
title: "Moves"
linkTitle: "Moves"
weight: 30
description: >
  Move types, selectors, and the zero-allocation MoveArena.
---

Moves are the atomic operations the solver uses to explore the search space.
Selectors decide which moves are generated for a phase. Together they form the
solver's reusable search building blocks.

Most application code should choose selectors in `solver.toml`; it should not
construct lower-level move structs directly. Move structs matter when you are
extending SolverForge internals or writing a custom runtime path. Selectors are
the public configuration surface for ordinary apps.

## Start by Problem Shape

| Problem shape                                       | Start with                                                                                         |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| one scalar variable per entity                      | `change_move_selector`, then `swap_move_selector`                                                  |
| scalar assignment with nearby domain knowledge      | `nearby_change_move_selector` or `nearby_swap_move_selector`                                       |
| nullable scalar variables that must change as one   | `grouped_scalar_move_selector` and grouped scalar construction with the same group                 |
| scalar models stuck behind hard conflicts           | `conflict_repair_move_selector` or `compound_conflict_repair_move_selector`                        |
| vehicle routes, machine sequences, or ordered lists | `nearby_list_change_move_selector`, `nearby_list_swap_move_selector`, `list_reverse_move_selector` |
| routing with 2-opt / 3-opt style improvements       | `list_reverse_move_selector`, then `k_opt_move_selector`                                           |
| large-neighborhood search                           | `ruin_recreate_move_selector` for scalar variables or `list_ruin_move_selector` for lists          |
| controlled broad neighborhoods                      | `limited_neighborhood`, `union_move_selector`, or `cartesian_product_move_selector`                |

Most apps should express these selectors in `solver.toml`. Lower-level Rust
selector types are available for custom runtime work, but the config surface is
the normal public path.

All selector `entity_class` and `variable_name` fields are optional target
filters. When omitted, the selector uses every compatible variable. When set,
they match the canonical model descriptor names, not local Rust aliases.

## Selector Recipes

### Scalar assignment baseline

Use change plus swap when each entity has one scalar assignment and no domain
specific nearby hooks yet:

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

### Route or sequence baseline

Use nearby list relocation, nearby list swap, and reverse for ordered variables:

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

### Coupled nullable scalar decisions

Use grouped scalar construction and grouped scalar local search when the legal
decision changes several nullable scalar variables at once:

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

### Conflict-directed hard repair

Use compound conflict repair when score matches can explain the coupled repair
edits:

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

### Controlled broad neighborhoods

Use `limited_neighborhood` when one selector is useful but too broad:

```toml
[phases.move_selector]
type = "limited_neighborhood"
selected_count_limit = 100

[phases.move_selector.selector]
type = "nearby_change_move_selector"
variable_name = "employee_idx"
max_nearby = 20
```

Use `accepted_count_limit` or `[phases.forager]` when the question is how many
accepted candidates survive scoring. Use `limited_neighborhood` when the
question is how many candidates a selector emits before scoring.

## Move Types

### `ChangeMove`

Changes one scalar planning variable on one entity to a candidate value. Use it
for assignment, matching, bin packing, staffing, and other scalar-variable
models where a single entity can be improved independently.

Config selector: `change_move_selector`

### `SwapMove`

Swaps one scalar planning variable between two entities. Use it when preserving
the multiset of assigned values matters, or when pair exchanges are a cheaper
way to repair a scalar schedule than assigning from scratch.

Config selector: `swap_move_selector`

### `PillarChangeMove`

Changes the same scalar variable on a group of related entities. A pillar is a
deterministic group of entities that currently share a compatible value. Use it
when single-entity changes break useful structure but a group reassignment is
meaningful.

Config selector: `pillar_change_move_selector`

### `PillarSwapMove`

Swaps scalar values between two pillars. Use it when groups of entities should
trade assignments together rather than one entity at a time.

Config selector: `pillar_swap_move_selector`

### `RuinMove`

Clears a bounded set of scalar assignments. This is the lower-level scalar ruin
primitive used by scalar large-neighborhood search code. It is not usually the
configured end-user selector by itself.

Related config selector: `ruin_recreate_move_selector`

### `RuinRecreateMove`

Ruins a bounded set of scalar assignments and recreates them with a configured
heuristic. Use it to escape local optima in scalar models where several
assignments need to move together before the score improves.

Config selector: `ruin_recreate_move_selector`

### `CompoundScalarMove`

Applies multiple scalar edits atomically with exact undo, affected-entity
reporting, tabu identity, duplicate filtering, not-doable filtering, and
hard-delta handling. Use it through grouped scalar or conflict-repair selectors
when feasibility depends on coupled scalar changes.

Config selectors: `grouped_scalar_move_selector`,
`compound_conflict_repair_move_selector`

### `ConflictRepairMove`

Wraps a provider-backed compound scalar repair for configured scoring
constraints. Use it when the model can explain how to repair a specific
constraint match without adding fake variables or relaxed hard constraints.

Config selectors: `conflict_repair_move_selector`,
`compound_conflict_repair_move_selector`

### `ListChangeMove`

Moves one list element to a different position in the same list or another
entity's list. Use it for routing stops, production sequences, task queues, and
other ordered list variables where relocation is the baseline operation.

Config selectors: `list_change_move_selector`,
`nearby_list_change_move_selector`

### `ListSwapMove`

Swaps two list elements, either inside one list or across two entities. Use it
when two positions should trade contents without changing total list sizes.

Config selectors: `list_swap_move_selector`, `nearby_list_swap_move_selector`

### `SublistChangeMove`

Moves a contiguous list segment to another position. This is the Or-opt-style
building block for preserving a useful run of adjacent visits or tasks while
placing that run elsewhere.

Config selector: `sublist_change_move_selector`

### `SublistSwapMove`

Swaps two contiguous list segments. Use it when route or sequence quality
depends on moving chunks rather than single elements.

Config selector: `sublist_swap_move_selector`

### `ListReverseMove`

Reverses a contiguous segment inside one list. This is the stock 2-opt-style
move for route crossing removal and sequence reversal.

Config selector: `list_reverse_move_selector`

### `KOptMove`

Cuts and reconnects route segments with configurable `k`. Use it for deeper
route optimization after relocation, swap, and reverse neighborhoods have found
the obvious improvements.

Config selector: `k_opt_move_selector`

### `ListRuinMove`

Removes a bounded set of elements from non-empty list owners so another phase
can reinsert or reshape the sequence. Empty routes and sequences can still
receive elements later, but they do not spend ruin candidate budget on removing
nothing.

Config selector: `list_ruin_move_selector`

### `CompositeMove`

Combines two moves into one typed lower-level move. This is mainly an internal
or advanced Rust extension building block.

Related config selector: `cartesian_product_move_selector`

### `SequentialCompositeMove`

Owns two sequential child moves and caches descriptor, entity, and tabu
metadata. Cartesian composition uses this shape so the solver can preview the
left child, open the right child against the preview state, and materialize only
the selected winning composite.

Config selector: `cartesian_product_move_selector`

### `ScalarMoveUnion`

Carries scalar `ChangeMove`, `SwapMove`, pillar, ruin/recreate,
conflict-repair, grouped compound, and composite moves through one typed scalar
move channel.

Use it when writing lower-level scalar runtime code that needs several scalar
move families in one phase.

### `ListMoveUnion`

Carries list change, list swap, sublist, reverse, K-opt, list ruin, and
composite moves through one typed list move channel.

Use it when writing lower-level list runtime code that combines several list
neighborhoods.

### `DescriptorScalarMoveUnion`

Carries descriptor-addressed scalar change, swap, pillar, ruin/recreate, and
composite moves. The canonical config-driven scalar runtime uses this union so
selector targets can resolve by descriptor index and variable name.

Most apps should configure scalar selectors rather than construct this type
directly.

### Descriptor Scalar Moves

`DescriptorChangeMove`, `DescriptorSwapMove`, `DescriptorPillarChangeMove`,
`DescriptorPillarSwapMove`, and `DescriptorRuinRecreateMove` are the
descriptor-addressed equivalents of the scalar move families above. They are
used by the canonical descriptor-scalar construction and local-search path after
the model support layer resolves runtime hooks onto descriptor-discovered
scalar bindings.

## Move Storage

`MoveArena` stores generated moves inline and clears them in O(1) at the end of
each step. The solver evaluates borrowable move candidates and only takes
ownership of the selected move by stable index. That keeps selector hot paths
cursor-native and avoids per-move heap allocation.

## Configured Move Selectors

### `change_move_selector`

Generates scalar `ChangeMove` candidates. Each candidate changes one entity's
target scalar variable to one candidate value.

Use it for the first scalar local-search neighborhood in assignment, matching,
allocation, and scheduling models.

Key fields:

| Field                   | Default | Meaning                                              |
| ----------------------- | ------- | ---------------------------------------------------- |
| `entity_class`          | `None`  | optional entity descriptor filter                    |
| `variable_name`         | `None`  | optional scalar variable filter                      |
| `value_candidate_limit` | `None`  | cap scalar values generated for each selected entity |

Nearby distance meters do not affect this selector. Candidate discovery comes
from the variable's value range or model-declared `candidate_values` hook.

### `swap_move_selector`

Generates scalar `SwapMove` candidates between pairs of entities for the same
target scalar variable.

Use it when pair exchanges are meaningful and assignments should be traded
between entities instead of drawn from the full value range.

Key fields:

| Field           | Default | Meaning                           |
| --------------- | ------- | --------------------------------- |
| `entity_class`  | `None`  | optional entity descriptor filter |
| `variable_name` | `None`  | optional scalar variable filter   |

### `nearby_change_move_selector`

Generates scalar `ChangeMove` candidates from a model-declared nearby value
candidate hook. The optional distance meter ranks or filters that bounded
candidate set; it does not discover candidates by itself.

Use it for large scalar domains where only nearby values are worth trying, such
as assigning a task to nearby resources or moving a visit to nearby time slots.

Key fields:

| Field                   | Default | Meaning                                            |
| ----------------------- | ------- | -------------------------------------------------- |
| `max_nearby`            | `10`    | maximum nearby values considered per source entity |
| `value_candidate_limit` | `None`  | additional cap on generated scalar values          |
| `entity_class`          | `None`  | optional entity descriptor filter                  |
| `variable_name`         | `None`  | optional scalar variable filter                    |

Requires `nearby_value_candidates` on the matching `#[planning_variable]`.

### `nearby_swap_move_selector`

Generates scalar `SwapMove` candidates from a model-declared nearby entity
candidate hook. The optional distance meter ranks or filters the bounded entity
candidate set.

Use it when a scalar swap should only consider nearby or domain-related
entities.

Key fields:

| Field           | Default | Meaning                                        |
| --------------- | ------- | ---------------------------------------------- |
| `max_nearby`    | `10`    | maximum nearby swap partners per source entity |
| `entity_class`  | `None`  | optional entity descriptor filter              |
| `variable_name` | `None`  | optional scalar variable filter                |

Requires `nearby_entity_candidates` on the matching `#[planning_variable]`.

### `pillar_change_move_selector`

Generates `PillarChangeMove` candidates. It selects deterministic entity groups
for a scalar variable and changes the group to a candidate value.

Use it when entities naturally move in groups and one-by-one changes are too
weak or temporarily infeasible.

Key fields:

| Field                     | Default | Meaning                                       |
| ------------------------- | ------- | --------------------------------------------- |
| `minimum_sub_pillar_size` | `0`     | minimum group size considered by the selector |
| `maximum_sub_pillar_size` | `0`     | maximum group size considered by the selector |
| `value_candidate_limit`   | `None`  | cap scalar values generated for each pillar   |
| `entity_class`            | `None`  | optional entity descriptor filter             |
| `variable_name`           | `None`  | optional scalar variable filter               |

### `pillar_swap_move_selector`

Generates `PillarSwapMove` candidates between two scalar pillars.

Use it when two groups should exchange scalar assignments together, for example
to preserve cohorts or repeated shift blocks.

Key fields:

| Field                     | Default | Meaning                                       |
| ------------------------- | ------- | --------------------------------------------- |
| `minimum_sub_pillar_size` | `0`     | minimum group size considered by the selector |
| `maximum_sub_pillar_size` | `0`     | maximum group size considered by the selector |
| `entity_class`            | `None`  | optional entity descriptor filter             |
| `variable_name`           | `None`  | optional scalar variable filter               |

### `ruin_recreate_move_selector`

Generates scalar `RuinRecreateMove` candidates. Each candidate ruins a bounded
number of scalar assignments and recreates them with `first_fit` or
`cheapest_insertion`.

Use it for scalar large-neighborhood search when several assignments must
change before a better state appears.

Key fields:

| Field                     | Default     | Meaning                                       |
| ------------------------- | ----------- | --------------------------------------------- |
| `min_ruin_count`          | `2`         | minimum scalar assignments ruined per move    |
| `max_ruin_count`          | `5`         | maximum scalar assignments ruined per move    |
| `moves_per_step`          | `None`      | optional cap on ruin/recreate moves generated |
| `value_candidate_limit`   | `None`      | cap values used while recreating assignments  |
| `recreate_heuristic_type` | `first_fit` | `first_fit` or `cheapest_insertion`           |
| `entity_class`            | `None`      | optional entity descriptor filter             |
| `variable_name`           | `None`      | optional scalar variable filter               |

### `grouped_scalar_move_selector`

Generates atomic `CompoundScalarMove` candidates from a named
`ScalarGroupContext`. The model owns the group and candidate provider; the
framework owns legality, duplicate filtering, not-doable filtering, scoring,
hard-delta gating, tabu identity, and affected-entity reporting.

Use it when nullable scalar variables must change together before the model can
reach a hard-feasible state.

Key fields:

| Field                      | Default  | Meaning                                            |
| -------------------------- | -------- | -------------------------------------------------- |
| `group_name`               | required | named model-provided scalar group                  |
| `value_candidate_limit`    | `None`   | provider-defined cap for assignment/value work     |
| `max_moves_per_step`       | `None`   | cap grouped local-search moves per selector step   |
| `require_hard_improvement` | `false`  | require a hard-score improvement before acceptance |

Grouped scalar construction uses the same named group through
`ConstructionHeuristicConfig { group_name }`. Without `group_name`, scalar
construction remains single-slot.

### `list_change_move_selector`

Generates `ListChangeMove` candidates that relocate one element within one list
or between lists.

Use it as the baseline list-variable neighborhood for routing, sequencing,
queues, and ordered assignment models.

Key fields:

| Field           | Default | Meaning                       |
| --------------- | ------- | ----------------------------- |
| `entity_class`  | `None`  | optional list-owner filter    |
| `variable_name` | `None`  | optional list variable filter |

### `nearby_list_change_move_selector`

Generates distance-pruned `ListChangeMove` candidates. Each source element only
considers the nearest destination positions allowed by the list distance meter.

Use it for routing and sequence models where full relocation is too broad.

Key fields:

| Field           | Default | Meaning                                     |
| --------------- | ------- | ------------------------------------------- |
| `max_nearby`    | `10`    | maximum nearby destination positions to try |
| `entity_class`  | `None`  | optional list-owner filter                  |
| `variable_name` | `None`  | optional list variable filter               |

Requires a list/cross-entity distance meter for the target variable.

### `list_swap_move_selector`

Generates `ListSwapMove` candidates that exchange two elements within one list
or between two lists.

Use it when route or sequence quality improves by trading visits, jobs, or
tasks without changing list lengths.

Key fields:

| Field           | Default | Meaning                       |
| --------------- | ------- | ----------------------------- |
| `entity_class`  | `None`  | optional list-owner filter    |
| `variable_name` | `None`  | optional list variable filter |

### `nearby_list_swap_move_selector`

Generates distance-pruned `ListSwapMove` candidates.

Use it when full list swap is too broad but nearby exchange still gives strong
improvements.

Key fields:

| Field           | Default | Meaning                             |
| --------------- | ------- | ----------------------------------- |
| `max_nearby`    | `10`    | maximum nearby swap partners to try |
| `entity_class`  | `None`  | optional list-owner filter          |
| `variable_name` | `None`  | optional list variable filter       |

Requires a list/cross-entity distance meter for the target variable.

### `sublist_change_move_selector`

Generates `SublistChangeMove` candidates that relocate contiguous segments.

Use it for Or-opt style route or sequence repair when useful neighboring
elements should stay adjacent.

Key fields:

| Field              | Default | Meaning                       |
| ------------------ | ------- | ----------------------------- |
| `min_sublist_size` | `1`     | minimum moved segment length  |
| `max_sublist_size` | `3`     | maximum moved segment length  |
| `entity_class`     | `None`  | optional list-owner filter    |
| `variable_name`    | `None`  | optional list variable filter |

### `sublist_swap_move_selector`

Generates `SublistSwapMove` candidates that exchange contiguous segments.

Use it when two route or sequence chunks should trade places while preserving
each chunk internally.

Key fields:

| Field              | Default | Meaning                        |
| ------------------ | ------- | ------------------------------ |
| `min_sublist_size` | `1`     | minimum swapped segment length |
| `max_sublist_size` | `3`     | maximum swapped segment length |
| `entity_class`     | `None`  | optional list-owner filter     |
| `variable_name`    | `None`  | optional list variable filter  |

### `list_reverse_move_selector`

Generates `ListReverseMove` candidates that reverse a segment inside one list.

Use it for 2-opt-style route cleanup and sequence orientation fixes.

Key fields:

| Field           | Default | Meaning                       |
| --------------- | ------- | ----------------------------- |
| `entity_class`  | `None`  | optional list-owner filter    |
| `variable_name` | `None`  | optional list variable filter |

### `k_opt_move_selector`

Generates `KOptMove` candidates for route reconnection. With `max_nearby = 0`,
it enumerates the configured K-opt neighborhood. With `max_nearby > 0`, the
runtime uses distance-pruned nearby K-opt generation.

Use it for advanced route optimization after cheaper list neighborhoods have
done their work.

Key fields:

| Field             | Default | Meaning                                              |
| ----------------- | ------- | ---------------------------------------------------- |
| `k`               | `3`     | number of cuts                                       |
| `min_segment_len` | `1`     | minimum segment length between cuts                  |
| `max_nearby`      | `0`     | nearby positions per cut; `0` means full enumeration |
| `entity_class`    | `None`  | optional list-owner filter                           |
| `variable_name`   | `None`  | optional list variable filter                        |

Nearby K-opt requires the list-position distance meter used by the target
variable.

### `list_ruin_move_selector`

Generates `ListRuinMove` candidates by removing a bounded number of elements
from non-empty list owners.

Use it as the list-variable large-neighborhood-search primitive when local
relocation, swap, reverse, and K-opt neighborhoods are too local.

Key fields:

| Field            | Default | Meaning                                   |
| ---------------- | ------- | ----------------------------------------- |
| `min_ruin_count` | `2`     | minimum elements removed by one move      |
| `max_ruin_count` | `5`     | maximum elements removed by one move      |
| `moves_per_step` | `None`  | optional cap on list ruin moves generated |
| `entity_class`   | `None`  | optional list-owner filter                |
| `variable_name`  | `None`  | optional list variable filter             |

### `limited_neighborhood`

Wraps one child selector and yields only the first `selected_count_limit`
candidates from that child while preserving the child's order.

Use it when one neighborhood is valuable but too broad. This is different from
`accepted_count_limit`, which controls how many accepted candidates the forager
retains after scoring.

Key fields:

| Field                  | Default  | Meaning                          |
| ---------------------- | -------- | -------------------------------- |
| `selected_count_limit` | required | maximum yielded child candidates |
| `selector`             | required | wrapped child selector           |

### `union_move_selector`

Combines multiple child selectors into one neighborhood. `sequential` drains
one child before the next; `round_robin` interleaves children.

Use it when a phase should search several independent neighborhoods together.

Key fields:

| Field             | Default      | Meaning                       |
| ----------------- | ------------ | ----------------------------- |
| `selection_order` | `sequential` | `sequential` or `round_robin` |
| `selectors`       | `[]`         | child selector configs        |

### `cartesian_product_move_selector`

Composes child selectors sequentially. The runtime previews the left child,
opens the right child against that preview state, and materializes only the
selected winning composite.

Use it when a useful move is naturally "do A, then choose B in the state after
A". Do not use it as a substitute for grouped scalar search; grouped scalar
uses a model-owned atomic candidate provider.

Key fields:

| Field                      | Default | Meaning                                            |
| -------------------------- | ------- | -------------------------------------------------- |
| `require_hard_improvement` | `false` | require a hard-score improvement before acceptance |
| `selectors`                | `[]`    | child selectors in preview/application order       |

Left children that require full score evaluation during preview are rejected
up front.

### `conflict_repair_move_selector`

Generates provider-backed `ConflictRepairMove` candidates for configured
scoring constraints. Domain providers suggest scalar repair edits; the
framework handles limits, duplicate filtering, legality, not-doable filtering,
scoring, hard-delta gates, tabu identity, and affected-entity reporting.

Use it when hard constraint matches can point to local scalar repairs.

Key fields:

| Field                      | Default | Meaning                                            |
| -------------------------- | ------- | -------------------------------------------------- |
| `constraints`              | `[]`    | scoring constraint keys to repair                  |
| `max_matches_per_step`     | `16`    | maximum matches inspected per selector step        |
| `max_repairs_per_match`    | `32`    | maximum provider repairs per match                 |
| `max_moves_per_step`       | `256`   | maximum repair moves emitted per selector step     |
| `require_hard_improvement` | `false` | require a hard-score improvement before acceptance |
| `include_soft_matches`     | `false` | allow soft scoring matches to drive repair         |

Configured constraint keys match scoring metadata exactly:
package-qualified constraints use `ConstraintRef::full_name()` strings such as
`package/name`; package-less constraints use the short name.

### `compound_conflict_repair_move_selector`

Generates provider-backed compound scalar repair candidates. It is the
conflict-directed repair selector to reach for when one repair requires several
scalar edits at once.

Use it for coupled hard conflicts where a single scalar edit cannot repair the
match without passing through invalid intermediate states.

Key fields:

| Field                      | Default | Meaning                                            |
| -------------------------- | ------- | -------------------------------------------------- |
| `constraints`              | `[]`    | scoring constraint keys to repair                  |
| `max_matches_per_step`     | `16`    | maximum matches inspected per selector step        |
| `max_repairs_per_match`    | `32`    | maximum provider repairs per match                 |
| `max_moves_per_step`       | `256`   | maximum repair moves emitted per selector step     |
| `require_hard_improvement` | `true`  | require a hard-score improvement before acceptance |
| `include_soft_matches`     | `false` | allow soft scoring matches to drive repair         |

The constraint key rules are the same as `conflict_repair_move_selector`.

## Lower-Level Selector Building Blocks

### Entity Selectors

| Selector                       | Use                                                            |
| ------------------------------ | -------------------------------------------------------------- |
| `FromSolutionEntitySelector`   | iterate entities from one descriptor; can skip pinned entities |
| `AllEntitiesSelector`          | iterate all entities across descriptors                        |
| `NearbyEntitySelector`         | distance-pruned entity selection                               |
| `MimicRecordingEntitySelector` | record selected entities for another selector to replay        |
| `MimicReplayingEntitySelector` | replay recorded entity selections                              |

### Value Selectors

| Selector                      | Use                                                   |
| ----------------------------- | ----------------------------------------------------- |
| `StaticValueSelector`         | use a fixed value list                                |
| `FromSolutionValueSelector`   | extract values from the working solution              |
| `RangeValueSelector`          | generate `0..count` values from solution state        |
| `PerEntityValueSelector`      | generate values from a per-entity callback            |
| `PerEntitySliceValueSelector` | borrow per-entity candidate slices without allocating |

### Runtime Move Selectors

These are the Rust-level selectors behind the config variants.

| Selector                       | Produces             | Use                                       |
| ------------------------------ | -------------------- | ----------------------------------------- |
| `ChangeMoveSelector`           | `ChangeMove`         | scalar value changes                      |
| `SwapMoveSelector`             | `SwapMove`           | scalar value swaps                        |
| `ScalarChangeMoveSelector`     | `ScalarMoveUnion`    | change selector lifted into scalar unions |
| `ScalarSwapMoveSelector`       | `ScalarMoveUnion`    | swap selector lifted into scalar unions   |
| `ListChangeMoveSelector`       | `ListChangeMove`     | list element relocation                   |
| `NearbyListChangeMoveSelector` | `ListChangeMove`     | distance-pruned list relocation           |
| `ListSwapMoveSelector`         | `ListSwapMove`       | list element swaps                        |
| `NearbyListSwapMoveSelector`   | `ListSwapMove`       | distance-pruned list swaps                |
| `SublistChangeMoveSelector`    | `SublistChangeMove`  | contiguous segment relocation             |
| `SublistSwapMoveSelector`      | `SublistSwapMove`    | contiguous segment swaps                  |
| `ListReverseMoveSelector`      | `ListReverseMove`    | segment reversal                          |
| `KOptMoveSelector`             | `KOptMove`           | full K-opt route reconnection             |
| `NearbyKOptMoveSelector`       | `KOptMove`           | distance-pruned K-opt route reconnection  |
| `ListRuinMoveSelector`         | `ListRuinMove`       | list large-neighborhood ruin              |
| `RuinMoveSelector`             | `RuinMove`           | lower-level scalar ruin                   |
| `ConflictRepairSelector`       | `ConflictRepairMove` | provider-backed scalar conflict repair    |

### Descriptor Scalar Selectors

These are the descriptor-addressed scalar selectors used by the stock
config-driven scalar runtime.

| Selector                             | Produces                    | Use                                                |
| ------------------------------------ | --------------------------- | -------------------------------------------------- |
| `DescriptorChangeMoveSelector`       | `DescriptorScalarMoveUnion` | descriptor-targeted scalar changes                 |
| `DescriptorSwapMoveSelector`         | `DescriptorScalarMoveUnion` | descriptor-targeted scalar swaps                   |
| `DescriptorPillarChangeMoveSelector` | `DescriptorScalarMoveUnion` | descriptor-targeted pillar changes                 |
| `DescriptorPillarSwapMoveSelector`   | `DescriptorScalarMoveUnion` | descriptor-targeted pillar swaps                   |
| `DescriptorRuinRecreateMoveSelector` | `DescriptorScalarMoveUnion` | descriptor-targeted scalar ruin/recreate           |
| `DescriptorLeafSelector`             | `DescriptorScalarMoveUnion` | leaf union over descriptor scalar selectors        |
| `DescriptorFlatSelector`             | `DescriptorScalarMoveUnion` | vector union used when no cartesian node is needed |
| `DescriptorSelectorNode`             | `DescriptorScalarMoveUnion` | leaf or cartesian descriptor selector node         |
| `DescriptorSelector`                 | `DescriptorScalarMoveUnion` | top-level descriptor scalar selector               |

Nearby scalar config variants are also implemented in this descriptor path.
They require descriptor-provided nearby candidate hooks, and optional distance
meters only rank or filter those candidates.

### Selector Decorators

| Decorator                  | Use                                                                  |
| -------------------------- | -------------------------------------------------------------------- |
| `UnionMoveSelector`        | combine two selectors sequentially                                   |
| `VecUnionSelector`         | combine a runtime vector of child selectors for config-driven unions |
| `CartesianProductArena`    | lower-level cross-product arena over two move types                  |
| `CartesianProductCursor`   | cursor-backed sequential preview rows with stable pair indexes       |
| `CartesianProductSelector` | compose selectors through preview-state sequential moves             |
| `FilteringMoveSelector`    | filter borrowable candidates without reopening cartesian children    |
| `ShufflingMoveSelector`    | randomize selector order                                             |
| `SortingMoveSelector`      | sort borrowable candidates                                           |
| `ProbabilityMoveSelector`  | probabilistically keep candidates by weight                          |

## See Also

- [Configuration](/docs/solverforge/solver/configuration/) — `solver.toml` examples and phase config
- [Phases](/docs/solverforge/solver/phases/) — How moves are used in solver phases
- [List Variables](/docs/solverforge/modeling/list-variables/) — Domain modeling for list moves
