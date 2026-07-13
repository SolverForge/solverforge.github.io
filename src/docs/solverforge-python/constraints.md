---
title: "Python Constraints"
description: >
  Write callback-authored SolverForge Python constraints with supported stream
  shapes, joins, grouping, balance scoring, score weights, and safe compiled
  evaluators.
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
| Unassigned list elements | `for_each_unassigned_element(Owner, "list_variable").filter(...).penalize/reward(...).named(...)` |
| List precedence makespan | `list_precedence_makespan(Owner, "list_variable").named(...)` |

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
one key on both sides. `joiner.equal_bi(...)` compares separate left and right
keys. A key may be a Python callback or an attribute-name string.

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

Use attribute strings when the equality key is a stable imported row field:

```python
(
    factory.for_each(Shift)
    .join(Employee, joiner.equal_bi("employee_idx", "index"))
    .filter(lambda shift, employee: shift.required_skill not in employee.skills)
    .penalize(HardSoftScore.ONE_HARD)
    .named("missing required skill")
)
```

SolverForge specializes string equality natively only for planning scalar slots
and stable fields stored directly on every imported row. Properties,
shadow-derived values, containers, unsupported scalar values, and callback keys
retain live Python attribute access and equality.

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

`indexed_presence(...)` is available as a grouped collector when the grouped
stream needs run or range presence scoring by ordinal index:

```python
from solverforge import indexed_presence

(
    factory.for_each(Shift)
    .group_by(lambda shift: shift.employee_idx, indexed_presence(lambda shift: shift.day))
    .penalize(
        lambda employee_idx, presence: HardSoftScore.of_soft(
            presence.complement_runs(0, 7).len()
            + (1 if presence.any_in(5, 7) else 0)
        )
    )
    .named("missing coverage days")
)
```

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

## List Constraints

Use `for_each_unassigned_element(...)` when a planning-list model must score
elements that are not currently assigned to any owner list.

```python
(
    factory.for_each_unassigned_element(Vehicle, "delivery_order")
    .penalize(HardSoftScore.ONE_HARD)
    .named("all deliveries assigned")
)
```

Use `list_precedence_makespan(...)` for list variables that declare
`element_owner`, `precedence_duration`, and `precedence_successors` metadata.
Each source can be a callback or a solution-level sequence field indexed by
element ID. The native scorer computes makespan from that declared metadata and
keeps ordinary Python constraints available for additional hard or soft
penalties.

```python
factory.list_precedence_makespan(Machine, "operations").named("job shop makespan")
```

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

## Compiled Evaluation Boundary

Python callbacks remain the constraint authoring surface, but 0.6.0 compiles a
native evaluator when schema evidence proves it has identical semantics. Safe
specializations include:

- simple fixed-weight unary constraints
- unassigned-list scoring
- list precedence/makespan metadata
- proven stable string-key equality joins

Callback filters, callback-computed weights, computed properties, unsupported
key values, and stateful callables remain on the Python callback path. Closures,
bound defaults, partials, methods, callable instances, and other stateful
callbacks compile per invocation rather than being retained across solves.

Only capture-free functions with canonical module provenance and no defaults or
function-owned metadata can share a schema/runtime plan. Mutable values in that
module namespace remain live, and callbacks from different module namespaces do
not share a plan merely because their code objects match.

## Python Stream API

Use stream-level `for_each(...).join(...)` and
`for_each(...).group_by(...)` for joins and grouped counts. These top-level
factory methods are not Python APIs yet:

- `ConstraintFactory.join(...)`
- `ConstraintFactory.group_by(...)`
- `ConstraintFactory.if_exists(...)`
- `ConstraintFactory.if_not_exists(...)`
- `ConstraintFactory.flattened(...)`
