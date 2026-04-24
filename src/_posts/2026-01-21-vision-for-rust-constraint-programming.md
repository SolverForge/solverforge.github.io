---
title: "Historical: Rust Constraint Solving Notes from the 0.5.0 Era"
date: 2026-01-21
draft: false
tags: [rust]
description: >
  Archived context for early SolverForge design thinking. The current
  architecture is CLI-first, Rust-native, and centered on the current
  SolverForge runtime.
---

<%= render Ui::Callout.new(title: "Superseded") do %>
This article originally framed SolverForge as "the future of constraint
programming in Rust" and discussed several directions from the SolverForge
0.5.0 era. That framing is no longer the clearest way to understand the
project. For the current architecture, read
[The Current SolverForge Architecture: CLI-First, Rust-Native, Explicit](/blog/technical/2026/04/23/current-solverforge-architecture-cli-first-rust-native/).
<% end %>

The durable part of the original article was the language choice: SolverForge is
a Rust constraint solver because planning and scheduling problems spend most of
their time in tight move-evaluation and scoring loops.

The current architecture keeps that Rust-native foundation, but the public
product shape has changed. SolverForge should now be understood through four
current surfaces:

- `solverforge`, the Rust runtime and modeling API
- `solverforge-cli`, the default entry point for new projects
- generated SolverForge applications with retained solve jobs, REST, SSE,
  snapshots, analysis, and UI integration
- scalar and list planning-variable families, with mixed models built by
  generators after scaffolding

## What Still Matters From The Original Piece

The original technical motivation remains valid:

- Constraint solving evaluates many candidate moves.
- Hot paths should avoid dynamic dispatch, heap allocation, and erased runtime
  machinery where concrete Rust types can do the work.
- Domain models, constraints, selectors, phases, and score analysis should stay
  explicit enough for users to inspect and tune.
- Generated helpers are useful when they remove repetition without hiding the
  application.

That is still the core of SolverForge.

## What Is No Longer The Current Story

The original article also contained roadmap framing that should not be treated
as current documentation:

- The project is no longer best introduced as a broad future-looking Rust
  programming essay.
- The CLI is not merely a possible future onboarding path; it is the default
  entry point.
- New users should not start by cloning a quickstart and deleting demo residue.
- Current CLI scaffolding does not ask for a problem-class preset.
- Current modeling terms are `scalar` and `list`, not "standard-variable" and
  list-variable.

The replacement mental model is concrete:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
cd my-scheduler
solverforge generate fact employee --field skill:String
solverforge generate entity shift --field starts_at:String --field ends_at:String
solverforge generate variable employee_idx --entity Shift --kind scalar --range employees
solverforge server
```

From there, the developer owns normal Rust code. The CLI owns repeated project
structure and managed generated regions. The runtime owns retained solve jobs,
snapshots, events, pause/resume/cancel controls, and score analysis.

## Current References

- [The Current SolverForge Architecture](/blog/technical/2026/04/23/current-solverforge-architecture-cli-first-rust-native/)
- [solverforge-cli Manual](/docs/solverforge-cli/)
- [SolverForge Hospital Use Case](/docs/getting-started/solverforge-hospital-use-case/)
- [solverforge-cli Command Reference](/docs/solverforge-cli/command-reference/)
- [SolverForge Overview](/docs/overview/)
