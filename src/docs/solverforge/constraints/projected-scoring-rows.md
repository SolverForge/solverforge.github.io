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

## Projection and Join Shapes

| Source shape | API | Emits |
| ------------ | --- | ----- |
| One source row | `.project(NamedProjection)` | Up to `MAX_EMITS` rows per source row |
| One retained joined pair | `.project(|left, right| row)` | Exactly one row per joined pair |
| Two retained projected rows | `.join(equal(...))` or `.join(equal_bi(...))` | Symmetric or directed row pairs |

Single-source projections use a named `Projection<A>` type. Joined-pair
projection uses the existing cross-join `.project(...)` verb with a closure.
Both forms create scoring-only rows; neither form changes the domain model.

## Single-Source Projection

The examples on this page use the
[example model](/docs/solverforge/constraints/#example-model) plus
`src/windows.rs` below (declare it with `mod windows;`), and compile in the
model's `src/examples.rs`.

Use a named projection type when one entity can emit zero, one, or several
bounded scoring rows. `ShiftWindows` emits one row for the part of a shift
before 17:00 and one for the part after:

<!-- rust: crate=schedule file=src/windows.rs -->
```rust
use solverforge::prelude::*;

use crate::domain::Shift;

/// One stretch of a shift. Shifts that run past 17:00 split there, so the
/// overtime part is its own row.
pub struct WorkWindow {
    pub shift_id: usize,
    pub employee_idx: Option<usize>,
    pub date: u32,
    pub start: u32,
    pub end: u32,
}

impl WorkWindow {
    pub fn is_overtime(&self) -> bool {
        self.start >= 17
    }

    pub fn overlaps(&self, other: &WorkWindow) -> bool {
        self.date == other.date && self.start < other.end && other.start < self.end
    }
}

pub struct ShiftWindows;

impl Projection<Shift> for ShiftWindows {
    type Out = WorkWindow;
    const MAX_EMITS: usize = 2;

    fn project<Sink>(&self, shift: &Shift, sink: &mut Sink)
    where
        Sink: ProjectionSink<Self::Out>,
    {
        let window = |start, end| WorkWindow {
            shift_id: shift.id,
            employee_idx: shift.employee_idx,
            date: shift.date,
            start,
            end,
        };
        if shift.start < 17 {
            sink.emit(window(shift.start, shift.end.min(17)));
        }
        if shift.end > 17 {
            sink.emit(window(shift.start.max(17), shift.end));
        }
    }
}
```

Score the overtime rows:

<!-- rust: crate=schedule in=example -->
```rust
use crate::windows::{ShiftWindows, WorkWindow};

Streams::new()
    .for_each(Schedule::shifts())
    .project(ShiftWindows)
    .filter(|window: &WorkWindow| window.is_overtime())
    .penalize(|window: &WorkWindow| HardSoftScore::of_soft(i64::from(window.end - window.start)))
    .named("Projected overtime")
```

`MAX_EMITS` is part of the contract. Avoid returning `Vec` from projection
closures; the scoring layer expects bounded emission through `ProjectionSink`.

## Joined-Pair Projection

Use cross-join projection when the row only exists after two source collections
match.

<!-- rust: crate=schedule in=example -->
```rust
struct ShiftLoad {
    shift_id: usize,
    hours: i64,
    max_hours: i64,
}

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
    .project(|shift: &Shift, employee: &Employee| ShiftLoad {
        shift_id: shift.id,
        hours: shift.hours(),
        max_hours: employee.max_hours,
    })
    .penalize(hard_weight(|row: &ShiftLoad| {
        HardSoftScore::of_hard((row.hours - row.max_hours).max(0))
    }))
    .named("Shift longer than the employee's limit")
```

Joined-pair projected rows are retained by joined coordinates, so localized updates from either side of the join can update the
cached scoring rows without materializing facts. The fluent
`.project(|left, right| row)` shape is unchanged: it creates a projected
`JoinedSource` and continues through the projected stream API. Incremental
notifications across the relational operator trees emit into reused
caller-owned handle buffers. Buffer reuse does not make projected payload
creation or an entire incremental update allocation-free. Do not confuse that
projected terminal with direct pair scoring, which finalizes onto
`OperatorTerminal`.

If the rule only needs an aggregate over joined pairs, use direct cross-join
grouping instead:

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
    .group_by(
        |_shift: &Shift, employee: &Employee| employee.index,
        sum(|(shift, employee): (&Shift, &Employee)| employee.max_hours - shift.hours()),
    )
```

Direct cross-join grouped streams can also continue into `complement(...)` when
the rule needs default rows for target keys with no joined matches. Keep a
joined-pair projection for scoring rows that need their own named retained
shape; use direct grouping and complementing when the aggregate itself is the
row.

## Clone-Free Rows and Keys

Projected outputs, projected self-join keys, and grouped collector values do
not need to implement `Clone`. This matters for
heavy scoring rows whose data should stay owned by the retained scoring state
rather than cloned through hot paths.

## Self-Joins

Projected streams can be filtered, self-joined, merged, grouped, and weighted
like normal scoring state. Use `equal(...)` when both sides use the same key
and each unordered pair should be considered once. `None` keys are equal, so
filter unassigned rows out:

<!-- rust: crate=schedule in=example -->
```rust
use crate::windows::{ShiftWindows, WorkWindow};

Streams::new()
    .for_each(Schedule::shifts())
    .project(ShiftWindows)
    .join(equal(|window: &WorkWindow| window.employee_idx))
    .filter(|a: &WorkWindow, b: &WorkWindow| {
        a.employee_idx.is_some() && a.shift_id != b.shift_id && a.overlaps(b)
    })
    .penalize(hard_weight(|_: &WorkWindow, _: &WorkWindow| {
        HardSoftScore::ONE_HARD
    }))
    .named("Projected overlap")
```

Self-join ordering is coordinate-stable. It follows source ownership and emit
index instead of sparse storage row IDs, so row reuse does not define pair
orientation.

Use `equal_bi(left_key, right_key)` when the projected rows have the same output
type but the relationship is oriented, such as a window that ends where the
same employee's next window starts. The retained scorer evaluates directed
left/right pairs where the left key equals the right key and skips only the
same retained row. Reciprocal rows therefore count as two matches when both
directions satisfy the keys.

<!-- rust: crate=schedule in=example -->
```rust
use crate::windows::{ShiftWindows, WorkWindow};

Streams::new()
    .for_each(Schedule::shifts())
    .project(ShiftWindows)
    .join(equal_bi(
        |left: &WorkWindow| (left.employee_idx, left.date, left.end),
        |right: &WorkWindow| (right.employee_idx, right.date, right.start),
    ))
    .penalize(|_: &WorkWindow, _: &WorkWindow| HardSoftScore::ONE_SOFT)
    .named("Back-to-back windows")
```

Low-level projected self-join filters receive each projected row's primary owner
entity index, not the retained storage row ID. The fluent `.filter(|a, b| ...)`
shape remains unchanged for normal application constraints.

## Group Complements

Projected streams can be grouped and then complemented against a generated
fact or entity source. Use this when the projected rows represent demand,
coverage, or usage and the constraint also needs explicit rows for keys with no
projected matches.

<!-- rust: crate=schedule in=example -->
```rust
use crate::windows::{ShiftWindows, WorkWindow};

Streams::new()
    .for_each(Schedule::shifts())
    .project(ShiftWindows)
    .group_by(
        |window: &WorkWindow| window.employee_idx.unwrap_or(usize::MAX),
        count(),
    )
    .complement(Schedule::employees(), |employee: &Employee| employee.index, |_employee: &Employee| 0usize)
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
