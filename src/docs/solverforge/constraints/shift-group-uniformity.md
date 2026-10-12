---
title: "Shift-Group Uniformity"
linkTitle: "Shift-Group Uniformity"
weight: 35
description: >
  A worked example that keeps employees on the same shift or work block in
  one shift group, with a medium penalty for mixed groups.
---

# Shift-Group Uniformity

Employees assigned to the same time/location block should belong to the same
shift group. A block that mixes groups takes a medium penalty — a preference
the solver trades against other medium constraints, not a hard limit. The
penalty is the number of **distinct** shift groups minus one, floored at zero:

| Groups in one block | Distinct − 1 | Penalty |
| ------------------- | ------------ | ------- |
| `[1, 1]`            | 0            | 0       |
| `[1, 2]`            | 1            | 1 medium |
| `[1, 2, 3]`         | 2            | 2 medium |

Counting distinct values is the point: `[1, 2]` and `[3, 4]` are both one
mixed group, regardless of which group numbers appear.

## The pipeline

The rule has five steps:

1. **Join** each assignment to the information the rule needs: its shift
   (for the block and the identity of the group) and its employee (for the
   employee's shift-group value).
2. **Group** the rows by the shift, or by the work block the shift belongs
   to.
3. **Collect** the shift-group values inside each bucket.
4. **Count** the distinct collected values per bucket.
5. **Apply** the medium penalty: distinct groups minus one, floored at zero.

Steps 1–3 produce grouped rows; step 4–5 score them. Two closures see
different shapes: the **collector** closure receives the stream's actual
match row (here, the full joined row), while the **terminal** weight closure
receives the grouped result — the bucket key and the collected values.

## The wrong grouping key

Grouping by the employee or by `shift_group` **itself** separates the values
that must be compared. If each row lands in its own bucket, the collected
values inside a bucket are trivially identical, every bucket counts one
distinct group, and the penalty is zero even when the shift is genuinely
mixed. The key must name the *bucket* employees are compared within — the
shift or the block — and the collector must read the value being compared —
the shift group.

## The model

```rust
#[derive(Clone, Debug)]
struct Shift { index: usize, start: i64, end: i64, location: String }

#[derive(Clone, Debug)]
struct ShiftAssignment { shift_id: usize, employee_idx: Option<usize> }

#[derive(Clone, Debug)]
struct Employee { index: usize, shift_group: i32 }

#[derive(Clone, Debug)]
struct Schedule { shifts: Vec<Shift>, assignments: Vec<ShiftAssignment>, employees: Vec<Employee> }

fn shifts(s: &Schedule) -> &[Shift] { &s.shifts }
fn assignments(s: &Schedule) -> &[ShiftAssignment] { &s.assignments }
fn employees(s: &Schedule) -> &[Employee] { &s.employees }
```

`employee_idx` is `Option<usize>`: unassigned rows must leave the stream
**before** key extraction, or a `None` assignment panics when a key closure
reads it. The example filters them out at the collection boundary.

## Authoring path

The two cases need a join chain of three sources grouped by the shift or the
block. Unary `.group_by(...)` groups a single collection and cross-bi
`.group_by(...)` groups joined pairs; there is no fluent `group_by` on a
`Tri` stream, so the rule is authored with the documented low-level operator
tree — the same `FilterNode` → `JoinNode` → `GroupNode` → `OperatorTerminal`
composition the [tagged scoring guide](https://github.com/SolverForge/solverforge/blob/v0.20.1/docs/extend-scoring.md)
and [Extend the Domain](/reference/extend-domain/) record. This
is deliberate: do not reach for a `Tri::group_by` method; it does not exist
in 0.20.1.

One shared chain serves both cases — the grouping key is the only part that
changes:

```rust
use solverforge::stream::joiner::{equal_bi, equal_on};
use solverforge::stream::relational::operator::{
    CollectionNode, FilterNode, GroupNode, GroupView, JoinNode, Pair,
};
use solverforge::stream::relational::Leaf;
use solverforge::HardMediumSoftScore;
use solverforge_scoring::api::constraint_set::IncrementalConstraint;
use solverforge_scoring::constraint::relational::OperatorTerminal;
use solverforge_scoring::stream::collection_extract::{source, ChangeSource};

#[derive(Clone, Debug)]
struct Shift { index: usize, start: i64, end: i64, location: String }

#[derive(Clone, Debug)]
struct ShiftAssignment { shift_id: usize, employee_idx: Option<usize> }

#[derive(Clone, Debug)]
struct Employee { index: usize, shift_group: i32 }

#[derive(Clone, Debug)]
struct Schedule { shifts: Vec<Shift>, assignments: Vec<ShiftAssignment>, employees: Vec<Employee> }

fn shifts(s: &Schedule) -> &[Shift] { &s.shifts }
fn assignments(s: &Schedule) -> &[ShiftAssignment] { &s.assignments }
fn employees(s: &Schedule) -> &[Employee] { &s.employees }

/* Row shapes, in binding order:
   (assignment, shift)             = Pair<Leaf<ShiftAssignment>, Leaf<Shift>>
   ((assignment, shift), employee) = Pair of that pair with Leaf<Employee>  */
type Row<'a> =
    Pair<Pair<Leaf<'a, ShiftAssignment>, Leaf<'a, Shift>>, Leaf<'a, Employee>>;

fn assignment_key(l: &Leaf<'_, ShiftAssignment>) -> usize { l.entity.shift_id }
fn shift_id_key(r: &Leaf<'_, Shift>) -> usize { r.entity.index }
fn employee_key(l: &Leaf<'_, Employee>) -> usize { l.entity.index }
fn row_employee_code(row: &Pair<Leaf<'_, ShiftAssignment>, Leaf<'_, Shift>>) -> usize {
    row.left.entity.employee_idx.unwrap()
}

fn assigned_only(_s: &Schedule, l: &Leaf<'_, ShiftAssignment>) -> bool {
    l.entity.employee_idx.is_some()
}

/* (assignment, shift): assignment.shift_id == shift.index, with unassigned
   assignments filtered out before the equality keys run. */
type SourceE =
    solverforge_scoring::stream::collection_extract::SourceExtract<fn(&Schedule) -> &[ShiftAssignment]>;
type SourceS =
    solverforge_scoring::stream::collection_extract::SourceExtract<fn(&Schedule) -> &[Shift]>;
type PairJoiner = solverforge::stream::joiner::EqualJoiner<
    for<'a, 'b> fn(&'a Leaf<'b, ShiftAssignment>) -> usize,
    for<'a, 'b> fn(&'a Leaf<'b, Shift>) -> usize,
    usize,
    solverforge::stream::joiner::Directed,
>;
type PairTree = JoinNode<
    Schedule,
    FilterNode<
        CollectionNode<Schedule, SourceE>,
        fn(&Schedule, &Leaf<'_, ShiftAssignment>) -> bool,
    >,
    CollectionNode<Schedule, SourceS>,
    PairJoiner,
>;

fn joined_pair_tree() -> PairTree {
    let a = CollectionNode::new(
        source(assignments as fn(&Schedule) -> &[ShiftAssignment], ChangeSource::Descriptor(0)),
        0,
    );
    let filtered =
        FilterNode::new(a, assigned_only as fn(&Schedule, &Leaf<'_, ShiftAssignment>) -> bool);
    let sh = CollectionNode::new(
        source(shifts as fn(&Schedule) -> &[Shift], ChangeSource::Descriptor(1)),
        1,
    );
    JoinNode::new(
        filtered,
        sh,
        equal_bi(
            assignment_key as for<'a, 'b> fn(&'a Leaf<'b, ShiftAssignment>) -> usize,
            shift_id_key as for<'a, 'b> fn(&'a Leaf<'b, Shift>) -> usize,
        ),
    )
}

/* ((assignment, shift), employee): the pair tree joined to the employee
   collection on the employee index carried by the assignment. */
type SourceEmp =
    solverforge_scoring::stream::collection_extract::SourceExtract<fn(&Schedule) -> &[Employee]>;
type EmpJoiner = solverforge::stream::joiner::EqualJoiner<
    for<'a, 'b> fn(&'a Pair<Leaf<'b, ShiftAssignment>, Leaf<'b, Shift>>) -> usize,
    for<'a, 'b> fn(&'a Leaf<'b, Employee>) -> usize,
    usize,
    solverforge::stream::joiner::Directed,
>;
type EmployeeTree = JoinNode<Schedule, PairTree, CollectionNode<Schedule, SourceEmp>, EmpJoiner>;

fn employee_tree() -> EmployeeTree {
    let e = CollectionNode::new(
        source(employees as fn(&Schedule) -> &[Employee], ChangeSource::Descriptor(2)),
        2,
    );
    JoinNode::new(
        joined_pair_tree(),
        e,
        equal_on(
            row_employee_code
                as for<'a, 'b> fn(&'a Pair<Leaf<'b, ShiftAssignment>, Leaf<'b, Shift>>) -> usize,
            employee_key as for<'a, 'b> fn(&'a Leaf<'b, Employee>) -> usize,
        ),
    )
}
use std::collections::HashSet;
use solverforge::stream::collector::collect_vec;
use solverforge::__internal::{ConstraintRef, ImpactType};

fn tri_shift_key(row: &Row<'_>) -> usize { row.left.right.entity.index }
fn tri_group_of(row: Row<'_>) -> i32 { row.right.entity.shift_group }

type ShiftGroup = GroupNode<
    EmployeeTree,
    for<'a, 'b> fn(&'a Row<'b>) -> usize,
    solverforge::stream::collector::CollectVecCollector<i32, for<'a> fn(Row<'a>) -> i32>,
    usize,
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32,
    solverforge::stream::collector::CollectedVec<i32>,
>;

fn shift_group() -> ShiftGroup {
    GroupNode::new(
        employee_tree(),
        tri_shift_key,
        collect_vec(tri_group_of),
    )
}

type ShiftGroupView<'a> = GroupView<
    'a, Schedule, EmployeeTree, usize,
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32, solverforge::stream::collector::CollectedVec<i32>,
>;

/* Distinct shift groups minus one, floored at zero, as a medium penalty. */
fn shift_weight(_s: &Schedule, g: &ShiftGroupView<'_>) -> HardMediumSoftScore {
    let distinct = g.with_result(|r| r.iter().collect::<HashSet<_>>().len()) as i64;
    HardMediumSoftScore::of_medium(distinct.saturating_sub(1))
}

fn shift_terminal() -> OperatorTerminal<Schedule, ShiftGroup, fn(&Schedule, &ShiftGroupView<'_>) -> HardMediumSoftScore, HardMediumSoftScore> {
    OperatorTerminal::new(
        ConstraintRef::new("shift-group", "Same shift keeps one shift group"),
        ImpactType::Penalty,
        shift_group(),
        shift_weight as fn(&Schedule, &ShiftGroupView<'_>) -> HardMediumSoftScore,
        false,
    )
}
fn tri_block_key(row: &Row<'_>) -> (i64, i64, String) {
    (row.left.right.entity.start, row.left.right.entity.end, row.left.right.entity.location.clone())
}

type BlockGroup = GroupNode<
    EmployeeTree,
    for<'a, 'b> fn(&'a Row<'b>) -> (i64, i64, String),
    solverforge::stream::collector::CollectVecCollector<i32, for<'a> fn(Row<'a>) -> i32>,
    (i64, i64, String),
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32,
    solverforge::stream::collector::CollectedVec<i32>,
>;

type BlockGroupView<'a> = GroupView<
    'a, Schedule, EmployeeTree, (i64, i64, String),
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32, solverforge::stream::collector::CollectedVec<i32>,
>;

fn block_weight(_s: &Schedule, g: &BlockGroupView<'_>) -> HardMediumSoftScore {
    let distinct = g.with_result(|r| r.iter().collect::<HashSet<_>>().len()) as i64;
    HardMediumSoftScore::of_medium(distinct.saturating_sub(1))
}

fn block_group() -> BlockGroup {
    GroupNode::new(
        employee_tree(),
        tri_block_key,
        collect_vec(tri_group_of),
    )
}

fn block_terminal() -> OperatorTerminal<Schedule, BlockGroup, fn(&Schedule, &BlockGroupView<'_>) -> HardMediumSoftScore, HardMediumSoftScore> {
    OperatorTerminal::new(
        ConstraintRef::new("shift-group", "Same block keeps one shift group"),
        ImpactType::Penalty,
        block_group(),
        block_weight as fn(&Schedule, &BlockGroupView<'_>) -> HardMediumSoftScore,
        false,
    )
}

```

Exact block equality is what the example needs: equal `start`, `end`, and
`location`. It is **not** interval-overlap detection — an overlapping but
shorter break block stays a separate bucket here. Overlap conditions exist
for rules that want them (see [Joiners](/docs/solverforge/constraints/joiners/)).

## Input to grouped result

Two shifts that name the same block, each staffed by one employee of one
group, show the two keys diverging:

```text
Shifts:      #0 08:00–12:00 North     #1 08:00–12:00 North
Assignments: a1 → shift #0, employee 0 (group 1)
             a2 → shift #1, employee 1 (group 2)

Group by shift index:        Group by block:
  0 → [1]                      (8, 12, "North") → [1, 2]
  1 → [2]
Penalty: 0                   Penalty: 1 medium
```

By shift index the buckets hold one group each, so nothing looks mixed. The
same block key merges the rows and exposes the mix.

## Behavior verified against 0.20.1

The example was compiled and executed against the published `solverforge
0.20.1` crate. The executed contract:

- `[1, 1]` on one shift scores zero; `[1, 2]` one medium; `[1, 2, 3]` two
  medium.
- An assignment with `employee_idx = None` leaves the stream at the filter
  and contributes nothing (the join never sees a `None` unwrap).
- Assignments to different shifts with different times or locations score in
  separate buckets under the block key: two blocks of one group score zero.
- Identical `(start, end, location)` blocks across different shift IDs merge
  into one bucket and score their mix.
- Incremental reassignment — `on_retract`, mutate, `on_insert` — agrees
  exactly with a full re-evaluation.
- Grouping by the employee index instead of the shift scores zero on a
  mixed shift where the correct key scores one medium: the regression that
  catches the wrong key.

Where a generated application carries these entities as planning entities,
the same rule ships as scaffolded constraint code; see
[Constraint Streams](/docs/solverforge/constraints/constraint-streams/) for
the fluent surface and its boundaries, and
[Collectors](/docs/solverforge/constraints/collectors/) for the built-in
collectors this example composes.