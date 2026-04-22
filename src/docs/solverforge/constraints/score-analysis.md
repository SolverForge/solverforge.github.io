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

let analysis = analyze(&solution);

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

| Field | Description |
|---|---|
| `name` | Human-readable constraint name (from `.named()`) |
| `weight` | Constraint weight used when scoring |
| `score` | Total score impact of this constraint |
| `match_count` | Number of times the constraint matched |

The stock `analyze(&solution)` helper returns this summarized view. If you need
full per-match justifications and indictment maps, use the lower-level
`solverforge-scoring` analysis APIs directly.

## Use Cases

- **Debugging constraints**: Find which constraints fire and why
- **User-facing explanations**: Show users why a schedule looks the way it does
- **Constraint tuning**: Identify which constraints dominate the score

## See Also

- [Score Types](../score-types/) — Available score types
- [Constraint Streams](../constraint-streams/) — Defining constraints
