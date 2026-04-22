---
title: "Ecosystem Maintainer Reference"
description: "Maintainer reference for the published site and the repo-local engineering surfaces across the SolverForge ecosystem."
---

# Ecosystem Maintainer Reference

<%= render Ui::Callout.new(title: "Internal maintainer note", variant: "warning") do %>
This page is for maintainers coordinating the published site with the
repo-local documentation and implementation surfaces in `solverforge`, `solverforge-cli`,
`solverforge-ui`, and `solverforge-maps`.
<% end %>

## Documentation surfaces

| Surface | Audience | Role |
|---|---|---|
| `src/docs/**` and `src/reference/**` in this repo | users, engineers, maintainers | published website surface |
| `README.md` in this repo | site maintainers | local workflow, build entry points, and repo boundaries |
| `SolverForge/solverforge` repo files | product maintainers | core Rust workspace source of truth, including `README.md` and `crates/*/WIREFRAME.md` |
| `SolverForge/solverforge-cli`, `SolverForge/solverforge-ui`, `SolverForge/solverforge-maps` repo files | product maintainers | canonical repo-local onboarding, architecture, and implementation detail for those products |

The site is the published documentation surface. Repo-local maintainer files in
the product repositories remain canonical for source-level detail and should be
referenced, not copied wholesale.

## Canonical update rules

| If you change... | Update... |
|---|---|
| published docs, navigation, reference, or blog content | the matching `src/**` pages in this repo |
| site workflow, build, or search plumbing | `README.md`, `.github/workflows/site.yml`, and the maintainer pages under `src/reference/maintainers/**` in this repo |
| public API surface or onboarding in a product repo | the product repo's own `README.md`, wireframes, and implementation docs, plus the matching published pages here |
| repo-local maintainer workflow or architecture notes in a product repo | the source repo first, then any site page here that summarizes or points to that guidance |

## Repo-local maintainer surfaces

The product repositories keep files that should remain repo-local:

- `SolverForge/solverforge`: `README.md`, `crates/*/WIREFRAME.md`
- `SolverForge/solverforge-cli`: repo-local maintainer docs and implementation notes
- `SolverForge/solverforge-ui`: repo-local maintainer docs and implementation notes
- `SolverForge/solverforge-maps`: repo-local maintainer docs and implementation notes

Those files are not rendered through the site. Mention them on the site when
helpful, but do not duplicate their full contents here.

## Routine maintainer checks

- in this repo: `make build`
- in a product repo: run that repo's own build, test, and release checks there

## See also

- [Docs Site Maintainer Reference](/reference/maintainers/docs-site-reference/)
- [Library Reference](/reference/library/)
