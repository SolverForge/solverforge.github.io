---
title: "solverforge 0.24.x: Explicit Configuration, Constraint Weights, and Problem Changes"
date: 2026-11-01
draft: false
description: >
  The 0.24.x line reads solver.toml only from the model, rejects unknown
  configuration keys, adds runtime constraint weights and problem changes,
  and trims the public API to what applications use.
---

<%= render Ui::Callout.new(title: "Historical release note", variant: "warning") do %>
This post records an older core release. The current core release is
`solverforge 0.26.1`; see the [0.26.x release note](/blog/releases/2026/11/10/solverforge-0-26-x/).
<% end %>

**solverforge 0.24.x** follows `solverforge 0.23.0`; the line was published on
crates.io on 2026-11-01. The first release is
[0.24.0](https://crates.io/crates/solverforge/0.24.0), with a Rust `1.95`
floor. At publication `cargo add solverforge` installed 0.24.0, and docs.rs
served the 0.24.0 API. `solverforge-cli 3.8.x` scaffolds target it; existing
applications keep their pins until they upgrade.

## What Changed

### `solver.toml` comes from the model — breaking change

A `#[planning_solution]` reads solver configuration only from the file its
`solver_toml = "..."` argument names, embedded at compile time, or from a
`SolverConfig` the application loads itself with `SolverConfig::load` or
`SolverConfig::from_toml_file`. Nothing reads `solver.toml` from the process
working directory. A model without `solver_toml` runs the default
configuration wherever it is launched. Add `solver_toml = "../../solver.toml"`
(the CLI scaffold's value, relative to `src/domain/plan.rs`) to keep using a
project file.

An embedded file that does not parse fails the solve with
`RuntimeBuildError::Configuration` instead of panicking or silently running the
defaults.

### Configuration is validated — breaking changes

- Unknown keys anywhere in solver configuration fail to load with
  `ConfigError::Toml`; a misspelled key no longer disappears.
- YAML configuration is removed: `SolverConfig::from_yaml_file`,
  `SolverConfig::from_yaml_str`, and `ConfigError::Yaml` are gone. Convert YAML
  files to TOML and load them with `from_toml_file` or `from_toml_str`.
- Acceptor and forager values are checked when the configuration compiles.
  `AcceptorBuilder::build`, `AcceptorBuilder::build_with_seed`, and
  `ForagerBuilder::build` return `Result<_, ConfigValueError>`, and an
  `accepted_count` forager with `limit = 0` is rejected instead of running with
  limit 1.
- A `best_score_limit` that does not parse fails the solve.
- In Rust, `AcceptorConfig::HillClimbing` and the unit-like `ForagerConfig`
  variants are written with `{}`.

### Runtime constraint weights

A `#[constraint_weights]` field of type `ConstraintWeights` on the planning
solution binds a multiplier to each named constraint. The weights travel with
the solution, so snapshots, best solutions, and evaluator replicas carry them,
and changing a weight is an ordinary problem change. Each constraint's total,
incremental delta, and match scores are scaled by the same integer multiplier,
so incremental scoring, full recalculation, and explanations agree. Models
without the field compile the unweighted path unchanged.

Solutions gain `validate_constraint_weights`, and a solve fails at start on
weights that name an unknown constraint. Score analysis reports
`ConstraintAnalysis::weight_multiplier` (a `u32`) in place of the removed
`weight` field.

Breaking for hand-written scoring code: `ConstraintSet` implementations must
provide `constraint_weight_refs` and the `*_weighted` methods;
`IncrementalConstraint::weight()`, `ConstraintWeightOverrides`, and
`WeightProvider` are removed; a `ScoreDirector` built with `new` or
`with_descriptor` does not apply a solution's weights, so use the weighted
constructors. The single-constraint marker is public as `SingleConstraint`;
hand-written constraints write `impl SingleConstraint for MyConstraint {}`.

### Problem changes reach running jobs

`ProblemChange`, `ClosureProblemChange`, and `ProblemChangeId` are exported
next to `SolverManager`, so a facade-only application can change a running
job's problem. Changes are queued, applied at runtime safe points in
submission order, and acknowledged in telemetry; a paused job applies its
queue after resume. Changes are consumed by ownership, `SolverHandle` is
removed, and `SolverManager::solve` returns a `SolverEventReceiver` instead of
Tokio's `UnboundedReceiver`. Weights installed by a problem change are
validated like the initial ones.

### Stream sources are the model's collections — breaking change

Constraint streams accept only planning-model collections as sources: pass
the generated accessor, such as `Plan::shifts()`. Closures, `fn` items, and
`vec(...)` are no longer stream sources, and a hand-written
`CollectionExtract` must report a `change_source`. Fluent same-collection
self-joins can continue past two sources, and a five-source join keeps its
cross-stream filters when it continues.

### Scores

Every `Score` implementation provides `scale(i64)`. Score arithmetic that
overflows `i64` panics in release builds instead of wrapping; multiply and
divide panic for non-finite factors and zero divisors, and the
`overflowing_*` methods report overflow without panicking.
`HardSoftDecimalScore` parses and prints with exact fixed-point arithmetic.
`BendableScore` serializes under the `serde` feature.

### A smaller public API — breaking changes

- `solverforge::bridge` is removed and `solverforge::console` exposes only
  `init()`; depend on `solverforge-bridge` or `solverforge-console` directly
  for anything else.
- The `decimal` feature is removed from `solverforge` and `solverforge-core`;
  drop it from `features = [...]`. `verbose-logging` enables `console`.
- `solverforge-solver` items are reachable only at the crate root
  (`solverforge_solver::Name`). Host-provider contracts such as
  `RuntimeProviderRegistry` are imported from `solverforge-bridge`.
- `MoveArena` and `MoveSelector::append_moves` are removed; selectors yield
  candidates through their cursors.
- Public types that nothing produced or consumed are deleted from
  `solverforge-core` and `solverforge-scoring` (and from the facade's
  `domain` and `analysis` modules), including the listener and supply modules,
  the value-range provider traits, `ScoreExplanation`, and the indictment
  types.
- `Solvable::solve` and the synchronous solve return `RuntimeBuildResult<()>`
  instead of re-panicking; `SearchContext::new` and the descriptor move
  selector builder are fallible, and `SearchContext::try_new` is removed.
- `SolverScope::rng()` is private; use `random_below` or `random_u64`.
- `VrpSolution::vehicle_data(&self, usize) -> Option<&ProblemData>` replaces
  the raw-pointer `vehicle_data_ptr`.
- `ListVariableSlot` drops the unused `construction_list_remove` hook.
- `SelectorTelemetry` drops six conflict-repair fields that were always zero.

Move selectors and construction reject values outside a variable's declared
domain.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.24.0` | Rust `1.95`; explicit configuration, constraint weights, problem changes, trimmed API |
| Previous core runtime | `solverforge 0.23.0` | Parallel evaluation and per-phase telemetry; see the [0.23.x release note](/blog/releases/2026/10/27/solverforge-0-23-x/) |
| CLI | `solverforge-cli 3.8.3` | Fresh scaffolds target core `0.24.0`; see the [CLI 3.8.x release note](/blog/releases/2026/11/03/solverforge-cli-3-8-x/) |
| Previous CLI | `solverforge-cli 3.7.1` | Scaffolds core `0.23.0`; existing projects retain their pins |
| Python | `solverforge-py 0.7.2` / PyPI `solverforge 0.7.2` | Still compiled onto core `0.23.0`; upgrading the Rust core does not retarget these wheels |
| Worked use cases | November 3 app releases | All eight target core `0.24.0` and UI `0.9.0`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |
| UI | `solverforge-ui 0.9.0` | Unchanged |
| Maps | `solverforge-maps 2.1.5` | Sends an identifying Overpass User-Agent |

The registry records the facade crate's publication at `2026-11-01T14:24:08Z`.
Its artifact SHA-256 is
`588a097929d85401d12561bda10dd20cdf784aa78abc6b19120b12ab50d9a852`;
`.cargo_vcs_info.json` binds it to
`c114e2d2bfabaada78beb5ee77318b847b964489`, the `v0.24.0` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.24.0)
was published at `2026-11-01T14:24:28Z`.

On that commit the [CI run](https://github.com/SolverForge/solverforge/actions/runs/41314986907)
passed on Linux, macOS, and Windows, plus the MSRV, docs, and package jobs. The
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/41314989365)
re-ran that CI matrix, verified the release, published to crates.io, and
created the GitHub Release; every job succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.24.0` | 2026-11-01 | `solver.toml` only from `solver_toml` or an explicit `SolverConfig`; unknown keys and YAML rejected; runtime constraint weights with `weight_multiplier`; problem changes through the facade; accessor-only stream sources; overflow-checked scores; trimmed public API. |

## Upgrade Checklist

- Add `solver_toml = "<path>"` to every `#[planning_solution]` that relies on
  a `solver.toml` file, or load the file with `SolverConfig::load`; then check
  that a solve uses the settings you expect.
- Remove unknown or misspelled keys from solver configuration, convert YAML
  configuration to TOML, and replace `accepted_count` `limit = 0`.
- Replace closure, `fn`, and `vec(...)` stream sources with the generated
  collection accessors.
- Read `weight_multiplier` instead of `ConstraintAnalysis::weight`; update
  hand-written `ConstraintSet` and constraint implementations for the weighted
  methods and `SingleConstraint`.
- Drop the `decimal` feature; import bridge, console, and solver internals
  from their own crates and crate roots.
- Update `SolverManager::solve` callers for `SolverEventReceiver`, custom
  selectors that overrode `append_moves`, and `VrpSolution` implementations.
- Run full-assert or fresh-evaluation comparisons after upgrading custom
  scoring code, and treat a new overflow panic as a weight or score-range bug.

## Where to read next

Read the [core manual](/docs/solverforge/) and the
[solver configuration guide](/docs/solverforge/solver/configuration/). The
[full compare](https://github.com/SolverForge/solverforge/compare/v0.23.0...v0.24.0)
covers all 107 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.24.0/CHANGELOG.md)
lists every breaking change.
