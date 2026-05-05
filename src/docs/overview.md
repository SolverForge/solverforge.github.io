---
title: Overview
description:
  What SolverForge is, how it differs from mathematical solvers, and where to
  start in the documentation.
weight: 1
tags: [concepts]
---

# What is SolverForge?

SolverForge is a **constraint satisfaction solver** for real-world planning and
scheduling problems. It helps you assign resources to tasks while respecting
business rules and optimizing for your goals.

## What Problems Does It Solve?

SolverForge excels at **combinatorial planning problems**: problems where a
brute-force search is impossible, but a good solution dramatically improves
efficiency.

<div class="card-grid">
  <%= render Ui::Card.new(title: "Hospital Scheduling", icon: "fa-solid fa-calendar-days") do %>
Assign hospital staff to shifts based on skills, availability, and labor regulations.
  <% end %>
  <%= render Ui::Card.new(title: "Vehicle Routing", icon: "fa-solid fa-route") do %>
Plan delivery routes that minimize travel time while meeting time windows.
  <% end %>
  <%= render Ui::Card.new(title: "School Timetabling", icon: "fa-solid fa-school") do %>
Schedule lessons to rooms and timeslots without conflicts.
  <% end %>
  <%= render Ui::Card.new(title: "Task Assignment", icon: "fa-solid fa-list-check") do %>
Allocate jobs to workers or machines optimally.
  <% end %>
  <%= render Ui::Card.new(title: "Meeting Scheduling", icon: "fa-solid fa-people-group") do %>
Find times and rooms that work for all attendees.
  <% end %>
  <%= render Ui::Card.new(title: "Bin Packing", icon: "fa-solid fa-boxes-stacked") do %>
Fit items into containers efficiently.
  <% end %>
</div>

## How Is This Different from Gurobi or CVXPY?

SolverForge and mathematical programming solvers solve different kinds of
problems using different modeling approaches.

|                          | SolverForge                                | Mathematical Solvers (Gurobi, CVXPY)                      |
| ------------------------ | ------------------------------------------ | --------------------------------------------------------- |
| **Problem type**         | Constraint satisfaction and scheduling     | Linear/mixed-integer programming                          |
| **Modeling approach**    | Business objects with rules                | Mathematical equations and matrices                       |
| **Constraints**          | Rules on domain objects                    | Linear inequalities                                       |
| **Best for**             | Scheduling, routing, assignment            | Resource allocation, network flow, portfolio optimization |
| **Developer experience** | Write rules about shifts and employees     | Formulate objective functions and constraint matrices     |

### A Concrete Example

<div class="code-tabs" data-code-tabs>
  <div class="code-tabs__buttons">
    <button class="code-tabs__button" type="button" data-tab-button="solverforge">SolverForge (Rust)</button>
    <button class="code-tabs__button" type="button" data-tab-button="gurobi">Gurobi / CVXPY</button>
  </div>
  <div class="code-tabs__panel" data-tab-panel="solverforge">
    <%= render Ui::CodeBlock.new(language: "rust") do %>
      use solverforge::prelude::*;
      use solverforge::stream::{joiner::*, ConstraintFactory};

      fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftDecimalScore> {
          type Streams = ConstraintFactory<Schedule, HardSoftDecimalScore>;

          let unassigned = Streams::new()
              .shifts()
              .unassigned()
              .penalize(HardSoftDecimalScore::of_hard_scaled(100_000))
              .named("Unassigned shift");

          let missing_skill = Streams::new()
              .shifts()
              .filter(|shift: &Shift| shift.employee_idx.is_some())
              .join((
                  Streams::new().employees(),
                  equal_bi(
                      |shift: &Shift| shift.employee_idx,
                      |employee: &Employee| Some(employee.index),
                  ),
              ))
              .filter(|shift: &Shift, employee: &Employee| {
                  !employee.skills.contains(&shift.required_skill)
              })
              .penalize(HardSoftDecimalScore::of_hard_scaled(1_000_000))
              .named("Missing skill");

          (unassigned, missing_skill)
      }
    <% end %>

  </div>
  <div class="code-tabs__panel" data-tab-panel="gurobi" hidden>
    <%= render Ui::CodeBlock.new(language: "python") do %>
      # You must translate your problem into mathematical form.
      x = model.addVars(employees, shifts, vtype=GRB.BINARY)
      model.addConstrs(sum(x[e,s] for e in employees) == 1 for s in shifts)
      model.addConstrs(sum(x[e,s] for s in shifts) <= max_shifts for e in employees)
    <% end %>
  </div>
</div>

With SolverForge, you work with domain objects (`Shift`, `Employee`) and
express constraints as business rules. You do not need to reformulate the
problem as a system of linear equations.

## When to Use Each

Use SolverForge when:

- your problem involves scheduling, routing, or assignment
- constraints are naturally expressed as business rules
- the problem structure does not fit neatly into linear programming
- readable, maintainable constraint definitions matter

Use Gurobi, CPLEX, or CVXPY when:

- your problem is naturally linear or convex
- you need provably optimal solutions with bounds
- the problem fits the mathematical programming paradigm

## Developer Experience

SolverForge provides a Rust derive-macro API for ergonomic domain modeling:

```rust
use solverforge::prelude::*;

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: String,
    pub required_skill: String,
    #[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
    pub employee_idx: Option<usize>,
}

#[planning_solution(constraints = "crate::constraints::define_constraints")]
pub struct Plan {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftDecimalScore>,
}
```

You define the domain model with derive macros and attribute annotations. The
solver searches assignments that satisfy hard rules and improve the configured
score.

## Where To Go Next

<div class="card-grid">
  <%= render Ui::Card.new(title: "Status & Roadmap", href: relative_url('/docs/status-and-roadmap/'), icon: "fa-solid fa-road") do %>
Current release, published package status, completed runtime surface, and roadmap.
  <% end %>
  <%= render Ui::Card.new(title: "Architecture", href: relative_url('/docs/architecture/'), icon: "fa-solid fa-diagram-project") do %>
Crate responsibilities, zero-erasure design, SERIO scoring, and retained runtime pieces.
  <% end %>
  <%= render Ui::Card.new(title: "Getting Started", href: relative_url('/docs/getting-started/'), icon: "fa-solid fa-rocket") do %>
Start from the CLI scaffold and follow concrete hospital or delivery examples.
  <% end %>
</div>
