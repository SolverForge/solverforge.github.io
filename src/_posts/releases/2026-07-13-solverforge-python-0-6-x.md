---
title: "SolverForge Python 0.6.x: One Compiled Runtime"
date: 2026-07-13
draft: false
description: >
  SolverForge Python 0.6.x moves dynamic Python models onto the SolverForge
  compiled runtime, makes model metadata explicit, adds qualified retained
  candidate diagnostics, and aligns 0.6.2 with SolverForge 0.19.0.
---

**SolverForge Python 0.6.x** started with the
[v0.6.1 source tag](https://github.com/SolverForge/solverforge-py/tree/v0.6.1)
on 2026-07-13. Its current patch is
[v0.6.2](https://github.com/SolverForge/solverforge-py/tree/v0.6.2), published
on 2026-07-17. The current tag plus the GitHub and Forgejo `main` branches point
to the same `0.6.2` source. GitHub CI and the automatic release workflow
completed successfully; the workflow built, verified, and published the source
distribution plus Linux, macOS, and Windows wheels. PyPI now resolves
`solverforge` to `0.6.2`.

The 0.6 line targets CPython 3.14, consumes the published
`solverforge 0.19.0` Rust crates, and embeds `solverforge-ui 0.7.0`. Version
0.6.2 is a compatibility release that moves the exact Rust crate set from
SolverForge 0.18.0 to 0.19.0 without changing the public Python API. The line
replaces the wrapper-owned search path with one compiled SolverForge runtime
and makes the Python-to-Rust contract explicit enough to validate, reuse, and
diagnose.

## What Changed

### Python models now use the core runtime directly

The binding compiles a Python model into the public SolverForge runtime model
and hands construction, local search, candidate ownership, lifecycle control,
and telemetry to the same compiler and executor used by native Rust models.

The 0.6 runtime deletes the wrapper-owned selector and move engine. There is no
parallel Python phase tree, assignment placer, TLS slot state, synthetic
candidate metric, or fallback solver path. Direct solves and retained jobs both
reuse one immutable compiled runtime plan containing the schema, descriptor,
and runtime model; solution rows, callbacks, seeds, and moves remain per solve.

### Model metadata is explicit and scoped

Python declarations now describe the capabilities the compiled runtime may use:

- `@candidate_metric("name")` registers a numeric candidate-ranking callback
  through `@planning_solution(..., candidate_metrics=[...])`.
- `scalar_assignment_group(...)` owns assignment-aware scalar construction and
  grouped local search, with callback or field-backed required, capacity,
  position, and sequence metadata.
- `planning_variable(...)` accepts callback or row-field sources for nearby
  candidates and distances.
- `planning_list_variable(...)` accepts independent `ListRouteHooks` and
  `ListSavingsHooks` bundles plus separate cross-position and intra-position
  distance sources.
- `RowField`, `SolutionField`, `EntityCallback`, and `SolutionCallback` state
  exactly where nested list metadata comes from.
- `CapacityRouteFeasibility` declares independently scoped capacity and demand
  fields without inferring callback meaning from arity.

Route metadata never silently enables savings construction, nearby list
distance is never inferred from route distance, and a missing field or
capability fails during schema import or runtime compilation instead of
becoming an unrestricted fallback.

### Dynamic state and safe scoring plans are compiled

The native extension stores scalar, list, and candidate state by compiled
descriptor index rather than repeated string lookup. Immutable metadata is
shared across clones, while Python callback views project clone-safe entity and
fact rows from the Rust-owned working solution and synchronize only changed
rows after their first full view.

Constraint plans specialize only where the schema proves semantic parity.
Fixed-weight unary constraints, unassigned-list scoring, list precedence
metadata, and proven string-key equality joins can execute natively. Callback
filters, callback weights, computed attributes, unsupported values, and
stateful functions stay on the Python callback path. The runtime does not trade
Python equality or callback behavior for an unsafe shortcut.

`joiner.equal(...)` and `joiner.equal_bi(...)` accept either callbacks or
attribute-name strings. String keys use native equality only for planning
scalar slots and stable imported row fields; other shapes retain live Python
attribute access and equality.

### Candidate policy and retained diagnostics cross the binding

Named candidate metrics can back `sorted` or `probabilistic` leaf selector
order. Metrics receive a read-only callback solution view and the core move's
canonical logical identity; they rank an existing core candidate rather than
rebuilding a second neighborhood in Python.

Candidate tracing is an opt-in retained-job diagnostic:

```python
manager = SolverManager(
    {
        "termination": {"seconds_spent_limit": 10},
        "candidate_trace": {"max_entries": 256},
    }
)
handle = manager.solve(plan)
detail = manager.telemetry_detail(handle.job_id)
trace = detail["candidate_trace"]
```

Ordinary status, event, and snapshot payloads remain compact. The detailed
format-3 trace records canonical config, execution policy, resolved phase-plan
provenance, candidate identities and dispositions, prefix digests,
completeness, and truncation. `Solver.solve(...)` rejects candidate tracing
because it has no retained detail channel.

External qualification can be supplied per managed job with immutable
`QualifiedCandidateTraceProvenance`. Its schema, instance, initial-state, core
tree, and build digests must be lowercase SHA-256 values and its producer must
be non-blank. The manager rejects qualified provenance before schema discovery
unless candidate tracing is enabled; it is never inferred from the Python
solution or accepted through serializable solver config.

### The examples exercise the public 0.6 contracts

The hospital example now starts with 688 unassigned shifts and declares a row
candidate callback that excludes employees without the required skill or with
overlapping unavailability before construction. Row-backed candidate and
distance metadata drive nearby search. Its reproducible seed-1 policy uses
`assign_when_candidate_exists`, max-10 nearby change/swap search, and a
`first_best_score_improving` forager; retained API payloads expose the current
phase and phase-local counters.

The deliveries example now starts every seeded city fixture with unassigned
routes. Each vehicle declares independent row-backed `ListRouteHooks` and
`ListSavingsHooks`, while solution-scoped feasibility remains explicit. The
reproducible seed-42 policy uses list cheapest insertion, `k = 2` construction
polish, a 100-step local-search limit, a 100-entry late-acceptance history, and
accepted-count foraging at four. The configured core phases construct and
improve the routes; the model no longer depends on seeded preassignment or
implicit route callback conventions.

## Install And Publication Status

Install the published package:

```bash
python3.14 -m pip install "solverforge==0.6.2"
```

The 0.6.2 source distribution is limited to package metadata and the Python and
Rust inputs needed to build the binding. Repository tests, examples, guidance,
and tooling remain in the tagged source checkout. The wheel contains the public
Python package, native extension, and embedded shared UI assets rather than the
FastAPI example applications.

Use the tagged source checkout when developing the repository examples or
inspecting the complete source:

```bash
git clone https://github.com/SolverForge/solverforge-py.git
cd solverforge-py
git checkout v0.6.2
make develop
. .venv/bin/activate
python -c 'import solverforge; print(solverforge.__version__)'
```

The command prints `0.6.2`.

Do not infer the Python package version from the Rust crate, CLI, or UI release
line. Their current boundaries are:

| Surface | Current line |
| ------- | ------------ |
| SolverForge Python source | tagged `solverforge-py 0.6.2` |
| Public PyPI package | published `solverforge 0.6.2` |
| Rust runtime base | published `solverforge 0.19.0` |
| Embedded UI base | published `solverforge-ui 0.7.0` |
| CLI scaffold runtime | published `solverforge-cli 2.2.2` still scaffolds `solverforge 0.15.2` |

## Upgrade Checklist

- When upgrading from 0.6.1, update the package pin to 0.6.2 and rebuild the
  native extension; the public Python API is unchanged.
- Check out `v0.6.2` and run model, lifecycle, snapshot, and example tests
  against the compiled 0.19.0 runtime.
- Replace legacy flat list route arguments with `ListRouteHooks` and
  `ListSavingsHooks`, using explicit row, solution, or callback source wrappers.
- Declare assignment-owned scalar variables through
  `scalar_assignment_group(...)` and target them only with their grouped
  construction and grouped local-search path.
- Register selector metrics with `@candidate_metric` and list them in
  `@planning_solution(candidate_metrics=[...])` before referencing them from
  `selection_metric`.
- Use `SolverManager.telemetry_detail(...)` for candidate traces. Do not expect
  traces in ordinary status/events or enable them on synchronous solves.
- Keep callback metadata deterministic and solution lookup context immutable
  for the duration of a solve, especially on free-threaded CPython 3.14.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.6.2` | 2026-07-17 | Aligns the exact SolverForge Rust crate set with 0.19.0 while keeping the 0.6 Python API and embedded `solverforge-ui 0.7.0` assets unchanged. |
| `0.6.1` | 2026-07-13 | Establishes the 0.6 line on SolverForge 0.18.0's compiled runtime, adds explicit model metadata, safe native scoring plans, qualified candidate diagnostics, and refreshed examples, and restricts source archives to the inputs needed to build the package. |

## Documentation Changes

- [SolverForge Python](/docs/solverforge-python/) now records the published
  0.6.2 package, Rust 0.19.0 base, and UI 0.7.0 base.
- [Python Modeling](/docs/solverforge-python/modeling/) documents candidate
  metrics, assignment metadata, scoped list sources, and nested route/savings
  bundles.
- [Python Constraints](/docs/solverforge-python/constraints/) explains the
  native specialization boundary and string-key join behavior.
- [Python Solving & Runtime](/docs/solverforge-python/solving-and-runtime/)
  covers the single compiled runtime, phase telemetry, candidate traces, and
  qualified provenance.
- The [Hospital](/docs/solverforge-python/hospital-example/) and
  [Deliveries](/docs/solverforge-python/deliveries-example/) pages now match the
  tagged 0.6.2 examples.
- [Status & Roadmap](/docs/status-and-roadmap/) keeps tagged source, PyPI,
  runtime, UI, CLI, and worked-use-case release lines separate.
