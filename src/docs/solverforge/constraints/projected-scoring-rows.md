---
title: "Projected Scoring Rows"
linkTitle: "Projected Scoring Rows"
weight: 12
description: >
  Retained scoring-only rows from single-source projections and joined pairs.
---

Projected scoring rows let a constraint express an intermediate shape without
adding planning entities, problem facts, value ranges, or move-selector targets.
They are retained inside the scoring layer and update incrementally as source
entities change.

## Two Projection Shapes

| Source shape | API | Emits |
| ------------ | --- | ----- |
| One source row | `.project(NamedProjection)` | Up to `MAX_EMITS` rows per source row |
| One retained joined pair | `.project(|left, right| row)` | Exactly one row per joined pair |

Single-source projections use a named `Projection<A>` type. Joined-pair
projection uses the existing cross-join `.project(...)` verb with a closure.
Both forms create scoring-only rows; neither form changes the domain model.

## Single-Source Projection

Use a named projection type when one entity can emit zero, one, or several
bounded scoring rows.

```rust
use solverforge::{Projection, ProjectionSink};

struct ShiftWindows;

impl Projection<Shift> for ShiftWindows {
    type Out = WorkWindow;
    const MAX_EMITS: usize = 2;

    fn project<Sink>(&self, shift: &Shift, sink: &mut Sink)
    where
        Sink: ProjectionSink<Self::Out>,
    {
        sink.emit(WorkWindow::primary(shift));
        if let Some(secondary) = WorkWindow::secondary(shift) {
            sink.emit(secondary);
        }
    }
}

factory.for_each(Schedule::shifts())
    .project(ShiftWindows)
    .filter(|window: &WorkWindow| window.is_overtime())
    .penalize(|_: &WorkWindow| HardSoftScore::ONE_SOFT)
    .named("Projected overtime");
```

`MAX_EMITS` is part of the contract. Avoid returning `Vec` from projection
closures; the scoring layer expects bounded emission through `ProjectionSink`.

## Joined-Pair Projection

Use cross-join projection when the row only exists after two source collections
match.

```rust
struct AssignmentCapacity {
    assignment_id: usize,
    demand: i64,
    capacity: i64,
}

type Streams = ConstraintFactory<Plan, HardSoftScore>;

Streams::new()
    .for_each(Plan::assignments())
    .join((
        Streams::new().for_each(Plan::capacities()),
        equal_bi(
            |assignment: &Assignment| assignment.bucket,
            |capacity: &Capacity| capacity.bucket,
        ),
    ))
    .project(|assignment: &Assignment, capacity: &Capacity| AssignmentCapacity {
        assignment_id: assignment.id,
        demand: assignment.demand,
        capacity: capacity.amount,
    })
    .penalize(hard_weight(|row: &AssignmentCapacity| {
        HardSoftScore::of_hard((row.demand - row.capacity).max(0))
    }))
    .named("Assignment capacity shortage");
```

Since the `0.11.x` release line, joined-pair projected rows are retained by joined
coordinates, so localized updates from either side of the join can update the
cached scoring rows without materializing facts.

If the rule only needs an aggregate over joined pairs, use direct cross-join
grouping instead:

```rust
Streams::new()
    .for_each(Plan::assignments())
    .join((
        Streams::new().for_each(Plan::capacities()),
        equal_bi(
            |assignment: &Assignment| assignment.capacity_id,
            |capacity: &Capacity| Some(capacity.id),
        ),
    ))
    .group_by(
        |assignment: &Assignment, capacity: &Capacity| assignment.bucket,
        sum(|(assignment, capacity): (&Assignment, &Capacity)| {
            capacity.amount - assignment.demand
        }),
    )
```

Direct cross-join grouped streams can also continue into `complement(...)` when
the rule needs default rows for target keys with no joined matches. Keep a
joined-pair projection for scoring rows that need their own named retained
shape; use direct grouping and complementing when the aggregate itself is the
row.

## Clone-Free Rows and Keys

Projected outputs, projected self-join keys, and grouped collector values no
longer need to implement `Clone` since the `0.11.x` release line. This matters for
heavy scoring rows whose data should stay owned by the retained scoring state
rather than cloned through hot paths.

## Self-Joins

Projected streams can be filtered, self-joined, merged, grouped, and weighted
like normal scoring state.

```rust
factory.for_each(Schedule::shifts())
    .project(ShiftWindows)
    .join(equal(|window: &WorkWindow| window.employee_id))
    .filter(|a: &WorkWindow, b: &WorkWindow| {
        a.shift_id != b.shift_id && a.overlaps(b)
    })
    .penalize(hard_weight(|_: &WorkWindow, _: &WorkWindow| {
        HardSoftScore::ONE_HARD
    }))
    .named("Projected overlap");
```

Self-join ordering is coordinate-stable. It follows source ownership and emit
index instead of sparse storage row IDs, so row reuse does not define pair
orientation.

Low-level projected self-join filters receive each projected row's primary owner
entity index, not the retained storage row ID. The fluent `.filter(|a, b| ...)`
shape remains unchanged for normal application constraints.

## Group Complements

Projected streams can be grouped and then complemented against a generated
fact or entity source. Use this when the projected rows represent demand,
coverage, or usage and the constraint also needs explicit rows for keys with no
projected matches.

```rust
factory.for_each(Schedule::shifts())
    .project(ShiftWindows)
    .group_by(
        |window: &WorkWindow| window.employee_id.unwrap_or(usize::MAX),
        count(),
    )
    .complement(Schedule::employees(), |employee: &Employee| employee.index, |_employee| 0usize)
    .penalize(|_employee_idx: &usize, count: &usize| {
        HardSoftScore::of_soft((*count as i64 - 4).abs())
    })
    .named("Projected workload balance")
```

## Boundaries

Projected rows are not:

- planning entities
- problem facts
- scalar or list value ranges
- construction targets
- move-selector targets

If a value must be assigned by the solver, model it as a planning variable. Use
projected rows when the value only exists to explain or score source entities.

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) - stream operations and terminal scoring methods
- [Score Analysis](/docs/solverforge/constraints/score-analysis/) - explaining score contributions
