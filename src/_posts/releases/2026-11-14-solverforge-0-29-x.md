---
title: "solverforge 0.29.x: Planning Ids in Constraint Matches"
date: 2026-11-14
draft: false
description: >
  The 0.29.x line names each matched entity by its planning id, so an
  application can look up the record behind a constraint match instead of
  parsing its Debug rendering, and justifies projected rows by the entities
  they were projected from.
---

<%= render Ui::Callout.new(title: "Historical release note", variant: "warning") do %>
This post records an older core line. The current core release is
`solverforge 0.31.2`; see the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/).
<% end %>

**solverforge 0.29.x** follows `solverforge 0.28.0`; the line was published on
crates.io on 2026-11-14 as [0.29.0](https://crates.io/crates/solverforge/0.29.0),
with a Rust `1.95` floor. At publication `cargo add solverforge` installed
0.29.0, and docs.rs served the 0.29.0 API. The one breaking change is a new
public field on `EntityRef`, which only code that builds an `EntityRef` with a
struct literal notices. `solverforge-cli 4.0.4` scaffolded 0.26.1 at the time,
and the eight worked use cases pinned 0.26.1.

## What Changed

### Planning ids in constraint matches — breaking change

`EntityRef` gains `planning_id: Option<String>`
([#267](https://github.com/SolverForge/solverforge/pull/267)). An entity
streamed from a model collection whose type has a `#[planning_id]` field
carries that id, rendered with `Display` when the id type implements it (`7`,
`anna`) and otherwise with `Debug` (a tuple-struct id renders as
`ShiftId(7)`). Types without a `#[planning_id]`, and values streamed from a
hand-built source, report `None`. Equal ids render equally, so the string is a
lookup key for the record within its type; `display` stays a rendering, not
an identifier.

Ids are read only when matches are explained, never while scoring, and the
change adds no bound on stream elements. Explanation moved from the row view
to the operator, which owns the source that renders the id: a custom operator
explains its rows by implementing `ExplainOperator`, mapping a row's
`RowOrigin` to its input rows. Projected rows are now justified by the
entities they were projected from; before 0.29.0 they had no justification.
See [Score Analysis](/docs/solverforge/constraints/score-analysis/#constraint-matches).

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime at publication | `solverforge 0.29.0` | Rust `1.95`; `EntityRef::planning_id`; projected rows justified by their sources |
| Previous core line | `solverforge 0.28.0` | Matches for grouped constraints, `EntityRef` without a copy; see the [0.28.x release note](/blog/releases/2026/11/14/solverforge-0-28-x/) |
| CLI at publication | `solverforge-cli 4.0.4` | Scaffolded core `0.26.1` |
| Worked use cases at publication | November 11 app releases | All eight pinned core `0.26.1`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |

All nine workspace crates publish `0.29.0`.

The registry records the facade crate's publication at `2026-11-14T22:04:00Z`.
Its artifact SHA-256 is
`23609c517d38e69c6b3223b444382fe742a31acfb4408db11da8f742a5d6b10b`;
`.cargo_vcs_info.json` binds it to
`59672a2b579f4ee0bbb58054af42d085f7c71ace`, the `v0.29.0` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.29.0)
was published at `2026-11-14T22:04:17Z`.

On that commit the [CI run](https://github.com/SolverForge/solverforge/actions/runs/43644117741)
passed. The
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/43644869186)
re-ran the CI matrix on Linux, macOS, and Windows with the Miri, MSRV, docs,
and package jobs, verified the release, published to crates.io, and created
the GitHub Release; every job succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.29.0` | 2026-11-14 | `EntityRef::planning_id` for entities and facts with a `#[planning_id]`; projected rows justified by the entities they were projected from. |

## Upgrade Checklist

- Move the `solverforge` pin to `0.29.0`.
- An `EntityRef { type_name, display }` struct literal sets
  `planning_id` too, or becomes `EntityRef::new(&entity).with_planning_id(id)`.
- Code that recovered a record by parsing `display` can match on
  `planning_id` instead.

## Where to read next

Read the [Score Analysis](/docs/solverforge/constraints/score-analysis/#constraint-matches)
page and the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/)
for the current line. The
[0.29.0 compare](https://github.com/SolverForge/solverforge/compare/v0.28.0...v0.29.0)
covers its 2 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.29.0/CHANGELOG.md)
lists the breaking change.
