---
title: "Score Analysis"
linkTitle: "Score Analysis"
weight: 50
description: >
  Understand why a solution received its score with ScoreAnalysis.
---

Score analysis answers the question: **"Why does my solution have this score?"** It breaks down the total score by constraint, helping you debug constraints and explain results to users.

## ScoreAnalysis

Types that derive `#[planning_solution]` with a `constraints` path automatically implement the `Analyzable` trait, which provides the `analyze` method.

```rust
use solverforge::prelude::*;

let analysis = analyze(&solution);

println!("Total score: {:?}", analysis.score);

for constraint in &analysis.constraints {
    println!(
        "{}: {:?} (count: {})",
        constraint.constraint_ref.name,
        constraint.score,
        constraint.match_count,
    );
}
```

### `ConstraintAnalysis`

Each `ConstraintAnalysis` contains:

| Field | Description |
|---|---|
| `constraint_ref` | The `ConstraintRef` with package and name (from `.named()`) |
| `score` | Total score impact of this constraint |
| `match_count` | Number of times the constraint matched |
| `matches` | Individual `DetailedConstraintMatch` entries with justifications |

## DetailedConstraintMatch

Each match includes a `ConstraintJustification` with the entities involved:

```rust
for constraint in &analysis.constraints {
    for m in &constraint.matches {
        println!(
            "  {} -> {:?} (entities: {:?})",
            m.constraint_ref.name,
            m.score,
            m.justification.entities.iter()
                .map(|e| e.short_type_name())
                .collect::<Vec<_>>(),
        );
    }
}
```

## Use Cases

- **Debugging constraints**: Find which constraints fire and why
- **User-facing explanations**: Show users why a schedule looks the way it does
- **Constraint tuning**: Identify which constraints dominate the score

## See Also

- [Score Types](../score-types/) — Available score types
- [Constraint Streams](../constraint-streams/) — Defining constraints
