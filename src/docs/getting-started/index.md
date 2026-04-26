---
title: Getting Started
linkTitle: 'Getting Started'
description: >
  Quickstart guides for building constraint solving applications with
  SolverForge.
categories: [Quickstarts]
tags: [quickstart]
weight: 2
---

<h1>Getting Started</h1>

<%= render Ui::Callout.new(title: "Current onboarding path") do %>
Start with **`solverforge-cli`** for the generic project shell. Then continue
with the **SolverForge Hospital Use Case** or **SolverForge Deliveries Use
Case** if you want one concrete worked example that goes further.
<% end %>

## Start Here

<div class="card-grid">
  <%= render Ui::Card.new(title: "CLI Quickstart", href: relative_url('/docs/solverforge-cli/getting-started/'), icon: "fa-solid fa-terminal") do %>
Install `solverforge-cli`, scaffold a new project, run the server, and extend the domain incrementally.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge Hospital Use Case", href: relative_url('/docs/getting-started/solverforge-hospital-use-case/'), icon: "fa-solid fa-calendar-days") do %>
Follow a longer worked example that carries the generic CLI shell into a
concrete hospital planning application.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge Deliveries Use Case", href: relative_url('/docs/getting-started/solverforge-deliveries-use-case/'), icon: "fa-solid fa-route") do %>
Study a route-optimization example with list variables, road-network data,
retained jobs, and delivery insertion recommendations.
  <% end %>
</div>

## Prerequisites

- **Rust toolchain**: Install via [rustup.rs](https://rustup.rs/) (stable channel)
- **Cargo**: Included with the Rust toolchain
- Familiarity with Rust basics (structs, traits, closures, derive macros)

## Fastest Path to a Running App

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

Open `http://localhost:7860` to see the generated app shell.

## Shaping the Model After Scaffolding

```bash
solverforge generate fact resource --field category:String --field load:i32
solverforge generate entity task --field label:String --field priority:i32
solverforge generate variable resource_idx --entity Task --kind scalar --range resources --allows-unassigned
solverforge generate data --size large
```

The current CLI no longer asks you to pick a modeling shape up front. Scalar
variables, list variables, and models that contain both are introduced through
generation and `solverforge.app.toml` after scaffolding.

## Where to Read More

- [CLI onboarding guide](../solverforge-cli/getting-started/)
- [SolverForge Hospital Use Case](solverforge-hospital-use-case/)
- [SolverForge Deliveries Use Case](solverforge-deliveries-use-case/)
- [SolverForge API documentation](https://docs.rs/solverforge)
- [Core GitHub repository](https://github.com/solverforge/solverforge)
