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
| `coverage_first_fit` | cover required nullable scalar slots from a named `CoverageGroup` |
| list-specific constructors | route and sequence initialization where list work is present |

Generic `FirstFit` and `CheapestInsertion` use the canonical construction
engine when matching list work is present. Pure scalar targets use the
descriptor-scalar construction path.

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

## Coverage-First Construction

Use coverage-first construction when the model has nullable scalar assignments
where some slots are required, some values share capacity, and construction
should cover every required slot that has a doable candidate.

The model declares a named `CoverageGroup`:

```rust
pub(super) fn coverage_groups() -> Vec<CoverageGroup<Schedule>> {
    vec![
        CoverageGroup::new(
            "required_shift_assignment",
            Schedule::shifts().scalar("employee_idx"),
        )
        .with_required_slot(required_shift)
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
    Some(schedule.shifts[shift_idx].date * schedule.employees.len() + employee_idx)
}

fn shift_order(schedule: &Schedule, shift_idx: usize) -> i64 {
    schedule.shifts[shift_idx].date as i64
}

fn employee_preference(
    _schedule: &Schedule,
    _shift_idx: usize,
    employee_idx: usize,
) -> i64 {
    employee_idx as i64
}
```

The solver policy selects that group by name:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "coverage_first_fit"
construction_obligation = "assign_when_candidate_exists"
group_name = "required_shift_assignment"
value_candidate_limit = 8
group_candidate_limit = 64
```

`coverage_first_fit` is different from grouped scalar construction. Coverage
targets one nullable scalar variable and reasons about required slots and
capacity keys. Grouped scalar construction is for arbitrary multi-scalar
candidates that must be applied atomically.

## Grouped Scalar Construction

Use grouped scalar construction when the legal assignment is a bundle of scalar
edits.

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
group_name = "task_operator_assignment"
value_candidate_limit = 32
group_candidate_limit = 128
```

`group_name` selects a named model-provided scalar group. `group_candidate_limit`
caps normalized grouped candidates after SolverForge removes illegal,
duplicate, no-op, and non-frontier edits.

## See Also

- [Local Search](/docs/solverforge/solver/local-search/) - improving the constructed solution
- [Scalar Move Selectors](/docs/solverforge/solver/scalar-move-selectors/) - grouped scalar local-search counterpart
