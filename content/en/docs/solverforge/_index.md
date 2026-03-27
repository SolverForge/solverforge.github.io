---
title: 'SolverForge'
linkTitle: 'SolverForge'
icon: fa-brands fa-rust
weight: 10
description: >
  Native Rust constraint solver — production-ready at v0.6.0.
---

SolverForge is a native Rust constraint solver for planning and scheduling
problems. It uses derive macros for domain modeling, constraint streams for
declarative rule definition, and metaheuristic algorithms for optimization.

## Installation

```bash
cargo add solverforge
```

## Minimal Example

```rust
use solverforge::prelude::*;

// 1. Define your domain
#[problem_fact]
#[derive(Clone, Debug)]
pub struct Employee {
    #[planning_id]
    pub id: i64,
    pub name: String,
}

#[planning_entity]
#[derive(Clone, Debug)]
pub struct Shift {
    #[planning_id]
    pub id: i64,
    pub required_skill: String,
    #[planning_variable(allows_unassigned = true)]
    pub employee: Option<Employee>,
}

#[planning_solution]
#[derive(Clone, Debug)]
pub struct Schedule {
    #[problem_fact_collection]
    #[value_range_provider]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

// 2. Define constraints
fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    let factory = ConstraintFactory::<Schedule, HardSoftScore>::new();

    let unassigned = factory
        .for_each(|s: &Schedule| s.shifts.as_slice())
        .filter(|s: &Shift| s.employee.is_none())
        .penalize(HardSoftScore::ONE_HARD)
        .named("Unassigned shift");

    (unassigned,)
}

// 3. Solve
fn main() {
    let problem = Schedule {
        employees: vec![/* ... */],
        shifts: vec![/* ... */],
        score: None,
    };

    let mut director = ScoreDirector::new(problem, define_constraints());
    let score = director.calculate_score();
    println!("Score: {:?}", score);
}
```

## API Reference

Full API documentation is available on
[docs.rs/solverforge](https://docs.rs/solverforge).

## Sections

- **[Domain Modeling](modeling/)** — Derive macros for solutions, entities, and
  problem facts
- **[Constraints](constraints/)** — Constraint streams, joiners, collectors, and
  score types
- **[Solver](solver/)** — Configuration, phases, moves, termination, and
  SolverManager
