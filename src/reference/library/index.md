---
title: "Library Reference"
description: "Fast lookup material for engineers integrating, extending, or evaluating SolverForge."
---

# Library Reference

<%= render Ui::Callout.new(title: "Use this section when you already know the question") do %>
The main docs teach concepts and workflows. This section is the compact reference layer for crate boundaries, modeling choices, extension decisions, and ecosystem fit.
<% end %>

## What lives here

- crate and runtime boundaries
- modeling rules of thumb
- practical extension playbooks
- integration boundaries across the SolverForge ecosystem

## Start here

<div class="card-grid">
  <%= render Ui::Card.new(title: "Crate & Runtime Map", href: relative_url('/reference/crate-map/'), icon: "fa-solid fa-diagram-project") do %>
Choose the right crate or companion repo before you start wiring code together.
  <% end %>
  <%= render Ui::Card.new(title: "Modeling Cheat Sheet", href: relative_url('/reference/modeling-cheat-sheet/'), icon: "fa-solid fa-table-list") do %>
Quick lookup for macros, field roles, and scalar-vs-list modeling choices.
  <% end %>
  <%= render Ui::Card.new(title: "Extend the Domain", href: relative_url('/reference/extend-domain/'), icon: "fa-solid fa-sitemap") do %>
Grow the generated shell into a real planning model without turning it into framework soup.
  <% end %>
  <%= render Ui::Card.new(title: "Extend the Solver", href: relative_url('/reference/extend-solver/'), icon: "fa-solid fa-sliders") do %>
Tune configuration first, then decide whether custom runtime code is actually justified.
  <% end %>
  <%= render Ui::Card.new(title: "Integration Surfaces", href: relative_url('/reference/integration-surfaces/'), icon: "fa-solid fa-puzzle-piece") do %>
See where the runtime ends and where `solverforge-cli`, `solverforge-ui`, and `solverforge-maps` begin.
  <% end %>
</div>

## Not what you need?

- For tutorials and walkthroughs, go to [Docs](/docs/).
- For internal contracts and site-operation notes, go to [Maintainer Notes](/reference/maintainers/).
