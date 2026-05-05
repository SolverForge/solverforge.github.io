---
title: Documentation
linkTitle: Docs
menu: { main: { weight: 20 } }
---

<h1>Documentation</h1>

Use these docs to learn what SolverForge solves, scaffold a working app, and
inspect the Rust APIs behind the runtime, UI, and routing helpers. Section
indexes orient the tree; deep links take you straight to the implementation
surface.

## Start Here

<div class="card-grid">
  <%= render Ui::Card.new(title: "Overview", href: relative_url('/docs/overview/'), icon: "fa-solid fa-compass") do %>
What SolverForge solves, when to use it, and how it differs from mathematical solvers.
  <% end %>
  <%= render Ui::Card.new(title: "Status & Roadmap", href: relative_url('/docs/status-and-roadmap/'), icon: "fa-solid fa-road") do %>
Current release, published package status, runtime surface, and roadmap.
  <% end %>
  <%= render Ui::Card.new(title: "Getting Started", href: relative_url('/docs/getting-started/'), icon: "fa-solid fa-terminal") do %>
Start with the CLI shell, then continue into a complete hospital, deliveries, or field-service use case.
  <% end %>
</div>

## Worked Use Cases

<div class="card-grid">
  <%= render Ui::Card.new(title: "Hospital Use Case", href: relative_url('/docs/getting-started/solverforge-hospital-use-case/'), icon: "fa-solid fa-calendar-days") do %>
Scalar assignment, retained jobs, schedule constraints, and browser updates in one worked app.
  <% end %>
  <%= render Ui::Card.new(title: "Deliveries Use Case", href: relative_url('/docs/getting-started/solverforge-deliveries-use-case/'), icon: "fa-solid fa-route") do %>
List-variable vehicle routing with maps, retained snapshots, and insertion recommendations.
  <% end %>
  <%= render Ui::Card.new(title: "FSR Use Case", href: relative_url('/docs/getting-started/solverforge-fsr-use-case/'), icon: "fa-solid fa-screwdriver-wrench") do %>
Field-service routing with technicians, skills, shifts, road-network travel, and route geometry.
  <% end %>
</div>

## Runtime Reference

<div class="card-grid">
  <%= render Ui::Card.new(title: "Constraint Factory Methods", href: relative_url('/docs/solverforge/constraints/constraint-factory-methods/'), icon: "fa-solid fa-filter") do %>
Generated accessors, source-aware streams, joins, projections, collections, and scoring terminals.
  <% end %>
  <%= render Ui::Card.new(title: "Solver Configuration", href: relative_url('/docs/solverforge/solver/configuration/'), icon: "fa-solid fa-sliders") do %>
`solver.toml`, phase configuration, move selectors, acceptors, foragers, and facade exports.
  <% end %>
  <%= render Ui::Card.new(title: "Projected Scoring Rows", href: relative_url('/docs/solverforge/constraints/projected-scoring-rows/'), icon: "fa-solid fa-table-list") do %>
Retained scoring-only rows from projection types and joined-pair `.project(...)`.
  <% end %>
  <%= render Ui::Card.new(title: "SolverManager", href: relative_url('/docs/solverforge/solver/solver-manager/'), icon: "fa-solid fa-arrows-rotate") do %>
Retained solve lifecycle, snapshots, events, analysis, pause, resume, cancel, and delete.
  <% end %>
</div>

## Companion Crates

<div class="card-grid">
  <%= render Ui::Card.new(title: "solverforge-maps", href: relative_url('/docs/solverforge-maps/'), icon: "fa-solid fa-route") do %>
Road-network loading, routing, matrices, route geometry, and map-backed planning helpers.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-ui", href: relative_url('/docs/solverforge-ui/'), icon: "fa-solid fa-display") do %>
Frontend assets, lifecycle adapters, retained-job controls, and scheduling views.
  <% end %>
  <%= render Ui::Card.new(title: "Crate & Runtime Map", href: relative_url('/reference/crate-map/'), icon: "fa-solid fa-diagram-project") do %>
Which crate or companion repository owns each part of the runtime surface.
  <% end %>
</div>
