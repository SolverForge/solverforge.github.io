---
title: About SolverForge
description: SolverForge helps teams build planning software that keeps scheduling, routing, allocation, and dispatch rules inspectable in Rust.
eyebrow: About
---

## What SolverForge Helps You Build

SolverForge is for teams whose planning logic has outgrown manual rules,
spreadsheet workflows, or opaque solver integrations. It keeps the model,
constraints, score analysis, and solve lifecycle in ordinary Rust, so engineers
can inspect what the planner is doing and operators can see why a plan changed.

Use it when your product needs to assign people, vehicles, jobs, inventory, or
time slots while respecting hard constraints and improving softer business
goals.

<div class="card-grid">
  <%= render Ui::Card.new(title: "Model real operations", href: relative_url('/docs/overview/'), icon: "fa-solid fa-diagram-project") do %>
Represent shifts, routes, tasks, workers, vehicles, and demand as typed Rust data instead of forcing the problem into a separate modeling language.
  <% end %>
  <%= render Ui::Card.new(title: "Explain tradeoffs", href: relative_url('/docs/solverforge/constraints/score-analysis/'), icon: "fa-solid fa-scale-balanced") do %>
Use score analysis, named constraints, and retained snapshots to understand why one plan beats another.
  <% end %>
  <%= render Ui::Card.new(title: "Ship the workflow", href: relative_url('/docs/solverforge-ui/'), icon: "fa-solid fa-display") do %>
Connect solving to browser controls, retained jobs, scheduling views, and lifecycle actions without rebuilding the same UI plumbing.
  <% end %>
  <%= render Ui::Card.new(title: "Add routing when needed", href: relative_url('/docs/solverforge-maps/'), icon: "fa-solid fa-route") do %>
Use road-network data, route geometry, and travel-time matrices when distance and geography affect the plan.
  <% end %>
</div>

## How It Works

The best way to judge SolverForge is through complete applications. These two
examples show how real planning questions become typed model objects, solver
variables, constraints, retained jobs, and browser behavior.

<div class="card-grid">
  <%= render Ui::Card.new(title: "Hospital scheduling", href: relative_url('/docs/getting-started/solverforge-hospital-use-case/'), icon: "fa-solid fa-calendar-days") do %>
"Given a hospital workforce and a month of shifts, which employee should cover each shift?"

- `Employee` is a problem fact: input data the solver does not move
- `Shift` is the planning entity: the thing the solver assigns
- `Shift.employee_idx` is the planning variable: the actual choice the solver makes
- 50 employees
- 688 shifts
  <% end %>
  <%= render Ui::Card.new(title: "Delivery routing", href: relative_url('/docs/getting-started/solverforge-deliveries-use-case/'), icon: "fa-solid fa-route") do %>
"Given depots, vehicles, delivery stops, capacities, and time windows, which vehicle should visit each delivery and in what order?"

- `Delivery` is a problem fact: a stop the solver must place in a route.
- `Vehicle` is a planning entity: each vehicle owns one mutable route.
- `Vehicle.delivery_order` is the list planning variable.
- `PHILADELPHIA` (default)
- `FIRENZE`
  <% end %>
</div>

## Where It Fits

- Workforce scheduling with skills, availability, compliance rules, and preferences
- Routing and dispatch where travel time changes the quality of the plan
- Allocation and assignment problems with many possible combinations
- Interactive planning tools where users need solver feedback before accepting a plan

## Why Teams Can Trust It

SolverForge ships as open source Rust crates, examples, release notes, and
documentation. Before adopting it, teams can inspect the implementation, run the
examples, review the API docs, and see how behavior changes from release to
release.

<div class="card-grid">
  <%= render Ui::Card.new(title: "Read the overview", href: relative_url('/docs/overview/'), icon: "fa-solid fa-compass") do %>
Understand the planning problems SolverForge handles and when another solver style is a better fit.
  <% end %>
  <%= render Ui::Card.new(title: "Run a worked example", href: relative_url('/docs/getting-started/solverforge-hospital-use-case/'), icon: "fa-solid fa-calendar-days") do %>
Inspect a hospital scheduling app with skills, availability, retained jobs, snapshots, and browser updates.
  <% end %>
  <%= render Ui::Card.new(title: "Inspect the source", href: "https://github.com/SolverForge", icon: "fa-brands fa-github") do %>
Review the crates, examples, releases, and issue history before depending on the work.
  <% end %>
</div>
