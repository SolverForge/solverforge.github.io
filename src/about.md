---
title: About SolverForge
description: SolverForge builds Rust-native planning software for scheduling, routing, allocation, and dispatch problems.
eyebrow: About
---

## What SolverForge Does

SolverForge builds Rust-native optimization software for real planning systems.
Teams use it when schedules, routes, assignments, or capacity plans depend on
many interacting hard rules and business preferences.

You model the domain in Rust, express hard and soft constraints as code, and
keep solver control inside the application instead of handing the planning
logic to a separate black box.

<div class="card-grid">
  <%= render Ui::Card.new(title: "Rust Solver Core", href: relative_url('/docs/overview/'), icon: "fa-brands fa-rust") do %>
A production-ready constraint solver with Constraint Streams, zero-allocation move types, score analysis, and a stable Rust API your team can audit.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge Hospital Use Case", href: relative_url('/docs/getting-started/solverforge-hospital-use-case/'), icon: "fa-solid fa-calendar-days") do %>
See one concrete hospital planning application end to end, starting from the
generic CLI shell and carrying it through to solver-driven updates.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-ui", href: relative_url('/docs/solverforge-ui/'), icon: "fa-solid fa-display") do %>
Frontend components and integration helpers for scheduling-heavy products built on SolverForge.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-maps", href: relative_url('/docs/solverforge-maps/'), icon: "fa-solid fa-route") do %>
Routing primitives, cached road-network data, and travel metrics for map-backed planning and dispatch systems.
  <% end %>
</div>

## How The Product Works

SolverForge applications start with planning solutions and entities represented
as ordinary Rust structs. Constraint Streams define what must be satisfied and
what should be optimized, while score analysis helps explain tradeoffs. The
solver searches for better solutions and emits progress, best-solution, and
finished events that application code can consume.

`solverforge-ui` adds retained-job controls and scheduling views for browser
applications. `solverforge-maps` adds road-network data, route geometry, and
travel-time matrices when routing costs matter.

## Common Uses

- Workforce scheduling with hard compliance rules and soft preferences
- Routing and dispatch with travel-time-aware scoring
- Interactive planning applications that need solver feedback in the UI

## Why Teams Can Trust It

SolverForge ships as open source Rust crates, examples, release notes, and
documentation. Teams can inspect the implementation, run the examples, review
the API docs, and see how behavior changes from release to release before they
commit to using it.

- [Project overview](/docs/overview/)
- [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
- [GitHub organization](https://github.com/SolverForge)
- [docs.rs API reference](https://docs.rs/solverforge)
- [Documentation](/docs/)

## Built For Operational Complexity

SolverForge is suited to scheduling, routing, capacity planning, assignment, and
similar problems where feasibility and business value depend on many
interacting rules.

- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
- [Routing docs](/docs/solverforge-maps/)
- [Blog](/blog/)
