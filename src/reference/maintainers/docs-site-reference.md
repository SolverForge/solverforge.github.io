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
It is the published documentation surface for users, engineers, and maintainers
across the SolverForge ecosystem.

## Information architecture

| Path                 | Role                                                                 |
| -------------------- | -------------------------------------------------------------------- |
| `src/docs/**`        | tutorials, concepts, and product-facing runtime docs                 |
| `src/reference/**`   | compact engineering reference plus internal maintainer pages         |
| `src/_posts/**`      | blog and release posts                                               |
| `src/_components/**` | reusable Ruby components                                             |
| `src/_layouts/**`    | layouts and shell templates                                          |
| `src/_data/**`       | navigation and structured content                                    |
| `frontend/**`        | bundled CSS/JS sources                                               |
| `plugins/**`         | Bridgetown build-time extensions, including static search generation |

## Published vs repo-only surfaces

The site publishes `src/**`. It does not publish:

- repo-local maintainer notes and workflow files
- repo-local `WIREFRAME.md` and `wireframe.md` files in those source repos

Those files still matter. Maintainer pages on the site should mention them when
relevant so maintainers understand where canonical repo-only detail lives, but
the site should not mirror them wholesale.

## Routine local workflow

From repository root:

1. `make help`
2. `make install`
3. `make ci-local`
4. `make pre-release`
5. `make start`

Direct commands behind the main targets:

- `bundle install`
- `npm ci`
- `bundle exec rake frontend:build`
- `bundle exec bridgetown build`
- `ruby scripts/verify-hospital-tutorial.rb`
- `ruby scripts/verify-deliveries-tutorial.rb`
- `bundle exec bridgetown start -P 4017`

The worked-example tutorial verifiers are portable for site-only clones. They
always check the published copy and snippets, then add deeper checks when local
product checkouts are configured. `SOLVERFORGE_CLI_REPO` and
`SOLVERFORGE_HOSPITAL_REPO` enable the CLI scaffold and live hospital app checks.
`SOLVERFORGE_DELIVERIES_REPO` enables deliveries source checks and a
straight-line retained-job smoke against the local deliveries app. The stable
workflow is the Make target; the Ruby script paths are implementation details.

## Quality gates

| Target             | Role                                                                     |
| ------------------ | ------------------------------------------------------------------------ |
| `make doctor`      | verifies Ruby, Bundler, Node, npm, and expected Ruby/Node major versions |
| `make lint`        | runs dependency-light Ruby and JavaScript syntax checks                  |
| `make build`       | builds esbuild assets and Bridgetown output                              |
| `make test`        | builds in the test environment and runs the tutorial verifiers           |
| `make ci-local`    | matches the GitHub Actions gate: doctor, lint, build, tutorial verifiers |
| `make pre-release` | local release-readiness gate, currently delegating to `ci-local`         |

## Lint follow-up

`make lint` intentionally avoids adding formatter or linter dependencies for
the Makefile overhaul. A later hardening pass should choose and configure:

- Ruby: StandardRB or RuboCop
- JavaScript/CSS: ESLint plus Prettier
- Markdown/content: markdownlint and an internal link checker

After that, add `fmt` and `fmt-check`, and extend `lint` to use the configured
tools instead of syntax checks only.

## Publishing

GitHub Pages should build from this repo directly. The deployment workflow lives
at `.github/workflows/site.yml`; it installs with `make install`, runs
`make ci-local`, and publishes `output/`.

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
- keep maintainer pages integrated into the reference nav instead of hiding
  them in repo-only side files
- keep repo-local source-repo guidance summarized rather than copied wholesale

## See also

- [Ecosystem Maintainer Reference](/reference/maintainers/ecosystem-reference/)
