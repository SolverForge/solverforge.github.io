---
title: "Score Types"
linkTitle: "Score Types"
weight: 40
description: >
  Choose the right score type for your constraints.
---

**Score types** determine how constraint violations and rewards are measured. Choose the type that matches your problem's structure.

## Available Score Types

| Score Type | Levels | Use Case |
|------------|--------|----------|
| `SimpleScore` | 1 | Single optimization objective |
| `HardSoftScore` | 2 | Feasibility + optimization |
| `HardMediumSoftScore` | 3 | Hard + important + nice-to-have |
| `BendableScore` | N | Custom number of levels |
| `*DecimalScore` variants | - | Decimal precision |

## SimpleScore

For single-objective optimization:

```python
from solverforge_legacy.solver.score import SimpleScore

# In domain model
score: Annotated[SimpleScore, PlanningScore] = field(default=None)

# In constraints
.penalize(SimpleScore.ONE)
.reward(SimpleScore.of(10))
```

**Use when:** You only need to maximize or minimize one thing (e.g., total profit, total distance).

## HardSoftScore

The most common type—separates feasibility from optimization:

```python
from solverforge_legacy.solver.score import HardSoftScore

# In domain model
score: Annotated[HardSoftScore, PlanningScore] = field(default=None)

# In constraints
.penalize(HardSoftScore.ONE_HARD)     # Broken constraint
.penalize(HardSoftScore.ONE_SOFT)     # Suboptimal
.penalize(HardSoftScore.of_hard(5))   # Weighted hard
.penalize(HardSoftScore.of_soft(10))  # Weighted soft
```

**Hard constraints:**
- Must be satisfied for a feasible solution
- Score format: `Xhard/Ysoft`
- `0hard/*soft` = feasible

**Soft constraints:**
- Preferences to optimize
- Better soft scores are preferred among feasible solutions

**Use when:** You have rules that must be followed AND preferences to optimize.

## HardMediumSoftScore

Three levels of priority:

```python
from solverforge_legacy.solver.score import HardMediumSoftScore

# In domain model
score: Annotated[HardMediumSoftScore, PlanningScore] = field(default=None)

# In constraints
.penalize(HardMediumSoftScore.ONE_HARD)    # Must satisfy
.penalize(HardMediumSoftScore.ONE_MEDIUM)  # Important preference
.penalize(HardMediumSoftScore.ONE_SOFT)    # Nice to have
```

**Use when:**
- Medium = "Assign as many as possible"
- Medium = "Important but not mandatory"
- Medium = "Prefer over soft, but not as critical as hard"

**Example:** Meeting scheduling where:
- Hard: Required attendees must be available
- Medium: Preferred attendees should attend
- Soft: Room size preferences

## BendableScore

Custom number of hard and soft levels:

```python
from solverforge_legacy.solver.score import BendableScore

# Configure levels (3 hard, 2 soft)
score: Annotated[BendableScore, PlanningScore] = field(default=None)

# In constraints
.penalize(BendableScore.of_hard(0, 1))   # First hard level
.penalize(BendableScore.of_hard(1, 1))   # Second hard level
.penalize(BendableScore.of_soft(0, 1))   # First soft level
```

**Use when:** You need more than 3 priority levels.

## Decimal Score Variants

For precise calculations:

```python
from solverforge_legacy.solver.score import HardSoftDecimalScore

score: Annotated[HardSoftDecimalScore, PlanningScore] = field(default=None)

# In constraints
from decimal import Decimal
.penalize(HardSoftDecimalScore.of_soft(Decimal("0.01")))
```

Available variants:
- `SimpleDecimalScore`
- `HardSoftDecimalScore`
- `HardMediumSoftDecimalScore`
- `BendableDecimalScore`

**Use when:** Integer scores aren't precise enough (e.g., money, distances).

## Score Constants

Common score values are predefined:

```python
# SimpleScore
SimpleScore.ZERO
SimpleScore.ONE
SimpleScore.of(n)

# HardSoftScore
HardSoftScore.ZERO
HardSoftScore.ONE_HARD
HardSoftScore.ONE_SOFT
HardSoftScore.of_hard(n)
HardSoftScore.of_soft(n)
HardSoftScore.of(hard, soft)

# HardMediumSoftScore
HardMediumSoftScore.ZERO
HardMediumSoftScore.ONE_HARD
HardMediumSoftScore.ONE_MEDIUM
HardMediumSoftScore.ONE_SOFT
HardMediumSoftScore.of(hard, medium, soft)
```

## Dynamic Weights

Apply weights based on entity properties:

```python
def weighted_penalty(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Task)
        .filter(lambda t: t.is_late())
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda task: task.priority  # High priority = bigger penalty
        )
        .as_constraint("Late task")
    )
```

## Score Comparison

Scores are compared level by level:

```
# Hard first, then soft
0hard/-100soft > -1hard/0soft    (first is feasible)
-1hard/-50soft > -2hard/-10soft  (first has better hard)
0hard/-50soft > 0hard/-100soft   (same hard, better soft)
```

## Score Properties

```python
score = HardSoftScore.of(-2, -100)

score.is_feasible          # False (hard < 0)
score.hard_score           # -2
score.soft_score           # -100
str(score)                 # "-2hard/-100soft"

HardSoftScore.parse("-2hard/-100soft")  # Parse from string
```

## Choosing a Score Type

| Question | Recommendation |
|----------|----------------|
| Need feasibility check? | Use `HardSoftScore` |
| Single objective only? | Use `SimpleScore` |
| "Assign as many as possible"? | Use `HardMediumSoftScore` |
| More than 3 priority levels? | Use `BendableScore` |
| Need decimal precision? | Use `*DecimalScore` variant |

## Best Practices

### Do

- Use `HardSoftScore` as default choice
- Keep hard constraints truly hard (legal requirements, physical limits)
- Use consistent weight scales within each level

### Don't

- Use medium level for actual hard constraints
- Over-complicate with BendableScore when HardMediumSoftScore works
- Mix units in the same level (e.g., minutes and dollars)

## Next Steps

- [Score Analysis](score-analysis.md) - Understand why solutions score what they do
- [Performance](performance.md) - Optimize constraint evaluation
