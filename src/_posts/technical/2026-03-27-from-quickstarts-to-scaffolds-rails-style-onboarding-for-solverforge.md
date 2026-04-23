---
title: 'Historical: From Quickstarts to Scaffolds'
date: 2026-03-27
draft: false
tags: [rust, quickstart, release]
description: >
  Archived transition note. The current SolverForge onboarding model is
  CLI-first: one neutral solverforge-cli project shell, generator-driven model
  growth, and scalar/list planning variables.
---

<%= render Ui::Callout.new(title: "Superseded") do %>
This article captured a March 2026 transition moment while `solverforge-cli`
was still becoming the public onboarding path. It has been superseded by
[The Current SolverForge Architecture: CLI-First, Rust-Native, Explicit](/blog/technical/2026/04/23/current-solverforge-architecture-cli-first-rust-native/).
<% end %>

The useful historical point was this: SolverForge moved away from
clone-and-edit quickstarts as the default way to start a new project.

The current product shape is now clearer than this article originally described:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge server
```

`solverforge-cli` creates one neutral application shell. It does not ask users
to choose a problem-class starter, and it does not expose public starter-family
flags such as `--scalar`, `--list`, or `--mixed`.

After scaffolding, the model grows through generators:

```bash
solverforge generate fact employee --field skill:String
solverforge generate entity shift --field starts_at:String --field ends_at:String
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees
solverforge generate variable stops --entity Route --kind list --elements visits
solverforge generate constraint no_overlap --pair --hard
```

The current planning-variable terms are `scalar` and `list`. The older
"standard-variable" phrasing should be treated as historical terminology, not
current documentation.

Quickstarts and tutorials remain useful as worked examples. They are no longer
the primary onboarding surface. For current usage, start with the
[solverforge-cli manual](/docs/solverforge-cli/) and the
[command reference](/docs/solverforge-cli/command-reference/).

## What Remains True

- Worked examples are still valuable for studying modeling patterns.
- SolverForge still prefers explicit generated Rust over opaque runtime magic.
- The CLI still exists to move repeated project structure into tooling while
  keeping user-owned code visible.

## What Changed

- The CLI is now the default project entry point, not a future direction.
- `solverforge new` creates one neutral shell instead of a menu of starter
  families.
- Scalar, list, and mixed models are introduced after scaffolding.
- Generated apps target the retained SolverForge runtime and expose REST, SSE,
  snapshot, analysis, and UI surfaces around solve jobs.

For the current architecture, read
[The Current SolverForge Architecture: CLI-First, Rust-Native, Explicit](/blog/technical/2026/04/23/current-solverforge-architecture-cli-first-rust-native/).
