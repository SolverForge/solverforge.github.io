# AGENTS.md

This file applies to the dedicated SolverForge site repository.

## Purpose

This repo is the live Bridgetown root for `solverforge.github.io`.

## Required structure

- Keep rendered site content in `src/**`.
- Keep reusable site UI in `src/_components/**`.
- Keep layouts in `src/_layouts/**`.
- Keep nav and structured content in `src/_data/**`.
- Keep `README.md` current with the actual local workflow.
- Keep `src/reference/maintainers/docs-site-reference.md` and
  `src/reference/maintainers/docs-site-agent-guide.md` current when docs-site
  workflow or structure changes.
- If the site mentions repo-local surfaces from source repositories such as
  `AGENTS.md`, `WIREFRAME.md`, or `wireframe.md`, keep those references
  accurate and concise.

## Bridgetown guardrails

- Prefer Bridgetown conventions over custom folder schemes.
- Use Ruby components for repeated UI instead of duplicating template fragments.
- Keep authored documentation in Markdown whenever practical.
- If a page needs ERB, use Bridgetown's normal page processing rather than inventing parallel templating paths.
- Treat this repo as the published site source, not as the canonical home for
  every repo-local maintainer file in the SolverForge ecosystem.

## Validation expectations

When editing the site, run at least one relevant local check and record it in your final report. Prefer:

- `make build`
- `bundle exec rake frontend:build`
- `bundle exec bridgetown build`

Bridgetown `doctor` is not available in the current `2.1.2` CLI used here, so do not rely on it in this repository.
