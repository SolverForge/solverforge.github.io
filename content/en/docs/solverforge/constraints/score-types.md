---
title: "Score Types"
linkTitle: "Score Types"
weight: 40
description: >
  Choose the right score type for your optimization problem.
---

The score represents the quality of a solution. SolverForge provides several score types with increasing granularity. Choose the simplest one that captures your constraint hierarchy.

## Available Score Types

| Score Type | Levels | When to Use |
|---|---|---|
| `SoftScore` | 1 (soft) | All constraints are preferences, no hard rules |
| `HardSoftScore` | 2 (hard, soft) | **Most common** — hard constraints must be satisfied, soft are optimized |
| `HardMediumSoftScore` | 3 (hard, medium, soft) | Three priority tiers (e.g., must / should / nice-to-have) |
| `HardSoftDecimalScore` | 2 (hard, soft) | Same as HardSoftScore but with decimal precision (i64 auto-scaled by 100,000) |
| `BendableScore<H, S>` | N | Custom number of hard and soft levels (const generics) |

## HardSoftScore (Most Common)

```rust
use solverforge::prelude::*;

// Constants for common impacts
HardSoftScore::ZERO
HardSoftScore::ONE_HARD        // 1 hard, 0 soft
HardSoftScore::ONE_SOFT        // 0 hard, 1 soft

// Custom values
HardSoftScore::of_hard(-5)
HardSoftScore::of_soft(-10)
HardSoftScore::of(-2, -15)     // -2 hard, -15 soft
```

**Hard constraints** are rules that must not be broken (e.g., "no employee works two shifts at the same time"). A solution with any hard penalty is **infeasible**.

**Soft constraints** are preferences to optimize (e.g., "prefer assigning employees to their preferred shifts"). The solver minimizes soft penalties after satisfying all hard constraints.

```rust
let score = HardSoftScore::of(-1, -50);
score.is_feasible()  // false — has hard violations
```

## SoftScore

For problems with only preferences and no hard rules:

```rust
SoftScore::ZERO
SoftScore::ONE
SoftScore::of(-5)
```

## HardMediumSoftScore

Three-level priority:

```rust
HardMediumSoftScore::of(-1, 0, -10)
// hard: must not violate
// medium: strongly prefer to satisfy
// soft: nice to have
```

## HardSoftDecimalScore

Like HardSoftScore but with fixed-point decimal precision. Values are `i64` internally, auto-scaled by 100,000:

```rust
HardSoftDecimalScore::ZERO
HardSoftDecimalScore::ONE_HARD    // scaled to 100,000
HardSoftDecimalScore::ONE_SOFT

HardSoftDecimalScore::of(-1, -3)          // auto-scaled: -100000, -300000
HardSoftDecimalScore::of_scaled(-150000, -370000)  // raw scaled values
```

## BendableScore

Configurable number of hard and soft levels using const generics:

```rust
// 2 hard levels, 3 soft levels
let score = BendableScore::<2, 3>::of([-1, 0], [-5, -3, -1]);
let zero = BendableScore::<2, 3>::zero();
```

Use when you need more than three priority tiers.

## Score Arithmetic

All score types support standard operations:

```rust
let a = HardSoftScore::of(-1, -5);
let b = HardSoftScore::of(0, -3);
let sum = a + b;           // (-1, -8)
```

## Choosing a Score Type

1. **Start with `HardSoftScore`** — it covers most problems
2. If you need decimal precision, use `HardSoftDecimalScore`
3. If you have three clear priority tiers, use `HardMediumSoftScore`
4. If you need more tiers, use `BendableScore`
5. If you have no hard constraints at all, use `SoftScore`

## See Also

- [Constraint Streams](../constraint-streams/) — Using scores in `penalize` / `reward`
- [Score Analysis](../score-analysis/) — Understanding score breakdowns
