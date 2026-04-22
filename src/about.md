---
title: About SolverForge
description: Constraint solving for planning, scheduling, routing, and allocation applications in Rust.
eyebrow: About
---

## Core Capabilities

SolverForge is Rust-native optimization infrastructure for real planning
systems. Build domain models in Rust, express hard and soft constraints as
code, and integrate solving into scheduling, dispatch, allocation, and
operational planning systems.

<div class="card-grid">
  <%= render Ui::Card.new(title: "Rust Solver Core", href: relative_url('/docs/overview/'), icon: "fa-brands fa-rust") do %>
A production-ready constraint solver with Constraint Streams, zero-allocation move types, score analysis, and a stable Rust API.
  <% end %>
  <%= render Ui::Card.new(title: "Employee Scheduling Tutorial", href: relative_url('/docs/getting-started/employee-scheduling-rust/'), icon: "fa-solid fa-calendar-days") do %>
Work through shifts, skills, preferences, and solver-driven updates end to end.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-ui", href: relative_url('/docs/solverforge-ui/'), icon: "fa-solid fa-display") do %>
Frontend components and integration helpers for scheduling-heavy products built on SolverForge.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-maps", href: relative_url('/docs/solverforge-maps/'), icon: "fa-solid fa-route") do %>
Routing primitives, cached road-network data, and travel metrics for map-backed planning and dispatch systems.
  <% end %>
</div>

## How It Works

SolverForge applications start with planning solutions and entities represented
as ordinary Rust structs. Constraint Streams define what must be satisfied and
what should be optimized, while score analysis helps explain tradeoffs. The
solver searches for better solutions and emits progress, best-solution, and
finished events that application code can consume.

`solverforge-ui` and `solverforge-maps` extend that core into interactive
scheduling and routing applications.

## Common Uses

- Workforce scheduling with hard compliance rules and soft preferences
- Routing and dispatch with travel-time-aware scoring
- Interactive planning applications that need solver feedback in the UI

## Open Source by Design

SolverForge ships as open source Rust crates, examples, and documentation on
GitHub. Teams can audit the solver, study the reference implementations, and
extend it for their own domains.

- [Project overview](/docs/overview/)
- [GitHub organization](https://github.com/SolverForge)
- [docs.rs API reference](https://docs.rs/solverforge)
- [Documentation](/docs/)

## Designed for Operational Complexity

SolverForge is suited to scheduling, routing, capacity planning, assignment, and
similar problems where feasibility and business value depend on many
interacting rules.

- [Employee scheduling tutorial](/docs/getting-started/employee-scheduling-rust/)
- [Routing docs](/docs/solverforge-maps/)
- [Blog](/blog/)
