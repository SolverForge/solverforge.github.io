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
the individual matches. For per-match justifications, use the lower-level
`solverforge::analysis` and `solverforge-scoring` APIs directly.

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
explanation independent. It retains signed scores by row handle and borrows the
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
