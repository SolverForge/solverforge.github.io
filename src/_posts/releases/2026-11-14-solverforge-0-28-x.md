---
title: "solverforge 0.28.x: Matches for Grouped Constraints, Entities Described Without Copies, and the Resolved Solver Policy"
date: 2026-11-14
draft: false
description: >
  The 0.28.x line reports a match for every grouped and complemented
  constraint, describes matched entities by type name and Debug rendering
  instead of keeping a copy, drops the Clone requirement from scoring streams,
  and reports the solver policy a solve actually ran in its final telemetry.
---

<%= render Ui::Callout.new(title: "Historical release note", variant: "warning") do %>
This post records an older core line. The current core release is
`solverforge 0.31.2`; see the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/).
<% end %>

**solverforge 0.28.x** follows `solverforge 0.27.0`; the line was published on
crates.io on 2026-11-14 as [0.28.0](https://crates.io/crates/solverforge/0.28.0),
with a Rust `1.95` floor. At publication `cargo add solverforge` installed
0.28.0, and docs.rs served the 0.28.0 API. The breaking change is in
constraint analysis: a matched entity is described by its type name and
`Debug` rendering, and analysis no longer hands back the entity itself.
`solverforge-cli 4.0.4` scaffolded 0.26.1 at the time, and the eight worked
use cases pinned 0.26.1.

## What Changed

### Grouped and complemented constraints report their matches

`ScoreDirector::constraint_analyses()` returned a grouped or complemented
constraint's score with no matches: seven of the eight grouped builders never
installed an explainer, and a grouped node shared by several terminals always
explained to an empty list. Every grouped and complemented constraint now
reports one match per group whose weight is not zero, justified by the
entities in the group (a complemented key without a group is justified by its
target entity), and the match scores add up to the constraint's score, before
and after the director initializes
([#262](https://github.com/SolverForge/solverforge/pull/262)). `match_count`
still counts every row.

### Matched entities without copies — breaking change

`EntityRef`, the entity entry of a match, used to keep a deep copy of the
entity behind `dyn Any` so `as_entity::<T>()` could downcast it. It is now the
entity's type name and `Debug` rendering, taken when the match is explained
([#264](https://github.com/SolverForge/solverforge/pull/264)):

- `EntityRef::as_entity` and `EntityRef::with_display` are removed, and
  `EntityRef::new` takes any `T: Debug + ?Sized`. Read the entity from your
  solution instead of from the match.
- No scoring stream requires `Clone` on an entity type; explaining a match
  needs only `Debug`, works for borrowed types, and allocates no entity
  copies.
- Grouped and complemented constraints require `Debug` on their entities, like
  every other constraint. Types declared with `#[planning_entity]` and
  `#[problem_fact]` already implement it.
- `SharedOperatorBuilder::with_explainer` and `OperatorScorerSet::score_for`
  are removed from `solverforge-scoring`.

See [Score Analysis](/docs/solverforge/constraints/score-analysis/#constraint-matches).

### The resolved solver policy in final telemetry

The compiled runtime resolves the exact phase plan before a solve starts, but
published it only into an enabled candidate trace. Every compiled solve now
reports it in `SolverTelemetry::resolved_phase_plan` once it ends
([#260](https://github.com/SolverForge/solverforge/pull/260)): each phase, the
construction every default stage chose with the `reason` that chose it, the
local-search families with their limits, the families a slot did not receive
with the capability it was missing, the family ordering and weighting, and the
acceptor, forager and effective `forager_accepted_count_limit`. Solver
behaviour is unchanged. See
[Solver Phases](/docs/solverforge/solver/phases/#resolved-phase-plan).

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime at publication | `solverforge 0.28.0` | Rust `1.95`; matches for grouped and complemented constraints; `EntityRef` holds a type name and `Debug` rendering; no `Clone` bound on scoring streams; `resolved_phase_plan` in final telemetry |
| Previous core line | `solverforge 0.27.0` | Pluggable route metrics and bounded Clarke-Wright savings; see the [0.27.x release note](/blog/releases/2026/11/13/solverforge-0-27-x/) |
| CLI at publication | `solverforge-cli 4.0.4` | Scaffolded core `0.26.1`; see the [4.0.x CLI release note](/blog/releases/2026/11/10/solverforge-cli-4-0-x/) |
| Python | `solverforge-py 0.7.2` / PyPI `solverforge 0.7.2` | Compiled onto core `0.23.0` |
| Worked use cases at publication | November 11 app releases | All eight pinned core `0.26.1` and UI `0.9.0`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |

All nine workspace crates (`solverforge`, `solverforge-core`,
`solverforge-config`, `solverforge-scoring`, `solverforge-solver`,
`solverforge-macros`, `solverforge-bridge`, `solverforge-console`, and
`solverforge-cvrp`) publish `0.28.0`.

The registry records the facade crate's publication at `2026-11-14T10:55:28Z`.
Its artifact SHA-256 is
`63d7032cb6ad713fe60b739c5b49539031a5b2267e3af37a0750650b0f516d77`;
`.cargo_vcs_info.json` binds it to
`d8acec768522a068f22556bd8c5288612d1b8bb0`, the `v0.28.0` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.28.0)
was published at `2026-11-14T10:55:45Z`.

On that commit the [CI run](https://github.com/SolverForge/solverforge/actions/runs/43585162853)
passed. The
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/43586479995)
re-ran the CI matrix on Linux, macOS, and Windows with the Miri, MSRV, docs,
and package jobs, verified the release, published to crates.io, and created
the GitHub Release; every job succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.28.0` | 2026-11-14 | Matches for grouped and complemented constraints; `EntityRef` without an entity copy (`as_entity` and `with_display` removed); no `Clone` bound on scoring streams; `resolved_phase_plan` in final telemetry. |

## Upgrade Checklist

- Move the `solverforge` pin to `0.28.0`.
- Replace `entity_ref.as_entity::<T>()` with a lookup in your solution: the
  match carries the type name and `display`, not the entity.
- Replace `EntityRef::new(&entity).with_display(text)` with
  `EntityRef::new(&entity)`; the display is the entity's `Debug` rendering.
- Entities scored by a grouped or complemented constraint need `Debug`.
  `#[planning_entity]` and `#[problem_fact]` types already have it.
- Code that built a `SharedOperatorBuilder` with `with_explainer` drops the
  call: shared grouped terminals explain their rows themselves.

## Where to read next

Read the [Score Analysis](/docs/solverforge/constraints/score-analysis/) page
and the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/)
for the current line. The
[0.28.0 compare](https://github.com/SolverForge/solverforge/compare/v0.27.0...v0.28.0)
covers its 4 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.28.0/CHANGELOG.md)
lists the breaking change.
