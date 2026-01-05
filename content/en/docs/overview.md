---
title: Overview
description: What SolverForge is, how it differs from mathematical solvers, and the project roadmap.
weight: 1
tags: [concepts]
---

# What is SolverForge?

SolverForge is a **constraint satisfaction solver** for real-world planning and scheduling problems. It helps you assign resources to tasks while respecting business rules and optimizing for your goals.

## What Problems Does It Solve?

SolverForge excels at **combinatorial planning problems** — problems where a brute-force search is impossible (millions to billions of possibilities), but a good solution dramatically improves efficiency.

{{< cardpane >}}
{{< card header="**Employee Scheduling**" >}}
Assign staff to shifts based on skills, availability, and labor regulations.
{{< /card >}}
{{< card header="**Vehicle Routing**" >}}
Plan delivery routes that minimize travel time while meeting time windows.
{{< /card >}}
{{< card header="**School Timetabling**" >}}
Schedule lessons to rooms and timeslots without conflicts.
{{< /card >}}
{{< /cardpane >}}

{{< cardpane >}}
{{< card header="**Task Assignment**" >}}
Allocate jobs to workers or machines optimally.
{{< /card >}}
{{< card header="**Meeting Scheduling**" >}}
Find times and rooms that work for all attendees.
{{< /card >}}
{{< card header="**Bin Packing**" >}}
Fit items into containers efficiently.
{{< /card >}}
{{< /cardpane >}}

## How Is This Different from Gurobi or CVXPY?

This is a common question. **SolverForge and mathematical programming solvers (Gurobi, CPLEX, OR-Tools, CVXPY) solve different kinds of problems using different approaches.**

| | SolverForge | Mathematical Solvers (Gurobi, CVXPY) |
|---|---|---|
| **Problem type** | Constraint satisfaction & scheduling | Linear/mixed-integer programming |
| **Modeling approach** | Business objects with rules | Mathematical equations & matrices |
| **Constraints** | Natural language-like rules on objects | Linear inequalities (Ax ≤ b) |
| **Best for** | Scheduling, routing, assignment | Resource allocation, network flow, portfolio optimization |
| **Developer experience** | Write rules about "Shifts" and "Employees" | Formulate objective functions and constraint matrices |

### A Concrete Example

{{< tabpane text=true >}}
{{% tab header="SolverForge" %}}
```python
# You describe rules about your business objects directly
@constraint_provider
def define_constraints(factory):
    return [
        factory.for_each(Shift)
            .filter(lambda s: s.employee is None)
            .penalize("Unassigned shift", HardSoftScore.ONE_HARD),
        factory.for_each(Shift)
            .filter(lambda s: s.required_skill not in s.employee.skills)
            .penalize("Missing skill", HardSoftScore.ONE_HARD),
    ]
```
{{% /tab %}}
{{% tab header="Gurobi/CVXPY" %}}
```python
# You must translate your problem into mathematical form
x = model.addVars(employees, shifts, vtype=GRB.BINARY)
model.addConstrs(sum(x[e,s] for e in employees) == 1 for s in shifts)
model.addConstrs(sum(x[e,s] for s in shifts) <= max_shifts for e in employees)
```
{{% /tab %}}
{{< /tabpane >}}

**The key difference:** With SolverForge, you work with domain objects (`Shift`, `Employee`) and express constraints as natural business rules. You don't need to reformulate your problem as a system of linear equations.

### When to Use Each

**Use SolverForge when:**
- Your problem involves scheduling, routing, or assignment
- Constraints are naturally expressed as business rules
- The problem structure doesn't fit neatly into linear programming
- You want readable, maintainable constraint definitions

**Use Gurobi/CVXPY when:**
- Your problem is naturally linear or convex
- You need provably optimal solutions with bounds
- The problem fits the mathematical programming paradigm (LP, MIP, QP)

## The Developer Experience

SolverForge provides a **Pythonic, business-object-oriented API**:

```python
from dataclasses import dataclass
from typing import Annotated
from solverforge import planning_entity, planning_solution, PlanningVariable

@planning_entity
@dataclass
class Shift:
    id: str
    required_skill: str
    employee: Annotated[Employee | None, PlanningVariable] = None  # Solver fills this in

@planning_solution
@dataclass
class Schedule:
    employees: list[Employee]
    shifts: list[Shift]
    score: HardSoftScore = None
```

You define your domain model with standard Python dataclasses and type annotations. The solver figures out how to assign employees to shifts while respecting your constraints.

---

# Project Status & Roadmap

{{% pageinfo %}}
SolverForge is a **production-ready constraint solver** written in Rust. The Rust API is complete and stable. Python bindings are in development.
{{% /pageinfo %}}

## Current Status

| Component | Status | Description |
|-----------|--------|-------------|
| **Rust Core** | ✅ Production-ready | Native Rust constraint solver with complete feature set — v0.4+ |
| **solverforge-legacy** | ✅ Usable now | Python wrapper for [Timefold](https://timefold.ai) — great for learning and prototyping |
| **Python bindings** | 🚧 In progress | PyO3-based bindings to the Rust core — coming Q1-Q2 2026 |

**Want to try it today?** 
- **Rust developers**: Use the [Rust crate](https://crates.io/crates/solverforge) directly
- **Python developers**: Start with [Python quickstarts](/docs/getting-started/) using `solverforge-legacy`

## What's Complete

SolverForge Rust is **feature-complete** as a production constraint solver:

- **Constraint Streams API**: Declarative constraint definition with `for_each`, `filter`, `join`, `group_by`, `penalize`, `reward`
- **Score Types**: SimpleScore, HardSoftScore, HardMediumSoftScore, BendableScore
- **SERIO Engine**: Scoring Engine for Real-time Incremental Optimization
- **Solver Phases**:
  - Construction Heuristic (First Fit, Best Fit)
  - Local Search (Hill Climbing, Simulated Annealing, Tabu Search, Late Acceptance)
  - Exhaustive Search (Branch and Bound with DFS/BFS/Score-First)
  - Partitioned Search (multi-threaded)
  - VND (Variable Neighborhood Descent)
- **Move System**: Zero-allocation typed moves with arena allocation
- **SolverManager API**: Ergonomic builder pattern for solver configuration
- **Configuration**: TOML/YAML support with builder API

## Roadmap

### Phase 1: Native Solver ✅ Complete

Built a complete constraint solver in Rust from the ground up:
- Full metaheuristic algorithm suite
- Incremental scoring engine (SERIO)
- Zero-cost abstractions with typed moves
- Derive macros for ergonomic domain modeling

### Phase 2: Python Bindings (Q1-Q2 2026)

Making the Rust solver available to Python developers:
- PyO3-based native extension: `pip install solverforge`
- Same Pythonic API you know from solverforge-legacy
- Seamless migration path — change one import, keep your code
- Native performance without JVM overhead

### Phase 3: Production Enhancements (H2 2026)

- Multi-threaded move evaluation
- Constraint strength system
- Constraint match analysis and explanation
- Performance tuning guides
- Enterprise features

---

## How You Can Help

- **Try the quickstarts** — [Try a quickstart](/docs/getting-started/) and share feedback
- **Report issues** — Found a bug or have a suggestion? [Open an issue](https://github.com/solverforge/solverforge/issues)
- **Contribute** — We're actively developing Python bindings. PRs welcome!
- **Spread the word** — Star the [GitHub repo](https://github.com/solverforge/solverforge) and share with colleagues

---

## Technical Details

<details>
<summary><strong>Architecture (for the curious)</strong></summary>

SolverForge is a **native Rust constraint solver** that delivers both developer ergonomics and high performance:

```
┌─────────────────────────────────────────────────────────────────┐
│                         solverforge                             │
│                    (facade + re-exports)                        │
└─────────────────────────────────────────────────────────────────┘
        │              │              │              │
        ▼              ▼              ▼              ▼
┌──────────────┬──────────────┬──────────────┬──────────────┐
│solverforge-  │solverforge-  │solverforge-  │solverforge-  │
│   solver     │   scoring    │   config     │  benchmark   │
│              │              │              │              │
│ • Phases     │ • Constraint │ • TOML/YAML  │ • Runner     │
│ • Moves      │   Streams    │ • Builders   │ • Statistics │
│ • Selectors  │ • Score      │              │ • Reports    │
│ • Foragers   │   Directors  │              │              │
│ • Acceptors  │ • SERIO      │              │              │
│ • Termination│   Engine     │              │              │
│ • Manager    │              │              │              │
└──────────────┴──────────────┴──────────────┴──────────────┘
        │              │
        └──────┬───────┘
               ▼
        ┌──────────────────────────────┐
        │       solverforge-core       │
        │                              │
        │ • Score types                │
        │ • Domain traits              │
        │ • Descriptors                │
        │ • Variable system            │
        └──────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────┐
        │      solverforge-macros      │
        │                              │
        │ • #[derive(PlanningSolution)]│
        │ • #[derive(PlanningEntity)]  │
        │ • #[derive(ProblemFact)]     │
        └──────────────────────────────┘
```

**Why this design?**

1. **Zero-cost abstractions** — Rust's type system eliminates runtime overhead. Constraint streams compile to efficient machine code with no dynamic dispatch.

2. **Incremental scoring (SERIO)** — The Scoring Engine for Real-time Incremental Optimization only recalculates affected constraints when moves are evaluated, delivering 10-100x speedups.

3. **Type-safe moves** — `ChangeMove<S, V>` and `SwapMove<S, V>` store values inline without boxing or heap allocation. Arena allocation provides O(1) per-step cleanup.

4. **No garbage collection** — Predictable, low-latency performance without GC pauses.

5. **Modular architecture** — Each crate has a single responsibility, making the codebase maintainable and testable.

**The result:** You write declarative constraint logic that compiles to highly optimized native code.

</details>

<details>
<summary><strong>What's implemented (v0.4+)</strong></summary>

**Repository**: [solverforge/solverforge-rs](https://github.com/solverforge/solverforge-rs)

**Core solver features:**
- **Score types**: SimpleScore, HardSoftScore, HardMediumSoftScore, BendableScore (all with BigDecimal variants)
- **Domain model**: Derive macros for `#[planning_solution]`, `#[planning_entity]`, `#[problem_fact]`
- **Variable types**: Genuine, shadow, list, and chained variables
- **Constraint Streams API**: `for_each`, `filter`, `join`, `group_by`, `if_exists`, `if_not_exists`, `penalize`, `reward`
- **Advanced collectors**: `count`, `count_distinct`, `sum`, `load_balance`

**Solver phases:**
- **Construction heuristics**: First Fit, Best Fit with automatic phase factory
- **Local search**: Hill Climbing, Simulated Annealing, Tabu Search, Late Acceptance
- **Exhaustive search**: Branch and Bound (DFS, BFS, Score-First)
- **Partitioned search**: Multi-threaded parallel solving
- **VND**: Variable Neighborhood Descent

**Infrastructure:**
- **SERIO**: Scoring Engine for Real-time Incremental Optimization
- **SolverManager**: Ergonomic builder API for solver configuration
- **Configuration**: TOML/YAML support with validation
- **Benchmarking**: Statistical analysis framework with warmup, measurement, and reporting
- **Termination**: Time limits, step counts, score targets, unimproved step detection

**Performance:**
- Zero-allocation move system with arena allocation
- Type-safe moves without boxing (`ChangeMove<S, V>`, `SwapMove<S, V>`)
- No garbage collection pauses
- Incremental score calculation (10-100x faster than full recalculation)

</details>
