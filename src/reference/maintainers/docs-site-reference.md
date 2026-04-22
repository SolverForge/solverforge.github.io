---
title: "Docs Site Maintainer Reference"
description: "Human maintainer reference for the Bridgetown docs site, its content layout, and the static publication pipeline."
---

# Docs Site Maintainer Reference

<%= render Ui::Callout.new(title: "Internal maintainer note", variant: "warning") do %>
This page is for maintainers of the dedicated Bridgetown site repository.
<% end %>

## Site role

This repository root is the live Bridgetown site for `solverforge.github.io`.
It is the published documentation surface for users, engineers, maintainers,
and coding agents across the SolverForge ecosystem.

## Information architecture

| Path | Role |
|---|---|
| `src/docs/**` | tutorials, concepts, and product-facing runtime docs |
| `src/reference/**` | compact engineering reference plus internal maintainer and agent pages |
| `src/_posts/**` | blog and release posts |
| `src/_components/**` | reusable Ruby components |
| `src/_layouts/**` | layouts and shell templates |
| `src/_data/**` | navigation and structured content |
| `frontend/**` | bundled CSS/JS sources |
| `plugins/**` | Bridgetown build-time extensions, including static search generation |

## Published vs repo-only surfaces

The site publishes `src/**`. It does not publish:

- repo root `AGENTS.md`
- repo-local `AGENTS.md` files in source repos such as `solverforge`,
  `solverforge-cli`, `solverforge-ui`, and `solverforge-maps`
- repo-local `WIREFRAME.md` and `wireframe.md` files in those source repos

Those files still matter. Maintainer pages on the site should mention them when
relevant so maintainers and agents understand where canonical repo-only detail
lives, but the site should not mirror them wholesale.

## Routine local workflow

From repository root:

1. `bundle install`
2. `npm install`
3. `bundle exec rake frontend:build`
4. `bundle exec bridgetown build`
5. `bundle exec bridgetown start -P 4017`

Equivalent Make targets:

- `make install`
- `make build`
- `make start`

## Publishing

GitHub Pages should build from this repo directly. The deployment workflow lives
at `.github/workflows/site.yml` and publishes `output/`.

## Static search

Search is static-build driven. If you change structure, titles, descriptions, or
section labels, rebuild the site and spot-check:

- `output/search-index.json`
- `/search/`
- the reference and docs landing pages

## Content rules

- keep one source of truth under `src/**`
- prefer Markdown for authored content
- use Ruby components for repeated UI
- keep internal pages clearly labeled as internal
- keep maintainer and agent pages integrated into the reference nav instead of
  hiding them in repo-only side files
- keep repo-local source-repo guidance summarized rather than copied wholesale

## See also

- [Docs Site Agent Guide](/reference/maintainers/docs-site-agent-guide/)
- [Ecosystem Maintainer Reference](/reference/maintainers/ecosystem-reference/)
