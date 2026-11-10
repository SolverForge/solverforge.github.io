---
title: "solverforge 0.26.x: Replica Directors Without Descriptor Types and Proportional Debug Info"
date: 2026-11-10
draft: false
description: >
  The 0.26.x line builds replica-forking score directors with
  ScoreDirector::with_replicas, keeps stream closure types proportional to the
  constraint set so large apps link with full debug info, and documents every
  public item the planning macros generate.
---

**solverforge 0.26.x** follows `solverforge 0.25.1`; the line was published on
crates.io on 2026-11-10. The first release is
[0.26.0](https://crates.io/crates/solverforge/0.26.0), with a Rust `1.95`
floor. `cargo add solverforge` installs 0.26.0, and docs.rs serves the 0.26.0
API. The public modeling, stream, configuration, and solving APIs are
unchanged; the one breaking change is in the lower-level
`solverforge-scoring` score-director constructors. `solverforge-cli 4.0.2`
scaffolds 0.26.0, and all eight worked use cases pin it.

## What Changed

### Replica-forking directors — breaking change

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
| Core runtime | `solverforge 0.26.0` | Rust `1.95`; replica directors built by `with_replicas*`; proportional stream closure types; documented generated items |
| Previous core runtime | `solverforge 0.25.1` | Bounded nearby list candidates; see the [0.25.x release note](/blog/releases/2026/11/09/solverforge-0-25-x/) |
| CLI | `solverforge-cli 4.0.2` | Fresh scaffolds target core `0.26.0`; see the [4.0.x CLI release note](/blog/releases/2026/11/10/solverforge-cli-4-0-x/) |
| Python | `solverforge-py 0.7.2` / PyPI `solverforge 0.7.2` | Compiled onto core `0.23.0`; upgrading the Rust core does not retarget these wheels |
| Worked use cases | November 10 app releases | All eight pin core `0.26.0` and UI `0.9.0`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/) |
| UI | `solverforge-ui 0.9.1` | Unchanged |
| Maps | `solverforge-maps 2.3.3` | Unchanged |

All nine workspace crates (`solverforge`, `solverforge-core`,
`solverforge-config`, `solverforge-scoring`, `solverforge-solver`,
`solverforge-macros`, `solverforge-bridge`, `solverforge-console`, and
`solverforge-cvrp`) publish `0.26.0`.

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

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.26.0` | 2026-11-10 | `ReplicaDescriptor` removed: replica-forking directors are built by `ScoreDirector::with_replicas*`, and `DirectorDescriptor::replica()` becomes `share()`; stream closures built in narrowly generic functions; generated public items documented or hidden; declaration-only module roots. |

## Upgrade Checklist

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

Read the [core manual](/docs/solverforge/) and
[Extend the Solver](/reference/extend-solver/). The
[full compare](https://github.com/SolverForge/solverforge/compare/v0.25.1...v0.26.0)
covers all 8 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.26.0/CHANGELOG.md)
lists the breaking change.
