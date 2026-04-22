---
title: "Ecosystem Agent Guide"
description: "Internal agent guide for navigating the published site and the repo-local engineering surfaces across the SolverForge ecosystem."
---

# Ecosystem Agent Guide

<%= render Ui::Callout.new(title: "Internal agent guide", variant: "warning") do %>
This page is for coding agents coordinating this site repo with the source
repositories across the SolverForge ecosystem.
<% end %>

## Read order

1. the relevant source repo's `AGENTS.md`, `README.md`, and wireframe files
2. this repo's `AGENTS.md`
3. the matching published pages under `src/docs/**` or `src/reference/**`
4. the docs-site maintainer pages if the change touches workflow or site structure

## What each surface is for

- source-repo `AGENTS.md` files define repo-local engineering rules and change
  policy
- source-repo wireframes are the canonical API maps where they exist
- source-repo `README.md` files are the high-level entry points for that codebase
- this repo's `src/docs/**` and `src/reference/**` are the published
  documentation surface

The important distinction is that source-repo maintainer files remain repo-local.
If a site page needs to acknowledge them, mention the repo and path plus what
the file is for; do not dump the entire file into the site.

## Required synchronization

- If you change a product repo's public API or onboarding, update that repo's
  local docs first and the matching site docs here in the same effort.
- If the change affects user discovery or public reasoning, update the relevant
  published pages here.
- If the change affects site workflow or site-maintainer guidance, update the
  relevant maintainer or agent page under `src/reference/maintainers/**`.
- Document the current checked-in state, not a desired future state.

## Validation

- run the relevant validation in the source repo you changed
- if this site changed too, run:
  `make build`

## Common mistakes to avoid

- treating this site repo as the canonical home for every source-repo maintainer file
- updating a source repo without syncing the matching published pages here
- documenting future intent as if it were already shipped
- duplicating repo-local wireframes or agent files into the site instead of summarizing them
- updating docs-site workflow without touching `README.md` or `AGENTS.md`

## See also

- [Ecosystem Maintainer Reference](/reference/maintainers/ecosystem-reference/)
- [Docs Site Agent Guide](/reference/maintainers/docs-site-agent-guide/)
