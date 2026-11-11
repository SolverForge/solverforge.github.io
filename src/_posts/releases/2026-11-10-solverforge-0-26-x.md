---
title: "solverforge 0.26.x: Replica Directors Without Descriptor Types, Proportional Debug Info, and Late Acceptance That Keeps Its History"
date: 2026-11-10
draft: false
description: >
  The 0.26.x line builds replica-forking score directors with
  ScoreDirector::with_replicas, keeps stream closure types proportional to the
  constraint set so large apps link with full debug info, and documents every
  public item the planning macros generate. 0.26.1 keeps the late-acceptance
  score history across soft-level improvements and draws scalar ruin batches
  without an entity-sized permutation.
---

**solverforge 0.26.x** follows `solverforge 0.25.1`; the line was published on
crates.io from 2026-11-10 through 2026-11-11. The current release is
[0.26.1](https://crates.io/crates/solverforge/0.26.1), with a Rust `1.95`
floor. `cargo add solverforge` installs 0.26.1, and docs.rs serves the 0.26.1
API. The public modeling, stream, configuration, and solving APIs are
unchanged across the line; the one breaking change, in 0.26.0, is in the
lower-level `solverforge-scoring` score-director constructors. 0.26.1 changes
no public API: late acceptance keeps its score history unless a hard or medium
level of the best score changes, and scalar ruin-and-recreate draws its batches
without an entity-sized permutation. `solverforge-cli 4.0.4`
scaffolds 0.26.1, and all eight worked use cases pin it.

## What Changed

### Late acceptance keeps its score history (0.26.1)

`late_acceptance` keeps its score history across a new best score unless a
hard or medium level of the best score changes: the hard level of a hard/soft
score, the hard and medium levels of a hard/medium/soft score, or a hard level
of a bendable score. Only then is the history refilled with the new best, so
entries from before a feasibility change cannot admit moves that keep the new
hard level but give up the soft levels. An improvement in soft levels alone
leaves the history as it is, and a score with only soft levels never refills
it.

Through 0.26.0 the acceptor refilled the whole history on every new best score.
After the first improvement every entry equalled the best, so only moves at
least as good as the best were accepted: from then on the phase ran as hill
climbing with sideways moves, and searches that rely on accepting worse moves
to leave a local optimum settled early. The configuration is unchanged:
`late_acceptance_size` still sets the history length, and
`diversified_late_acceptance` is unaffected.

The fix was contributed by [slapers](https://github.com/slapers) in
[#242](https://github.com/SolverForge/solverforge/pull/242), together with a
follow-up that refills the history of a bendable score only on its hard levels.

### Scalar ruin batches without an entity-sized permutation (0.26.1)

`ruin_recreate_move_selector` draws each batch of entities to clear from a
partial shuffle that records only the positions it displaces, so a batch costs
time and memory proportional to the ruin count instead of the entity count, and
opening the move cursor no longer resets an entity-sized permutation for every
batch. The batches and the random draws they consume are unchanged, so a seed
selects the same entities as before. In the zero-regression gate's `ruin`
case, a 15-trial run against 0.26.0 measured 41.8% less wall time and 55.5%
fewer instructions
([#249](https://github.com/SolverForge/solverforge/pull/249)).

### Replica-forking directors — breaking change (0.26.0)

`solverforge-scoring` removes `ReplicaDescriptor`. A score director that forks
evaluator replicas is built with `ScoreDirector::with_replicas`,
`with_replicas_weighted`, or `with_replicas_in_mode`, which take the
constraint-set constructor beside a borrowed descriptor:

```text
ScoreDirector::with_replicas(
    solution,
    constraints,            // normally constraint_builder(&solution)
    constraint_builder,     // fn(&S) -> C
    &descriptor,            // &SolutionDescriptor
    entity_counter,         // fn(&S, usize) -> usize
)
```

The constructor is a field of the director instead of part of its descriptor
type, so a replica-capable director is `ScoreDirector<S, C, &SolutionDescriptor>`
and names its constraint set once. `DirectorDescriptor` has no type
parameters, and `DirectorDescriptor::replica()` is replaced by `share()`.
Forking with `Director::fork_replica()` and `Director::fork_for_solution()`,
and rebuilding the constraint set on `reset()`, behave as before; a director
not built by `with_replicas*` returns `None` from both forks.

Macro-generated solves and the configured entry points build their directors
themselves, so application code that does not construct a `ScoreDirector`
directly needs no change. See
[Extend the Solver](/reference/extend-solver/#evaluator-replicas-and-solve-entry-points).

### Debug info stays proportional to the constraint set

The stream combinators build the closures they store (filters, weights,
extractors, joined-row adapters) in functions generic only over what each
closure captures. A closure built inside a generic method used to name every
upstream stream type, so each chained `filter`, `penalize`, or `named` repeated
the whole stream type, and debug-info type names grew with the length of every
constraint chain. The public stream API is unchanged.

On a 30-constraint application test build, the line-tables debug strings drop
from 2.82 GB to 0.37 GB and the longest type name from 8.0 MB to 1.0 MB, and
the test binary links and passes with full debug info.

### Generated items are documented or hidden

Every public item the planning macros generate carries documentation or is
`#[doc(hidden)]`: descriptor and entity-count plumbing is hidden, and the
collection source methods and the generated `<Solution>ConstraintStreams`
trait and its methods are documented. A crate that enables `missing_docs` gets
no warnings from the macros
([#235](https://github.com/SolverForge/solverforge/issues/235)).

### Module roots hold declarations only

Every `mod.rs` and `lib.rs` in the workspace holds only module declarations and
re-exports, and each crate's lint levels live in its Cargo `[lints]` table.
Public paths and behaviour are unchanged.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.26.1` | Rust `1.95`; late acceptance keeps its history across soft-level improvements; scalar ruin batches without an entity-sized permutation; replica directors built by `with_replicas*` |
| First 0.26 release | `solverforge 0.26.0` | Replica directors built by `with_replicas*`; proportional stream closure types; documented generated items |
| Previous core runtime | `solverforge 0.25.1` | Bounded nearby list candidates; see the [0.25.x release note](/blog/releases/2026/11/09/solverforge-0-25-x/) |
| CLI | `solverforge-cli 4.0.4` | Fresh scaffolds target core `0.26.1` (4.0.2 and 4.0.3 target `0.26.0`); see the [4.0.x CLI release note](/blog/releases/2026/11/10/solverforge-cli-4-0-x/) |
| Python | `solverforge-py 0.7.2` / PyPI `solverforge 0.7.2` | Compiled onto core `0.23.0`; upgrading the Rust core does not retarget these wheels |
| Worked use cases | November 11 app releases | All eight pin core `0.26.1` and UI `0.9.0`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |
| UI | `solverforge-ui 0.9.1` | Unchanged |
| Maps | `solverforge-maps 2.3.3` | Unchanged |

All nine workspace crates (`solverforge`, `solverforge-core`,
`solverforge-config`, `solverforge-scoring`, `solverforge-solver`,
`solverforge-macros`, `solverforge-bridge`, `solverforge-console`, and
`solverforge-cvrp`) publish `0.26.0` and `0.26.1`.

The registry records the facade crate's publication at `2026-11-10T10:33:40Z`.
Its artifact SHA-256 is
`62181b0bb54c94833633b2b69cb0592d98d4532e0ba204f7cce828966cc0f773`;
`.cargo_vcs_info.json` binds it to
`720fdaded42f16a131cdb8820b624b407b275d5f`, the `v0.26.0` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.26.0)
was published at `2026-11-10T10:33:56Z`.

On that commit the [CI run](https://github.com/SolverForge/solverforge/actions/runs/42797763891)
passed. The
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/42797767461)
re-ran the CI matrix on Linux, macOS, and Windows with the Miri, MSRV, docs,
and package jobs, verified the release, published to crates.io, and created
the GitHub Release; every job succeeded.

The registry records the 0.26.1 facade publication at `2026-11-11T02:49:52Z`.
Its artifact SHA-256 is
`a00f06d8db244d619f556a25165115015bda50f01c811db0d515c9e6e3c28458`;
`.cargo_vcs_info.json` binds it to
`f3b41788e7519f3b707f8a9aa450fc545e0d5c08`, the `v0.26.1` tag commit. The
[GitHub Release](https://github.com/SolverForge/solverforge/releases/tag/v0.26.1)
was published at `2026-11-11T02:50:11Z`. On that commit the
[CI run](https://github.com/SolverForge/solverforge/actions/runs/42947324720)
passed, and every job of the
[Release workflow](https://github.com/SolverForge/solverforge/actions/runs/42947327153)
succeeded: the Linux, macOS, Windows, Miri, MSRV, docs, and package jobs,
release verification, crates.io publication, and the GitHub Release. The
0.26.1 range also changes the zero-regression gate's own tooling (timed trials
rotate through the code layouts, and hardware branch misses are reported
rather than graded); no published crate behaviour depends on it.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.26.1` | 2026-11-11 | Late acceptance refills its history only when a hard or medium level of the best score changes (contributed by [slapers](https://github.com/slapers) in [#242](https://github.com/SolverForge/solverforge/pull/242)); scalar ruin batches drawn without an entity-sized permutation; no public API change. |
| `0.26.0` | 2026-11-10 | `ReplicaDescriptor` removed: replica-forking directors are built by `ScoreDirector::with_replicas*`, and `DirectorDescriptor::replica()` becomes `share()`; stream closures built in narrowly generic functions; generated public items documented or hidden; declaration-only module roots. |

## Upgrade Checklist

- From 0.26.0, move the `solverforge` pin to `0.26.1`; no code changes. A
  `late_acceptance` phase now keeps accepting worse moves after its first
  improvement, so re-check solve quality and any tuned `late_acceptance_size`
  or termination budget on models that use it.
- Replace
  `ScoreDirector::with_descriptor(solution, constraints, ReplicaDescriptor::new(&descriptor, constraint_builder), entity_counter)`
  with
  `ScoreDirector::with_replicas(solution, constraints, constraint_builder, &descriptor, entity_counter)`,
  and the weighted or mode-generic forms with `with_replicas_weighted` or
  `with_replicas_in_mode`.
- Spell a replica-capable director's type as
  `ScoreDirector<S, C, &SolutionDescriptor>` (plus the weight mode, if not the
  default) instead of naming `ReplicaDescriptor`.
- Drop the type parameters from `DirectorDescriptor` bounds, and call
  `share()` where a custom descriptor implementation or caller used
  `replica()`.
- Application code that only uses the facade, the planning macros, and the
  configured solve entry points upgrades by moving the `solverforge` pin.

## Where to read next

Read the [core manual](/docs/solverforge/),
[Local Search](/docs/solverforge/solver/local-search/#late-acceptance), and
[Extend the Solver](/reference/extend-solver/). The
[0.26.0 compare](https://github.com/SolverForge/solverforge/compare/v0.25.1...v0.26.0)
covers its 8 commits and the
[0.26.1 compare](https://github.com/SolverForge/solverforge/compare/v0.26.0...v0.26.1)
its 8 commits; the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.26.1/CHANGELOG.md)
lists the breaking change and both releases.
