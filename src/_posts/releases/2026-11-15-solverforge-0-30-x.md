---
title: "solverforge 0.30.x: Cascading List Shadows Across Owners and Filtered Grouped Complements"
date: 2026-11-15
draft: false
description: >
  The 0.30.x line computes element values that depend on elements in other
  owners' lists, such as a start time that waits on a task on another
  machine, incrementally after every move; applies the stream filter to uni
  grouped complements; and in 0.30.1 retracts cascading arrivals before their
  structure shadows change.
---

<%= render Ui::Callout.new(title: "Historical release note", variant: "warning") do %>
This post records an older core line. The current core release is
`solverforge 0.31.2`; see the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/).
<% end %>

**solverforge 0.30.x** follows `solverforge 0.29.0`; the line was published on
crates.io from 2026-11-15 through 2026-11-16 and closes with
[0.30.1](https://crates.io/crates/solverforge/0.30.1), with a Rust `1.95`
floor. At publication `cargo add solverforge` installed 0.30.1, and docs.rs
served the 0.30.1 API. The one breaking change, in 0.30.0, adds a filter type
parameter to the complemented stream types, which only code that names those
types notices. `solverforge-cli 4.0.4` scaffolded 0.26.1 at the time, and the
eight worked use cases pinned 0.26.1.

## What Changed

### Cascading list shadows across owners

A list shadow could depend only on the list holding its element, so a start
time that waits on a task in another owner's list (job shop, flow shop,
transfers between vehicles) could not stay correct incrementally: the score
director refreshed only the changed owner's elements.
`#[shadow_variable_updates]` gains `cascading_field` (an `Option<_>` element
field), `cascading_compute` (a solution method computing it from the previous
element and the dependencies) and `cascading_dependencies` (the elements an
element waits on), and SolverForge owns ordering, propagation, change
reporting and undo ([#269](https://github.com/SolverForge/solverforge/pull/269)):

- After each move the score director recomputes the downstream cone of the
  changed elements in dependency order: each element once, after its inputs,
  and only when an input changed, so propagation stops where a value is
  unchanged.
- An element on a dependency cycle a move creates, or in no list, is unset
  (`None`), which constraints can penalize.
- `cascading_listener`, `post_update_listener`, `entity_aggregate` and
  `entity_compute` cannot be combined with a cascading shadow.
- A solution without a cascading shadow keeps its move path: the branch is an
  associated constant (`PlanningSolution::HAS_CASCADING_SHADOWS`).

See [List Variables](/docs/solverforge/modeling/list-variables/#cascading-shadows-across-lists).

### Filtered uni grouped complements

`for_each(..).filter(..).group_by(..).complement(..)` grouped every element of
the source, not only those the filter kept, so the complemented rows and their
scores ignored the filter. `complement` and `complement_with_key` now group
through the stream's filter
([#269](https://github.com/SolverForge/solverforge/pull/269), issue
[#266](https://github.com/SolverForge/solverforge/issues/266)).
`ComplementedConstraintStream` and `ComplementedConstraintBuilder` gain a
filter type parameter `Fi` after `EA`; code that only chains the fluent
methods compiles unchanged.

### Cascading arrivals retracted first (0.30.1)

With a cascading shadow, an owner's refresh rewrote the inverse, previous and
next fields of every element it held before it retracted the rows of elements
that arrived from no list. A constraint reading those fields retracted a
different score from the one it inserted, and the incremental score drifted
from a fresh one. 0.30.1 retracts arrivals first, as the non-cascading refresh
does.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Last 0.30 release | `solverforge 0.30.1` | Rust `1.95`; cascading arrivals retracted before their structure shadows change |
| First 0.30 release | `solverforge 0.30.0` | Cascading list shadows across owners; filtered uni grouped complements |
| Previous core line | `solverforge 0.29.0` | Planning ids in constraint matches; see the [0.29.x release note](/blog/releases/2026/11/14/solverforge-0-29-x/) |
| CLI at publication | `solverforge-cli 4.0.4` | Scaffolded core `0.26.1` |
| Worked use cases at publication | November 11 app releases | All eight pinned core `0.26.1`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |

All nine workspace crates publish `0.30.0` and `0.30.1`.

The registry records the facade crate's publication at `2026-11-15T19:45:28Z`.
Its artifact SHA-256 is
`4f9af00f82a984651a8287f33973b98b261ca3138450d8e7cd2177af2bec4cd4`;
`.cargo_vcs_info.json` binds it to
`147011d92b93fcfa4a2bd02344f6c965a2915293`, the `v0.30.0` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.30.0)
was published at `2026-11-15T19:45:49Z`. On that commit the
[CI run](https://github.com/SolverForge/solverforge/actions/runs/43752268061)
passed, and the
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/43753275831)
re-ran the CI matrix on Linux, macOS, and Windows with the Miri, MSRV, docs,
and package jobs, verified the release, published to crates.io, and created
the GitHub Release; every job succeeded.

The registry records the 0.30.1 facade publication at `2026-11-16T14:03:38Z`.
Its artifact SHA-256 is
`5c9314f4fa01d96fdfe1a151c83508ad41bc4ea9257345c0ec45f34c31972ae4`;
`.cargo_vcs_info.json` binds it to
`ebab46ba9595f52703b178b372b0281cecafaa22`, the `v0.30.1` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.30.1)
was published at `2026-11-16T14:04:00Z`. On that commit the
[CI run](https://github.com/SolverForge/solverforge/actions/runs/43875154430)
passed, and every job of the
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/43879691165)
succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.30.1` | 2026-11-16 | Cascading arrivals from no list are retracted before their inverse, previous and next shadows change. |
| `0.30.0` | 2026-11-15 | `cascading_field`, `cascading_compute` and `cascading_dependencies` on `#[shadow_variable_updates]`; uni grouped complements honour the stream filter (`Fi` type parameter). |

## Upgrade Checklist

- Move the `solverforge` pin to `0.30.1`.
- Code that names `ComplementedConstraintStream` or
  `ComplementedConstraintBuilder` adds the filter type parameter after `EA`.
- A uni `filter(..).group_by(..).complement(..)` constraint now scores only
  the filtered elements; expect its score to change if the filter excluded
  any.

## Where to read next

Read [List Variables](/docs/solverforge/modeling/list-variables/#cascading-shadows-across-lists)
and the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/)
for the current line. The
[0.30.0 compare](https://github.com/SolverForge/solverforge/compare/v0.29.0...v0.30.0)
and the [0.30.1 compare](https://github.com/SolverForge/solverforge/compare/v0.30.0...v0.30.1)
cover the line's 6 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.30.1/CHANGELOG.md)
lists the breaking change.
