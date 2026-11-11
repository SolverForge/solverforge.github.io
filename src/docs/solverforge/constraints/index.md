---
title: "Constraints"
linkTitle: "Constraints"
weight: 40
description: >
  Define business rules using constraint streams, joiners, collectors, and score types.
---

Constraints are the business rules that define what makes a good solution.
SolverForge uses a **constraint streams API** - a declarative, composable way to
express rules that reads like a pipeline of filters and transformations.

## How Constraints Work

1. **Select** entities or facts from your solution using generated source methods
2. **Filter, project, join, or group** to narrow down the matches
3. **Penalize or reward** to affect the score
4. **Name** the constraint with `.named()`

<!-- rust: crate=schedule in=example -->
```rust
Streams::new()
    .for_each(Schedule::shifts())                // Select all shifts
    .filter(|s: &Shift| s.employee_idx.is_none()) // Keep unassigned ones
    .penalize(HardSoftScore::ONE_HARD)           // Penalize each
    .named("Unassigned shift")                   // Finalize
```

Constraints are returned as a tuple implementing `ConstraintSet<S, Sc>`, which
the solver evaluates incrementally as it explores moves. Generated solution
sources such as `Schedule::shifts()` preserve source metadata for localized
incremental updates. Projected streams can emit retained scoring rows from one
source or one joined pair, grouped streams can use collectors such as
`consecutive_runs(...)`, `collect_vec(...)`, and `indexed_presence(...)`, and
projected self-joins can be symmetric with `equal(...)` or directed with
`equal_bi(left_key, right_key)`. Direct cross joins can group joined pairs
without projecting them first. Chained joins use
`.join((target, equal_on(left_row_key, right_leaf_key)))`, with an independent
key domain for each relationship. Every second or later join takes the whole
borrowed left row and a right `Leaf` view; read fields through `.entity`.
Plain entity-closure `equal_bi` is for the first join, not a continuation.
`Tri`, `Quad`, and `Penta` provide named
cross-stream arity adapters; cross `Penta::join` continues into `Chain` at
arbitrary depth. That continuation drops an authored penta filter; apply the row
filter on the returned `Chain`. Same-source
`PentaConstraintStream` is terminal.
Direct pair scoring, chained joins, existence, flattening, and unary complemented
groups execute through concrete `stream::relational::operator` trees and the shared
`OperatorTerminal`, not per-shape retained engines.
Direct cross-join groups can also call
`complement(...)` against generated target sources. On the first unary keyed
equality cross-join, unary source membership is checked before keys and pairs
are created; post-join filters remain row filters. This left-source pushdown
does not apply to comparison, overlap, composed-condition, predicate, or
same-source self-join dispatch. Fluent right targets implement
`CollectionExtract`; arbitrary derived inputs belong at low-level `JoinNode`.
See [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) for
nullable-row examples and the exact dispatch boundary.

Annotate reusable constraint functions with `#[solverforge_constraints]` when
the same grouped stream feeds multiple named terminal constraints. SolverForge
then shares the retained grouped node work while keeping each terminal
constraint's name, ordering, metadata, and explanation independent. The
lower-level constraint metadata borrows full `ConstraintRef` identity from the
owning constraint. Package-qualified constraints use
`ConstraintRef::full_name()` as the configured key; package-less constraints use
the short name.

## Example model

Every example in the Constraints pages runs against this shift-scheduling
model. Start a binary crate with `cargo new` and
`cargo add solverforge@=0.26.1`, then add these files.

`src/domain/mod.rs` registers the model. `planning_model!` accepts only
`mod name;` and `pub use ...;` items, and every planning type must be
reachable through it:

<!-- rust: crate=schedule file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod model;

    pub use model::{Employee, Schedule, Shift, Unavailability};
}
```

`src/domain/model.rs` holds the types. `employee_idx` stores a position in
`Schedule::employees`, so `Employee::index` is that position:

<!-- rust: crate=schedule file=src/domain/model.rs -->
```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub index: usize,
    pub name: String,
    pub skills: Vec<String>,
    pub available_days: Vec<u32>,
    pub max_hours: i64,
}

#[problem_fact]
pub struct Unavailability {
    #[planning_id]
    pub id: usize,
    pub employee_idx: usize,
    pub date: u32,
}

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub date: u32,
    pub start: u32,
    pub end: u32,
    pub required_skill: String,
    pub preferred_employee: Option<usize>,
    #[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
    pub employee_idx: Option<usize>,
}

impl Shift {
    pub fn hours(&self) -> i64 {
        i64::from(self.end - self.start)
    }

    pub fn overlaps(&self, other: &Shift) -> bool {
        self.date == other.date && self.start < other.end && other.start < self.end
    }

    pub fn is_preferred(&self) -> bool {
        self.employee_idx.is_some() && self.employee_idx == self.preferred_employee
    }
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[problem_fact_collection]
    pub unavailability: Vec<Unavailability>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

`src/constraints.rs` is the constraint set the solution names:

<!-- rust: crate=schedule file=src/constraints.rs -->
```rust
use solverforge::prelude::*;
use solverforge::stream::joiner::*;

use crate::domain::{Schedule, Shift, Unavailability};

#[solverforge_constraints]
pub fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;

    (
        Streams::new()
            .for_each(Schedule::shifts())
            .unassigned()
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unassigned shift"),
        Streams::new()
            .for_each(Schedule::shifts())
            .join(equal(|shift: &Shift| shift.employee_idx))
            .filter(|a: &Shift, b: &Shift| a.employee_idx.is_some() && a.overlaps(b))
            .penalize(HardSoftScore::ONE_HARD)
            .named("Overlapping shifts"),
        Streams::new()
            .for_each(Schedule::shifts())
            .if_exists((
                Streams::new().for_each(Schedule::unavailability()),
                equal_bi(
                    |shift: &Shift| shift.employee_idx.map(|employee| (employee, shift.date)),
                    |u: &Unavailability| Some((u.employee_idx, u.date)),
                ),
            ))
            .penalize(HardSoftScore::ONE_HARD)
            .named("Unavailable employee"),
        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift: &Shift| shift.is_preferred())
            .reward(HardSoftScore::ONE_SOFT)
            .named("Preferred employee"),
    )
}
```

The shorter examples on these pages are stream expressions. Each one compiles
in place of the `// example` line in this file:

<!-- rust: crate=schedule file=src/examples.rs slot=example -->
```rust
use solverforge::prelude::*;
use solverforge::stream::joiner::*;

use crate::domain::{Employee, Schedule, Shift, Unavailability};

type Streams = ConstraintFactory<Schedule, HardSoftScore>;

pub fn example() {
    let _ = {
        // example
    };
}
```

Declare the modules in the crate root: `mod constraints; mod domain;`, plus
`mod examples;` while you try the examples.

## Sections

- **[Constraint Streams](/docs/solverforge/constraints/constraint-streams/)** - The core stream API
- **[Constraint Node Sharing](/docs/solverforge/constraints/node-sharing/)** - `#[solverforge_constraints]` and repeated grouped terminal sharing
- **[Constraint Factory Methods](/docs/solverforge/constraints/constraint-factory-methods/)** - `ConstraintFactory`, generated collection sources, and lower-level `for_each`
- **[Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)** - Scoring-only rows, joined-pair `.project(...)`, and directed projected self-joins
- **[Existence & Flattening](/docs/solverforge/constraints/existence-and-flattening/)** - `if_exists`, `if_not_exists`, and `flatten_last`
- **[Joiners](/docs/solverforge/constraints/joiners/)** - Combining multiple entity streams
- **[Collectors](/docs/solverforge/constraints/collectors/)** - Aggregation functions for `group_by`
- **[Shift-Group Uniformity](/docs/solverforge/constraints/shift-group-uniformity/)** - A worked grouped-penalty example over operators
- **[Score Types](/docs/solverforge/constraints/score-types/)** - Available score types and when to use each
- **[Score Analysis](/docs/solverforge/constraints/score-analysis/)** - Understanding and explaining scores
