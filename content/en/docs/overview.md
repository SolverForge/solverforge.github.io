---
title: Overview
description:
  What SolverForge is, how it differs from mathematical solvers, and the project
  roadmap.
weight: 1
tags: [concepts]
---

# What is SolverForge?

SolverForge is a **constraint satisfaction solver** for real-world planning and
scheduling problems. It helps you assign resources to tasks while respecting
business rules and optimizing for your goals.

## What Problems Does It Solve?

SolverForge excels at **combinatorial planning problems** — problems where a
brute-force search is impossible (millions to billions of possibilities), but a
good solution dramatically improves efficiency.

{{< cardpane >}} {{< card header="**Employee Scheduling**" >}} Assign staff to
shifts based on skills, availability, and labor regulations. {{< /card >}}
{{< card header="**Vehicle Routing**" >}} Plan delivery routes that minimize
travel time while meeting time windows. {{< /card >}}
{{< card header="**School Timetabling**" >}} Schedule lessons to rooms and
timeslots without conflicts. {{< /card >}} {{< /cardpane >}}

{{< cardpane >}} {{< card header="**Task Assignment**" >}} Allocate jobs to
workers or machines optimally. {{< /card >}}
{{< card header="**Meeting Scheduling**" >}} Find times and rooms that work for
all attendees. {{< /card >}} {{< card header="**Bin Packing**" >}} Fit items
into containers efficiently. {{< /card >}} {{< /cardpane >}}

## How Is This Different from Gurobi or CVXPY?

This is a common question. **SolverForge and mathematical programming solvers
(Gurobi, CPLEX, OR-Tools, CVXPY) solve different kinds of problems using
different approaches.**

|                          | SolverForge                                | Mathematical Solvers (Gurobi, CVXPY)                      |
| ------------------------ | ------------------------------------------ | --------------------------------------------------------- |
| **Problem type**         | Constraint satisfaction & scheduling       | Linear/mixed-integer programming                          |
| **Modeling approach**    | Business objects with rules                | Mathematical equations & matrices                         |
| **Constraints**          | Natural language-like rules on objects     | Linear inequalities (Ax ≤ b)                              |
| **Best for**             | Scheduling, routing, assignment            | Resource allocation, network flow, portfolio optimization |
| **Developer experience** | Write rules about "Shifts" and "Employees" | Formulate objective functions and constraint matrices     |

### A Concrete Example

{{< tabpane text=true >}} {{% tab header="SolverForge (Rust)" %}}

```rust
use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    use ScheduleConstraintStreams;
    use ShiftUnassignedFilter;

    let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

    let unassigned = factory.clone()
        .shifts()
        .unassigned()
        .penalize_hard()
        .named("Unassigned shift");

    let missing_skill = factory
        .shifts()
        .filter(|shift: &Shift| shift.employee_id.is_some())
        .join((
            |s: &Schedule| &s.employees,
            equal_bi(
                |shift: &Shift| shift.employee_id,
                |emp: &Employee| Some(emp.id),
            ),
        ))
        .filter(|shift: &Shift, emp: &Employee| {
            !emp.skills.contains(&shift.required_skill)
        })
        .penalize_hard()
        .named("Missing skill");

    (unassigned, missing_skill)
}
```

{{% /tab %}} {{% tab header="Gurobi/CVXPY" %}}

```python
# You must translate your problem into mathematical form
x = model.addVars(employees, shifts, vtype=GRB.BINARY)
model.addConstrs(sum(x[e,s] for e in employees) == 1 for s in shifts)
model.addConstrs(sum(x[e,s] for s in shifts) <= max_shifts for e in employees)
```

{{% /tab %}} {{< /tabpane >}}

**The key difference:** With SolverForge, you work with domain objects (`Shift`,
`Employee`) and express constraints as natural business rules. You don't need to
reformulate your problem as a system of linear equations.

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

SolverForge provides a **Rust derive-macro API** for ergonomic domain modeling:

```rust
use solverforge::prelude::*;

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub required_skill: String,
    #[planning_variable(value_range = "employees", allows_unassigned = true)]
    pub employee_id: Option<usize>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}
```

You define your domain model with derive macros and attribute annotations. The
solver figures out how to assign employees to shifts while respecting your
constraints.

---

# Project Status & Roadmap

{{% pageinfo %}} SolverForge is a **production-ready constraint solver** written
in Rust. This documentation set is aligned with **SolverForge 0.7.1**. {{% /pageinfo %}}

## Current Status

| Component     | Status              | Description                                                      |
| ------------- | ------------------- | ---------------------------------------------------------------- |
| **Rust Core** | ✅ Production-ready | Native Rust constraint solver with the current `0.7.1` runtime surface |

**Want to try it today?**

- Follow [Getting Started](/docs/getting-started/) to run the current employee
  scheduling quickstart locally

## What's Complete

SolverForge Rust is **feature-complete** as a production constraint solver:

- **Constraint Streams API**: Declarative constraint definition with `for_each`,
  generated collection accessors, `filter`, unified `join(...)`,
  `flatten_last`, `group_by`, `balance`, `if_exists_filtered`,
  `if_not_exists_filtered`, `penalize`, `reward`, and `.named(...)`
- **Score Types**: SoftScore, HardSoftScore, HardMediumSoftScore,
  HardSoftDecimalScore, BendableScore
- **Score Analysis**: `ScoreAnalysis`, `ConstraintAnalysis`, `ScoreExplanation`,
  `IndictmentMap`
- **SERIO Engine**: Scoring Engine for Real-time Incremental Optimization
- **Solver Phases**:
  - Construction Heuristics for standard and list-variable models
  - Local Search with Hill Climbing, Simulated Annealing, Tabu Search, Late
    Acceptance, and Great Deluge in the stock config surface
  - Exhaustive Search (`branch_and_bound`, `brute_force`)
  - Partitioned Search (multi-threaded)
  - VND (Variable Neighborhood Descent)
- **Move System**: Zero-allocation typed moves with arena allocation — Change,
  Swap, Composite, ListChange, ListSwap, ListReverse, SubListChange,
  SubListSwap, KOpt, ListRuin, Ruin, PillarChange, PillarSwap
- **List Variables**: Full support for sequencing/routing problems
- **Nearby Selection**: Distance-based move selection for large problems
- **Balance Collector**: Load balancing constraint support
- **SolverManager API**: Channel-based streaming with
  `SolverEvent::{Progress, BestSolution, Finished}`, `terminate_early()`,
  `get_status()`, and `free_slot()`
- **Configuration**: stock `solver.toml` loading plus
  `SolverConfig::load()`, `from_toml_str()`, and `from_yaml_str()`

## Roadmap

### Phase 1: Native Solver ✅ Complete

Built a complete constraint solver in Rust from the ground up:

- Full metaheuristic algorithm suite
- Incremental scoring engine (SERIO)
- Zero-cost abstractions with typed moves
- Derive macros for ergonomic domain modeling

### Phase 2: Rust API Refinement & Production Enhancements (H1 2026)

- Multi-threaded move evaluation
- Constraint strength system
- Performance tuning guides
- Enterprise features

### Phase 3: Python Bindings (H2 2026)

Bringing the Rust solver to Python developers via PyO3:

- Native extension: `pip install solverforge`
- Pythonic API backed by the Rust core
- Native performance without JVM overhead

---

## How You Can Help

- **Get started** — [Follow the getting started guides](/docs/getting-started/)
  and share feedback
- **Report issues** — Found a bug or have a suggestion?
  [Open an issue](https://github.com/solverforge/solverforge/issues)
- **Contribute** — PRs welcome! Check the
  [issue tracker](https://github.com/solverforge/solverforge/issues) for good
  first issues
- **Spread the word** — Star the
  [GitHub repo](https://github.com/solverforge/solverforge) and share with
  colleagues

---

## Technical Details

<details>
<summary><strong>Architecture (for the curious)</strong></summary>

SolverForge is a **native Rust constraint solver** that delivers both developer
ergonomics and high performance:

```
┌─────────────────────────────────────────────────────────────────┐
│                         solverforge                             │
│                    (facade + re-exports)                        │
└─────────────────────────────────────────────────────────────────┘
        │              │              │
        ▼              ▼              ▼
┌──────────────┬──────────────┬──────────────┐
│solverforge-  │solverforge-  │solverforge-  │
│   solver     │   scoring    │   config     │
│              │              │              │
│ • Phases     │ • Constraint │ • TOML       │
│ • Moves      │   Streams    │ • YAML       │
│ • Selectors  │ • Score      │ • Builders   │
│ • Foragers   │   Directors  │              │
│ • Acceptors  │ • SERIO      │              │
│ • Termination│   Engine     │              │
│ • Manager    │              │              │
└──────────────┴──────────────┴──────────────┘
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
        │ • #[planning_solution]       │
        │ • #[planning_entity]         │
        │ • #[problem_fact]            │
        └──────────────────────────────┘
```

**Why this design?**

1. **Zero-cost abstractions** — Rust's type system eliminates runtime overhead.
   Constraint streams compile to efficient machine code with no dynamic
   dispatch.

2. **Incremental scoring (SERIO)** — The Scoring Engine for Real-time
   Incremental Optimization only recalculates affected constraints when moves
   are evaluated, delivering 10-100x speedups.

3. **Type-safe moves** — `ChangeMove<S, V>` and `SwapMove<S, V>` store values
   inline without boxing or heap allocation. Arena allocation provides O(1)
   per-step cleanup.

4. **No garbage collection** — Predictable, low-latency performance without GC
   pauses.

5. **Modular architecture** — Each crate has a single responsibility, making the
   codebase maintainable and testable.

**The result:** You write declarative constraint logic that compiles to highly
optimized native code.

</details>

<details>
<summary><strong>What's implemented (0.7.1)</strong></summary>

**Repository**:
[solverforge/solverforge](https://github.com/solverforge/solverforge)

**Core solver features:**

- **Score types**: SoftScore, HardSoftScore, HardMediumSoftScore,
  HardSoftDecimalScore, BendableScore
- **Domain model**: Derive macros for `#[planning_solution]`,
  `#[planning_entity]`, `#[problem_fact]`
- **Variable types**: Genuine, shadow, list variables
- **Shadow variables**: `#[inverse_relation_shadow_variable]`,
  `#[previous_element_shadow_variable]`, `#[next_element_shadow_variable]`
- **Constraint Streams API**: `for_each`, generated collection accessors,
  unified `join`, `flatten_last`, `group_by`, `balance`,
  `if_exists_filtered`, `if_not_exists_filtered`, `penalize`, `reward`,
  and `.named()`
- **Advanced collectors**: `count`, `count_distinct`, `sum`, `min`, `max`,
  `to_list`, `to_set`, `balance`
- **Score analysis**: `ScoreAnalysis`, `ConstraintAnalysis`, `ScoreExplanation`,
  `IndictmentMap`

**Solver phases and runtime:**

- **Construction heuristics**: first fit, weakest fit, strongest fit, queue
  allocators, cheapest insertion, and list-specific constructors
- **Local search**: hill climbing, simulated annealing, tabu search, late
  acceptance, great deluge
- **Exhaustive search**: branch and bound and brute force
- **Partitioned search**: Multi-threaded parallel solving
- **VND**: Variable Neighborhood Descent

**Move system:**

- Basic: ChangeMove, SwapMove, CompositeMove
- List: ListChangeMove, ListSwapMove, ListReverseMove, SubListChangeMove,
  SubListSwapMove
- Advanced: KOptMove, RuinMove, PillarChangeMove, PillarSwapMove
- MoveArena: Zero-allocation move storage

**Infrastructure:**

- **SERIO**: Scoring Engine for Real-time Incremental Optimization
- **SolverManager**: Channel-based streaming API with `SolverEvent`
- **Configuration**: stock `solver.toml` loading plus TOML/YAML parsing APIs
- **Termination**: Time limits, step counts, score targets, unimproved step
  detection, composites (And/Or)
- **Nearby selection**: Distance-based move selection

**Performance:**

- Zero-allocation move system with arena allocation
- Type-safe moves without boxing (`ChangeMove<S, V>`, `SwapMove<S, V>`)
- No garbage collection pauses
- Incremental score calculation (10-100x faster than full recalculation)

</details>
