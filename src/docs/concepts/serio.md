---
title: "SERIO Scoring"
linkTitle: "SERIO Scoring"
weight: 40
tags: [concepts]
description: >
  How SolverForge scores a move: constraint streams run as a retained operator
  tree, and each change updates only the matches it touches.
---

SERIO, the Scoring Engine for Real-time Incremental Optimization, is how
SolverForge scores plans. Every solver phase scores through it, and so does
score analysis.

Local search tries many candidate moves for each step it takes. Each
candidate changes one or two planning variables, then gets scored and usually
undone. If every candidate re-evaluated every constraint over the whole
solution, scoring would cost as much as the plan is large, every time. SERIO
keeps the score, and every match behind it, between moves. A move costs only
the matches the changed entity takes part in.

## Constraint streams become an operator tree

You write constraints as streams: select a collection, join, filter, group,
then penalize or reward. SERIO does not run a stream as a loop over the data.
It builds the stream into a tree of operators that keeps its rows between
moves.

Take two rules for a shift schedule: one employee must not work two
overlapping shifts, and an unassigned shift costs a soft point.

```rust
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;
    (
        Streams::new()
            .for_each(Schedule::shifts())
            .join(equal(|shift: &Shift| shift.employee_idx))
            .filter(|a: &Shift, b: &Shift| {
                a.employee_idx.is_some() && a.start < b.end && b.start < a.end
            })
            .penalize(HardSoftScore::ONE_HARD)
            .named("Overlapping shifts"),
        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift: &Shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_SOFT)
            .named("Unassigned shift"),
    )
}
```

Each step of the first stream becomes one node in the tree:

| Stream step | Operator | What it keeps |
| --- | --- | --- |
| `for_each(Schedule::shifts())` | Collection source | One row per shift, tagged with the collection it came from |
| `.join(equal(...))` | Self-join | Shifts bucketed by employee; one row per pair inside a bucket, each pair once |
| `.filter(...)` | Filter | Only the pairs that overlap |
| `.penalize(...).named(...)` | Terminal | The signed score of every row that reached it |

The second rule has no join. It is a single filter over the shift collection,
so it keeps no rows at all and simply re-checks the one shift that changed.

The joiner you choose decides how a join finds partners. `equal` joins use a
hash index, so a changed row looks up one bucket. `less_than`, `greater_than`,
and the inclusive comparisons use an ordered index, and `overlapping` uses an
interval index. A joiner with only a predicate scans the other side. Grouping
keeps one accumulator per key, and terminals that reuse one grouped binding in
`#[solverforge_constraints]` share that accumulator; see
[Node Sharing](/docs/solverforge/constraints/node-sharing/).

## One move, step by step

A change move notifies the score director twice: once before it writes the
new value and once after.

1. **Retract.** Before the value changes, the entity is withdrawn from every
   constraint. Each operator removes the rows the entity takes part in, and
   each terminal subtracts the scores it kept for those rows.
2. **Change.** The move writes the new value.
3. **Insert.** Derived values such as shadow variables update first. Then the
   entity is offered to every constraint again: each operator finds the rows
   the entity now takes part in, through its index, and each terminal scores
   only those new rows.

The new score is the old score plus both deltas. Undoing the move is the same
protocol with the old value.

Here is that move traced with the constraints above. Two employees, four
shifts:

| Shift | Hours | Employee |
| --- | --- | --- |
| 0 | 8–16 | 0 |
| 1 | 12–20 | 0 |
| 2 | 6–10 | 1 |
| 3 | 18–22 | none |

Shifts 0 and 1 overlap for employee 0, and shift 3 is unassigned. The move
gives shift 1 to employee 1.

| Step | What SERIO touches | Score |
| --- | --- | --- |
| Initialize | Every shift enters both constraints once; the pair (0, 1) reaches the terminal | `-1hard/-1soft` |
| Retract shift 1 | The pair (0, 1) leaves employee 0's bucket and its hard point is refunded; shift 1 was assigned, so "Unassigned shift" has nothing to remove | `0hard/-1soft` |
| Insert shift 1 | Shift 1 joins employee 1's bucket and pairs with shift 2; 6–10 and 12–20 do not overlap, so the filter stops the pair before the terminal | `0hard/-1soft` |
| Undo | Retract and insert again with employee 0; the pair (0, 1) returns | `-1hard/-1soft` |

No other shift is retracted or inserted, and a constraint over another
collection would not run at all. With hundreds of employees the move still
costs one bucket out and one bucket in.

## Why it stays fast

- **Changes stay local.** Generated source methods such as
  `Schedule::shifts()` tag every row with its collection. A change to a shift
  never touches a constraint whose sources do not include shifts.
- **Indexes, not scans.** Equality, comparison, and overlap joins look up
  partners in an index instead of walking the other side of the join.
- **Kept scores.** Each terminal remembers the score of every row it holds,
  so retracting a row is a subtraction. The weight function runs only for new
  rows.
- **No dynamic dispatch.** A constraint set is a tuple of concrete types, and
  every filter, key, and weight closure is a type parameter. The compiler sees
  the whole tree and can inline it.

## Trusting the kept score

A kept score is only correct if every change is reported. Moves report their
changes through the protocol above. Set `environment_mode = "full_assert"` in
`solver.toml` to check that while you develop: at its scoring checkpoints,
including every new best solution, the solver re-evaluates the whole solution
from scratch and stops on the first difference, naming the checkpoint where the
kept score drifted.

[Score analysis](/docs/solverforge/constraints/score-analysis/) reads the same
constraints: the total for each named constraint, its matches, and the
entities behind each match.

## Writing rules that stay incremental

- Select sources with the generated methods (`Schedule::shifts()`), so changes
  stay local to the constraints that read that collection.
- Put relationships in joiners instead of filters. `equal(...)` buckets the
  partners; a filter over every pair has to look at every pair.
- Keep filters and weights pure functions of the row they receive. A terminal
  keeps the score it computed; a weight that reads anything else goes stale.
- Group once and reuse the binding when several rules need the same groups.

For the full stream vocabulary, see
[Constraint Streams](/docs/solverforge/constraints/constraint-streams/) and
[Joiners](/docs/solverforge/constraints/joiners/). For how the scoring crate
fits beside the solver, see [Architecture](/docs/architecture/#serio-scoring).
