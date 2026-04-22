---
title: "Maintainer Notes"
description: "Internal maintainer references and operational contracts for SolverForge maintainers."
---

# Maintainer Notes

<%= render Ui::Callout.new(title: "Internal audience", variant: "warning") do %>
These pages are for SolverForge maintainers. They tie together the published
docs site with the repo-local maintenance surfaces in the source repositories.
The site can mention those files, but it does not render them directly.
<% end %>

<div class="card-grid">
  <%= render Ui::Card.new(title: "Ecosystem Maintainer Reference", href: relative_url('/reference/maintainers/ecosystem-reference/'), icon: "fa-solid fa-book-open") do %>
How the published site fits with repo-local maintainer surfaces across `solverforge`, `solverforge-cli`, `solverforge-ui`, and `solverforge-maps`.
  <% end %>
  <%= render Ui::Card.new(title: "Lifecycle Contract", href: relative_url('/reference/lifecycle-pause-resume-contract/'), icon: "fa-solid fa-arrows-rotate") do %>
Retained-job lifecycle, pause/resume semantics, snapshot identity, and terminal-state rules.
  <% end %>
  <%= render Ui::Card.new(title: "Docs Site Maintainer Reference", href: relative_url('/reference/maintainers/docs-site-reference/'), icon: "fa-solid fa-screwdriver-wrench") do %>
Human maintainer reference for the Bridgetown docs site, static search, and published information architecture.
  <% end %>
</div>
