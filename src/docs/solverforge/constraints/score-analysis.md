---
title: "Score Analysis"
linkTitle: "Score Analysis"
weight: 50
description: >
  Understand why a solution received its score with ScoreAnalysis.
---

Score analysis answers the question: **"Why does my solution have this score?"**
It breaks down the total score by constraint, helping you debug constraints and
explain results to users.

## ScoreAnalysis

Types that derive `#[planning_solution]` with a `constraints` path implement
the `Analyzable` trait, which provides the `analyze` method. This program
analyzes a two-shift plan of the
[example model](/docs/solverforge/constraints/#example-model): one shift is
unassigned and the other falls on its employee's unavailable day. It adds
`src/main.rs` to the example model:

<!-- rust: crate=score-analysis extends=schedule file=src/main.rs -->
```rust
mod constraints;
mod domain;

use domain::{Employee, Schedule, Shift, Unavailability};
use solverforge::Analyzable;

fn shift(id: usize, employee_idx: Option<usize>) -> Shift {
    Shift {
        id,
        date: 2,
        start: 8,
        end: 16,
        required_skill: "nurse".into(),
        preferred_employee: None,
        employee_idx,
    }
}

fn main() {
    let solution = Schedule {
        employees: vec![Employee {
            index: 0,
            name: "Amina".into(),
            skills: vec!["nurse".into()],
            available_days: vec![1],
            max_hours: 40,
        }],
        unavailability: vec![Unavailability { id: 0, employee_idx: 0, date: 2 }],
        shifts: vec![shift(0, Some(0)), shift(1, None)],
        score: None,
    };

    let analysis = solution.analyze();

    println!("Total score: {}", analysis.score);

    for constraint in &analysis.constraints {
        println!(
            "{}: {} (count: {}, weight multiplier: {})",
            constraint.name,
            constraint.score,
            constraint.match_count,
            constraint.weight_multiplier,
        );
    }
}
```

`cargo run` prints one row per named constraint, including the ones that do
not match:

<!-- rust: crate=score-analysis output -->
```text
Total score: -2hard/0soft
Unassigned shift: -1hard/0soft (count: 1, weight multiplier: 1)
Overlapping shifts: 0hard/0soft (count: 0, weight multiplier: 1)
Unavailable employee: -1hard/0soft (count: 1, weight multiplier: 1)
Preferred employee: 0hard/0soft (count: 0, weight multiplier: 1)
```

### `ConstraintAnalysis`

Each `ConstraintAnalysis` contains:

| Field               | Description                                                     |
| ------------------- | --------------------------------------------------------------- |
| `name`              | Constraint name (from `.named()`)                               |
| `weight_multiplier` | Runtime weight multiplier bound to the constraint; `0` disables it, `1` keeps the authored weight |
| `score`             | Total score impact of this constraint, after the multiplier     |
| `match_count`       | Number of times the constraint matched                          |

`solution.analyze()` returns this summarized view: totals per constraint, not
the individual matches. It always scores with the solution's `constraints`
function. A retained job's `SolverManager::analyze_snapshot` instead uses the
provider the job scored with (`score_director.constraint_provider`), and fails
with `SnapshotAnalysisDisabled` when the job ran with
`score_director.constraint_match_enabled = false`; see
[Score Director](/docs/solverforge/solver/configuration/#score-director). For
per-match justifications, read the matches from a score director.

## Constraint Matches

`ScoreDirector::constraint_analyses()` lists every constraint with its
matches. Each match carries its score and a justification naming the entities
behind it. This program scores three shifts of the example model: shift 7
falls on its employee's unavailable day, and shifts 8 and 9 are unassigned:

<!-- rust: crate=score-matches extends=schedule file=src/main.rs -->
```rust
mod constraints;
mod domain;

use constraints::define_constraints;
use domain::{Employee, Schedule, Shift, Unavailability};
use solverforge::ScoreDirector;

fn shift(id: usize, date: u32, employee_idx: Option<usize>) -> Shift {
    Shift {
        id,
        date,
        start: 8,
        end: 16,
        required_skill: "nurse".into(),
        preferred_employee: None,
        employee_idx,
    }
}

fn main() {
    let solution = Schedule {
        employees: vec![Employee {
            index: 0,
            name: "Amina".into(),
            skills: vec!["nurse".into()],
            available_days: vec![1],
            max_hours: 40,
        }],
        unavailability: vec![Unavailability { id: 4, employee_idx: 0, date: 2 }],
        shifts: vec![shift(7, 2, Some(0)), shift(8, 2, None), shift(9, 3, None)],
        score: None,
    };

    let mut director = ScoreDirector::new(solution, define_constraints());
    println!("Total score: {}", director.calculate_score());

    for analysis in director.constraint_analyses() {
        for found in &analysis.matches {
            let entities: Vec<String> = found
                .justification
                .entities
                .iter()
                .map(|entity| {
                    let id = entity.planning_id.as_deref().unwrap_or("-");
                    format!("{} {id}", entity.short_type_name())
                })
                .collect();
            println!("{}: {} [{}]", analysis.name(), found.score, entities.join(", "));
        }
    }
}
```

`cargo run` prints one line per match:

<!-- rust: crate=score-matches output -->
```text
Total score: -3hard/0soft
Unassigned shift: -1hard/0soft [Shift 8]
Unassigned shift: -1hard/0soft [Shift 9]
Unavailable employee: -1hard/0soft [Shift 7]
```

Each entity in a justification is an `EntityRef`:

| Field | Description |
| ----- | ----------- |
| `type_name` | The entity's type name; `short_type_name()` drops the module path |
| `display` | The entity's `Debug` rendering, for display only |
| `planning_id` | The entity's `#[planning_id]`, rendered as a string |

`planning_id` is rendered with `Display` when the id type implements it (`7`,
`anna`), otherwise with `Debug` (a tuple-struct id renders as `ShiftId(7)`).
Equal ids render equally, so use it to look up the record behind a match
instead of parsing `display`. An entity streamed from a model collection whose
type has a `#[planning_id]` field carries it; types without one, and values
streamed from a hand-built source, report `None`. Ids are read only when
matches are explained, never while scoring.

A grouped or complemented constraint reports one match per group whose weight
is not zero, justified by the entities in the group; a complemented key
without a group is justified by its target entity. A projected row is
justified by the entities it was projected from. Match scores add up to the
constraint's score. Analysis keeps no copy of your entities: it records the
type name and `Debug` rendering, so constraints need entities that implement
`Debug` (`#[planning_entity]` and `#[problem_fact]` derive it), and no
constraint requires `Clone`.

Lower-level scoring metadata uses `ConstraintRef` as the constraint identity.
Analysis views borrow that identity from the owning constraint rather than cloning it into public reporting types. That means
package-qualified constraints can share a short display name without collapsing
into one constraint during scoring, analysis, or conflict-repair lookup.
Configured constraint keys match that metadata exactly: package-qualified
constraints use `ConstraintRef::full_name()` strings, while package-less
constraints use the short name.

Constraint node sharing does not collapse analysis rows. When
`#[solverforge_constraints]` emits one shared grouped node for several terminal
constraints, each terminal still contributes its own constraint metadata,
score, match count, and detailed explanation. The shared node only removes
duplicate retained update work.

Direct pair, chained-join, existence, flattened, unary complemented, and grouped
terminals use `OperatorTerminal`; a `#[solverforge_constraints]` chain of
grouped terminals finalizes them onto one shared operator owner through
`SharedOperatorTerminal`, keeping each named terminal's score, metadata, and
explanation independent. That shared owner is a grouped operator
(`GroupedOperator`). It retains signed scores by row handle and borrows the
complete operator row for scoring and explanation; it does not retain borrowed
entities or solution references. This execution change does not merge terminal
identities or change the summarized `solution.analyze()` API.

## Use Cases

- **Debugging constraints**: Find which constraints fire and why
- **User-facing explanations**: Show users why a schedule looks the way it does
- **Constraint tuning**: Identify which constraints dominate the score

## See Also

- [Score Types](/docs/solverforge/constraints/score-types/) — Available score types
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) — Defining constraints
