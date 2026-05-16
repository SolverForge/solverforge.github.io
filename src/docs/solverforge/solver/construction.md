---
title: "Construction"
linkTitle: "Construction"
weight: 12
description: >
  Construction heuristic policy, nullable obligations, candidate limits, and
  grouped scalar construction.
---

Construction creates the first workable solution before local search improves
it. A production config usually starts with one construction phase and then
hands the result to local search.

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "preserve_unassigned"
value_candidate_limit = 32
```

## Heuristic Types

| Type | Use |
| ---- | --- |
| `first_fit` | assign the first doable value that improves or preserves the current construction policy |
| `cheapest_insertion` | evaluate bounded candidates and pick the cheapest insertion |
| grouped scalar with `group_name` | cover required nullable scalar slots or apply atomic multi-scalar candidates from a named `ScalarGroup` |
| list-specific constructors | route and sequence initialization where list work is present |

Generic `FirstFit` and `CheapestInsertion` use the canonical construction
engine when matching list work is present. Pure scalar targets use the
descriptor-scalar construction path.

List-specific construction such as Clarke-Wright consumes the owner-aware route
hooks declared on the list variable: `route_get_fn`, `route_set_fn`,
`route_depot_fn`, optional `route_metric_class_fn`, `route_distance_fn`, and
`route_feasible_fn`. These hooks are shared with k-opt route improvement, so
route distance and feasibility stay bound to the owner whose depot, matrix,
capacity, and time-window context scored the route. When a metric-class hook is
present, Clarke-Wright computes savings once per class of owners with identical
depot and route-distance behavior, then keeps feasibility owner-specific.

## Nullable Construction Obligation

Nullable scalar variables default to `preserve_unassigned`: construction may
leave `None` in place when that is legal and scores best.

Use `assign_when_candidate_exists` when construction should assign a doable
value whenever one exists:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
```

This separates Rust nullability from construction policy. A field can be
nullable because later moves may unassign it, while construction can still be
told to fill it whenever a legal value exists.

## Candidate Limits

Scalar construction can use bounded candidates from model hooks or from config:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "cheapest_insertion"
value_candidate_limit = 32
```

`cheapest_insertion` for scalar construction requires one bounded candidate
source: either `candidate_values` on the model or a config candidate limit.

## Construction Order Keys

Scalar construction heuristics that sort entities or values declare those
capabilities on `#[planning_variable]`:

- `construction_entity_order_key = "fn_name"`
- `construction_value_order_key = "fn_name"`

SolverForge re-evaluates construction order hooks on the current working
solution at every construction step. Queue-style and weakest/strongest-fit
heuristics therefore track live model state instead of a phase-start snapshot.

These hooks are construction-only. Local-search scalar change, pillar-change,
and ruin/recreate selectors keep canonical bounded candidate order.

## Assignment-Backed ScalarGroup Construction

Use assignment-backed grouped scalar construction when the model has nullable
scalar assignments where some slots are required, some values share capacity,
and construction should cover every required slot that has a doable candidate.

The solution points the macro at its scalar-group provider, and the model
declares a named assignment-backed `ScalarGroup`:

```rust
#[planning_solution(
    constraints = "define_constraints",
    scalar_groups = "scalar_groups"
)]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}

pub(super) fn scalar_groups() -> Vec<ScalarGroup<Schedule>> {
    vec![
        ScalarGroup::assignment(
            "required_shift_assignment",
            Schedule::shifts().scalar("employee_idx"),
        )
        .with_required_entity(required_shift)
        .with_capacity_key(employee_day_capacity)
        .with_entity_order(shift_order)
        .with_value_order(employee_preference),
    ]
}

fn required_shift(_schedule: &Schedule, _shift_idx: usize) -> bool {
    true
}

fn employee_day_capacity(
    schedule: &Schedule,
    shift_idx: usize,
    employee_idx: usize,
) -> Option<usize> {
    let shift = &schedule.shifts[shift_idx];
    shift
        .date
        .checked_mul(schedule.employees.len())
        .and_then(|base| base.checked_add(employee_idx))
}

fn shift_order(schedule: &Schedule, shift_idx: usize) -> i64 {
    i64::try_from(schedule.shifts[shift_idx].date).unwrap_or(i64::MAX)
}

fn employee_preference(
    schedule: &Schedule,
    shift_idx: usize,
    employee_idx: usize,
) -> i64 {
    let preferred = schedule.shifts[shift_idx].date % schedule.employees.len();
    let distance = (employee_idx + schedule.employees.len() - preferred)
        % schedule.employees.len();
    i64::try_from(distance).unwrap_or(i64::MAX)
}
```

The solver policy selects that group by name. The grouped scalar construction
path owns required-slot assignment; there is no separate coverage-specific
phase type:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
group_name = "required_shift_assignment"
value_candidate_limit = 8
group_candidate_limit = 64
```

Required entities are handled before optional entities. Required assignments
may displace optional occupants or move required blockers through a bounded
augmenting path. Optional assignments remain score-improving only unless the
model marks them required and configuration uses
`assign_when_candidate_exists`.

## Grouped Scalar Construction

Use candidate-backed grouped scalar construction when the legal assignment is a
custom bundle of scalar edits instead of one stock nullable-scalar assignment.

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
group_name = "task_operator_assignment"
value_candidate_limit = 32
group_candidate_limit = 128
```

`group_name` selects a named model-provided `ScalarGroup`.
`group_candidate_limit` caps normalized grouped candidates after SolverForge
removes illegal, duplicate, no-op, and non-frontier edits. Config limits
override model-owned `ScalarGroup::with_limits(...)` values.

## See Also

- [Local Search](/docs/solverforge/solver/local-search/) - improving the constructed solution
- [Scalar Move Selectors](/docs/solverforge/solver/scalar-move-selectors/) - grouped scalar local-search counterpart
