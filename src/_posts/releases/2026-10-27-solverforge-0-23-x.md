---
title: "solverforge 0.23.x: Parallel Evaluation and Phase-Owned Statistics"
date: 2026-10-27
draft: false
description: >
  The 0.23.x line adds opt-in parallel local-search evaluation, phase-owned
  statistics, borrowed tabu signatures, correct list-shadow scoring, and
  thread-independent dynamic scores.
---

**solverforge 0.23.x** follows `solverforge 0.22.0`; the line was published on
crates.io on 2026-10-27. The first release is
[0.23.0](https://crates.io/crates/solverforge/0.23.0), with a Rust `1.95`
floor. Direct Rust applications can upgrade independently of the CLI,
Python binding, and released use-case apps.

## What Changed

### Opt-in parallel candidate evaluation

Acceptor-forager local search can evaluate candidates on several cores within
one solve. Set `move_thread_count = { count = 4 }` in `solver.toml` to request
four evaluators, including the main score director. The effective count is
bounded by the solve's Rayon pool and by **32 evaluators**. `auto`, `none`,
zero, and one remain sequential; construction and VND are not made parallel
by this setting.

The coordinator generates candidates serially in canonical order. Independent
score directors run apply-score-undo trials, then the coordinator consumes
results in candidate order through the acceptor and forager. Each replica
clones the committed working solution and constructs fresh incremental
constraint state; it does not clone or share that state. Committed moves are
replayed on the replicas, and external working-solution writes trigger
resynchronization. Account for those solution copies when choosing a count.

Windows contain at most 32 candidates and adapt to the previous step's
consumption, while respecting the remaining in-phase move-count and
score-calculation budgets. With the same seed and fixed-work termination,
selectors without cross-step stream state retain the sequential trajectory
across evaluator counts. Ruin selectors and lazily activated providers are
reproducible for a **given evaluator count**, not guaranteed identical across
counts. Wall-clock termination is not a cross-count reproducibility contract.

Trials beyond a step's decision point are reported as `moves_speculative` and
candidate-trace disposition `DiscardedSpeculative`, separately from logical
evaluated-move accounting. Sequential evaluation reports no speculative work.
Window buffers and undo journals are reused; window dispatch avoids per-job
heap allocation, and compiled-runtime K-opt trials return journals to their
pool. The one-evaluator path retains its own sequential loop without replica
or window state. These are execution changes, not a universal speedup claim.

### Statistics retain every phase — breaking API changes

`SolverStats` owns one `PhaseStats` record per phase and a single pause-aware
solve clock. Events are recorded once rather than duplicated in phase and
solve counters. Run totals sum phase records plus work outside phases, such
as the initial score calculation.

`SolverTelemetry.phase` is replaced by `phases: Vec<PhaseTelemetry>` in
execution order. Progress snapshots include the running phase as the last
entry; completed snapshots retain construction and local-search phases.
`PhaseTelemetry` gains `moves_speculative`. Direct `SolverStats` counter
access becomes method calls, for example `stats.moves_evaluated()` and
`stats.step_count()`; telemetry snapshot counters remain fields. Consumers
of progress payloads and custom metrics need to migrate both shapes.

### Tabu signatures are lent through one method — breaking API change

`Move::tabu_signature` returns `Cow<'_, MoveTabuSignature>`;
`borrowed_tabu_signature` is removed. Moves with prebuilt signatures return
`Cow::Borrowed`, while signatures derived on demand return `Cow::Owned`.
Borrowing survives move wrappers and the compiled runtime carrier, avoiding
signature clones before acceptor decisions. Custom `Move` implementations
must update their return type and wrap newly constructed signatures in
`Cow::Owned(...)`.

### List-shadow writes update the rows that read them

When a list owner changes, its elements' inverse, index, previous, and next
shadows can change too. The score director now retracts affected element rows
before shadow writes and reinserts them after refresh. Elements left in no
list have their shadows cleared and their rows reinserted. This fixes stale
incremental scores in streams over list elements, including disagreement
between the main director and freshly initialized evaluator replicas.

Generated model support supplies the element notifications and shadow
clearing. Hand-written `PlanningSolution` implementations with list shadows
must provide `list_shadow_elements`, `clear_list_shadows`, and
`list_shadow_source`; the default hooks report no list shadows. Full shadow
rebuilds clear configured element shadows before rebuilding ownership. Scores
that previously depended on stale shadow rows can change after upgrading:
check incremental results against a fresh evaluation rather than expecting
parity with the old incorrect score.

### Dynamic scores and replica construction — bridge breaking changes

Configured native and dynamic solve entrypoints accept a constraint-set
constructor, `fn(&S) -> C`, rather than a ready-made constraint set. Generated
solves adapt the model's constraints function; direct runner integrations must
provide the constructor. `ReplicaDescriptor` carries the borrowed solution
descriptor and constructor. A custom director needs replica-forking support
before requesting parallel evaluation. Host-language bindings with a global
runtime lock must release it on the calling thread for the solve so worker
callbacks can run.

`DynamicScore` stores only hard, medium, and soft levels. Equality, ordering,
hashing, zero, and arithmetic no longer depend on a thread-local family.
The declared family controls presentation and parsing through
`scoped_dynamic_score_family` and `active_dynamic_score_family`; worker
scoring needs no family scope. Decimal parsing scales whole-number parts
under `HardSoftDecimal`, so it inverts display. The `family` field and
`with_family` constructor are removed; use `of` instead of
`hard_medium_soft` or `hard_soft_decimal` (preserving scaled decimal units),
and `ZERO` instead of `zero_for_family`.

### Candidate neighborhoods are not legal domains

The modeling documentation corrects the distinction between
`candidate_values` and `value_range_provider`. `candidate_values` orders and
bounds construction and change-style neighborhoods; it is **not** a legality
restriction. Swap, nearby swap, and pillar swap can exchange a current value
outside that hint if it is inside the receiving entity's legal domain.
Declare a shared domain through a solution collection, or a per-entity legal
domain through an entity `Vec<usize>` field named by
`value_range_provider`. Use `#[planning_pin]` for fixed input values. This is
a correction to the documented contract, not a new swap restriction.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.23.0` | Rust `1.95`; opt-in parallel evaluation and breaking extension/telemetry APIs |
| Previous core runtime | `solverforge 0.22.0` | Canonical grouping kernel; existing applications keep their pins |
| CLI | `solverforge-cli 3.7.1` | Independently released on October 27; fresh scaffolds target core `0.23.0`; see the [CLI release note](/blog/releases/2026/10/27/solverforge-cli-3-7-x/) |
| Previous CLI | `solverforge-cli 3.6.0` | Scaffolds core `0.22.0`; existing projects retain their pins |
| Python | `solverforge-py 0.7.2` / PyPI `solverforge 0.7.2` | Published October 28; the 0.7.x line started October 27; core `0.23.0`, UI `0.9.0`; see the [Python release note](/blog/releases/2026/10/27/solverforge-python-0-7-x/) |
| Previous Python | `solverforge-py 0.6.15` / PyPI `solverforge 0.6.15` | Core `0.22.0`; upgrading the Rust core alone does not retarget these wheels |
| Worked use cases | October 27 released apps | All eight target core `0.23.0` and UI `0.9.0`; see the [app release matrix](/blog/releases/2026/09/27/solverforge-usecases-repository-apps/#october-runtime-updates) |
| Previous worked use cases | October 18 released apps | Retain core `0.22.0` and UI `0.9.0` |

The registry records the non-yanked facade crate's publication at
`2026-10-27T08:35:49Z`. Its artifact SHA-256 is
`1f8c86c2a087fa16102100ba0e2f4eb80b501904853e9baf701533df1b19a063`;
`.cargo_vcs_info.json` binds it to
`e835624a7c04a8ecd2a2ac9a1bcbd92cbc6aca89`, the `v0.23.0` tag commit.
The [GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.23.0)
was published at `2026-10-27T08:34:00Z`.

On that exact commit,
[Publish to crates.io](https://github.com/SolverForge/solverforge/actions/runs/40473570696)
and [Release](https://github.com/SolverForge/solverforge/actions/runs/40473570732)
succeeded. The separate [CI run](https://github.com/SolverForge/solverforge/actions/runs/40473567305)
failed: Ubuntu and Windows passed, macOS failed
`dynamic_nearby_swap_uses_the_finite_all_entity_row_fallback` (expected `3`,
observed `7`), and integration tests were skipped. Publication does not mean
that this cross-platform CI run passed.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.23.0` | 2026-10-27 | Opt-in parallel acceptor-forager evaluation; phase-owned statistics; Cow-returning tabu signatures; list-shadow element rescoring; thread-independent dynamic scores; candidate-hint legality documentation correction. |

## Upgrade Checklist

- Update direct Rust dependencies deliberately and confirm the resolved
  `Cargo.lock`; upgrading core does not retarget published CLI scaffolds,
  Python wheels, or app tags.
- Replace `SolverStats` field reads with methods and migrate telemetry
  consumers from `phase` to `phases`; retain speculative-work counters when
  comparing evaluation costs.
- Update custom move tabu signatures to return `Cow` and direct solve callers
  to supply `fn(&S) -> C`; migrate removed dynamic-score family APIs.
- For hand-written list-shadow models, implement the element/source hooks and
  compare incremental scoring with fresh evaluation after transfers,
  reversals, and removals. Recheck score baselines affected by the fix.
- Express forbidden values in `value_range_provider`, not `candidate_values`,
  and fixed assignments with planning pins.
- Start parallel evaluation with an explicit small count, budget for replica
  memory, and compare seeded fixed-work runs. Keep the evaluator count fixed
  for stateful providers and do not use wall-clock equality as a parity test.
- Review the macOS CI failure above when qualifying your target platforms.

## Where to read next

Read the [core manual](/docs/solverforge/),
[local-search guide](/docs/solverforge/solver/local-search/), and
[domain modeling guide](/docs/solverforge/modeling/).
The [full compare](https://github.com/SolverForge/solverforge/compare/v0.22.0...v0.23.0)
covers all 39 commits; the
[tagged source](https://github.com/SolverForge/solverforge/tree/v0.23.0)
records the final implementation rather than intermediate window policies.
