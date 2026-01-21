---
title: "The Future of Constraint Programming in Rust"
date: 2026-01-21
draft: false
tags: [rust]
description: >
  Why we chose Rust for SolverForge, the ergonomics trade-offs compared to Python,
  and how we're addressing them with Python bindings and improved Rust APIs.
---

SolverForge is a constraint solver written in Rust. The goal: **write constraints like you write code**.

This wasn't an obvious language choice. Python dominates the optimization space. Java has decades of established solvers. Why Rust?

The answer comes down to what constraint solving actually does: evaluate millions of candidate moves per second, score each one, and navigate toward better solutions. Every microsecond in the inner loop matters. Every allocation compounds.

## Why Rust for Constraint Solvers?

### The Zero-Erasure Architecture

SolverForge follows a strict architectural principle: **all code must be fully monomorphized**. This means:

- **No** `Box<dyn Trait>` in hot paths
- **No** `Arc<T>` or `Rc<T>` anywhere
- **No** vtable lookups during move evaluation
- Types are preserved through the entire solver pipeline

When you define a constraint in SolverForge, the Rust compiler generates specialized code for your exact domain model. There's no runtime dispatch deciding which scoring function to call—the compiler has already resolved everything to direct function calls.

### Performance Characteristics

The inner loop of a local search solver evaluates candidate moves. A typical solving run might evaluate hundreds of millions of moves. At this scale:

- **Memory allocation** becomes visible. Stack-allocated moves and scores avoid heap pressure.
- **Cache locality** matters. Predictable memory layout keeps data hot.
- **Branch prediction** affects throughput. Monomorphized code has predictable call sites.

Rust's ownership model also eliminates an entire class of bugs. Solutions can be safely shared between threads, moves can be evaluated in parallel, and the type system prevents data races at compile time.

## What SolverForge Offers Today

### SERIO: Incremental Scoring Engine

![SERIO - Scoring Engine for Real-time Incremental Optimization](/images/SERIO.jpg)

At the core of SolverForge is SERIO (Scoring Engine for Real-time Incremental Optimization). When a move changes a single variable, SERIO recalculates only the affected constraints rather than rescoring the entire solution. This is essential for performance—without incremental scoring, solvers can't evaluate enough moves to find good solutions.

The constraint stream API, which defines how constraints are expressed, was pioneered by [Timefold](https://timefold.ai/) (and its predecessor OptaPlanner) with their Bavet incremental scoring engine. SolverForge's constraint streams follow the same pattern, acknowledging that Timefold established an effective API for declarative constraint definition. SERIO is our implementation of incremental scoring for Rust's type system and zero-erasure requirements.

### Derive Macros for Domain Models

Define your planning domain with attribute macros:

```rust
#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub id: i64,
    pub name: String,
    pub skills: Vec<String>,
}

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: i64,
    pub required_skill: String,

    #[planning_variable(allows_unassigned = true)]
    pub employee: Option<i64>,
}

#[planning_solution]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

The macros generate all the plumbing: entity descriptors, variable accessors, solution metadata. You focus on the domain model.

### Fluent Constraint Stream API

Define constraints with a builder-style API:

```rust
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

    let assigned = factory
        .clone()
        .for_each(|s: &Schedule| s.shifts.as_slice())
        .filter(|shift: &Shift| shift.employee.is_none())
        .penalize(HardSoftScore::ONE_HARD)
        .as_constraint("All shifts assigned");

    let skill_match = factory
        .clone()
        .for_each(|s: &Schedule| s.shifts.as_slice())
        .join(
            |s: &Schedule| s.employees.as_slice(),
            joiner::equal_bi(
                |shift: &Shift| shift.employee,
                |emp: &Employee| Some(emp.id),
            ),
        )
        .filter(|shift: &Shift, emp: &Employee| {
            !emp.skills.contains(&shift.required_skill)
        })
        .penalize(HardSoftScore::ONE_HARD)
        .as_constraint("Skill requirement");

    (assigned, skill_match)
}
```

Each method in the chain is generic, preserving full type information. The compiler generates specialized scoring code for your exact constraint structure.

## The Ergonomics Gap: Rust vs Python

Rust requires more syntax than Python for equivalent operations.

### Comparison

| Aspect | Python | Rust (SolverForge) |
|--------|--------|-------------------|
| Domain definition | `@planning_entity` decorator | `#[planning_entity]` macro |
| Lambda syntax | `lambda x: x.field` | `\|x: &Type\| x.field` |
| Factory reuse | Implicit sharing | Explicit `.clone()` |
| Type annotations | Optional | Often required |
| Collection access | Direct | `.as_slice()` |
| Error messages | Runtime | Compile-time (but verbose) |

### Python Bindings: In Development

We're not just theorizing. Python bindings for SolverForge are in active development. The same constraint in Python:

```python
@constraint_provider
def define_constraints(factory):
    return [
        factory.for_each(Shift)
            .filter(lambda shift: shift.employee is None)
            .penalize(HardSoftScore.ONE_HARD)
            .as_constraint("All shifts assigned"),
    ]
```

Fewer characters. No type annotations. No `.clone()`. No `.as_slice()`.

We're addressing the difference from both directions—improving Rust ergonomics and providing Python bindings that compile to the same high-performance core.

## Toward More Fluent Rust APIs

[Ruby](https://www.ruby-lang.org/) demonstrated that expressive DSLs are possible in statically-inspired languages. The question is whether similar fluency is achievable in Rust for constraint programming.

### What Fluency Means Here

- Method chaining without excessive ceremony
- DSL-style definitions that read like specifications
- Less boilerplate between intent and implementation

### Hypothetical: A `constraints!` Macro DSL

One possible direction:

```rust
constraints! {
    "All shifts assigned" => {
        for_each shift in shifts
        where shift.employee.is_none()
        penalize HARD
    },

    "No overlapping shifts" => {
        for_each_pair (a, b) in shifts
        where a.employee == b.employee
        where a.overlaps(&b)
        penalize HARD
    },

    "Skill requirement" => {
        for_each shift in shifts
        join employee in employees on shift.employee == Some(employee.id)
        where !employee.skills.contains(&shift.required_skill)
        penalize HARD
    },

    "Preferred hours" => {
        for_each shift in shifts
        join employee in employees on shift.employee == Some(employee.id)
        where !employee.preferred_hours.contains(&shift.start_time)
        penalize SOFT by 10
    },
}
```

This would compile down to the same zero-erasure code. The macro expands the declarative syntax into the full generic constraint definitions, with no additional runtime cost.

### Incremental Improvements

Before a full DSL, smaller changes can reduce boilerplate:

```rust
// Generated accessors from domain model
let factory = ConstraintFactory::new();

factory.shifts()           // Generated from #[planning_entity_collection]
    .unassigned()          // Generated: filter where planning_variable is None
    .penalize_hard()       // Shorthand for penalize(HardSoftScore::ONE_HARD)
    .named("All assigned")

// Inferred joiners from field relationships
factory.shifts()
    .join_employees()      // Inferred from Option<employee_id> field
    .filter_skill_mismatch()  // Generated from domain knowledge
    .penalize_hard()
    .named("Skill match")
```

The macro already knows the domain model. It can generate helper methods that understand the specific problem structure.

## Technical Challenges

Building fluent DSLs in Rust has inherent difficulties:

### 1. Rust Closure Types Are Unique

Every closure has a unique, anonymous type. You can't easily abstract over closures:

```rust
// This works
let f1 = |s: &Shift| s.employee.is_none();

// But you can't return closures from functions without boxing
fn make_filter() -> impl Fn(&Shift) -> bool {
    |s| s.employee.is_none()  // Each call returns a different type
}
```

**Workaround:** Procedural macros generate concrete types at compile time. The macro sees your predicate and generates a specific struct with the filter logic inlined.

### 2. Type Inference Has Limits

Complex generic chains can overwhelm the Rust compiler's inference:

```rust
// Sometimes needs explicit type hints
factory.for_each::<Shift, _>(|s| s.shifts.as_slice())
```

**Workaround:** Generated accessors like `.shifts()` pre-bake the types, eliminating inference ambiguity.

### 3. Trait Bound Accumulation

Each fluent method adds trait bounds. By the time you chain several operations, the bounds list is enormous:

```
error[E0277]: the trait bound `for<'a> {closure@src/main.rs:45:17} :
    Fn(&'a Shift) -> bool` is not satisfied
    |
45  |     .filter(|s| s.employee.is_none())
    |      ^^^^^^
    |
note: required by a bound in `UniStream::<S, Score, A, E, Ex>::filter`
   --> src/stream/mod.rs:234:12
    |
234 |         F: for<'a> Fn(&'a E) -> bool + Clone + Send + Sync + 'static,
    |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    ... [200 more lines of bounds]
```

**Workaround:** Wrapper types that hide the intermediate generic parameters from users. The complexity exists but isn't exposed.

### 4. No Variadic Generics (Yet)

Rust doesn't have variadic generics, so you can't write `constraints!(c1, c2, c3, ...)` for arbitrary counts:

```rust
// We want this to work for any number of constraints
(c1, c2, c3)  // Works via tuple impl
(c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13)  // Too many
```

**Workaround:** Implement `ConstraintSet` for tuples up to some reasonable N. We currently support up to 12 constraints in a tuple. Beyond that, nest tuples or use a different pattern.

## The Python Bindings Approach

While we work on Rust ergonomics, we're also building Python bindings via PyO3. The architecture:

```
Python API (decorators, constraint streams, lambdas)
    ↓
Lambda Analysis (Python AST → Expression trees)
    ↓
Native Evaluation (Rust constraint engine)
    ↓
Zero-erasure solver core
```

The key insight: Python lambdas are analyzed at constraint definition time, not evaluation time. When you write:

```python
factory.for_each(Shift).filter(lambda s: s.employee is None)
```

The lambda `lambda s: s.employee is None` is inspected via Python's AST, converted to a native `Expression` tree, and compiled. During solving, there's no Python interpreter in the hot path—just native Rust evaluation of the expression tree.

This gives Python users the ergonomics they expect while preserving the performance characteristics of the Rust core. The same solver, two interfaces.

## Motivation

Constraint programming has a steep learning curve. Complex generic type parameters and verbose error messages add friction.

The goal is constraint modeling that feels closer to describing the problem than to satisfying the type system. You shouldn't need to understand monomorphization to express "employees can't work overlapping shifts."

The solver internals require zero-cost abstractions. The user-facing API doesn't have to expose them.

## Conclusion

We chose Rust because constraint solving is computationally intensive. Every allocation matters. Every vtable lookup compounds across millions of move evaluations. Rust provides the performance ceiling we need.

We're addressing the ergonomics difference two ways:

1. **Python bindings** that provide familiar syntax while compiling to native evaluation
2. **Rust API improvements** via procedural macros that generate domain-aware helpers

Both approaches share the same zero-erasure solver core.

---

**Try it now:** [Employee Scheduling in Rust](/docs/getting-started/employee-scheduling-rust/)

**Source:** [SolverForge on GitHub](https://github.com/SolverForge/solverforge)

**Related:**
- [How We Build Frontends: jQuery in 2026](/blog/technical/how-we-build-frontends/)
- [Python Constraint Solver Architecture](/blog/technical/python-constraint-solver-architecture/)
