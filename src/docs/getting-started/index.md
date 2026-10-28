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
Install **`solverforge-cli`** and the **`solverforge-modeling` agent skill**,
then describe your planning problem to your coding agent. Follow the
**maintenance planning walkthrough** to see one run end to end, or build the
shell by hand with the CLI quickstart and the four worked use cases.
<% end %>

## Start Here

<div class="card-grid">
    <%= render Ui::Card.new(title: "1. Install the Agent Skill", href: relative_url('/docs/solverforge-cli/agent-skill/'), icon: "fa-solid fa-wand-magic-sparkles") do %>
Install the CLI and the `solverforge-modeling` skill, then describe your
problem to Claude Code, Codex, or opencode.
  <% end %>
  <%= render Ui::Card.new(title: "Maintenance Planning Walkthrough", href: relative_url('/docs/getting-started/maintenance-planning-with-the-agent-skill/'), icon: "fa-solid fa-screwdriver-wrench") do %>
Follow one agent run from a plain-language depot maintenance problem to a
solved plan served by an API shell.
  <% end %>
  <%= render Ui::Card.new(title: "CLI Quickstart", href: relative_url('/docs/solverforge-cli/getting-started/'), icon: "fa-solid fa-terminal") do %>
Install `solverforge-cli`, scaffold a new project, run the server, and extend the domain incrementally.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge Hospital Use Case", href: relative_url('/docs/getting-started/solverforge-hospital-use-case/'), icon: "fa-solid fa-calendar-days") do %>
Follow a longer worked example that carries the generic CLI shell into a
concrete hospital planning application.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge Lessons Use Case", href: relative_url('/docs/getting-started/solverforge-lessons-use-case/'), icon: "fa-solid fa-school") do %>
Study a lesson-timetabling example with teachers, cohorts, rooms, weekly
timeslots, two scalar variables, retained jobs, and timetable views.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge Deliveries Use Case", href: relative_url('/docs/getting-started/solverforge-deliveries-use-case/'), icon: "fa-solid fa-route") do %>
Study a route-optimization example with list variables, road-network data,
retained jobs, and delivery insertion recommendations.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge FSR Use Case", href: relative_url('/docs/getting-started/solverforge-fsr-use-case/'), icon: "fa-solid fa-screwdriver-wrench") do %>
Follow a field-service routing example with technicians, skills, parts, shifts,
road-network travel, retained jobs, and route geometry.
  <% end %>
</div>

## Prerequisites

- **Rust toolchain**: Install via [rustup.rs](https://rustup.rs/) (stable channel)
- **Cargo**: Included with the Rust toolchain
- Familiarity with Rust basics (structs, traits, closures, derive macros)

## Fastest Path to a Running App

With a coding agent:

```bash
cargo install solverforge-cli
git clone https://github.com/SolverForge/solverforge-cli
cd solverforge-cli
./scripts/install-skill --agent claude     # or: --agent codex, --agent opencode
```

Restart the agent and describe your problem; the
[Agent Skill](/docs/solverforge-cli/agent-skill/#quick-start) page has a prompt
template.

By hand:

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

- [Agent Skill](/docs/solverforge-cli/agent-skill/)
- [Maintenance planning walkthrough](/docs/getting-started/maintenance-planning-with-the-agent-skill/)
- [Use cases showcase](/use-cases/): narrated walkthroughs and annotated screenshots of eight planning apps
- [CLI onboarding guide](/docs/solverforge-cli/getting-started/)
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
- [SolverForge Lessons Use Case](/docs/getting-started/solverforge-lessons-use-case/)
- [SolverForge Deliveries Use Case](/docs/getting-started/solverforge-deliveries-use-case/)
- [SolverForge FSR Use Case](/docs/getting-started/solverforge-fsr-use-case/)
- [SolverForge API documentation](https://docs.rs/solverforge)
- [Core GitHub repository](https://github.com/solverforge/solverforge)
