---
title: "Domain Modeling"
linkTitle: "Domain Modeling"
weight: 30
description: >
  Define planning solutions, entities, and problem facts using Rust derive macros.
---

SolverForge uses derive macros to turn your Rust structs into a planning domain. There are three key concepts:

| Concept               | Macro                  | Purpose                                                        |
| --------------------- | ---------------------- | -------------------------------------------------------------- |
| **Planning Solution** | `#[planning_solution]` | The top-level container — holds entities, facts, and the score |
| **Planning Entity**   | `#[planning_entity]`   | Something the solver changes (assigns variables to)            |
| **Problem Fact**      | `#[problem_fact]`      | Immutable input data the solver reads but doesn't modify       |

```
Planning Solution
├── problem_fact_collection  → Vec<ProblemFact>   (inputs)
├── planning_entity_collection → Vec<Entity>      (solver changes these)
└── planning_score           → Option<ScoreType>   (current quality)

Planning Entity
├── planning_variable(value_range_provider = "facts")       (single assignment)
└── planning_list_variable(element_collection = "elements") (assignment + order)
```

## How It Works

1. Annotate your structs with the appropriate derive macros
2. Mark fields with attribute macros to tell the solver their role
3. The macros generate trait implementations that the solver uses at runtime

The derive macros generate implementations of `PlanningSolution`,
`PlanningEntity`, and `ProblemFact` automatically. In the common stock runtime,
planning variables name their value source with `value_range_provider = "solution_field"`
and `#[planning_solution]` generates typed stream source methods such as
`factory.for_each(Schedule::shifts())`.

## The Model Manifest

Every model needs a `solverforge::planning_model!` manifest. It lists the
modules that hold the model, and it is what makes a `#[planning_solution]`
solvable: without it the solution type fails to compile with
`PlanningModelSupport is not satisfied`. The manifest lives in
`src/domain/mod.rs` and its modules are files under the `root` directory.
It accepts only `mod name;` and `pub use ...;` items; a re-export can rename a
type (`pub use shift::Shift as Duty;`), but solver configuration still names
the canonical descriptor type, such as `Shift.employee_idx`.

The model these pages build: start a crate with `cargo new`, run
`cargo add solverforge@=0.24.0`, and add these files.

`src/domain/mod.rs`:

<!-- rust: crate=modeling file=src/domain/mod.rs -->
```rust
solverforge::planning_model! {
    root = "src/domain";

    mod employee;
    mod shift;
    mod schedule;

    pub use employee::Employee;
    pub use shift::Shift;
    pub use schedule::Schedule;
}
```

`src/domain/employee.rs`:

<!-- rust: crate=modeling file=src/domain/employee.rs -->
```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub id: usize,
    pub name: String,
    pub skills: Vec<String>,
}
```

`src/domain/shift.rs`:

<!-- rust: crate=modeling file=src/domain/shift.rs -->
```rust
use solverforge::prelude::*;

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub required_skill: String,

    #[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
    pub employee_idx: Option<usize>,
}
```

`src/domain/schedule.rs`:

<!-- rust: crate=modeling file=src/domain/schedule.rs -->
```rust
use solverforge::prelude::*;

use super::{Employee, Shift};

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

`src/constraints.rs` holds the constraint set the solution names:

<!-- rust: crate=modeling file=src/constraints.rs -->
```rust
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;

use crate::domain::{Employee, Schedule, Shift};

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
            .join((
                Streams::new().for_each(Schedule::employees()),
                equal_bi(|shift: &Shift| shift.employee_idx, |employee: &Employee| Some(employee.id)),
            ))
            .filter(|shift: &Shift, employee: &Employee| !employee.skills.contains(&shift.required_skill))
            .penalize(HardSoftScore::ONE_HARD)
            .named("Missing skill"),
    )
}
```

`employee_idx` stores a position in `Schedule::employees`; the "Missing skill"
join relies on each employee's `id` being that position.

Declare both modules in the crate root (`mod constraints; mod domain;`).

Scalar runtime metadata is descriptor-addressed. The generated compact
`variable_index` remains an internal getter/setter dispatch index, while runtime
hook attachment and ordering use the descriptor index plus variable name. That
means Rust module declaration order is not a modeling contract.

At solve time, the generated model becomes one value-owned `RuntimeModel` plus
a typed search declaration. SolverForge resolves descriptor targets, stable list
sources, scalar/list capabilities, groups, providers, and config into an
immutable graph before the first phase runs. The macro path therefore uses the
same compiled lifecycle as dynamic bridge models without moving schema discovery
into candidate loops.

## Sections

- **[Planning Solutions](/docs/solverforge/modeling/planning-solutions/)** — The top-level container struct
- **[Planning Entities](/docs/solverforge/modeling/planning-entities/)** — Structs the solver modifies
- **[Problem Facts](/docs/solverforge/modeling/problem-facts/)** — Immutable input data
- **[List Variables](/docs/solverforge/modeling/list-variables/)** — Ordered sequence variables for routing/sequencing

## See Also

- [docs.rs/solverforge](https://docs.rs/solverforge) — Full API reference
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/) — Concrete worked example built on the generic CLI scaffold
- [SolverForge Lessons Use Case](/docs/getting-started/solverforge-lessons-use-case/) — Two scalar planning variables on one lesson entity
