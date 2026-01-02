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
SolverForge is under active development. The Python API shown above works today via `solverforge-legacy`. We're building a new high-performance backend to make it faster.
{{% /pageinfo %}}

## Current Status

| Component | Status | Description |
|-----------|--------|-------------|
| **solverforge-legacy** | ✅ Usable now | Python wrapper for [Timefold](https://timefold.ai) — works today, great for learning and prototyping |
| **solverforge-core** | ✅ Complete | High-performance Rust backend — native Rust solver complete, not yet user-facing |
| **Python bindings** | 🚧 In progress | PyO3-based bindings to the fast Rust core — coming Q1-Q2 2026 |

**Want to try it today?** Start with the [Python quickstarts](/docs/getting-started/) using `solverforge-legacy`.

## Roadmap

### Phase 1: Foundation ✅ 

We've built the core solver infrastructure:
- Complete constraint streams API (forEach, filter, join, groupBy, penalize, reward)
- Support for all common score types (HardSoft, HardMediumSoft, Bendable)
- End-to-end solving with employee scheduling, vehicle routing, and more

### Phase 2: Python Bindings (Q1-Q2 2026)

Making the fast Rust core available to Python developers:
- PyO3-based native extension: `pip install solverforge`
- Same Pythonic API you know from solverforge-legacy
- Seamless migration path — change one import, keep your code

### Phase 3: Production Ready (H2 2026)

- Stable v1.0.0 release
- Performance tuning guides
- Advanced features

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

SolverForge uses a unique architecture to achieve both developer ergonomics and performance:

```
┌────────────────────────────────────────────────────────┐
│              Your Python/Rust Code                     │
│     (Domain models, constraints, problem data)         │
└────────────────────────────────────────────────────────┘
                           │
                      HTTP/JSON
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│            Solver Service (Java + Timefold)            │
│                                                        │
│   • Executes metaheuristic search algorithms           │
│   • Runs WASM-compiled constraint predicates           │
│   • Returns optimized solutions                        │
└────────────────────────────────────────────────────────┘
```

**Why this design?**

1. **Timefold's algorithms are battle-tested** — Rather than reimplementing 20+ years of metaheuristic research, we leverage Timefold's proven solver engine

2. **WASM enables portable constraints** — Your constraint logic compiles to WebAssembly, which runs efficiently inside the JVM via the Chicory runtime

3. **HTTP keeps things simple** — No JNI, no platform-specific native code, no complex build configurations

**The result:** You write clean Python code; we handle the complexity of making it run fast.

</details>

<details>
<summary><strong>Detailed achievements (Q4 2025)</strong></summary>

**Repository**: [solverforge/solverforge](https://github.com/solverforge/solverforge) (v0.1.56)

**Rust core library (`solverforge-core`):**
- Domain model definition with planning annotations
- Comprehensive constraint streams API (forEach, filter, join, groupBy, complement, flattenLast)
- Advanced collectors (count, countDistinct, loadBalance)
- Full score type system with BigDecimal variants
- Score analysis with constraint breakdown

**WASM module generation:**
- Proper memory alignment for 32-bit and 64-bit types
- Field accessors and constraint predicates
- Support for temporal types (LocalDate, LocalDateTime)

**Java service (`timefold-wasm-service`):**
- Chicory WASM runtime integration
- Dynamic bytecode generation for domain classes
- HTTP endpoints for solving and score analysis

**End-to-end validation:**
- Employee scheduling with 5+ constraints
- Load balancing with fair distribution
- Comprehensive test suite

</details>
