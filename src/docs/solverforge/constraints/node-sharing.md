---
title: "Constraint Node Sharing"
linkTitle: "Node Sharing"
weight: 11
description: >
  Use solverforge_constraints to share repeated grouped constraint-stream work
  without changing the public fluent authoring model.
---

Constraint node sharing removes duplicate retained scoring work when one
grouped stream feeds several named terminal constraints. It is an optimization
and compiler boundary, not a new modeling API.

## Use the Attribute

Annotate the constraint factory function with `#[solverforge_constraints]`.
Inside the function, keep writing ordinary fluent constraint streams:

```rust
#[solverforge_constraints]
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    let shifts_by_employee = Streams::new()
        .for_each(Schedule::shifts())
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .group_by(
            |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
            count(),
        );

    (
        shifts_by_employee
            .penalize(|_employee_idx: &usize, count: &usize| {
                HardSoftScore::of_soft((*count as i64 - 5).max(0))
            })
            .named("Too many shifts"),
        shifts_by_employee
            .reward(|_employee_idx: &usize, count: &usize| {
                HardSoftScore::of_soft((*count as i64).min(5))
            })
            .named("Assigned shifts"),
    )
}
```

The grouped stream is authored once and finalized twice. The compiler emits one
retained grouped node plus separate terminal scorers. Terminal names, impact
direction, hard/soft metadata, authored order, and score-analysis rows remain
independent.

## What Shares

The 0.15.x compiler shares these grouped families:

| Shape | Example |
| ----- | ------- |
| Grouped unary stream | `for_each(...).group_by(...)` |
| Projected grouped stream | `for_each(...).project(...).group_by(...)` |
| Direct cross grouped stream | `join(...).group_by(|left, right| ..., collector)` |
| Complemented grouped stream | grouped or cross grouped streams followed by `complement(...)` |

Same-binding reuse shares directly. Separate fluent chains share only when the
macro can prove the grouped expression is identical from syntax inside the same
annotated function. Opaque helper calls, unsupported direct complemented forms,
or mixed tuple shapes that cannot be proven stay on the normal Rust path.

## What Does Not Change

- You still finish constraints with `.penalize(...)`, `.reward(...)`, and
  `.named(...)`.
- You still return a typed `ConstraintSet<S, Sc>`, often as a tuple.
- There is no public `share`, `derive`, cache, registry, suffix, or naming API.
- The runtime does not add a global memoization layer.
- Score analysis still reports terminal constraints separately.

## Diagnostics Surface

`SharedNodeDiagnostics`, `SharedNodeId`, and `SharedNodeOperation` are public
diagnostic vocabulary for shared-node reporting. They describe the node kind,
terminal consumers, update count, and changed-key count without exposing the
internal grouped node-state structs as modeling API.

## Boundaries

Use node sharing when a constraint function naturally reuses the same grouped
intermediate result for several named rules. Do not contort simple constraints
into shared shapes. Single terminal constraints should stay as single fluent
chains; the ordinary incremental scorer is already the right path.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/)
- [Collectors](/docs/solverforge/constraints/collectors/)
- [Score Analysis](/docs/solverforge/constraints/score-analysis/)
