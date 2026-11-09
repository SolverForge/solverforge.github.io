---
title: "solverforge 0.25.x: Literal Configuration, Framework Partitioned Search, and Automatic Parallel Evaluation"
date: 2026-11-09
draft: false
description: >
  The 0.25.x line applies every configured termination criterion, adds no
  hidden time limit, validates configuration that used to be ignored, runs
  partitioned search in the framework, and turns on measured parallel
  evaluation by default.
---

**solverforge 0.25.x** follows `solverforge 0.24.0`; the line was published on
crates.io on 2026-11-09. The first release is
[0.25.0](https://crates.io/crates/solverforge/0.25.0), with a Rust `1.95`
floor. `cargo add solverforge` installs 0.25.0, and docs.rs serves the 0.25.0
API. Fresh `solverforge-cli 3.9.x` scaffolds target it; existing applications
keep their pins until they upgrade.

## What Changed

### Termination means what the configuration says — breaking changes

- Every configured solver-level criterion applies, combined with OR: the first
  one reached stops the solve. A configuration with several criteria can stop
  earlier than before.
- Nothing adds a time limit the configuration does not set. A solve with only
  `best_score_limit`, `step_count_limit`, or an unimproved limit is no longer
  capped at 30 or 60 seconds.
- `seconds_spent_limit = 0` and `minutes_spent_limit = 0` are a zero time
  limit, not "no limit"; time limits are literal and saturate instead of
  overflowing.
- The `solverforge.execution_policy` candidate-trace header carries one
  attribute per criterion, and `termination_composition` names every installed
  criterion (for example `time_or_step_count`). The `criterion` and
  `criterion_target` attributes are removed.
- `try_run_solver_with_config_and_search`,
  `try_run_weighted_solver_with_config_and_search`, and
  `try_run_dynamic_solver_with_config_parts` lose their
  `default_time_limit_secs` parameter.

See [Termination](/docs/solverforge/solver/termination/).

### Parallel evaluation is automatic — breaking change

The default `move_thread_count = "auto"` evaluates local-search steps on up to
four evaluators, choosing per step between sequential evaluation and parallel
windows from measured trial and coordination costs. A parallel window forks up
to three working-solution replicas. `"none"` keeps evaluation sequential.
`{ count = N }` needs `N >= 1`: `MoveThreadCount::Count` and
`ThreadCount::Specific` hold a `NonZeroUsize`, and `{ count = 0 }` is a
configuration error. The thread policy is resolved when the local-search phase
solves, on the pool that runs it.

See [Local Search](/docs/solverforge/solver/local-search/).

### Environment modes seed and check — breaking changes

- `reproducible`, `fast_assert`, and `full_assert` without `random_seed` solve
  with the fixed seed `REPRODUCIBLE_RANDOM_SEED`; only `non_reproducible` draws
  an operating-system seed.
- `fast_assert` panics on score drift at committed steps and best-solution
  updates.
- `full_assert` panics on drift in any score-director calculation, including
  move evaluations and evaluator replicas. `Director` gains the provided method
  `set_score_assertion`.

### Partitioned search runs in the framework — breaking changes

`SearchBuilder::partitioned_phase` is removed. Register a `SolutionPartitioner`
with `SearchBuilder::partitioner`; the framework builds and runs the phase from
the `partitioned_search` configuration, and the phase termination bounds every
partition. `SolutionPartitioner::recommended_partition_count` returns
`Option<NonZeroUsize>`, `FunctionalPartitioner::with_recommended_count` takes a
`NonZeroUsize`, `ThreadCount::resolve` takes the recommendation as its second
argument, and `auto` threads are bounded by the recommended count. A
`partitioned_search` termination with `best_score_limit`,
`unimproved_step_count_limit`, or `unimproved_seconds_spent_limit` is a
configuration error.

### Configuration that used to be ignored is rejected — breaking changes

- `group_candidate_limit` without `group_name`.
- `value_candidate_limit`, `group_candidate_limit`, or a non-default
  `construction_obligation` on a list construction heuristic.
- `simulated_annealing` with both `calibration` and `level_temperatures`.
- `step_counting_hill_climbing.step_count_limit = 0`.
- A non-positive or non-finite `great_deluge.water_level_increase_ratio`.
- A `score_director.constraint_provider` that names no `constraints` or
  `constraint_provider` path declared on the solution
  (`RuntimeBuildError::UnknownConstraintProvider`).

A fixed-weight union needs at least one positive weight; a zero weight disables
its child instead of failing the configuration.

### Score director and analysis — breaking changes

`score_director.constraint_provider` selects which declared constraint set a
solve uses, and `score_director.constraint_match_enabled` defaults to `true`.
Setting it to `false` disables `SolverManager::analyze_snapshot` for the job,
which returns the new `SolverManagerError::SnapshotAnalysisDisabled`.
`SolverRuntime::bind_snapshot_analysis` takes
`Option<fn(&S) -> ScoreAnalysis<S::Score>>`, and
`try_run_dynamic_solver_with_config_parts` takes
`&[DynamicConstraintProvider]`.

### Runtime overrides

`SolverConfig::with_override` applies a `SolverConfigOverride` to a
configuration, and `SolverManager` can run a retained job under an override.
See [SolverManager](/docs/solverforge/solver/solver-manager/).

### Search

- VND phases honour `score_tie_break`, whose default is `random`; set
  `score_tie_break = "first"` to apply the first of several equally scored best
  improving moves.
- `list_k_opt` construction accepts `k` from 2 to 5, and polishes routes with
  k-opt for `k` from 3 to 5.

### Scoring — breaking changes

- `SharedOperatorTerminal` requires its operator to implement
  `GroupedOperator`, and `changed_key_count` sums changed group keys instead of
  counting row-changing notifications.
- A `Projection` that emits more rows for one input than its `MAX_EMITS`
  panics; raise `MAX_EMITS` to the real maximum. Row lists are sized by
  `MAX_EMITS`.
- `ConstraintWeight` is documented and exported at the crate roots beside
  `FixedWeight` and `HardWeight`.
- A score director can fork over another solution.
- Scoring production code forbids `unsafe`.

### Performance

Construction reuses its candidate and value buffers across placements, a solver
runner keeps its declaration only when it runs partitioned search, and the
global Rayon pool is no longer initialized while a solver compiles.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.25.0` | Rust `1.95`; literal termination, automatic parallel evaluation, framework partitioned search, stricter configuration |
| Previous core runtime | `solverforge 0.24.0` | Explicit configuration and constraint weights; see the [0.24.x release note](/blog/releases/2026/11/01/solverforge-0-24-x/) |
| CLI | `solverforge-cli 3.9.0` | Fresh scaffolds target core `0.25.0` |
| Previous CLI | `solverforge-cli 3.8.3` | Scaffolds core `0.24.0`; existing projects retain their pins |
| Python | `solverforge-py 0.7.2` / PyPI `solverforge 0.7.2` | Still compiled onto core `0.23.0`; upgrading the Rust core does not retarget these wheels |
| Worked use cases | November 9 app releases | All eight target core `0.25.0` and UI `0.9.0`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |
| UI | `solverforge-ui 0.9.1` | Unchanged |
| Maps | `solverforge-maps 2.3.3` | Unchanged |

All nine workspace crates (`solverforge`, `solverforge-core`,
`solverforge-config`, `solverforge-scoring`, `solverforge-solver`,
`solverforge-macros`, `solverforge-bridge`, `solverforge-console`, and
`solverforge-cvrp`) publish `0.25.0`.

The registry records the facade crate's publication at `2026-11-09T03:06:41Z`.
Its artifact SHA-256 is
`4a3ecc7e869c19a21e06386736824f230ad106941188b861424389556456737c`;
`.cargo_vcs_info.json` binds it to
`3115b4dd6b40bc72a472b042f5e6b665cb9720c7`, the `v0.25.0` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.25.0)
was published at `2026-11-09T03:06:58Z`.

On that commit the [CI run](https://github.com/SolverForge/solverforge/actions/runs/42552915915)
passed. The
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/42552934483)
re-ran the CI matrix on Linux, macOS, and Windows with the Miri, MSRV, docs,
and package jobs, verified the release, published to crates.io, and created
the GitHub Release; every job succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.25.0` | 2026-11-09 | Every termination criterion applies with no hidden time limit; automatic measured parallel evaluation; fixed seeds and stronger checks in the assert modes; partitioned search run by the framework; ignored configuration rejected; snapshot analysis gated on `constraint_match_enabled`; configuration overrides. |

## Upgrade Checklist

- Read every `[termination]` table: all criteria now apply, a work or score
  criterion without a time limit can run indefinitely, and a zero time limit
  stops at once.
- Replace `move_thread_count = { count = 0 }`, and set
  `move_thread_count = "none"` where a run must stay sequential.
- Set `random_seed` explicitly if a reproducible or assert-mode run relied on
  a fresh seed each time.
- Move partitioned search to `SearchBuilder::partitioner` and the
  `partitioned_search` configuration; pass `NonZeroUsize` partition counts.
- Remove the configuration combinations listed above, and give a union with
  fixed weights at least one positive weight.
- Handle `SolverManagerError::SnapshotAnalysisDisabled` in exhaustive matches.
- Raise a `Projection`'s `MAX_EMITS` to its real maximum, and read
  `changed_key_count` as a count of changed group keys.
- Add `score_tie_break = "first"` to a VND phase that must keep the earlier
  choice among equal best moves.

## Where to read next

Read the [core manual](/docs/solverforge/) and the
[solver configuration guide](/docs/solverforge/solver/configuration/). The
[full compare](https://github.com/SolverForge/solverforge/compare/v0.24.0...v0.25.0)
covers all 54 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.25.0/CHANGELOG.md)
lists every breaking change.
