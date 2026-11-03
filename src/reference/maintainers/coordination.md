---
title: "Maintainer Coordination Reference"
description: "Maintainer reference for ownership checks across SolverForge crates, docs, and companion libraries."
---

# Maintainer Coordination Reference

<%= render Ui::Callout.new(title: "Internal maintainer note", variant: "warning") do %>
This page is for maintainers coordinating documentation and implementation
contracts in `solverforge`, `solverforge-cli`, `solverforge-ui`, and
`solverforge-maps`.
<% end %>

## Documentation ownership

| Source                                                                                                 | Audience                      | Role                                                                                        |
| ------------------------------------------------------------------------------------------------------ | ----------------------------- | ------------------------------------------------------------------------------------------- |
| Public SolverForge docs                                                                                | users, engineers, maintainers | tutorials, concepts, references, releases, and integration guidance                         |
| `SolverForge/solverforge` repo files                                                                   | product maintainers           | core Rust workspace source of truth, including `README.md` and `crates/*/WIREFRAME.md`      |
| `SolverForge/solverforge-cli`, `SolverForge/solverforge-ui`, `SolverForge/solverforge-maps` repo files | product maintainers           | canonical repo-local onboarding, architecture, and implementation detail for those products |

Product repositories remain canonical for source-level maintainer detail and
should be referenced, not copied wholesale.

## Canonical update rules

| If you change...                                                       | Update...                                                                                                       |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| public docs, navigation, reference, or release content                 | the matching public documentation pages                                                                         |
| public API or onboarding in a product repo                             | the product repo's own `README.md`, wireframes, and implementation docs, plus the matching public documentation |
| repo-local maintainer workflow or architecture notes in a product repo | the source repo first, then any public maintainer note that summarizes or points to that guidance                |

## Repo-local maintainer material

The product repositories keep files that should remain repo-local:

- `SolverForge/solverforge`: `README.md`, `crates/*/WIREFRAME.md`
- `SolverForge/solverforge-cli`: repo-local maintainer docs and implementation notes
- `SolverForge/solverforge-ui`: repo-local maintainer docs and implementation notes
- `SolverForge/solverforge-maps`: repo-local maintainer docs and implementation notes

Those files are source-level maintainer material. Mention them when helpful, but
do not duplicate their full contents here.

## Routine maintainer checks

- in this repo: `make ci-local`
- before release or publishing: `make pre-release`
- while editing locally: `make help`, `make install`, `make build`, and `make start`
- in a product repo: run that repo's own build, test, and release checks there

`make verify-cli-getting-started` and `make verify-maintenance-walkthrough`
replay their pages' commands with the published `solverforge-cli` named in
`scripts/release_pins.rb` and the walkthrough gate, build the app, and solve
it; both fail rather than skip when `solverforge` or `cargo` is missing. Every
gate that states a current version reads it from `scripts/release_pins.rb`,
which `make verify-release-surface` compares with the crates.io index, so a new
publish fails the gates until the pin and the pages move. The tutorial gates
describe the checkouts and environment they need at the top of each
`scripts/verify-*-tutorial.rb`. The Make targets are the stable workflow entry
points; the verifier implementations are Ruby.

## See also

- [Library Reference](/reference/library/)
