---
title: "Python Constraints"
description: >
  Write callback-authored SolverForge Python constraints with supported stream
  shapes, joins, grouping, balance scoring, and score weights.
---

# Python Constraints

A constraint provider receives a `ConstraintFactory` and returns a list of named
rules. Each rule starts from an entity stream, filters or joins rows, assigns a
penalty or reward, and ends with `.named(...)`.

```python
@constraint_provider
def constraints(factory: ConstraintFactory):
    return [
        factory.for_each(Shift)
        .filter(lambda shift: shift.required and shift.nurse is None)
        .penalize(HardSoftScore.ONE_HARD)
        .named("required shift is unassigned")
    ]
```

Use small callback functions or lambdas for the business rule itself. Keep data
loading, validation, and reporting outside the constraint provider.

## Supported Stream Shapes

| Shape | Pattern |
| ----- | ------- |
| Unary | `for_each(Entity).filter(...).penalize/reward(...).named(...)` |
| Binary join | `for_each(A).join(B, joiner).filter(...).penalize/reward(...).named(...)` |
| Grouped count | `for_each(Entity).group_by(key).filter(...).penalize/reward(...).named(...)` |
| Balance | `for_each(Entity).balance(key).filter(...).penalize/reward(...).named(...)` |

The supported terminal operations are `penalize(...)`, `reward(...)`, and
`named(...)`.

## Unary Constraints

Use unary constraints for rules on one entity at a time.

```python
(
    factory.for_each(Shift)
    .filter(lambda shift: shift.employee_idx is None)
    .penalize(HardSoftScore.ONE_HARD)
    .named("unassigned shift")
)
```

The filter callback must return `bool`.

## Joins

Use stream-level `join(...)` for pair constraints. `joiner.equal(...)` compares
one key on both sides. `joiner.equal_bi(...)` compares a left-key callback to a
right-key callback.

```python
from solverforge import joiner

(
    factory.for_each(Shift)
    .filter(lambda shift: shift.employee_idx is not None)
    .join(
        Employee,
        joiner.equal_bi(lambda shift: shift.employee_idx, lambda employee: employee.index),
    )
    .filter(lambda shift, employee: shift.required_skill not in employee.skills)
    .penalize(HardSoftScore.ONE_HARD)
    .named("missing required skill")
)
```

You may also join against a filtered right-hand stream:

```python
active_employees = factory.for_each(Employee).filter(lambda employee: employee.active)

(
    factory.for_each(Shift)
    .join(
        active_employees,
        joiner.equal_bi(lambda shift: shift.employee_idx, lambda employee: employee.index),
    )
)
```

Joiners preserve Python equality semantics.

## Grouped Counts

`group_by(...)` groups rows by a Python key callback. The filter on the grouped
stream receives the grouped key and the count for that key.

```python
(
    factory.for_each(Shift)
    .filter(lambda shift: shift.employee_idx is not None)
    .group_by(lambda shift: shift.employee_idx)
    .filter(lambda employee_idx, shift_count: shift_count > 5)
    .penalize(HardSoftScore.ONE_SOFT)
    .named("too many shifts per employee")
)
```

Use grouped counts for simple capacity, frequency, or load rules.

## Balance

`balance(...)` scores imbalance across keys returned by the callback.

```python
(
    factory.for_each(Shift)
    .filter(lambda shift: shift.employee_idx is not None)
    .balance(lambda shift: shift.employee_idx)
    .penalize(HardSoftScore.ONE_SOFT)
    .named("balance employee assignments")
)
```

Balance scoring is useful for spreading assignments across employees, machines,
vehicles, or other owner keys.

## Weights

Weights may be score objects, integers, score-level sequences, or callbacks.

```python
(
    factory.for_each(Shift)
    .filter(lambda shift: shift.is_weekend)
    .penalize(HardSoftScore.of_soft(10))
    .named("weekend assignment")
)
```

For callback weights, return a score object or integer compatible with the
solution score family:

```python
(
    factory.for_each(Shift)
    .filter(lambda shift: shift.employee_idx is None)
    .penalize(lambda shift: HardSoftScore.of_hard(shift.priority))
    .named("priority weighted unassigned shift")
)
```

## Python Stream API

Use stream-level `for_each(...).join(...)` and
`for_each(...).group_by(...)` for joins and grouped counts. These top-level
factory methods are not Python APIs yet:

- `ConstraintFactory.join(...)`
- `ConstraintFactory.group_by(...)`
- `ConstraintFactory.if_exists(...)`
- `ConstraintFactory.if_not_exists(...)`
- `ConstraintFactory.flattened(...)`
