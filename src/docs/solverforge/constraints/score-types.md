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

<!-- rust: crate=score-types excerpt -->
```rust
let zero = HardSoftScore::ZERO;
let one_hard = HardSoftScore::ONE_HARD; // 1 hard, 0 soft
let one_soft = HardSoftScore::ONE_SOFT; // 0 hard, 1 soft
let hard = HardSoftScore::of_hard(-5);
let soft = HardSoftScore::of_soft(-10);
let both = HardSoftScore::of(-2, -15); // -2 hard, -15 soft
```

**Hard constraints** are rules that must not be broken (e.g., "no employee works two shifts at the same time"). A solution with any hard penalty is **infeasible**.

**Soft constraints** are preferences to optimize (e.g., "prefer assigning employees to their preferred shifts"). The solver minimizes soft penalties after satisfying all hard constraints.

<!-- rust: crate=score-types excerpt -->
```rust
let score = HardSoftScore::of(-1, -50);
println!("feasible: {}", score.is_feasible()); // false: it has a hard violation
```

## SoftScore

For problems with only preferences and no hard rules:

<!-- rust: crate=score-types excerpt -->
```rust
let soft_only = [SoftScore::ZERO, SoftScore::ONE, SoftScore::of(-5)];
```

## HardMediumSoftScore

Three-level priority:

<!-- rust: crate=score-types excerpt -->
```rust
let tiers = HardMediumSoftScore::of(-1, 0, -10);
// hard: must not violate
// medium: strongly prefer to satisfy
// soft: nice to have
```

## HardSoftDecimalScore

Like HardSoftScore but with fixed-point decimal precision. Values are `i64` internally, scaled by 100,000:

<!-- rust: crate=score-types excerpt -->
```rust
let decimal = HardSoftDecimalScore::of(-1, -3); // stored as -100000, -300000
let precise = HardSoftDecimalScore::of_scaled(-150000, -370000); // raw scaled values
println!("{decimal} {precise}");
println!("scaled hard level: {}", decimal.hard_scaled());
```

## BendableScore

Configurable number of hard and soft levels using const generics:

<!-- rust: crate=score-types excerpt -->
```rust
// 2 hard levels, 3 soft levels
let bendable = BendableScore::<2, 3>::of([-1, 0], [-5, -3, -1]);
let bendable_zero = BendableScore::<2, 3>::zero();
```

Use when you need more than three priority tiers.

## Score Arithmetic

All score types support standard operations:

<!-- rust: crate=score-types excerpt -->
```rust
let a = HardSoftScore::of(-1, -5);
let b = HardSoftScore::of(0, -3);
let sum = a + b; // -1hard/-8soft
```

## Try It

The snippets above come from this program. In a binary crate with
`cargo add solverforge@=0.26.1`, save it as `src/main.rs`:

<!-- rust: crate=score-types file=src/main.rs -->
```rust
use solverforge::prelude::*;

fn main() {
    let zero = HardSoftScore::ZERO;
    let one_hard = HardSoftScore::ONE_HARD; // 1 hard, 0 soft
    let one_soft = HardSoftScore::ONE_SOFT; // 0 hard, 1 soft
    let hard = HardSoftScore::of_hard(-5);
    let soft = HardSoftScore::of_soft(-10);
    let both = HardSoftScore::of(-2, -15); // -2 hard, -15 soft
    println!("{zero} {one_hard} {one_soft} {hard} {soft} {both}");

    let score = HardSoftScore::of(-1, -50);
    println!("feasible: {}", score.is_feasible()); // false: it has a hard violation
    println!("hard beats soft: {}", HardSoftScore::of(0, -1000) > HardSoftScore::of(-1, 0));

    let soft_only = [SoftScore::ZERO, SoftScore::ONE, SoftScore::of(-5)];
    println!("{} {} {}", soft_only[0], soft_only[1], soft_only[2]);

    let tiers = HardMediumSoftScore::of(-1, 0, -10);
    // hard: must not violate
    // medium: strongly prefer to satisfy
    // soft: nice to have
    println!("{tiers}");

    let decimal = HardSoftDecimalScore::of(-1, -3); // stored as -100000, -300000
    let precise = HardSoftDecimalScore::of_scaled(-150000, -370000); // raw scaled values
    println!("{decimal} {precise}");
    println!("scaled hard level: {}", decimal.hard_scaled());

    // 2 hard levels, 3 soft levels
    let bendable = BendableScore::<2, 3>::of([-1, 0], [-5, -3, -1]);
    let bendable_zero = BendableScore::<2, 3>::zero();
    println!("{bendable} {bendable_zero}");

    let a = HardSoftScore::of(-1, -5);
    let b = HardSoftScore::of(0, -3);
    let sum = a + b; // -1hard/-8soft
    println!("{sum}");
}
```

`cargo run` prints:

<!-- rust: crate=score-types output -->
```text
0hard/0soft 1hard/0soft 0hard/1soft -5hard/0soft 0hard/-10soft -2hard/-15soft
feasible: false
hard beats soft: true
0 1 -5
-1hard/0medium/-10soft
-1hard/-3soft -1.5hard/-3.7soft
scaled hard level: -100000
[-1/0]hard/[-5/-3/-1]soft [0/0]hard/[0/0/0]soft
-1hard/-8soft
```

## Dynamic Binding Scores

`solverforge_bridge::DynamicScore`, from the separate `solverforge-bridge`
crate, is the binding-facing three-level value
`{ hard: i64, medium: i64, soft: i64 }`. It has no family field. Equality,
ordering, hashing, zero, and arithmetic compare or operate on levels only,
independently of the thread computing the score. Keep unused levels zero;
decimal hard/soft levels store values scaled by 100,000.

Construct it with `DynamicScore::of(hard, medium, soft)`, `soft(soft)`, or
`hard_soft(hard, soft)`. Select host-facing levels with `family_levels(family)`.
`scoped_dynamic_score_family(family, callback)` controls thread-local display
and `ParseableScore::parse` units, not score values; the active family can be
read with `active_dynamic_score_family()`. Under `HardSoftDecimal`, whole-number
parts scale too, so parsing inverts display. Parallel scoring workers need no
family scope. These bridge contracts do not change native score-type APIs.

## Choosing a Score Type

1. **Start with `HardSoftScore`** — it covers most problems
2. If you need decimal precision, use `HardSoftDecimalScore`
3. If you have three clear priority tiers, use `HardMediumSoftScore`
4. If you need more tiers, use `BendableScore`
5. If you have no hard constraints at all, use `SoftScore`

## See Also

- [Constraint Streams](/docs/solverforge/constraints/constraint-streams/) — Using scores in `penalize` / `reward`
- [Score Analysis](/docs/solverforge/constraints/score-analysis/) — Understanding score breakdowns
