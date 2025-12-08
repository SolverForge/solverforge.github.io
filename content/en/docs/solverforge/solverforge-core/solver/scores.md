---
title: "Score Types"
linkTitle: "Scores"
weight: 30
description: "Understand SimpleScore, HardSoftScore, HardMediumSoftScore, and BendableScore"
---

# Score Types

Scores measure solution quality. SolverForge supports multiple score types.

## Score Trait

All score types implement the `Score` trait:

```rust
pub trait Score {
    fn is_feasible(&self) -> bool;
    fn is_solution_initialized(&self) -> bool;
    fn zero() -> Self;
    fn negate(&self) -> Self;
    fn add(&self, other: &Self) -> Self;
    fn subtract(&self, other: &Self) -> Self;
}
```

## Score Types

### SimpleScore

Single dimension score:

```rust
use solverforge_core::SimpleScore;

let score = SimpleScore::of(-5);
println!("{}", score);  // "-5"
```

### HardSoftScore

Two dimensions - hard constraints and soft constraints:

```rust
use solverforge_core::HardSoftScore;

// Create scores
let score = HardSoftScore::of(-2, 10);
let zero = HardSoftScore::ZERO;
let one_hard = HardSoftScore::ONE_HARD;
let one_soft = HardSoftScore::ONE_SOFT;

// Convenience constructors
let hard_only = HardSoftScore::of_hard(-5);
let soft_only = HardSoftScore::of_soft(10);

// Access components
println!("Hard: {}, Soft: {}", score.hard_score, score.soft_score);

// Display format
println!("{}", score);  // "-2hard/10soft"
```

### HardMediumSoftScore

Three dimensions - hard, medium, and soft:

```rust
use solverforge_core::HardMediumSoftScore;

let score = HardMediumSoftScore::of(-1, 5, 10);

// Convenience constructors
let hard = HardMediumSoftScore::of_hard(-2);
let medium = HardMediumSoftScore::of_medium(3);
let soft = HardMediumSoftScore::of_soft(10);

// Display format
println!("{}", score);  // "-1hard/5medium/10soft"
```

### BendableScore

Configurable number of hard and soft levels:

```rust
use solverforge_core::BendableScore;

// 2 hard levels, 3 soft levels
let score = BendableScore::of(
    vec![-1, 0],     // hard scores
    vec![5, 10, 2]   // soft scores
);
```

## Decimal Variants

For precise decimal arithmetic:

- `SimpleDecimalScore`
- `HardSoftDecimalScore`
- `HardMediumSoftDecimalScore`
- `BendableDecimalScore`

```rust
use solverforge_core::HardSoftDecimalScore;
use rust_decimal::Decimal;

let score = HardSoftDecimalScore::of(
    Decimal::from(-2),
    Decimal::new(105, 1)  // 10.5
);
```

## Feasibility

A solution is **feasible** when all hard constraints are satisfied:

```rust
use solverforge_core::HardSoftScore;

let feasible = HardSoftScore::of(0, -100);
let infeasible = HardSoftScore::of(-1, 100);

assert!(feasible.is_feasible());     // true - hard >= 0
assert!(!infeasible.is_feasible()); // false - hard < 0
```

## Score Comparison

Scores are compared lexicographically (hard first, then soft):

```rust
use solverforge_core::HardSoftScore;

// Hard score takes priority
assert!(HardSoftScore::of(0, 0) > HardSoftScore::of(-1, 1000));

// Same hard: compare soft
assert!(HardSoftScore::of(0, 10) > HardSoftScore::of(0, 5));
assert!(HardSoftScore::of(0, -5) > HardSoftScore::of(0, -10));
```

## Score Arithmetic

```rust
use solverforge_core::HardSoftScore;

let a = HardSoftScore::of(-2, 10);
let b = HardSoftScore::of(-1, 5);

// Addition
let sum = a + b;  // -3hard/15soft

// Subtraction
let diff = a - b;  // -1hard/5soft

// Negation
let neg = -a;  // 2hard/-10soft
```

## Parsing Scores

Parse score strings returned by the solver:

```rust
use solverforge_core::HardSoftScore;

// With labels
let score = HardSoftScore::parse("0hard/-5soft")?;

// Without labels
let score = HardSoftScore::parse("-2/-10")?;

// Parse and check feasibility
let score = HardSoftScore::parse(&response.score)?;
if score.is_feasible() {
    println!("Solution satisfies all hard constraints");
}
```

## Weight Strings

Penalty/reward weights use score format strings:

```rust
// HardSoftScore weights
StreamComponent::penalize("1hard/0soft")   // 1 hard point per match
StreamComponent::penalize("0hard/1soft")   // 1 soft point per match
StreamComponent::penalize("1hard/5soft")   // Both hard and soft

// SimpleScore weights
StreamComponent::penalize("1")

// HardMediumSoftScore weights
StreamComponent::penalize("0hard/1medium/0soft")
```

## Score Type Summary

| Type | Dimensions | Format | Feasible When |
|------|------------|--------|---------------|
| `SimpleScore` | 1 | `-5` | score >= 0 |
| `HardSoftScore` | 2 | `-2hard/10soft` | hard >= 0 |
| `HardMediumSoftScore` | 3 | `-1hard/5medium/10soft` | hard >= 0 |
| `BendableScore` | N | `[-1, 0]/[5, 10, 2]` | all hard >= 0 |

## Constants

```rust
use solverforge_core::HardSoftScore;

HardSoftScore::ZERO      // 0hard/0soft
HardSoftScore::ONE_HARD  // 1hard/0soft
HardSoftScore::ONE_SOFT  // 0hard/1soft
```
