---
title: "SolverForge Python 0.7.x: Parallel Evaluation and Per-Phase Telemetry"
date: 2026-10-27
draft: false
description: >
  Python models use the SolverForge 0.23.0 runtime for opt-in parallel
  candidate evaluation, with ordered phase telemetry and speculative-work
  diagnostics. Retained clients migrate from phase to phases.
---

**SolverForge Python 0.7.x** follows `solverforge 0.6.15`; `solverforge 0.7.0`
is published on PyPI on 2026-10-27. Install it with
`python3.14 -m pip install "solverforge==0.7.0"`. The source tag is
`solverforge-py v0.7.0`; Python package versions remain independent of Rust
core, CLI, UI, and application versions.

## What Changed

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
| PyPI package | `solverforge 0.7.0` | CPython 3.14; parallel evaluation is opt-in |
| Python source | `solverforge-py v0.7.0` | Core dependencies exactly `=0.23.0`; UI exactly `=0.9.0` |
| Previous Python package | `solverforge 0.6.15` | Core `0.22.0`; single-phase telemetry shape |
| Rust core | `solverforge 0.23.0` | Separate registry release and platform validation |
| CLI | `solverforge-cli 3.6.0` | Still scaffolds core `0.22.0` |
| Rust use-case bundle | October 18 app tags | Still declares core `0.22.0`, UI `0.9.0` |

The `v0.7.0` source tag is commit
`0f739eb5d427a8a7748b21009ca70bbfa4697750`. PyPI provides CPython 3.14
wheels for Linux x86_64, macOS arm64, and Windows x64, plus a source archive.
These wheels use `cp314`, not the free-threaded `cp314t` ABI; free-threaded
installations need a source build with the matching interpreter.
The Linux wheel's SHA-256 is
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
| `0.7.0` | 2026-10-27 | Core `0.23.0`; opt-in parallel evaluation; GIL release during direct solves; ordered `phases` telemetry and speculative-work diagnostics; thread-independent score bridge. |

## Upgrade Checklist

- Install `solverforge==0.7.0` and use source tag `v0.7.0` for examples and
  development. Package wheels do not contain the repository example apps.
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
- [Full tagged comparison](https://github.com/SolverForge/solverforge-py/compare/v0.6.15...v0.7.0)
