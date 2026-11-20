---
title: "SolverForge Python 0.8.x: The SolverForge 0.31.2 Runtime"
date: 2026-11-20
draft: false
description: >
  Python models compile onto the SolverForge 0.31.2 runtime: every termination
  criterion applies with no implicit time limit, the auto evaluator policy can
  run in parallel, the constraint provider is selected by name, and detailed
  telemetry reports the resolved phase plan.
---

**SolverForge Python 0.8.x** follows `solverforge 0.7.2`. The current PyPI
package is `solverforge 0.8.1`, published on 2026-11-20. Install it with
`python3.14 -m pip install "solverforge==0.8.1"`. The source tag is
`solverforge-py v0.8.1`; Python package versions remain independent of Rust
core, CLI, UI, and application versions. The `0.8.0` number was tagged but
never published: its release run could not build the macOS wheel, and no
artifact carries it.

## What Changed

### The SolverForge 0.31.2 runtime

The six direct SolverForge Rust dependencies move from `=0.23.0` to exactly
`=0.31.2`, and the embedded UI from `=0.9.0` to `=0.9.1`. Python solves run on
the core's current default search policy, its Clarke-Wright and selector
implementations, and its configuration validation. Core features that need a
model declaration the binding does not expose, such as list element groups and
cascading list shadows, are not available from Python in this line. The binding
still compiles one immutable runtime plan per schema and supplies no search
engine of its own.

### Termination has no implicit time limit — breaking change

`0.7.x` stopped a solve with no time limit after 30 seconds, or 60 seconds for
list models. That cap is gone. Every configured solver-level criterion applies,
combined with OR, and a zero `seconds_spent_limit` is a zero budget.

Without any criterion and without `phases`, a solve runs construction and
stops, because the default local search is assembled only when a criterion
exists. An explicit `local_search` phase with no solver or phase limit runs
until the process or a retained `cancel(...)` stops it. Give every
long-running config a limit.

### Configuration is validated before solving — breaking change

The core rejects unknown keys and invalid values before any search runs. A
zero `selected_count_limit`, a zero `max_nearby` on the nearby selectors, a
zero `min_ruin_count` or `min_sublist_size`, and a `k_opt` `k` outside 2 to 5
are configuration errors rather than empty neighborhoods. A direct solve raises
`RuntimeError` naming the config path; a retained job enters `FAILED` with the
same message.

### Automatic parallel evaluation

`move_thread_count = "auto"`, the default, decides per local-search step
whether parallel windows on up to four evaluators beat sequential evaluation,
from measured trial, window, and replica costs. Scoring callbacks can therefore
run on several threads without any `move_thread_count` key. Set
`move_thread_count = "none"` to keep a solve strictly sequential. `{"count": 0}`
is a configuration error.

### Constraint provider selection

`score_director.constraint_provider` names the solution's constraint provider
by the `__name__` of the function passed to
`@planning_solution(constraints=...)`. Omitting it selects that provider. An
undeclared name, or any name on a solution without constraints, fails before
solving with `unknown constraint provider`. Hand-built schema dictionaries passed
to `_native.compile_schema` need a `constraint_provider` key (`None` without
constraints).

### Telemetry

Retained run totals gain `problem_changes_applied`, which stays `0` because
the Python manager queues no problem changes. `telemetry_detail(job_id)` adds
`resolved_phase_plan`, the tree of phases, construction stages, and default
local-search selectors the core actually ran; it is `None` until the solve
ends and stays out of ordinary status and event payloads. Selector telemetry
entries drop their six `conflict_repair_*` keys, which the core never filled;
run totals keep theirs.

### Release workflow

The macOS arm64 wheel builds on GitHub's `macos-15` image. GitHub stopped
accepting the `macos-14` arm64 runner configuration, which is why the `0.8.0`
release run published nothing; `0.8.1` carries the same source plus that
workflow change.

## Published Version Boundaries

| Surface | Version | Runtime or compatibility boundary |
| ------- | ------- | --------------------------------- |
| PyPI package | `solverforge 0.8.1` | CPython 3.14; `cp314` wheels for Linux x86_64, macOS arm64, and Windows x64 |
| Python source | `solverforge-py v0.8.1` | Core dependencies exactly `=0.31.2`; UI exactly `=0.9.1` |
| Retired number | `solverforge-py v0.8.0` | Tagged, never published to PyPI |
| Previous Python package | `solverforge 0.7.2` | Core `0.23.0`; 30/60-second cap on solves without a time limit |
| Rust core | `solverforge 0.31.2` | Separate registry release; see the [core release note](/blog/releases/2026/11/17/solverforge-0-31-x/) |
| CLI | `solverforge-cli 4.2.0` | Fresh scaffolds target core `0.31.2`; see the [CLI release note](/blog/releases/2026/11/18/solverforge-cli-4-1-4-2-x/) |
| Rust use-case bundle | November 18 app releases | All nine pin core `0.31.2` and UI `0.9.1`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/#november-18-releases-solverforge-0312) |

The `v0.8.1` source tag points to
`6776c18c76134b40ecc8a459c6d74fe771c49210`. Its exact-commit
[CI](https://github.com/SolverForge/solverforge-py/actions/runs/44814575001)
and [release/PyPI publication](https://github.com/SolverForge/solverforge-py/actions/runs/44814580348)
passed. The repository publishes through PyPI; it has no GitHub Release object
for this tag. These wheels use `cp314`, not the free-threaded `cp314t` ABI;
free-threaded installations need a source build with the matching interpreter.

| Artifact | SHA-256 |
| -------- | ------- |
| `solverforge-0.8.1-cp314-cp314-manylinux_2_17_x86_64.manylinux2014_x86_64.whl` | `44eea1e3f1f5035e128e7d1c1ae9814c53347730b98e54fb49877def76e7f064` |
| `solverforge-0.8.1-cp314-cp314-macosx_11_0_arm64.whl` | `5e6e05d284e1430571e2f50051fb4d71c717327150c66996517cf076005d81bf` |
| `solverforge-0.8.1-cp314-cp314-win_amd64.whl` | `6ad1f1285a01c663f75efb8c864eb3c9239b5eb43a2cf6d12bdd381b95825862` |
| `solverforge-0.8.1.tar.gz` | `7b9c92a1a86dabb94176316161062641c225c0e53af13db353f19ba57074c377` |

The `v0.8.0` tag points to `7c8a5f8a3dbfbbedd7e72e4295b797d8faca7dce`. Its
exact-commit [CI](https://github.com/SolverForge/solverforge-py/actions/runs/44812794516)
passed; its [release run](https://github.com/SolverForge/solverforge-py/actions/runs/44812798819)
was cancelled when GitHub rejected the macOS runner, so the artifact checks and
PyPI publication never ran.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.8.1` | 2026-11-20 | Builds the macOS arm64 wheel on `macos-15`; first published 0.8.x package. |
| `0.8.0` | 2026-11-20 | Retired: tagged, never published. Core `0.31.2`, UI `0.9.1`; no implicit time limit; validated config; named constraint provider; `problem_changes_applied` and `resolved_phase_plan` telemetry. |

## Upgrade Checklist

- Install `solverforge==0.8.1` and use source tag `v0.8.1` for examples and
  development. Package wheels do not contain the repository example apps.
- Give every config that runs local search a termination criterion; a solve
  that relied on the old 30/60-second cap now runs until it is cancelled.
- Replace zero-valued `selected_count_limit`, `max_nearby`, and other count
  fields; remove unknown config keys. The solve now refuses them up front.
- Treat scoring callbacks as concurrent by default, or set
  `move_thread_count = "none"`. Callbacks must already be deterministic and
  free of shared mutation.
- Stop reading `conflict_repair_*` keys from `selector_telemetry` entries.
  Read the resolved phase plan from `telemetry_detail(...)` after the solve
  ends.
- Add `constraint_provider` to hand-built schema dictionaries.
- Re-run model checks at fixed work and seed, then compare time-budgeted
  quality separately. Do not change benchmark tested-version labels without a
  new run.

## Where to read next

- [Python manual](/docs/solverforge-python/)
- [Getting started](/docs/solverforge-python/getting-started/)
- [Config, parallel evaluation, and retained telemetry](/docs/solverforge-python/solving-and-runtime/)
- [Hospital example](/docs/solverforge-python/hospital-example/)
- [Deliveries example](/docs/solverforge-python/deliveries-example/)
- [Previous Python line](/blog/releases/2026/10/27/solverforge-python-0-7-x/)
- [Full tagged comparison](https://github.com/SolverForge/solverforge-py/compare/v0.7.2...v0.8.1)
