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


## The rule, step by step

**1. Filter unassigned rows before keys run.** `employee_idx` is
`Option<usize>`, and joining on it unwraps the value. The filter therefore
sits on the assignment collection, ahead of any join index:

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing at the end of this page compiles end to end" -->
```rust
let filtered = FilterNode::new(assignments, assigned_only as
    fn(&Schedule, &Leaf<'_, ShiftAssignment>) -> bool);
```

A filter placed *after* the join would not protect key extraction.

**2. Bring each assignment the data the rule needs.** An assignment knows its
shift; the shift knows its block; the employee knows their shift group. Two
equality joins build that row:

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing at the end of this page compiles end to end" -->
```rust
// (assignment, shift): assignment.shift_id == shift.index
JoinNode::new(filtered, shifts, equal_bi(assignment_key, shift_id_key))

// ((assignment, shift), employee): pair.employee_idx == employee.index.
// The left key is row-aware — it reads the assignment out of the prior row.
JoinNode::new(pair_tree, employees, equal_on(row_employee_code, employee_key))
```

The first join uses entity keys (`equal_bi`); every later join uses row-aware
keys (`equal_on`) whose left closure receives the whole borrowed row so far.
Leaf views name their entity through `.entity`:

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing at the end of this page compiles end to end" -->
```rust
fn row_employee_code(row: &Pair<Leaf<'_, ShiftAssignment>, Leaf<'_, Shift>>) -> usize {
    row.left.entity.employee_idx.unwrap()
}
```

**3. Group the joined rows by the bucket they are compared within.**
`GroupNode` buckets rows by a key and collects a value per row. The two
cases are the same stream with a different key:

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing at the end of this page compiles end to end" -->
```rust
// Case 1: the shift's own index.
fn tri_shift_key(row: &Row<'_>) -> usize { row.left.right.entity.index }

// Case 2: the block — two shifts with different indexes that name the same
// (start, end, location) land in one bucket.
fn tri_block_key(row: &Row<'_>) -> (i64, i64, String) {
    (row.left.right.entity.start, row.left.right.entity.end,
     row.left.right.entity.location.clone())
}
```

**4. Collect each employee's shift-group value.** The collector's closure
receives the stream's match row — the full `(assignment, shift, employee)`
row — and reads the one field the rule compares:

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing at the end of this page compiles end to end" -->
```rust
fn tri_group_of(row: Row<'_>) -> i32 { row.right.entity.shift_group }
```

**5. Score the grouped result.** The terminal weight closure receives the
grouped result, not the raw rows: the bucket key and the collected
`CollectedVec<i32>`. Distinct count minus one, floored at zero:

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing at the end of this page compiles end to end" -->
```rust
fn shift_weight(_s: &Schedule, g: &ShiftGroupView<'_>) -> HardMediumSoftScore {
    let distinct = g.with_result(|r| r.iter().collect::<HashSet<_>>().len()) as i64;
    HardMediumSoftScore::of_medium(distinct.saturating_sub(1))
}
```

`with_result` borrows the collector's result; nothing is cloned to score it.

## Why the grouping key cannot be the shift group

Grouping by the employee, or by `shift_group` itself, puts each value in its
own bucket. Every bucket then holds exactly one distinct group, the score is
zero everywhere, and a mixed block is never penalized. The key must name the
bucket employees are compared within — the shift or the block — and the
collector must read the value being compared — the shift group.

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
same block key merges the rows and exposes the mix. Incremental reassignment
follows the same rule: `on_retract` → mutate → `on_insert` yields the same
score as a full re-evaluation.

Exact block equality is what the rule needs: equal `start`, `end`, and
`location`. It is **not** interval-overlap detection — an overlapping but
shorter break block stays a separate bucket here. Overlap conditions exist
for rules that want them; see [Joiners](/docs/solverforge/constraints/joiners/).

## Complete example

Both cases share the filter, both joins, the collector, and the weight; the
`GroupNode` key and the constraint name are the only parts that differ. The
`check` function pins the expected scores for `[1, 1]`, `[1, 2]`,
`[1, 2, 3]`, unassigned slots, separate shifts, identical blocks across
shift IDs, split blocks, an incremental reassignment, and the wrong grouping
key.

```rust
use std::collections::HashSet;

use solverforge::stream::relational::operator::{
    CollectionNode, GroupNode, GroupView, JoinNode, Pair,
};
use solverforge::stream::relational::Leaf;
use solverforge::stream::joiner::{equal_bi, equal_on};
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

/* Row shapes after each join, in binding order:
   (assignment, shift)                          = Pair<Leaf<A>, Leaf<Sh>>
   ((assignment, shift), employee)              = Pair<Pair<Leaf<A>, Leaf<Sh>>, Leaf<E>> */
fn assignment_key(l: &Leaf<'_, ShiftAssignment>) -> usize { l.entity.shift_id }
fn shift_id_key(r: &Leaf<'_, Shift>) -> usize { r.entity.index }
fn employee_key(l: &Leaf<'_, Employee>) -> usize { l.entity.index }
fn row_employee_code(row: &Pair<Leaf<'_, ShiftAssignment>, Leaf<'_, Shift>>) -> usize {
    row.left.entity.employee_idx.unwrap()
}

fn assigned_only(s: &Schedule, l: &Leaf<'_, ShiftAssignment>) -> bool {
    let _ = s;
    l.entity.employee_idx.is_some()
}

fn joined_pair_tree() -> PairTree {
    let a = CollectionNode::new(source(assignments as fn(&Schedule) -> &[ShiftAssignment], ChangeSource::Descriptor(0)), 0);
    let filtered = solverforge::stream::relational::operator::FilterNode::new(a, assigned_only as fn(&Schedule, &Leaf<'_, ShiftAssignment>) -> bool);
    let sh = CollectionNode::new(source(shifts as fn(&Schedule) -> &[Shift], ChangeSource::Descriptor(1)), 1);
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
type ShiftFilter = solverforge::stream::relational::operator::FilterNode<
    CollectionNode<Schedule, solverforge_scoring::stream::collection_extract::SourceExtract<fn(&Schedule) -> &[ShiftAssignment]>>,
    fn(&Schedule, &Leaf<'_, ShiftAssignment>) -> bool,
>;
type PairTree = JoinNode<
    Schedule,
    ShiftFilter,
    CollectionNode<Schedule, solverforge_scoring::stream::collection_extract::SourceExtract<fn(&Schedule) -> &[Shift]>>,
    solverforge::stream::joiner::EqualJoiner<
        for<'a, 'b> fn(&'a Leaf<'b, ShiftAssignment>) -> usize,
        for<'a, 'b> fn(&'a Leaf<'b, Shift>) -> usize,
        usize,
        solverforge::stream::joiner::Directed,
    >,
>;
type EmployeeTree = JoinNode<
    Schedule,
    PairTree,
    CollectionNode<Schedule, solverforge_scoring::stream::collection_extract::SourceExtract<fn(&Schedule) -> &[Employee]>>,
    solverforge::stream::joiner::EqualJoiner<
        for<'a, 'b> fn(&'a Pair<Leaf<'b, ShiftAssignment>, Leaf<'b, Shift>>) -> usize,
        for<'a, 'b> fn(&'a Leaf<'b, Employee>) -> usize,
        usize,
        solverforge::stream::joiner::Directed,
    >,
>;

fn employee_tree() -> EmployeeTree {
    let e = CollectionNode::new(source(employees as fn(&Schedule) -> &[Employee], ChangeSource::Descriptor(2)), 2);
    JoinNode::new(
        joined_pair_tree(),
        e,
        equal_on(
            row_employee_code as for<'a, 'b> fn(&'a Pair<Leaf<'b, ShiftAssignment>, Leaf<'b, Shift>>) -> usize,
            employee_key as for<'a, 'b> fn(&'a Leaf<'b, Employee>) -> usize,
        ),
    )
}


type Tri<'a> = Pair<Pair<Leaf<'a, ShiftAssignment>, Leaf<'a, Shift>>, Leaf<'a, Employee>>;

type ShiftGroup = GroupNode<
    EmployeeTree,
    for<'a, 'b> fn(&'a Tri<'b>) -> usize,
    solverforge::stream::collector::CollectVecCollector<i32, for<'a> fn(Tri<'a>) -> i32>,
    usize,
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32,
    solverforge::stream::collector::CollectedVec<i32>,
>;

fn tri_shift_key(row: &Tri<'_>) -> usize { row.left.right.entity.index }
fn tri_group_of(row: Tri<'_>) -> i32 { row.right.entity.shift_group }
fn tri_block_key(row: &Tri<'_>) -> (i64, i64, String) {
    (row.left.right.entity.start, row.left.right.entity.end, row.left.right.entity.location.clone())
}

fn shift_group() -> ShiftGroup {
    GroupNode::new(
        employee_tree(),
        tri_shift_key,
        solverforge::stream::collector::collect_vec(tri_group_of),
    )
}

fn block_group() -> GroupNode<
    EmployeeTree,
    for<'a, 'b> fn(&'a Tri<'b>) -> (i64, i64, String),
    solverforge::stream::collector::CollectVecCollector<i32, for<'a> fn(Tri<'a>) -> i32>,
    (i64, i64, String),
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32,
    solverforge::stream::collector::CollectedVec<i32>,
> {
    GroupNode::new(
        employee_tree(),
        tri_block_key,
        solverforge::stream::collector::collect_vec(tri_group_of),
    )
}

type TriView<'a> = GroupView<
    'a,
    Schedule,
    EmployeeTree,
    usize,
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32,
    solverforge::stream::collector::CollectedVec<i32>,
>;

fn medium(mixed_groups: i64) -> HardMediumSoftScore {
    HardMediumSoftScore::of_medium(mixed_groups.saturating_sub(1))
}

fn shift_weight(_s: &Schedule, g: &TriView<'_>) -> HardMediumSoftScore {
    medium(g.with_result(|r| r.iter().collect::<HashSet<_>>().len()) as i64)
}

type BlockView<'a> = GroupView<
    'a,
    Schedule,
    EmployeeTree,
    (i64, i64, String),
    solverforge::stream::collector::CollectVecAccumulator<i32>,
    i32,
    solverforge::stream::collector::CollectedVec<i32>,
>;

fn block_weight(_s: &Schedule, g: &BlockView<'_>) -> HardMediumSoftScore {
    medium(g.with_result(|r| r.iter().collect::<HashSet<_>>().len()) as i64)
}

fn shift_terminal() -> OperatorTerminal<Schedule, ShiftGroup, fn(&Schedule, &TriView<'_>) -> HardMediumSoftScore, HardMediumSoftScore> {
    OperatorTerminal::new(
        solverforge::__internal::ConstraintRef::new("shift-group", "Same shift keeps one shift group"),
        solverforge::__internal::ImpactType::Penalty,
        shift_group(),
        shift_weight as fn(&Schedule, &TriView<'_>) -> HardMediumSoftScore,
        false,
    )
}

pub fn check() {

    /* [1, 1] on one shift -> no penalty */
    let mut c = shift_terminal();
    let base = Schedule {
        shifts: vec![Shift { index: 0, start: 8, end: 12, location: "North".into() }],
        assignments: vec![
            ShiftAssignment { shift_id: 0, employee_idx: Some(0) },
            ShiftAssignment { shift_id: 0, employee_idx: Some(1) },
        ],
        employees: vec![Employee { index: 0, shift_group: 7 }, Employee { index: 1, shift_group: 7 }],
    };
    assert_eq!(c.evaluate(&base), HardMediumSoftScore::ZERO);

    /* [1, 2] -> one medium penalty */
    let mixed = Schedule { employees: vec![Employee { index: 0, shift_group: 7 }, Employee { index: 1, shift_group: 8 }], ..base.clone() };
    assert_eq!(c.evaluate(&mixed), -HardMediumSoftScore::ONE_MEDIUM, "two distinct groups");

    /* [1, 2, 3] -> two medium penalties */
    let three = Schedule {
        assignments: vec![
            ShiftAssignment { shift_id: 0, employee_idx: Some(0) },
            ShiftAssignment { shift_id: 0, employee_idx: Some(1) },
            ShiftAssignment { shift_id: 0, employee_idx: Some(2) },
        ],
        employees: vec![
            Employee { index: 0, shift_group: 7 },
            Employee { index: 1, shift_group: 8 },
            Employee { index: 2, shift_group: 9 },
        ],
        ..base.clone()
    };
    assert_eq!(c.evaluate(&three), HardMediumSoftScore::of_medium(-2), "three distinct groups");

    /* Unassigned slots are excluded before key extraction. */
    let unassigned = Schedule { assignments: vec![ShiftAssignment { shift_id: 0, employee_idx: None }], ..base.clone() };
    assert_eq!(c.evaluate(&unassigned), HardMediumSoftScore::ZERO, "unassigned only");

    /* Same block across different shift IDs — group by the block, not the shift. */
    let b = OperatorTerminal::new(
        solverforge::__internal::ConstraintRef::new("shift-group", "Same block keeps one shift group"),
        solverforge::__internal::ImpactType::Penalty,
        block_group(),
        block_weight,
        false,
    );
    let two_shifts = Schedule {
        shifts: vec![
            Shift { index: 0, start: 8, end: 12, location: "North".into() },
            Shift { index: 1, start: 8, end: 12, location: "North".into() },
        ],
        assignments: vec![
            ShiftAssignment { shift_id: 0, employee_idx: Some(0) },
            ShiftAssignment { shift_id: 1, employee_idx: Some(1) },
        ],
        employees: vec![Employee { index: 0, shift_group: 7 }, Employee { index: 1, shift_group: 7 }],
        ..base.clone()
    };
    assert_eq!(b.evaluate(&two_shifts), HardMediumSoftScore::ZERO, "identical blocks across shift ids");

    /* Different times -> separate blocks -> mixed groups -> one penalty each. */
    /* Different times split blocks: two employees with different groups share
       the morning block (one penalty); the afternoon block is single-group. */
    let apart = Schedule {
        shifts: vec![
            Shift { index: 0, start: 8, end: 12, location: "North".into() },
            Shift { index: 1, start: 13, end: 17, location: "North".into() },
        ],
        assignments: vec![
            ShiftAssignment { shift_id: 0, employee_idx: Some(0) },
            ShiftAssignment { shift_id: 0, employee_idx: Some(1) },
            ShiftAssignment { shift_id: 1, employee_idx: Some(2) },
        ],
        employees: vec![
            Employee { index: 0, shift_group: 7 },
            Employee { index: 1, shift_group: 8 },
            Employee { index: 2, shift_group: 9 },
        ],
    };
    assert_eq!(b.evaluate(&apart), -HardMediumSoftScore::ONE_MEDIUM, "different times split blocks");

    /* Incremental reassignment agrees with full evaluation. */
    let mut m = mixed.clone();
    let full_before = c.evaluate(&m);
    let init = c.initialize(&m);
    assert_eq!(init, full_before);
    /* Reassign employee 1's assignment to employee 0: mutate the entity field,
       applying the incremental protocol around the edit. */
    let d_retract = c.on_retract(&m, 1, 0);
    m.assignments[1].employee_idx = Some(0);
    let d_insert = c.on_insert(&m, 1, 0);
    let incremental = init + d_retract + d_insert;
    assert_eq!(incremental, c.evaluate(&m), "incremental matches full re-evaluation");
    let _ = full_before;

    /* Wrong grouping key regression: grouping by employee index instead of the
       shift yields a distinct-group count of 1 per bucket -> zero penalty even
       for a genuinely mixed shift. */
    /* Grouping by the WRONG key: the employee index separates every row into
       its own bucket, so no bucket ever holds two groups and the same mixed
       shift scores zero. The correct shift key scores -1 medium. This is why
       grouping by the employee (or by the shift_group itself) is wrong. */
    let wrong_group = GroupNode::new(
        employee_tree(),
        |row: &Tri<'_>| row.right.entity.index,
        solverforge::stream::collector::collect_vec(tri_group_of),
    );
    let wrong = OperatorTerminal::new(
        solverforge::__internal::ConstraintRef::new("shift-group", "wrong grouping key"),
        solverforge::__internal::ImpactType::Penalty,
        wrong_group,
        shift_weight,
        false,
    );
    assert_eq!(wrong.evaluate(&mixed), HardMediumSoftScore::ZERO, "wrong key hides the mix");
    assert_eq!(c.evaluate(&mixed), -HardMediumSoftScore::ONE_MEDIUM);
}
```

## Authoring surface

A rule over three joined sources grouped per bucket needs the low-level
operator tree: unary `.group_by(...)` groups a single collection, cross-bi
`.group_by(...)` groups joined pairs, and a `Tri` stream has no fluent
`group_by`. The composition used here is the same
`FilterNode` → `JoinNode` → `GroupNode` → `OperatorTerminal` the
[tagged scoring guide](https://github.com/SolverForge/solverforge/blob/v0.20.1/docs/extend-scoring.md)
and [Extend the Domain](/reference/extend-domain/) record; it adds a direct
`solverforge-scoring` dependency.

Where a generated application carries these entities as planning entities,
the same rule ships as scaffolded constraint code; see
[Constraint Streams](/docs/solverforge/constraints/constraint-streams/) for
the fluent surface and its boundaries, and
[Collectors](/docs/solverforge/constraints/collectors/) for the built-in
collectors this example composes.
