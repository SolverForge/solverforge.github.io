---
title: "Shift-Group Uniformity"
linkTitle: "Shift-Group Uniformity"
weight: 35
description: >
  Keep employees on the same shift or exact time/location block in one shift
  group using fluent joined grouping and a medium penalty.
---

# Shift-Group Uniformity

Employees assigned to the same shift or time/location block should belong to
one shift group. Mixing groups takes a **medium penalty**, not a hard violation.
The penalty magnitude is the number of distinct groups minus one, floored at
zero; `.penalize(...)` makes its score impact negative.

| Groups in one bucket | Distinct − 1 | Medium score impact |
| --- | --- | --- |
| `[1, 1]` | 0 | 0 |
| `[1, 2]` | 1 | −1 |
| `[1, 2, 3]` | 2 | −2 |
| `[1, 2, 1]` | 1 | −1 |

Group labels do not determine the penalty: `[1, 2]` and `[3, 4]` both contain
two distinct groups.

## Input → grouped rows → score

Two shift IDs can name the same block. Choosing the bucket key determines
whether their employees are compared together:

```text
Shifts:      #0 08:00–12:00 North     #1 08:00–12:00 North
Assignments: a1 → shift #0, employee 0 (group 1)
             a2 → shift #1, employee 1 (group 2)

Group by shift index:           Group by exact block:
  0 → [1]                        (8, 12, "North") → [1, 2]
  1 → [2]
Medium score: 0                Medium score: −1
```

Use the shift index for **same-shift** uniformity. Use `(start, end, location)`
for **same-block** uniformity across shift IDs. Exact block equality is not
interval overlap: a shorter overlapping block, or the same times at a different
location, stays a separate bucket. See [Joiners](/docs/solverforge/constraints/joiners/)
for overlap relationships.

## The model

A `ShiftAssignment` stores a shift ID and an optional employee index. `Shift`
stores the block; `Employee` stores the shift-group value. The complete listing
uses plain structs so the rule can run independently of a solver configuration.

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing below defines and executes the model" -->
```rust
struct ShiftAssignment { shift_id: usize, employee_idx: Option<usize> }
struct Shift { index: usize, start: i64, end: i64, location: String }
struct Employee { index: usize, shift_group: i32 }
```

In a planning solution, use generated sources such as `Schedule::assignments()`.
The standalone listing supplies `source(...)` metadata explicitly: assignments
use descriptor 0 for incremental updates; shifts and employees are immutable
facts. It only needs the `solverforge` dependency.

## The rule, step by step

### 1. Exclude unassigned rows before key extraction

Start from assignments and filter out `None` values before the first equality
join. Later employee-key extraction can then safely require an assigned index.

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing below compiles end to end" -->
```rust
Streams::new()
    .for_each(source(assignments as fn(&Schedule) -> &[ShiftAssignment], ChangeSource::Descriptor(0)))
    .filter(|assignment: &ShiftAssignment| assignment.employee_idx.is_some())
```

A post-join filter would not protect key extraction. This source-filter
pushdown applies to the first unary keyed equality cross-join, not every join
dispatch; see [Constraint Streams](/docs/solverforge/constraints/constraint-streams/).

### 2. Join the shift, then the assigned employee

The first join uses entity keys. The continuation uses `equal_on` over the
whole borrowed pair and the new employee leaf.

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing below compiles end to end" -->
```rust
.join((
    source(shifts as fn(&Schedule) -> &[Shift], ChangeSource::Static),
    equal_bi(|assignment: &ShiftAssignment| assignment.shift_id, |shift: &Shift| shift.index),
))
.join((
    source(employees as fn(&Schedule) -> &[Employee], ChangeSource::Static),
    equal_on(assigned_employee, employee_index),
))
```

`assigned_employee` reads `row.left.entity.employee_idx` from
`Pair<Leaf<ShiftAssignment>, Leaf<Shift>>`; `employee_index` reads the new
`Leaf<Employee>` through `.entity`. The result binds `(assignment, shift,
employee)` in that order.

### 3. Choose the bucket key

Fluent `Tri::group_by` takes a key closure with three separate entity
arguments. Both rules use the same stream; only the key and name differ.

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing below compiles end to end" -->
```rust
// Same shift:
|_assignment: &ShiftAssignment, shift: &Shift, _employee: &Employee| shift.index

// Same exact block, even across different shift IDs:
|_assignment: &ShiftAssignment, shift: &Shift, _employee: &Employee| {
    (shift.start, shift.end, shift.location.clone())
}
```

**Do not group by employee or by `shift_group` itself.** Those keys separate
values into buckets that each hold one group, hiding a genuinely mixed shift.
The key identifies where employees are compared; the collected value is what
is compared. The complete listing tests both wrong-key regressions.

### 4. Collect the shift-group value from each joined tuple

Unlike the key closure, a collector mapper takes **one tuple argument** of
borrowed entities, not a nested operator row and not three separate arguments.

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing below compiles end to end" -->
```rust
.group_by(
    key,
    collect_vec(|(_assignment, _shift, employee): (&ShiftAssignment, &Shift, &Employee)| {
        employee.shift_group
    }),
)
```

The input is `(&ShiftAssignment, &Shift, &Employee)`. Each mapped `i32` becomes
an owned collector value, and the result is a `CollectedVec<i32>` for the bucket.
Duplicates remain in the collection; the score closure counts distinct values.

### 5. Score the grouped key and collector result

Grouping changes the terminal input. The weight closure now receives two
separate borrowed arguments: `&K` and `&CollectedVec<i32>`, **not** the original
three-entity tuple.

<!-- sf-rust: ignore reason="walkthrough excerpt; the complete listing below compiles end to end" -->
```rust
.penalize(|_key: &K, groups: &CollectedVec<i32>| {
    let distinct = groups.iter().copied().collect::<HashSet<_>>().len();
    HardMediumSoftScore::of_medium(distinct.saturating_sub(1) as i64)
})
.named(name)
```

Return a nonnegative penalty magnitude. The terminal applies the negative sign,
so two distinct groups contribute `0hard/-1medium/0soft`. The result is borrowed
for scoring; the collection itself is not cloned.

## Complete runnable example

Use `solverforge = "=0.21.0"` in the dependencies of a Rust binary crate and
save this listing as `src/main.rs`. Run it with `cargo run`. `check()` covers
uniform and mixed groups, duplicate values, unassigned and empty input,
separate shift IDs, exact shared blocks, different times and locations, overlap,
wrong keys, and incremental reassignment with membership exit and re-entry.

```rust
use std::collections::HashSet;
use std::hash::Hash;

use solverforge::{HardMediumSoftScore, IncrementalConstraint};
use solverforge::stream::{source, ChangeSource, ConstraintFactory};
use solverforge::stream::collector::{collect_vec, CollectedVec};
use solverforge::stream::joiner::{equal_bi, equal_on};
use solverforge::stream::relational::{operator::Pair, Leaf};

#[derive(Clone, Debug)]
struct Shift { index: usize, start: i64, end: i64, location: String }
#[derive(Clone, Debug)]
struct ShiftAssignment { shift_id: usize, employee_idx: Option<usize> }
#[derive(Clone, Debug)]
struct Employee { index: usize, shift_group: i32 }
#[derive(Clone, Debug)]
struct Schedule {
    shifts: Vec<Shift>,
    assignments: Vec<ShiftAssignment>,
    employees: Vec<Employee>,
}

fn shifts(s: &Schedule) -> &[Shift] { &s.shifts }
fn assignments(s: &Schedule) -> &[ShiftAssignment] { &s.assignments }
fn employees(s: &Schedule) -> &[Employee] { &s.employees }

// Continuation keys inspect the borrowed pair and the new leaf.
fn assigned_employee(row: &Pair<Leaf<'_, ShiftAssignment>, Leaf<'_, Shift>>) -> usize {
    row.left.entity.employee_idx.expect("assigned rows only")
}
fn employee_index(row: &Leaf<'_, Employee>) -> usize { row.entity.index }

fn uniformity<K>(
    key: impl Fn(&ShiftAssignment, &Shift, &Employee) -> K + Send + Sync + 'static,
    name: &str,
) -> impl IncrementalConstraint<Schedule, HardMediumSoftScore>
where K: Eq + Hash + Clone + Send + Sync + 'static,
{
    type Streams = ConstraintFactory<Schedule, HardMediumSoftScore>;
    Streams::new()
        .for_each(source(assignments as fn(&Schedule) -> &[ShiftAssignment], ChangeSource::Descriptor(0)))
        .filter(|assignment: &ShiftAssignment| assignment.employee_idx.is_some())
        .join((
            source(shifts as fn(&Schedule) -> &[Shift], ChangeSource::Static),
            equal_bi(|assignment: &ShiftAssignment| assignment.shift_id, |shift: &Shift| shift.index),
        ))
        .join((
            source(employees as fn(&Schedule) -> &[Employee], ChangeSource::Static),
            equal_on(assigned_employee, employee_index),
        ))
        .group_by(
            key,
            collect_vec(|(_assignment, _shift, employee): (&ShiftAssignment, &Shift, &Employee)| employee.shift_group),
        )
        .penalize(|_key: &K, groups: &CollectedVec<i32>| {
            let distinct = groups.iter().copied().collect::<HashSet<_>>().len();
            HardMediumSoftScore::of_medium(distinct.saturating_sub(1) as i64)
        })
        .named(name)
}

fn shift_rule() -> impl IncrementalConstraint<Schedule, HardMediumSoftScore> {
    uniformity(|_assignment, shift, _employee| shift.index, "Same shift keeps one shift group")
}
fn block_rule() -> impl IncrementalConstraint<Schedule, HardMediumSoftScore> {
    uniformity(
        |_assignment, shift, _employee| (shift.start, shift.end, shift.location.clone()),
        "Same block keeps one shift group",
    )
}

fn check() {
    let shift = shift_rule();
    let block = block_rule();
    let base = Schedule {
        shifts: vec![Shift { index: 0, start: 8, end: 12, location: "North".into() }],
        assignments: vec![
            ShiftAssignment { shift_id: 0, employee_idx: Some(0) },
            ShiftAssignment { shift_id: 0, employee_idx: Some(1) },
        ],
        employees: vec![Employee { index: 0, shift_group: 1 }, Employee { index: 1, shift_group: 1 }],
    };
    assert_eq!(shift.evaluate(&base), HardMediumSoftScore::ZERO, "[1, 1]");
    let mut mixed = base.clone();
    mixed.employees[1].shift_group = 2;
    assert_eq!(shift.evaluate(&mixed), HardMediumSoftScore::of_medium(-1), "[1, 2]");
    let mut renamed = mixed.clone();
    renamed.employees[0].shift_group = 3;
    renamed.employees[1].shift_group = 4;
    assert_eq!(shift.evaluate(&renamed), HardMediumSoftScore::of_medium(-1), "labels do not affect penalty");
    let mut three = mixed.clone();
    three.employees.push(Employee { index: 2, shift_group: 3 });
    three.assignments.push(ShiftAssignment { shift_id: 0, employee_idx: Some(2) });
    assert_eq!(shift.evaluate(&three), HardMediumSoftScore::of_medium(-2), "[1, 2, 3]");
    let mut duplicate = mixed.clone();
    duplicate.assignments.push(duplicate.assignments[0].clone());
    assert_eq!(shift.evaluate(&duplicate), HardMediumSoftScore::of_medium(-1), "[1, 2, 1] counts distinct groups");

    let mut unassigned = mixed.clone();
    unassigned.assignments.push(ShiftAssignment { shift_id: 0, employee_idx: None });
    assert_eq!(shift.evaluate(&unassigned), HardMediumSoftScore::of_medium(-1), "unassigned excluded");
    unassigned.assignments = vec![ShiftAssignment { shift_id: 0, employee_idx: None }];
    assert_eq!(shift.evaluate(&unassigned), HardMediumSoftScore::ZERO, "only unassigned");
    unassigned.assignments.clear();
    assert_eq!(shift.evaluate(&unassigned), HardMediumSoftScore::ZERO, "empty input");

    let mut same_block = mixed.clone();
    same_block.shifts.push(Shift { index: 1, ..same_block.shifts[0].clone() });
    same_block.assignments[1].shift_id = 1;
    assert_eq!(shift.evaluate(&same_block), HardMediumSoftScore::ZERO, "separate shift IDs");
    assert_eq!(block.evaluate(&same_block), HardMediumSoftScore::of_medium(-1), "identical blocks across shift IDs");
    let mut uniform_block = same_block.clone();
    uniform_block.employees[1].shift_group = 1;
    assert_eq!(block.evaluate(&uniform_block), HardMediumSoftScore::ZERO, "uniform shared block");
    let mut different_time = same_block.clone();
    different_time.shifts[1].start = 13;
    different_time.shifts[1].end = 17;
    assert_eq!(block.evaluate(&different_time), HardMediumSoftScore::ZERO, "different times split blocks");
    let mut different_location = same_block.clone();
    different_location.shifts[1].location = "South".into();
    assert_eq!(block.evaluate(&different_location), HardMediumSoftScore::ZERO, "different locations split blocks");
    let mut overlapping = same_block.clone();
    overlapping.shifts[1].start = 9;
    overlapping.shifts[1].end = 11;
    assert_eq!(block.evaluate(&overlapping), HardMediumSoftScore::ZERO, "overlap is not exact block equality");
    let mut split = three.clone();
    split.shifts.push(Shift { index: 1, start: 13, end: 17, location: "North".into() });
    split.assignments[2].shift_id = 1;
    assert_eq!(block.evaluate(&split), HardMediumSoftScore::of_medium(-1), "mixed morning, uniform afternoon");

    let wrong_employee = uniformity(|_assignment, _shift, employee| employee.index, "Wrong employee key");
    let wrong_group = uniformity(|_assignment, _shift, employee| employee.shift_group, "Wrong shift-group key");
    assert_eq!(wrong_employee.evaluate(&mixed), HardMediumSoftScore::ZERO, "employee key hides mix");
    assert_eq!(wrong_group.evaluate(&mixed), HardMediumSoftScore::ZERO, "group key hides mix");
    assert_eq!(shift.evaluate(&mixed), HardMediumSoftScore::of_medium(-1), "correct key exposes mix");

    // Descriptor 0 is the assignment source; retract before editing, insert after.
    let mut retained = shift_rule();
    let mut live = mixed.clone();
    let mut score = retained.initialize(&live);
    assert_eq!(score, HardMediumSoftScore::of_medium(-1));
    score = score + retained.on_retract(&live, 1, 0);
    live.assignments[1].employee_idx = Some(0);
    score = score + retained.on_insert(&live, 1, 0);
    assert_eq!(score, HardMediumSoftScore::ZERO, "reassignment removes mix");
    assert_eq!(score, retained.evaluate(&live), "incremental equals full");
    score = score + retained.on_retract(&live, 1, 0);
    live.assignments[1].employee_idx = None;
    score = score + retained.on_insert(&live, 1, 0);
    assert_eq!(score, retained.evaluate(&live), "exit assigned membership");
    score = score + retained.on_retract(&live, 1, 0);
    live.assignments[1].employee_idx = Some(1);
    score = score + retained.on_insert(&live, 1, 0);
    assert_eq!(score, HardMediumSoftScore::of_medium(-1), "re-enter assigned membership");
    assert_eq!(score, retained.evaluate(&live));
    retained.reset();
    assert_eq!(retained.initialize(&live), score, "reset and reinitialize");
}

fn main() {
    check();
    println!("Shift-group uniformity: all behavioral checks passed.");
}
```

## Authoring boundaries

Named joined arities `Tri`, `Quad`, and `Penta`, and their same-source
counterparts, expose fluent `group_by(key, collector)`. Key closures take three,
four, or five entity arguments; collector mappers take the corresponding tuple
of references. Authored filters remain binding during full and incremental
grouped evaluation. Grouped terminals take only the key and collected result.

These joined groups finalize through `GroupNode` and `OperatorTerminal` without
application code constructing either type. The arbitrary-depth `Chain` does
not expose fluent grouping; custom operator composition remains useful there.
The joined tri/quad/penta grouped builder exposes `penalize` and `reward`, not
`complement`; do not assume the pair-group complement surface extends to it.

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) — fluent operations and boundaries
- [Collectors](/docs/solverforge/constraints/collectors/) — collector input and result shapes
- [Tagged joined-group implementation](https://github.com/SolverForge/solverforge/blob/v0.21.0/crates/solverforge-scoring/src/stream/group_by_tri.rs)
