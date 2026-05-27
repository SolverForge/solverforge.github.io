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

Types that derive `#[planning_solution]` with a `constraints` path automatically implement the `Analyzable` trait, which provides the `analyze` method.

```rust
use solverforge::prelude::*;
use solverforge::Analyzable;

let analysis = solution.analyze();

println!("Total score: {:?}", analysis.score);

for constraint in &analysis.constraints {
    println!(
        "{}: {:?} (count: {})",
        constraint.name,
        constraint.score,
        constraint.match_count,
    );
}
```

### `ConstraintAnalysis`

Each `ConstraintAnalysis` contains:

| Field         | Description                                      |
| ------------- | ------------------------------------------------ |
| `name`        | Human-readable constraint name (from `.named()`) |
| `weight`      | Constraint weight used when scoring              |
| `score`       | Total score impact of this constraint            |
| `match_count` | Number of times the constraint matched           |

The stock `solution.analyze()` method returns this summarized view. If you need
full per-match justifications and indictment maps, use the lower-level
`solverforge-scoring` analysis APIs directly.

Lower-level scoring metadata uses `ConstraintRef` as the constraint identity.
Since the `0.11.x` release line, analysis views borrow that identity from the owning
constraint rather than cloning it into public reporting types. That means
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

## Use Cases

- **Debugging constraints**: Find which constraints fire and why
- **User-facing explanations**: Show users why a schedule looks the way it does
- **Constraint tuning**: Identify which constraints dominate the score

## See Also

- [Score Types](/docs/solverforge/constraints/score-types/) — Available score types
- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) — Defining constraints
