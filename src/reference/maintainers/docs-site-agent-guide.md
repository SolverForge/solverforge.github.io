---
title: "Docs Site Agent Guide"
description: "Internal agent guide for editing the Bridgetown docs site, its navigation, and its static search surface."
---

# Docs Site Agent Guide

<%= render Ui::Callout.new(title: "Internal agent guide", variant: "warning") do %>
This page is for coding agents editing the dedicated Bridgetown site repo.
<% end %>

## Start here

1. read `AGENTS.md`
2. work from repository root
3. identify whether the change belongs in `src/docs/**`, `src/reference/**`,
   `src/_posts/**`, or shared UI/data

## Edit the right layer

- `src/docs/**` for narrative and tutorial content
- `src/reference/**` for compact reference and maintainer/agent material
- `src/_components/**` for reusable UI
- `src/_layouts/**` for page shells
- `src/_data/*.yml` for navigation and section structure
- `frontend/**` only when shared CSS/JS behavior really changed

## Required synchronization

- if docs-site workflow changed, update `README.md` and `AGENTS.md`
- if maintainer or agent guidance changed, update the relevant pages under
  `src/reference/maintainers/**`
- if section structure changed, update landing pages, nav data, and search quick
  links where needed
- if you mention source-repo wireframes or `AGENTS.md` files on the site, keep
  the mention accurate and concise; those files remain repo-local

## Local validation

Preferred root-level entry points:

- `make build`
- `make start`

Underlying commands:

- `bundle exec rake frontend:build`
- `bundle exec bridgetown build`
- `bundle exec bridgetown start -P 4017`

`bridgetown doctor` is not available in the current CLI here, so do not rely on
it in this repository.

## Static output checks

- search changes only appear after `bridgetown build`
- spot-check `output/search-index.json` after structural edits
- verify the rendered `/reference/` and `/docs/` sidebars after nav changes

## See also

- [Docs Site Maintainer Reference](/reference/maintainers/docs-site-reference/)
- [Ecosystem Agent Guide](/reference/maintainers/ecosystem-agent-guide/)
