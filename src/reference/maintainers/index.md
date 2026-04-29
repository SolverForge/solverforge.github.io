---
title: "Maintainer Notes"
description: "Internal maintainer references and operational contracts for SolverForge maintainers."
---

# Maintainer Notes

<%= render Ui::Callout.new(title: "Internal audience", variant: "warning") do %>
These pages are for SolverForge maintainers. They tie together ecosystem
maintenance contracts across the core runtime and companion libraries.
<% end %>

<div class="card-grid">
  <%= render Ui::Card.new(title: "Ecosystem Maintainer Reference", href: relative_url('/reference/maintainers/ecosystem-reference/'), icon: "fa-solid fa-book-open") do %>
How SolverForge maintainer responsibilities fit across `solverforge`, `solverforge-cli`, `solverforge-ui`, and `solverforge-maps`.
  <% end %>
  <%= render Ui::Card.new(title: "Lifecycle Contract", href: relative_url('/reference/lifecycle-pause-resume-contract/'), icon: "fa-solid fa-arrows-rotate") do %>
Retained-job lifecycle, pause/resume semantics, snapshot identity, and terminal-state rules.
  <% end %>
</div>
