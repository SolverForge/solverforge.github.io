---
title: "solverforge-py 0.6.x: The Python Binding Runtime Bases"
date: 2026-09-29
draft: false
description: >
  solverforge-py 0.6.7 through 0.6.14 move the Python binding onto published
  SolverForge Rust runtimes — 0.19.7 through 0.6.10, then 0.21.0 through 0.6.13
  and 0.21.3 — keeping the 0.6 Python authoring surface unchanged.
---

**solverforge-py 0.6.14** is tagged on GitHub and published to PyPI
(2026-10-14), so `python3.14 -m pip install "solverforge==0.6.14"` installs the
current binding. The previous published package, `solverforge 0.6.6`, compiled
onto the `solverforge 0.19.4` runtime with `solverforge-ui 0.7.0` assets.

The package targets CPython 3.14 and Rust `1.95.0`, and its six SolverForge
Rust dependencies are pinned to exact crates.io requirements in `Cargo.toml`
and registry checksums in `Cargo.lock`: `0.21.3` with `solverforge-ui 0.9.0`
on `0.6.14`, `0.21.2` through `0.6.12`, and `0.19.7` through `0.6.10`. There
is no local path or Git dependency override.

## What Changed

### The binding moves to the 0.19.7 runtime line

`0.6.7` picks up the SolverForge 0.19.7 construction and telemetry behavior for
Python-authored models, and `0.6.8` completes the move onto that runtime line.
Python models author constraints through callbacks and never write Rust, so the
change is in the runtime the callbacks are compiled against rather than in the
authoring surface.

### Embedded UI assets move to solverforge-ui 0.9.0

`0.6.9` and `0.6.10` align the exact SolverForge Rust crate set with `0.19.7`
and embed the `solverforge-ui 0.9.0` assets, so the FastAPI example apps serve
the same browser shell the Rust use cases ship. The assets stay reachable
through `solverforge.ui.asset()` and `solverforge.ui.asset_paths()`.

### The binding retargets to runtime 0.21.2 and 0.21.3

`0.6.11` moves the six pinned SolverForge Rust dependencies to the published
`0.21.0` registry base, `0.6.12` moves them to `0.21.2`, and `0.6.13`/`0.6.14`
move them to `0.21.3`. Python-authored models gain the joined-tuple grouping,
live-solution lending, owned search state, selector-subgraph fixes, and the
net-route-delta precedence scoring of the 0.21 line through callbacks without
any Python surface change.

### Direct dispatch for list-precedence constraints (0.6.14)

`list_precedence_makespan` compiles to its own plan variant and is scored
directly, so full evaluation and insert/retract deltas no longer decode the
generic plan dictionary or build cached Python rows. Per-plan dispatch keeps
mixed constraint sets correct: plans that need Python fall back individually,
and original plan indices preserve the existing caches. The parsed plan is
cached once per constraint instead of per delta, the makespan achiever count is
tracked instead of scanned per node, and route, diff, and probe scratch storage
is reused across trials. `0.6.13` resolves assignment metadata fields once at
import instead of string-keyed lookups in the construction path.

### The Python surface is unchanged

`0.6.7` through `0.6.10` keep the 0.6 Python API: Python classes, decorators,
functions, and lambdas, with the native extension owning the working solution
state so SolverForge can clone, mutate, and snapshot solutions safely. Callback
constraints remain the single authoring surface.

## Published Version Boundaries

| Surface | Version | Runtime base |
| ------- | ------- | ------------ |
| Documented source line | `solverforge-py 0.6.14` | `solverforge 0.21.3`, `solverforge-ui 0.9.0` |
| PyPI package | `solverforge 0.6.14` | `solverforge 0.21.3`, `solverforge-ui 0.9.0` |
| Previous package | `solverforge 0.6.12` | `solverforge 0.21.2`, `solverforge-ui 0.9.0` |

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.6.14` | 2026-10-14 | Current published package; direct list-precedence dispatch on the `solverforge 0.21.3` registry base. |
| `0.6.13` | 2026-10-14 | Resolves assignment metadata fields once at import; `solverforge 0.21.3` registry base. |
| `0.6.12` | 2026-10-14 | Published package on the `solverforge 0.21.2` registry base. |
| `0.6.11` | 2026-10-14 | Pins the six SolverForge Rust dependencies to the published `0.21.0` registry base. |
| `0.6.10` | 2026-09-29 | Published package on the `solverforge 0.19.7` base with `solverforge-ui 0.9.0` assets. |
| `0.6.9` | 2026-09-29 | Aligns the exact SolverForge Rust crate set with 0.19.7 and embeds the `solverforge-ui 0.9.0` assets. |
| `0.6.8` | 2026-09-29 | Moves the binding onto the SolverForge 0.19.7 runtime line. |
| `0.6.7` | 2026-09-29 | Picks up the 0.19.7 construction and telemetry behavior for Python-authored models. |
| `0.6.6` | 2026-08-11 | Aligns the exact SolverForge Rust crate set with 0.19.4, enforces imported row candidate sets across every native scalar mutation, and adds `same_value_conflict_field` for static assignment conflict graphs. |

## Upgrade Checklist

- Install the matching package after its Python release:
  `python3.14 -m pip install "solverforge==0.6.14"`.
- Use the `v0.6.14` tag for source-checkout work; the source line and the PyPI
  package share the version.
- The 0.6 Python API is unchanged, so models authored for `0.6.6` do not need
  editing to run on `0.6.14`. Re-run the model's tests against the new runtime
  base, since constraint and telemetry behavior comes from `0.21.3`.

## Where to read next

Use the [SolverForge Python](/docs/solverforge-python/) section for the current
binding surface, the
[getting started guide](/docs/solverforge-python/getting-started/) for the
install and run path, and the
[hospital](/docs/solverforge-python/hospital-example/) and
[deliveries](/docs/solverforge-python/deliveries-example/) examples for complete
FastAPI apps.
