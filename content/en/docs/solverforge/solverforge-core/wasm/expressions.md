---
title: "Expressions"
linkTitle: "Expressions"
weight: 10
tags: [reference, rust]
description: "Build predicate expressions with the Expression API"
---

The `Expression` enum represents predicate logic as an abstract syntax tree. Use the `Expr` helper for fluent construction.

## Expr Helper

The `Expr` struct provides static methods for building expressions:

```rust
use solverforge_core::wasm::{Expr, FieldAccessExt};

// Get first parameter
let shift = Expr::param(0);

// Access field with FieldAccessExt trait
let employee = shift.clone().get("Shift", "employee");

// Build predicate: employee != null
let predicate = Expr::is_not_null(employee);
```

## Literals

```rust
// Integer literal
Expr::int(42)

// Boolean literal
Expr::bool(true)
Expr::bool(false)

// Null
Expr::null()
```

## Parameter Access

Access predicate function parameters:

```rust
// param(0) - first parameter (e.g., Shift in a filter)
// param(1) - second parameter (e.g., in a join)
let first = Expr::param(0);
let second = Expr::param(1);
```

## Field Access

Use the `FieldAccessExt` trait to chain field access:

```rust
use solverforge_core::wasm::FieldAccessExt;

// shift.employee
let employee = Expr::param(0).get("Shift", "employee");

// shift.employee.name (nested)
let name = Expr::param(0)
    .get("Shift", "employee")
    .get("Employee", "name");

// shift.start
let start = Expr::param(0).get("Shift", "start");
```

## Comparisons

```rust
// Equal (==)
Expr::eq(left, right)

// Not equal (!=)
Expr::ne(left, right)

// Less than (<)
Expr::lt(left, right)

// Less than or equal (<=)
Expr::le(left, right)

// Greater than (>)
Expr::gt(left, right)

// Greater than or equal (>=)
Expr::ge(left, right)
```

## Logical Operations

```rust
// AND (&&)
Expr::and(left, right)

// OR (||)
Expr::or(left, right)

// NOT (!)
Expr::not(operand)

// Null checks
Expr::is_null(operand)
Expr::is_not_null(operand)
```

## Arithmetic

```rust
// Addition (+)
Expr::add(left, right)

// Subtraction (-)
Expr::sub(left, right)

// Multiplication (*)
Expr::mul(left, right)

// Division (/)
Expr::div(left, right)
```

## List Operations

```rust
// Check if list contains element
Expr::list_contains(list, element)

// Example: employee.skills contains shift.requiredSkill
let skills = Expr::param(0).get("Shift", "employee").get("Employee", "skills");
let required = Expr::param(0).get("Shift", "requiredSkill");
Expr::list_contains(skills, required)
```

## Host Function Calls

Call host-provided functions:

```rust
// Generic host call
Expr::host_call("functionName", vec![arg1, arg2])

// String equality (convenience method)
Expr::string_equals(left, right)

// Time range overlap (convenience method)
Expr::ranges_overlap(start1, end1, start2, end2)
```

## Conditional

```rust
// if condition { then } else { else }
Expr::if_then_else(condition, then_branch, else_branch)

// Example: if (x > 0) { 1 } else { 0 }
Expr::if_then_else(
    Expr::gt(Expr::param(0), Expr::int(0)),
    Expr::int(1),
    Expr::int(0)
)
```

## Complete Examples

### Skill Mismatch Predicate

```rust
// Returns true if employee assigned but doesn't have required skill
let shift = Expr::param(0);
let employee = shift.clone().get("Shift", "employee");

let predicate = Expr::and(
    Expr::is_not_null(employee.clone()),
    Expr::not(Expr::list_contains(
        employee.get("Employee", "skills"),
        shift.get("Shift", "requiredSkill"),
    ))
);
```

### Shifts Overlap Predicate

```rust
// Returns true if two shifts overlap in time
let shift1 = Expr::param(0);
let shift2 = Expr::param(1);

let predicate = Expr::ranges_overlap(
    shift1.clone().get("Shift", "start"),
    shift1.get("Shift", "end"),
    shift2.clone().get("Shift", "start"),
    shift2.get("Shift", "end"),
);
```

### Gap Too Small Predicate

```rust
// Returns true if gap between shifts is less than 10 hours
let shift1 = Expr::param(0);
let shift2 = Expr::param(1);

let shift1_end = shift1.get("Shift", "end");
let shift2_start = shift2.get("Shift", "start");

let gap_seconds = Expr::sub(shift2_start, shift1_end);
let gap_hours = Expr::div(gap_seconds, Expr::int(3600));

let predicate = Expr::lt(gap_hours, Expr::int(10));
```

### Same Employee Check

```rust
// Returns true if both shifts have the same employee
let shift1 = Expr::param(0);
let shift2 = Expr::param(1);

let emp1 = shift1.get("Shift", "employee");
let emp2 = shift2.get("Shift", "employee");

let predicate = Expr::and(
    Expr::and(
        Expr::is_not_null(emp1.clone()),
        Expr::is_not_null(emp2.clone())
    ),
    Expr::eq(emp1, emp2)
);
```

## API Reference

| Method | Description |
|--------|-------------|
| `Expr::int(value)` | Integer literal |
| `Expr::bool(value)` | Boolean literal |
| `Expr::null()` | Null value |
| `Expr::param(index)` | Function parameter |
| `expr.get(class, field)` | Field access |
| `Expr::eq(l, r)` | Equal |
| `Expr::ne(l, r)` | Not equal |
| `Expr::lt(l, r)` | Less than |
| `Expr::le(l, r)` | Less than or equal |
| `Expr::gt(l, r)` | Greater than |
| `Expr::ge(l, r)` | Greater than or equal |
| `Expr::and(l, r)` | Logical AND |
| `Expr::or(l, r)` | Logical OR |
| `Expr::not(expr)` | Logical NOT |
| `Expr::is_null(expr)` | Is null check |
| `Expr::is_not_null(expr)` | Is not null check |
| `Expr::add(l, r)` | Addition |
| `Expr::sub(l, r)` | Subtraction |
| `Expr::mul(l, r)` | Multiplication |
| `Expr::div(l, r)` | Division |
| `Expr::list_contains(list, elem)` | List contains |
| `Expr::host_call(name, args)` | Host function call |
| `Expr::string_equals(l, r)` | String comparison |
| `Expr::ranges_overlap(s1, e1, s2, e2)` | Time overlap |
| `Expr::if_then_else(c, t, e)` | Conditional |
