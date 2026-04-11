---
title: 'SolverForge 0.8.2: Retained Runtime Refinement'
date: 2026-04-11
draft: false
description: >
  SolverForge 0.8.2 is now available with more responsive retained-runtime
  controls, list-variable solution trait bounds, and pause lifecycle fixes.
---

SolverForge **0.8.2** is now available.

This release tightens the retained-runtime surface introduced in `0.8.0` and
rounds out a few gaps for production applications:

- **Interruptible retained phases** so built-in search work responds faster to
  `pause()`, `cancel()`, and config termination
- **List-variable solution trait bounds** via
  `#[planning_list_variable(solution_trait = "...")]` when routing helpers or
  meters need extra solution-side contracts
- **Serialized pause lifecycle publication** so `PauseRequested` remains
  authoritative before later pause-state events
- **Pause-resume construction fixes** so interrupted placements are retried
  correctly after a retained pause

## Why this release matters

If you are building a service, UI, or embedded runtime around `SolverManager`,
`0.8.2` makes the retained lifecycle more predictable under real interactive
control. Pause and cancellation settle faster, pause-state events stay ordered,
and list-heavy domains have a cleaner way to express extra trait requirements
without local macro forks.

## Upgrade notes

- Keep using the retained job lifecycle from `SolverManager`; the public model
  is still job, snapshot, and checkpoint based.
- Prefer `#[planning_solution(config = "...")]` when a solve should decorate
  the loaded `solver.toml` rather than replace it.
- For list-heavy models with custom meters or helpers, add
  `solution_trait = "path::Trait"` only when generated stock helpers need an
  explicit extra solution-side bound.
- The current crate line targets Rust `1.92+`.

## What's next

The next documentation pass will keep tightening the public API guides around
retained lifecycle orchestration, list-heavy planning models, and scaffold
extension workflows.
