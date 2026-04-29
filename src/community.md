---
title: Community
description: Ask technical questions, inspect the implementation, follow releases, or start a commercial conversation with SolverForge.
eyebrow: Community
---

Use the channel that matches what you need next. SolverForge is open source, so
technical evaluation can happen in public; commercial or adoption-specific
questions can go directly to the maintainers.

<div class="card-grid">
  <%= render Ui::Card.new(title: "Ask a question", href: "https://discord.gg/ngUDEAhq4P", icon: "fa-brands fa-discord") do %>
Use Discord for early technical questions, modeling feedback, and adoption discussion.
  <% end %>
  <%= render Ui::Card.new(title: "Follow public updates", href: site.metadata.x, icon: "fa-brands fa-x-twitter") do %>
Use X for public build notes, release context, and short updates from the SolverForge maintainer.
  <% end %>
  <%= render Ui::Card.new(title: "Report or inspect work", href: "https://github.com/SolverForge", icon: "fa-brands fa-github") do %>
Use GitHub for source code, issues, releases, and implementation history.
  <% end %>
  <%= render Ui::Card.new(title: "Check published APIs", href: "https://docs.rs/solverforge", icon: "fa-brands fa-rust") do %>
Use docs.rs and crates.io to verify the exact Rust API and crate version you plan to install.
  <% end %>
  <%= render Ui::Card.new(title: "Discuss a project", href: "mailto:maintainers@solverforge.org", icon: "fa-solid fa-envelope") do %>
Email when you need help judging fit, reducing adoption risk, or planning commercial work.
  <% end %>
</div>

## Good Starting Points

<div class="card-grid">
  <%= render Ui::Card.new(title: "Project overview", href: relative_url('/docs/overview/'), icon: "fa-solid fa-compass") do %>
Start here to understand the problem types, solver fit, and current runtime line.
  <% end %>
  <%= render Ui::Card.new(title: "CLI quickstart", href: relative_url('/docs/solverforge-cli/getting-started/'), icon: "fa-solid fa-terminal") do %>
Install the CLI, scaffold a runnable app, and make the first model change.
  <% end %>
  <%= render Ui::Card.new(title: "Hospital use case", href: relative_url('/docs/getting-started/solverforge-hospital-use-case/'), icon: "fa-solid fa-calendar-days") do %>
Follow a concrete scheduling example from scaffold to solver-driven browser updates.
  <% end %>
</div>
