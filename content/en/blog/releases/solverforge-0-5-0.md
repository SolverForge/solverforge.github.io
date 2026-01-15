---
title: "SolverForge 0.5.0: Zero-Erasure Constraint Solving"
date: 2026-01-15
draft: false
tags: [rust, release]
description: >
  Introducing SolverForge 0.5.0 - a general-purpose constraint solver written in native Rust with zero-erasure architecture and the SERIO incremental scoring engine.
---

{{< alert title="Major Release" color="success" >}}
SolverForge 0.5.0 represents a complete architectural rewrite. It is no longer a WASM compiler or a wrapper around the JVM.
This is a native Rust constraint solver built from the ground up with zero-erasure design and the SERIO incremental scoring engine.
{{< /alert >}}

We're excited to announce **SolverForge 0.5.0**, a complete rewrite of SolverForge as a native Rust constraint solver. This isn't a wrapper around an existing solver or a bridge between languages, but a ground-up implementation built on a new architecture powered by the SERIO (Scoring Engine for Real-time Incremental Optimization) engine - our zero-erasure implementation inspired by Timefold's BAVET engine.

After [exploring FFI complexity](/blog/technical/2025/12/30/why-java-interop-is-difficult/), [performance bottlenecks in Python-Java bridges](/blog/technical/2025/12/07/order-picking-quickstart-jpype-performance/) and the [architectural constraints of cross-language constraint solving](/blog/technical/2025/12/06/python-constraint-solver-architecture/), we made a fundamental choice: build something different. 
The result is a general-purpose constraint solver in Rust and it is blazing fast.

While this release is labeled beta as the API continues to mature, SolverForge 0.5.0 is production-capable and represents a major architectural milestone in the project's evolution.

## What is SolverForge?

SolverForge is a constraint solver for planning and scheduling problems. It tackles complex optimization challenges like employee scheduling, vehicle routing, resource allocation, and task assignment—problems where you need to satisfy hard constraints while optimizing for quality metrics.

Inspired by [Timefold](https://timefold.ai/) (formerly OptaPlanner), SolverForge takes a fundamentally different architectural approach centered on **zero-erasure design**. Rather than relying on dynamic dispatch and runtime polymorphism, SolverForge preserves concrete types throughout the solver pipeline, enabling aggressive compiler optimizations and predictable performance characteristics.

At its core is the **SERIO engine**—Scoring Engine for Real-time Incremental Optimization—which efficiently propagates constraint changes through the solution space as the solver explores candidate moves.

## Zero-Erasure Architecture

The zero-erasure philosophy shapes every layer of SolverForge. Here's what it means in practice:

- **No trait objects**: No `Box<dyn Trait>` or `Arc<dyn Trait>` in hot paths
- **No runtime dispatch**: All generics resolved at compile time via monomorphization
- **No hidden allocations**: Moves, scores, and constraints are stack-allocated
- **Predictable performance**: No garbage collection pauses, no vtable lookups

Traditional constraint solvers often use polymorphism to handle different problem types dynamically. This flexibility comes at a cost: heap allocations, pointer indirection, and unpredictable cache behavior. In constraint solving, where the inner loop evaluates millions of moves per second, these costs compound quickly.

SolverForge's zero-erasure design means the compiler knows the concrete types of your entities, variables, scores, and constraints at compile time. It can inline aggressively, eliminate dead code, and generate cache-friendly machine code tailored to your specific problem structure.

```rust
// Zero-erasure move evaluation - fully monomorphized
fn evaluate_move<M: Move<Solution>>(
    move_: &M,
    director: &mut TypedScoreDirector<Solution, Score>
) -> Score {
    // No dynamic dispatch, no allocations, no boxing
    director.do_and_process_move(move_)
}
```

This isn't just a performance optimization—it fundamentally changes how you reason about solver behavior. Costs are visible in the type system. There are no surprise heap allocations or dynamic dispatch overhead hiding in framework abstractions.

## The SERIO Engine

SERIO—Scoring Engine for Real-time Incremental Optimization—is SolverForge's constraint evaluation engine. It powers the ConstraintStream API, which lets you define constraints declaratively using fluent builders:

```rust
use solverforge::stream::{ConstraintFactory, joiner};

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

    let required_skill = factory
        .clone()
        .for_each(|s: &Schedule| s.shifts.as_slice())
        .join(
            |s: &Schedule| s.employees.as_slice(),
            joiner::equal_bi(
                |shift: &Shift| shift.employee_id,
                |emp: &Employee| Some(emp.id),
            ),
        )
        .filter(|shift: &Shift, emp: &Employee| {
            !emp.skills.contains(&shift.required_skill)
        })
        .penalize(HardSoftScore::ONE_HARD)
        .as_constraint("Required skill");

    let no_overlap = factory
        .for_each_unique_pair(
            |s: &Schedule| s.shifts.as_slice(),
            joiner::equal(|shift: &Shift| shift.employee_id),
        )
        .filter(|a: &Shift, b: &Shift| {
            a.employee_id.is_some() && a.start < b.end && b.start < a.end
        })
        .penalize(HardSoftScore::ONE_HARD)
        .as_constraint("No overlap");

    (required_skill, no_overlap)
}
```

The key to SERIO's efficiency is **incremental scoring**. When the solver considers a move (like reassigning a shift to a different employee), SERIO doesn't re-evaluate every constraint from scratch. Instead, it tracks which constraint matches are affected by the change and recalculates only those.

Under the zero-erasure design, these incremental updates happen without heap allocations or dynamic dispatch. The constraint evaluation pipeline is fully monomorphized—each constraint stream compiles to specialized code for your exact entity types and filter predicates.

## Developer Experience in 0.5.0

Version 0.5.0 brings significant improvements to the developer experience, making it easier to define problems and monitor solver progress.

### Fluent API & Macros

Domain models are defined using derive macros that generate the boilerplate:

```rust
use solverforge::prelude::*;

#[problem_fact]
pub struct Employee {
    pub id: i64,
    pub name: String,
    pub skills: Vec<String>,
}

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: i64,
    pub required_skill: String,
    #[planning_variable]
    pub employee_id: Option<i64>,
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

The `#[planning_solution]` macro now generates helper methods for basic variable problems, including:
- Entity count accessors (`shift_count()`, `employee_count()`)
- List operation methods for manipulating planning entities
- A `solve()` method that sets up the solver with sensible defaults

This reduces boilerplate and makes simple problems trivial to solve while still allowing full customization for complex scenarios.

### Console Output

With the `console` feature enabled, SolverForge displays beautiful real-time progress:

```
 ____        _                 _____
/ ___|  ___ | |_   _____ _ __ |  ___|__  _ __ __ _  ___
\___ \ / _ \| \ \ / / _ \ '__|| |_ / _ \| '__/ _` |/ _ \
 ___) | (_) | |\ V /  __/ |   |  _| (_) | | | (_| |  __/
|____/ \___/|_| \_/ \___|_|   |_|  \___/|_|  \__, |\___|
                                             |___/
                   v0.5.0 - Zero-Erasure Constraint Solver

  0.000s ▶ Solving │ 14 entities │ 5 values │ scale 9.799 x 10^0
  0.001s ▶ Construction Heuristic started
  0.002s ◀ Construction Heuristic ended │ 1ms │ 14 steps │ 14,000/s │ 0hard/-50soft
  0.002s ▶ Late Acceptance started
  1.002s ⚡    12,456 steps │      445,000/s │ -2hard/8soft
  2.003s ⚡    24,891 steps │      448,000/s │ 0hard/12soft
 30.001s ◀ Late Acceptance ended │ 30.00s │ 104,864 steps │ 456,000/s │ 0hard/15soft
 30.001s ■ Solving complete │ 0hard/15soft │ FEASIBLE
```

The `verbose-logging` feature adds DEBUG-level progress updates (approximately once per second during local search), giving insight into solver behavior without overwhelming the terminal.

### Shadow Variables

Shadow variables are derived values that depend on genuine planning variables. For example, in vehicle routing, a vehicle's arrival time at a location depends on which locations come before it in the route.

Version 0.5.0 adds first-class support for shadow variables:

```rust
#[planning_entity]
pub struct Visit {
    #[planning_variable]
    pub vehicle_id: Option<i64>,

    #[shadow_variable]
    pub arrival_time: Option<i64>,  // Computed based on route position
}
```

The new `ShadowAwareScoreDirector` tracks shadow variable dependencies and updates them automatically when genuine variables change. The `filter_with_solution()` method on uni-streams allows constraints to access shadow variables during evaluation:

```rust
factory
    .for_each(|s: &Schedule| s.visits.as_slice())
    .filter_with_solution(|solution: &Schedule, visit: &Visit| {
        // Access shadow variable through solution
        visit.arrival_time.unwrap() > solution.time_window_end
    })
    .penalize(HardSoftScore::ONE_HARD)
    .as_constraint("Late arrival")
```

### Event-Based Solving

The new `solve_with_events()` API provides real-time feedback during solving:

```rust
use solverforge::{SolverManager, SolverEvent};

let (job_id, receiver) = SolverManager::global().solve_with_events(schedule);

for event in receiver {
    match event {
        SolverEvent::BestSolutionChanged { solution, score } => {
            println!("New best: {}", score);
            update_dashboard(&solution);
        }
        SolverEvent::PhaseStarted { phase_name } => {
            println!("Starting {}", phase_name);
        }
        SolverEvent::SolvingEnded { final_solution, .. } => {
            println!("Done!");
            break;
        }
    }
}
```

This enables building interactive UIs, progress bars, and real-time solution dashboards that update as the solver finds better solutions.

## Phase Builders

SolverForge 0.5.0 introduces fluent builders for configuring solver phases:

```rust
use solverforge::prelude::*;

let solver = SolverManager::builder()
    .with_phase_factory(|config| {
        vec![
            Box::new(BasicConstructionPhaseBuilder::new()),
            Box::new(BasicLocalSearchPhaseBuilder::new()
                .with_late_acceptance(400)),
        ]
    })
    .build()?;
```

Available phase builders include:
- **BasicConstructionPhaseBuilder**: First Fit construction for basic variables
- **BasicLocalSearchPhaseBuilder**: Hill climbing, simulated annealing, tabu search, late acceptance
- **ListConstructionPhaseBuilder**: Construction heuristics for list variables
- **KOptPhaseBuilder**: K-opt local search for tour optimization (TSP, VRP)

Each phase builder integrates with the new stats system (`PhaseStats`, `SolverStats`), providing structured access to solve metrics like step count, score calculation speed, and time spent per phase.

## Breaking Changes

Version 0.5.0 includes one breaking change to enable shadow variable support:

**Solution-aware filter traits**: Uni-stream filters can now optionally access the solution using `filter_with_solution()`. This enables constraints to reference shadow variables and other solution-level computed state.

```rust
// Before: Filter receives only the entity
.filter(|shift: &Shift| shift.employee_id.is_some())

// After: Same syntax still works
.filter(|shift: &Shift| shift.employee_id.is_some())

// New: Can also access solution for shadow variables
.filter_with_solution(|solution: &Schedule, shift: &Shift| {
    // Access shadow variables through solution context
    shift.arrival_time.unwrap() < solution.deadline
})
```

The standard `filter()` method remains unchanged for simple predicates. Bi/Tri/Quad/Penta stream filters (after joins) continue to receive only the entity tuples without the solution reference.

{{< alert title="Note" color="info" >}}
The API split between `filter()` and `filter_with_solution()` is temporary. Version 0.5.1 will unify these into a single `filter()` method that accepts both closure signatures, eliminating this distinction.
{{< /alert >}}

If you're upgrading from 0.4.0 and only using entity-level filters, no changes are required.

## What's Still Beta

{{< alert title="Beta Status" color="warning" >}}
While SolverForge 0.5.0 is production-capable, some areas are still maturing:

- **API stability**: Core APIs are stable, but we may introduce minor breaking changes based on feedback
- **Documentation**: API docs are comprehensive, but tutorials and guides are still being developed
- **Ecosystem**: Quickstarts and examples are growing but not yet comprehensive
{{< /alert >}}

The [component status table](https://github.com/solverforge/solverforge#component-status) in the README tracks what's complete:

| Component | Status |
|-----------|--------|
| Score types | Complete |
| Domain model macros | Complete |
| ConstraintStream API | Complete |
| SERIO incremental scoring | Complete |
| Construction heuristics | Complete |
| Local search | Complete |
| Exhaustive search | Complete |
| Partitioned search | Complete |
| VND | Complete |
| Move system | Complete |
| Termination | Complete |
| SolverManager | Complete |
| SolutionManager | Complete |
| Console output | Complete |
| Benchmarking | Complete |

Core solver functionality is complete and well-tested. The beta label reflects that we're still gathering real-world feedback on ergonomics and API design.

## Getting Started

Add SolverForge to your `Cargo.toml`:

```toml
[dependencies]
solverforge = { version = "0.5", features = ["console"] }
```

Try the **[Employee Scheduling Quickstart](https://github.com/solverforge/solverforge-quickstarts)**, which demonstrates a complete employee scheduling problem with shifts, skills, and availability constraints. It's the fastest way to see SolverForge in action and understand the workflow for defining problems, constraints, and solving.

The quickstarts repository will continue to grow with more examples covering different problem types and solver features.

## Python Bindings Coming Soon

While SolverForge is now a native Rust solver, we remain committed to multi-language accessibility. **Python bindings are under active development** at [github.com/solverforge/solverforge-py](https://github.com/solverforge/solverforge-py) and will be released later this month (late January 2026).

The architectural shift to native Rust was a major undertaking, and we chose to focus on getting the core solver right before building language bridges. The Python bindings will provide idiomatic Python APIs backed by SolverForge's zero-erasure engine, giving Python developers native constraint solving performance with familiar syntax.

This gives us the best of both worlds: predictable, high-performance solving in Rust, with accessible bindings for the broader Python ecosystem.

## What's Next

Beyond Python bindings, the quickstart roadmap includes:

- **Employee Scheduling**: ✓ Available now
- **Vehicle Routing**: Next in pipeline
- More domain-specific examples as the ecosystem grows

We're also working on:
- Expanded documentation and tutorials
- Additional constraint stream operations
- Performance benchmarks comparing different solver configurations
- Community-contributed problem templates

## Looking Ahead

Version 0.5.0 represents a turning point for SolverForge. The zero-erasure architecture and SERIO engine provide a foundation for building a high-performance, accessible constraint solver that works across languages while maintaining Rust's performance and safety guarantees.

We invite you to try SolverForge 0.5.0, explore the [quickstarts](https://github.com/solverforge/solverforge-quickstarts), and share your feedback. Whether you're scheduling employees, routing vehicles, or optimizing resource allocation, SolverForge provides the tools to model and solve your constraints efficiently.

The journey from FFI experiments to native Rust solver has been challenging, but the result is a constraint solver built on solid architectural foundations. We're excited to see what you build with it.

---

**Further reading:**
- [SolverForge on GitHub](https://github.com/solverforge/solverforge)
- [Quickstarts Repository](https://github.com/solverforge/solverforge-quickstarts)
- [API Documentation](https://docs.rs/solverforge)
- [Python Bindings (Coming Soon)](https://github.com/solverforge/solverforge-py)
- [Why Java Interop is Difficult](/blog/technical/2025/12/30/why-java-interop-is-difficult/)
- [JPype Performance Challenges](/blog/technical/2025/12/07/order-picking-quickstart-jpype-performance/)
- [Python Architecture Lessons](/blog/technical/2025/12/06/python-constraint-solver-architecture/)
