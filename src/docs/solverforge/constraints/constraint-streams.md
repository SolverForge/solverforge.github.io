---
title: "Constraint Streams"
linkTitle: "Constraint Streams"
weight: 10
description: >
  Declarative constraint definition using the stream API.
---

Constraint streams are the primary way to define constraints in SolverForge.
They provide a pipeline-style API where you select entities or facts, transform
the stream, and terminate with a scoring impact.

## Defining Constraints

Constraints are defined as a function that returns a constraint set, usually a
tuple of fluent terminal constraints. The `#[planning_solution]` macro wires
this up automatically. Use `#[solverforge_constraints]` when the function owns
reusable stream bindings or grouped chains that should be compiled as one
shared retained node.

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

#[solverforge_constraints]
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

    (
        factory.for_each(Schedule::shifts())
            .filter(|shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),
    )
}
```

Each constraint builder chain finalizes through `.named()`. Since v0.19.10,
direct pair scoring, chained joins, existence, flattening, and unary complemented grouping
use concrete `stream::relational::operator` trees and the generic
`constraint::relational::OperatorTerminal`, rather than separate retained
engines for each shape. Unary scoring still has its own fluent terminal.
Return terminals as a tuple; SolverForge implements `ConstraintSet` for singleton
incremental constraints and for nested typed constraint sets, with tuple support
up to 32 members.

## Source Operations

### Generated Source Methods

Generated solution source methods select all items from a solution collection
and carry hidden source metadata for localized incremental scoring.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new().for_each(Schedule::shifts())
Streams::new().for_each(Schedule::employees())
```

These should be the default source arguments for planning entity and problem fact
collections. See [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/)
for the generated method contract.

### `for_each`

`for_each` starts a stream from any collection extractor. Use generated source
methods such as `Schedule::shifts()` for ordinary model collections. Use
`solverforge::stream::vec(...)` for lower-level custom collection surfaces.

```rust
use solverforge::stream::vec;

factory.for_each(vec(|solution: &Schedule| &solution.custom_rows))
```

## Intermediate Operations

| Operation | Purpose |
| --------- | ------- |
| `filter` | Keep only matches that satisfy a predicate |
| `join` | Combine sources; chained `.join((target, equal_on(left_row_key, right_leaf_key)))` adds relationships with independent key domains |
| `project` | Create retained scoring-only rows |
| `flatten_last` | Expand a collection carried by the last joined item |
| `group_by` | Group unary rows, projected rows, or cross-join pairs and apply a collector |
| `balance` | Score load balance without manual grouped unfairness logic |
| `complement` | Fill missing grouped keys from a generated fact or entity source after unary, projected, or direct cross-join grouping |
| `if_exists` / `if_not_exists` | Keep rows based on matching rows in another collection |

### `filter`

```rust
factory.for_each(Schedule::shifts())
    .filter(|shift| shift.employee_idx.is_none())
```

### `join`

`join` dispatches on the target shape. Fluent right-hand collection targets
implement `CollectionExtract`, including generated sources and filtered unary
streams. Arbitrary joined, projected, grouped, or complemented producers are
not interchangeable fluent targets; compatible derived producers can be inputs
on either side of a low-level `JoinNode`.

#### Unary source membership before equality keys

On the first unary keyed equality cross-join (`join((target, equal_bi(...)))`),
an accumulated left unary filter excludes rows before key extraction, index
insertion, and pair creation. A filtered unary right target preserves its own
source membership. Put nullable-row filters on each unary input whose keys
require an assignment:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .filter(|shift: &Shift| shift.employee_idx.is_some())
    .join((
        Streams::new()
            .for_each(Schedule::unavailability())
            .filter(|u: &Unavailability| u.employee_idx.is_some()),
        equal_bi(
            |shift: &Shift| shift.employee_idx.expect("filtered assigned shift"),
            |u: &Unavailability| u.employee_idx.expect("filtered assigned row"),
        ),
    ))
    .penalize(HardSoftScore::ONE_HARD)
    .named("Assigned employee unavailable")
```

Original source indexes and change metadata survive incremental transitions
into and out of membership. A filter after the join operates on joined rows;
it cannot protect a key extractor from an excluded unary row. This left-source
pushdown does **not** apply to comparison, overlap, composed-condition,
predicate, or same-source self-join dispatch. In particular,
`equal_bi(...).and(...)` is composed dispatch, not this first equality path.
The membership adapter is hidden implementation detail, not a modeling API.

To relate two independently oriented rows from the same collection, pass that
collection as the right target of a keyed cross-join. This tuple form still
uses the first unary equality cross-join dispatch and its source-membership
boundary:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::shifts()),
        equal_bi(
            |left: &Shift| left.employee_idx,
            |right: &Shift| right.employee_idx,
        ),
    ))
```

For same-source unique combinations instead, use `.join(equal(|row| key))`.
That dispatch creates the same-source `BiConstraintStream`; it does not receive
the left-source key-extraction pushdown described above. Do not confuse it with
the keyed cross-stream tuple form, even when both tuple inputs name the same
collection.

Cross-join with a generated accessor plus `equal_bi`:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::unavailability()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |u: &Unavailability| u.employee_idx,
        ),
    ))
```

See [Joiners](/docs/solverforge/constraints/joiners/) for joiner types and
composition.

After a cross join, choose the operation that matches the rule:

- score the joined pair directly with `penalize(...)` or `reward(...)`
- group joined pairs directly with `.group_by(|left, right| key, collector)`
- emit one retained scoring row per pair with `.project(|left, right| row)`

A cross join does not stop at two sources. A subsequent `.join((target,
equal_on(left_row_key, right_leaf_key)))` relates the whole existing row to
the new source. Each join has its own key type and domain; it need not reuse
the first join's key. For example, match an employee by index, then match that
shift's unavailability by `(employee index, date)`:

```rust
use solverforge::stream::relational::{operator::Pair, Leaf};

type Streams = ConstraintFactory<Schedule, SoftScore>;

Streams::new()
    .for_each(Schedule::shifts())
    .join((
        Streams::new().for_each(Schedule::employees()),
        equal_bi(
            |shift: &Shift| shift.employee_idx,
            |employee: &Employee| Some(employee.index),
        ),
    ))
    .join((
        Schedule::unavailability(),
        equal_on(
            |row: &Pair<Leaf<'_, Shift>, Leaf<'_, Employee>>| {
                (row.left.entity.employee_idx, row.left.entity.date)
            },
            |u: &Leaf<'_, Unavailability>| (u.entity.employee_idx, u.entity.date),
        ),
    ))
    .penalize(|_shift: &Shift, _employee: &Employee, _u: &Unavailability| SoftScore::of(1))
    .named("Shift falls on an unavailability day")
```

The first equality remains the employee-index relationship. The second uses a
compound key and can inspect either member of the borrowed pair. `equal_on`
receives `Pair<Leaf<A>, Leaf<B>>` on the left and `Leaf<C>` on the right;
access entity values through `.entity`. The target is a collection extractor,
such as the generated `Schedule::unavailability()`, not just a new key function.

Cross-stream `Bi::join` produces `Tri`; further joins produce `Quad` and `Penta`.
`stream::cross::Penta::join` enters the arbitrary-depth `Chain`, and `Chain::join` can keep
nesting operators without a fixed arity ceiling. At each step the left row is
nested: a triple is `Pair<Pair<Leaf<A>, Leaf<B>>, Leaf<C>>`. Named key functions
with explicit borrowed row types are useful for deeper chains' higher-ranked
lifetime bounds. The view-key rule applies to every continuation: `Bi::join`
reads the borrowed pair, `Tri::join` the borrowed triple, `Quad::join` the
borrowed quadruple, `Penta::join` the borrowed quintuple, and `Chain::join`
the whole `O::View<'_>`. Each right key reads `&Leaf<'_, NewEntity>` through
`.entity`. Plain entity-closure `equal_bi` is only for the first unary join;
using it at a continuation produces a type mismatch (`E0631`). Use `equal_on`
and choose the prior binding explicitly. These existing signatures are
clarified in the `0.19.14` source docs.

Since v0.19.12, including v0.19.14, continuing from cross `Penta` discards its authored penta filter.
Apply the row filter on the returned `Chain` instead. Same-source
`PentaConstraintStream` is terminal and has no join continuation.

`Tri`, `Quad`, and `Penta` keep value-oriented filter and weight closures with
three, four, or five entity arguments. `Chain` instead passes `(&Solution,
&BorrowedRow)` to filters and score-weight closures. Its dynamic weights are
non-hard by default; use `.penalize(weight).hard().named(...)` (or the reward
builder's `.hard()`) when hard classification is required. Each relationship
keeps its own indexes, and updates from any source flow through the operator
tree to the terminal.

After `.project(...)`, the projected stream can self-join retained scoring rows.
Use `equal(|row| key)` for symmetric same-key pairs and
`equal_bi(left_key, right_key)` for directed same-output row relationships such
as parent-child or predecessor-successor rows.

### `group_by`

```rust
factory.for_each(Schedule::shifts())
    .group_by(
        |shift: &Shift| shift.employee_idx,
        count(),
    )
```

See [Collectors](/docs/solverforge/constraints/collectors/) for `count`, `sum`,
`load_balance`, `consecutive_runs`, `collect_vec`, and `indexed_presence`.

Cross-join streams can group pairs without a projection step. The key function
receives the joined values as separate arguments, while the collector receives
the stream match shape as one tuple:

```rust
type Streams = ConstraintFactory<Plan, HardSoftScore>;

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
        |assignment: &Assignment, capacity: &Capacity| (assignment.id, capacity.id),
        count(),
    )
```

Grouped cross-join streams can continue into `complement(...)` when the rule
needs a row for target keys that have no joined matches:

```rust
type Streams = ConstraintFactory<Plan, HardSoftScore>;

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
        |_assignment: &Assignment, capacity: &Capacity| capacity.id,
        sum(|(assignment, _capacity): (&Assignment, &Capacity)| assignment.demand),
    )
    .complement(
        Plan::capacities(),
        |capacity: &Capacity| capacity.id,
        |_capacity: &Capacity| 0i64,
    )
```

For the first unary keyed equality cross-join, left and right unary source
membership is preserved before indexing. Filtered right-hand join sources,
flattened keyed targets, and complement sources also retain their membership
contracts. Do not generalize the left-source pushdown to other join dispatches
or to the cross-Penta continuation limitation described above.

Since `v0.19.13`, the `if_exists`/`if_not_exists` terminal builds the
count-backed `ExistenceNode`: its right side is the right stream's collection,
whose key adapter expands flattened children in place, so flattened existence
no longer creates child rows. Incremental notifications emit into
caller-owned buffers. See
[Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/).

## Constraint Node Sharing

`#[solverforge_constraints]` gives the macro crate a whole-function compiler
boundary while preserving normal fluent Rust authoring. When repeated grouped
terminals reuse the same local grouped stream binding, SolverForge updates one
retained node and refreshes separate terminal scorers from that shared state:

```rust
#[solverforge_constraints]
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    let shift_count_by_employee = Streams::new()
        .for_each(Schedule::shifts())
        .filter(|shift: &Shift| shift.employee_idx.is_some())
        .group_by(
            |shift: &Shift| shift.employee_idx.unwrap_or(usize::MAX),
            count(),
        );

    (
        shift_count_by_employee
            .penalize(|_employee_idx: &usize, count: &usize| {
                HardSoftScore::of_soft((*count as i64 - 5).max(0))
            })
            .named("Too many shifts"),
        shift_count_by_employee
            .reward(|_employee_idx: &usize, count: &usize| {
                HardSoftScore::of_soft((*count as i64).min(5))
            })
            .named("Assigned shifts"),
    )
}
```

Supported sharing covers grouped, projected grouped, direct cross grouped, and
complemented grouped streams. The compiler is conservative: same-binding reuse
shares directly, and separately written chains share only when their grouped
stream expression is syntax-proved identical inside the annotated function.
Opaque or mixed shapes that cannot be proven stay on the ordinary Rust path.
There is no public `share` or cache API.

### `balance`

`balance` calculates load imbalance across a grouping key. The key function
returns `Option<K>`; `None` values are skipped, which is useful for unassigned
entities.

```rust
factory.for_each(Schedule::shifts())
    .balance(|shift: &Shift| shift.employee_idx)
```

## Terminal Operations

### `penalize` / `reward`

Apply a fixed score impact per match, then finalize with `.named()`.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let hard = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(HardSoftScore::ONE_HARD)
    .named("Constraint name");

let soft = Streams::new()
    .for_each(Schedule::shifts())
    .reward(HardSoftScore::ONE_SOFT)
    .named("Preference bonus");
```

Use fixed score values when the constraint applies one hard or soft unit:

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let hard = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(HardSoftScore::ONE_HARD)
    .named("Hard violation");

let soft = Streams::new()
    .for_each(Schedule::shifts())
    .reward(HardSoftScore::ONE_SOFT)
    .named("Soft preference");
```

Use a typed dynamic closure when the score depends on the match. Dynamic
closure weights are non-hard metadata by default; wrap the closure in
`hard_weight(...)` when score analysis and conflict repair should classify the
constraint as hard.

```rust
type Streams = ConstraintFactory<Schedule, HardSoftScore>;

let overtime = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(hard_weight(|shift: &Shift| {
        HardSoftScore::of_hard(shift.overtime_hours() as i64)
    }))
    .named("Overtime");

let preference = Streams::new()
    .for_each(Schedule::shifts())
    .penalize(|shift: &Shift| HardSoftScore::of_soft(shift.preference_penalty()))
    .named("Preference");
```

## Joined Filter Indexes

Normal `.filter(...)` predicates stay value-oriented. The lower-level retained
filter contract also receives semantic source indexes so localized incremental
scoring can retract and re-evaluate the correct joined rows:

- same-source joins pass canonical entity indexes
- cross joins pass the left and right source indexes
- named multi-source adapters pass the semantic index for each source
- flattened rows pass the left source index and the owning right-side source
  index
- projected self-joins, including directed projected self-joins, pass each
  projected row's primary owner entity index

This matters for advanced scoring extensions and retained match inspection; it
does not change ordinary fluent `.filter(|a, b| ...)` application code.

## Full Example

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

#[solverforge_constraints]
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    (
        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),

        Streams::new()
            .for_each(Schedule::shifts())
            .join((
                Streams::new().for_each(Schedule::shifts()),
                equal_bi(
                    |left: &Shift| left.employee_idx,
                    |right: &Shift| right.employee_idx,
                ),
            ))
            .filter(|a: &Shift, b: &Shift| {
                a.id < b.id && a.employee_idx.is_some() && a.overlaps(b)
            })
            .penalize(HardSoftScore::ONE_HARD)
            .named("Overlap"),

        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift| shift.is_preferred_by_employee())
            .reward(HardSoftScore::ONE_SOFT)
            .named("Preference"),
    )
}
```

## See Also

- [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/) - scoring-only derived rows
- [Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/) - generated collection sources and `for_each`
- [Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/) - `if_exists`, `if_not_exists`, and `flatten_last`
- [Score Analysis](/docs/solverforge/constraints/score-analysis/) - inspecting score contributions
