---
title: "SolverForge Python 0.7.x: Parallel Evaluation and Per-Phase Telemetry"
date: 2026-10-27
draft: false
description: >
  Python models use the SolverForge 0.23.0 runtime for opt-in parallel
  candidate evaluation, with ordered phase telemetry and speculative-work
  diagnostics. Retained clients migrate from phase to phases; the patches
  preserve interrupts and report callback errors without a Rust panic preamble.
---

**SolverForge Python 0.7.x** follows `solverforge 0.6.15`. The line started
with `0.7.0` on 2026-10-27; the current PyPI package is `solverforge 0.7.2`,
published on 2026-10-28. Install it with
`python3.14 -m pip install "solverforge==0.7.2"`. The source tag is
`solverforge-py v0.7.2`; Python package versions remain independent of Rust
core, CLI, UI, and application versions.

## What Changed

### Interrupts and optional attribute errors reach the caller

The `0.7.1` patch stops treating every failed optional attribute probe as a
missing field. Callback-view synchronization, score conversion's `to_native`
lookup, and compound-edit entity-marker lookups treat only `AttributeError`
as absence. Other exceptions, including `KeyboardInterrupt` raised during a
planning-field descriptor lookup, propagate instead of being consumed while
the solve runs to its termination limit. Provider edit dictionaries and score
representations keep their existing shapes.

### Callback errors have one reporting path

The `0.7.2` patch suppresses the Rust panic-hook preamble for the binding's
recognized `SolverPanicPayload`. A direct solve still re-raises the original
Python exception with its traceback; a retained job still records its failure.
The hook is installed once when the native module loads and forwards every
unrelated panic to the previous hook. This removes the misleading
`Box<dyn Any>` crash-looking stderr message without hiding Python errors or
silencing arbitrary Rust panics.

## What Changed in the Initial 0.7.0 Release

### Parallel candidate evaluation within a solve

Config dictionaries and `SolverConfig.from_toml(...)` pass `move_thread_count`
to the native acceptor-forager local-search runtime. An explicit
`{"move_thread_count": {"count": 4}}` requests up to four evaluators,
including the main director. The effective count is capped by the current
Rayon pool and **32 evaluators**. `"auto"`, `"none"`, zero, and one stay
sequential. Construction and variable neighborhood descent remain sequential.

The coordinator generates candidates serially and consumes their results in
canonical order through the acceptor and forager. Each evaluator owns a
working-solution replica and an independent constraint set built from the same
compiled model. This uses the core's evaluation windows, not a Python-side
thread pool or a second search engine.

Callbacks must be deterministic and must not mutate shared state. The direct
`Solver.solve` entry releases the GIL for the duration of the solve so Rayon
workers can attach to Python without deadlocking. On GIL-enabled CPython,
Python callbacks still serialize on the GIL. Free-threaded Python permits
concurrent callbacks, subject to the thread-safety of their dependencies;
parallel configuration alone is not a speedup guarantee.

At fixed seed and deterministic work limits, scalar/list selectors without
cross-step stream state preserve the sequential trajectory across evaluator
counts. Stateful ruin selectors and lazily activated providers can observe
speculative pulls: keep the evaluator count fixed for reproducibility. A
wall-clock budget is not a cross-count trajectory guarantee.

### Retained telemetry uses an ordered phase list — breaking change

Retained status and event payloads replace the single `phase` dictionary with
`phases`, a list in execution order. Each started phase retains its own index,
type, elapsed time, steps, moves, score-calculation counts, and generation and
evaluation durations. In a running phase's progress event, the last entry is
that phase; completed telemetry keeps the earlier records too. Guard the empty
list before any phase has started. Run totals include work outside phases,
such as initial scoring.

Both run telemetry and each phase expose `moves_speculative`. Candidate traces
use the `discarded_speculative` disposition for trials evaluated ahead of a
decision point and discarded. These trials do not inflate logical consumed
`moves_evaluated` or `score_calculations` budgets. Sequential evaluation reports
zero speculation.

The source-checkout hospital and deliveries DTOs expose `phases` and camel-case
`movesSpeculative`. Clients of their SSE payloads must migrate the same way;
these Python examples are separate from the independently tagged Rust apps.

### Runtime and score bridge alignment

Six direct SolverForge Rust dependencies are pinned exactly to `=0.23.0`.
The embedded UI remains `=0.9.0`, Python requires `>=3.14`, and source builds
require Rust `1.95`. The binding supplies a constraint-set constructor at every
solve entry so each replica starts with independent incremental state.

The bridge's `DynamicScore` is a plain hard/medium/soft value: worker scoring
does not depend on thread-local score-family state. Python's declared score
families and decimal units remain intact. Callback exceptions from worker
trials propagate with their Python traceback rather than disappearing inside
the native worker.

## Published Version Boundaries

| Surface | Version | Runtime or compatibility boundary |
| ------- | ------- | --------------------------------- |
| PyPI package | `solverforge 0.7.2` | CPython 3.14; parallel evaluation is opt-in |
| Python source | `solverforge-py v0.7.2` | Core dependencies exactly `=0.23.0`; UI exactly `=0.9.0` |
| Previous Python package | `solverforge 0.6.15` | Core `0.22.0`; single-phase telemetry shape |
| Rust core | `solverforge 0.23.0` | Separate registry release and platform validation |
| CLI | `solverforge-cli 3.7.1` | Fresh scaffolds target core `0.23.0`; see the [CLI release note](/blog/releases/2026/10/27/solverforge-cli-3-7-x/) |
| Rust use-case bundle | October 27 app tags | All eight declare core `0.23.0`, UI `0.9.0`; see the [app release matrix](/blog/releases/2026/09/27/solverforge-usecases-repository-apps/#october-runtime-updates) |

The current `v0.7.2` source tag points to
`22833923229c008a70c385e05c76072a5d87c75f`. Its Linux x86_64 wheel SHA-256 is
`3f9bac5b0196c33dbe8906aa7e7c3293873cfd3488331a390ce426db0fe7e218`;
its source archive SHA-256 is
`c2945fad91e450cd6dbf691090ea91753adcde45e513805d6bc8df01a7810288`.
Its exact-commit [CI](https://github.com/SolverForge/solverforge-py/actions/runs/40672018229)
and [release/PyPI publication](https://github.com/SolverForge/solverforge-py/actions/runs/40672022045)
passed. The intermediate `v0.7.1` tag points to
`b8ff34c48a2e87aae3f83b849d71e25e3188c6e5`; its
[CI](https://github.com/SolverForge/solverforge-py/actions/runs/40665034987) and
[release/PyPI publication](https://github.com/SolverForge/solverforge-py/actions/runs/40665037880)
also passed. These patches keep the core, UI, Python requirement, and wheel ABI
unchanged.

The original `v0.7.0` source tag is commit
`0f739eb5d427a8a7748b21009ca70bbfa4697750`. PyPI provides CPython 3.14
wheels for Linux x86_64, macOS arm64, and Windows x64, plus a source archive.
These wheels use `cp314`, not the free-threaded `cp314t` ABI; free-threaded
installations need a source build with the matching interpreter.
That release's Linux wheel SHA-256 is
`db040cc537d5f281822ac438b123cc281966c344eab23cbf6b80ac7f1125872c`;
the source archive's is
`258dc6279865d67b2503eae775cc03114cc6db71d8bd96276ae5ba27c830be6c`.
Its exact-commit
[CI](https://github.com/SolverForge/solverforge-py/actions/runs/40499986297) and
[release/PyPI publication](https://github.com/SolverForge/solverforge-py/actions/runs/40499989425)
workflows passed. The repository publishes through PyPI; it has no GitHub
Release object for this tag. The Rust core's separate macOS CI finding is
recorded in the [core release note](/blog/releases/2026/10/27/solverforge-0-23-x/),
not substituted for this binding's validation.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.7.2` | 2026-10-28 | Suppresses the panic-hook preamble only for recognized Python callback-error payloads; direct exceptions and retained failures remain visible, and unrelated Rust panics reach the previous hook. |
| `0.7.1` | 2026-10-28 | Propagates interrupts and other non-`AttributeError` failures from callback-view, optional score-conversion, and compound-edit marker lookups. |
| `0.7.0` | 2026-10-27 | Core `0.23.0`; opt-in parallel evaluation; GIL release during direct solves; ordered `phases` telemetry and speculative-work diagnostics; thread-independent score bridge. |

## Upgrade Checklist

- Install `solverforge==0.7.2` and use source tag `v0.7.2` for examples and
  development. Package wheels do not contain the repository example apps.
- Handle direct callback exceptions through Python tracebacks and retained
  failures through the job status; do not parse a Rust panic preamble as the
  error interface. Let `KeyboardInterrupt` propagate unless the application
  intentionally handles interruption.
- Migrate retained consumers from `telemetry["phase"]` to the ordered
  `telemetry["phases"]` list. Use its last entry for running phase progress,
  handle an empty list, and preserve completed entries for phase breakdowns.
- Update hospital/deliveries SSE clients to read `phases` and
  `movesSpeculative`; retain `moves_speculative` in native diagnostic consumers.
- Keep callbacks free of shared mutation; begin with a small explicit evaluator
  count and budget for solution replicas. Check the interpreter's actual GIL
  mode rather than assuming parallel callbacks from the Python version alone.
- Re-run model checks at fixed work and seed, then compare time-budgeted quality
  separately. Do not change benchmark tested-version labels without a new run.

## Where to read next

- [Python manual](/docs/solverforge-python/)
- [Getting started](/docs/solverforge-python/getting-started/)
- [Parallel evaluation and retained diagnostics](/docs/solverforge-python/solving-and-runtime/)
- [Hospital example](/docs/solverforge-python/hospital-example/)
- [Deliveries example](/docs/solverforge-python/deliveries-example/)
- [Previous Python line](/blog/releases/2026/09/29/solverforge-python-0-6-10-x/)
- [Full tagged comparison](https://github.com/SolverForge/solverforge-py/compare/v0.6.15...v0.7.2)
