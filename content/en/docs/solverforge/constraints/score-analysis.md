---
title: "Score Analysis"
linkTitle: "Score Analysis"
weight: 50
description: >
  Understand why a solution received its score with ScoreAnalysis and ScoreExplanation.
---

Score analysis answers the question: **"Why does my solution have this score?"** It breaks down the total score by constraint and by entity, helping you debug constraints and explain results to users.

## ScoreAnalysis

`ScoreAnalysis` provides a per-constraint breakdown of the score.

```rust
let analysis = analyze(&solution, &constraint_provider);

println!("Total score: {:?}", analysis.score());

for constraint in analysis.constraint_analyses() {
    println!(
        "{}: {} (count: {})",
        constraint.constraint_name(),
        constraint.score(),
        constraint.match_count(),
    );
}
```

### `ConstraintAnalysis`

Each `ConstraintAnalysis` contains:

| Method | Description |
|---|---|
| `constraint_name()` | The name passed to `penalize()` / `reward()` |
| `score()` | Total score impact of this constraint |
| `match_count()` | Number of times the constraint matched |
| `matches()` | Individual constraint matches with their justifications |

## ScoreExplanation

`ScoreExplanation` extends `ScoreAnalysis` with entity-level details.

```rust
let explanation = explain(&solution, &constraint_provider);

// Same constraint-level analysis
for constraint in explanation.constraint_analyses() {
    // ...
}
```

## IndictmentMap

The `IndictmentMap` shows which **entities** are responsible for score impacts — useful for highlighting problem areas in a UI.

```rust
let indictments = explanation.indictment_map();

for (entity_id, indictment) in indictments.iter() {
    println!(
        "Entity {}: score impact {}",
        entity_id,
        indictment.score(),
    );
    for constraint_match in indictment.constraint_matches() {
        println!("  - {}: {}", constraint_match.constraint_name(), constraint_match.score());
    }
}
```

This tells you, for example, "Employee Alice causes -3 hard because she's assigned to 3 overlapping shifts."

## Use Cases

- **Debugging constraints**: Find which constraints fire and why
- **User-facing explanations**: Show users why a schedule looks the way it does
- **Constraint tuning**: Identify which constraints dominate the score

## See Also

- [Score Types](../score-types/) — Available score types
- [Constraint Streams](../constraint-streams/) — Defining constraints
