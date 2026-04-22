---
title: Documentation
linkTitle: Docs
menu: { main: { weight: 20 } }
---

<h1>Documentation</h1>

Welcome to the SolverForge documentation. Choose a section to get started:

<div class="card-grid">
  <%= render Ui::Card.new(title: "Overview", href: relative_url('/docs/overview/'), icon: "fa-solid fa-compass") do %>
Project overview, positioning, and roadmap notes.
  <% end %>
  <%= render Ui::Card.new(title: "Concepts", href: relative_url('/docs/concepts/'), icon: "fa-solid fa-lightbulb") do %>
Core planning and optimization concepts for SolverForge users.
  <% end %>
  <%= render Ui::Card.new(title: "Getting Started", href: relative_url('/docs/getting-started/'), icon: "fa-solid fa-rocket") do %>
CLI-first onboarding, quickstarts, and longer tutorials.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-cli", href: relative_url('/docs/solverforge-cli/'), icon: "fa-solid fa-terminal") do %>
Project scaffolding and generator workflows.
  <% end %>
  <%= render Ui::Card.new(title: "SolverForge", href: relative_url('/docs/solverforge/'), icon: "fa-brands fa-rust") do %>
Native runtime, modeling surface, phases, moves, and analysis APIs.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-ui", href: relative_url('/docs/solverforge-ui/'), icon: "fa-solid fa-display") do %>
Frontend components, lifecycle adapters, scheduling views, and assets.
  <% end %>
  <%= render Ui::Card.new(title: "solverforge-maps", href: relative_url('/docs/solverforge-maps/'), icon: "fa-solid fa-route") do %>
Road-network loading, routing, matrices, and map-backed planning helpers.
  <% end %>
</div>
