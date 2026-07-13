---
title: "SolverForge 0.18.x: One Compiled Search Runtime"
date: 2026-07-13
draft: false
description: >
  SolverForge 0.18.x compiles native and dynamic models into one immutable
  search graph, adds resolved selector policy and qualified candidate traces,
  and hardens retained lifecycle control.
---

**SolverForge 0.18.x** started with
[v0.18.0](https://github.com/SolverForge/solverforge/releases/tag/v0.18.0)
on 2026-07-13. The current core patch is
[v0.18.0](https://crates.io/crates/solverforge/0.18.0). GitHub CI, the GitHub
Release workflow, and the coordinated crates.io publish completed successfully.
The 0.18 line keeps the Rust `1.95` floor and publishes the workspace crates on
one version line.

This release makes one architectural promise concrete: native Rust models,
dynamic host-language models, explicit phase configs, and omitted-config
defaults all enter the same validated compiler and executor. There is no second
descriptor phase builder or binding-only fallback that can drift from the main
runtime.

The runtime release remains separate from scaffold and binding publication.
The published `solverforge-cli 2.2.2` package still scaffolds
`solverforge 0.15.2`. The tagged `solverforge-py 0.5.0` source line remains
backed by `solverforge 0.17.2`, while PyPI latest remains `solverforge 0.4.0`.
Those targets do not change merely because the Rust core published 0.18.0.

## What Changed

### One immutable runtime graph

SolverForge now resolves a value-owned `RuntimeModel` into one immutable graph
before solving. The compiler validates and freezes:

- construction stages and obligations
- recursive local-search and VND selector trees
- scalar, list, grouped-scalar, and dynamic slot bindings
- native and host compound-provider handles
- stable list element-source identities
- candidate metrics, selector order, union weighting, and score tie policy
- configured and model-aware default phases

Macro-generated `Solvable` implementations and the dynamic bridge both use this
path. A failure is reported as a declaration, compilation, phase preparation,
or phase execution error with a specific path; private graph types and an
alternate fallback runner are not exposed.

### Cursor-owned candidates and stable source identity

Shared scalar and list kernels now expose stable candidate IDs. Foragers can
stop without draining the rest of a neighborhood, losing candidates are
released promptly, and the selected move transfers by value exactly once.
Generated telemetry therefore counts candidates actually yielded to the engine,
not a logical tail the engine never requested.

Specialized list construction also binds elements by an explicit stable source
key. `ListConstructionPhaseBuilder`, `ListCheapestInsertionPhase`,
`ListRegretInsertionPhase`, and `ListClarkeWrightPhase` lower-level callers must
map declared elements, current assignments, and precedence successors to the
same unique `usize` identity. Generated `usize` list models supply that key.
Duplicate, missing, or inconsistent identities fail before candidate work;
SolverForge does not recover identity through payload equality or hashing.

### Selector policy is explicit data

Every non-composite leaf can select `original`, seeded `random`, `shuffled`,
`sorted`, or `probabilistic` order. Sorted and probabilistic order require a
registered named candidate metric. Local search also owns a seeded score
tie-break policy, while union selectors now separate scheduling order from
child weighting:

```toml
[[phases]]
type = "local_search"
score_tie_break = "random"

[phases.move_selector]
type = "union_move_selector"
selection_order = "stratified_random"
weighting = "fixed"
weights = [3, 1]

[[phases.move_selector.selectors]]
type = "change_move_selector"
selection_order = "random"

[[phases.move_selector.selectors]]
type = "swap_move_selector"
selection_order = "random"
```

Union order can be sequential, round-robin, rotating round-robin, random, or
stratified random. Weighting can be equal, fixed, or derived from declared
candidate counts. Omitted stock local search uses seeded random leaves, a
stratified-random union for multiple families, and sequential union order for a
single family.

The omitted selector profile is capability-matched. List slots receive
precedence/permutation, nearby or plain change/swap, sublist, reverse, k-opt,
and ruin families only where their declared operations allow them. Nearby
scalar leaves precede plain scalar fallbacks. Assignment-owned scalar slots
remain on their grouped path, and registered repair providers add compound
conflict-repair leaves.

### Candidate traces carry execution provenance

Candidate tracing is opt-in and bounded:

```toml
[candidate_trace]
max_entries = 4096
```

The trace header owns canonical config, execution policy, resolved phase plan,
and optional externally attested input and qualification provenance. Each
retained pull records source, phase/step coordinates, optional selector and
construction target, logical operation identity, and ordered dispositions such
as interrupted, evaluated, rejected, selected, and applied. Truncation,
unencoded identity, and incomplete provenance stay explicit.

Large trace detail is not cloned into routine lifecycle events, status, or
snapshots. `SolverManager::get_telemetry_detail(...)` returns candidate detail
atomically with the aggregate status, scores, and snapshot revision from the
same publication instant. Benchmark and bridge callers can provide externally
validated provenance through
`solve_with_qualified_candidate_trace_provenance(...)`; that changes only the
diagnostic header, not the runner.

### Dynamic models declare their capabilities

The bridge surface now includes explicit contracts for dynamic scalar
assignment metadata, list mutation capabilities, and immutable list metadata
bundles. A dynamic list declares whether it supports set, whole-row replace,
reverse, and sublist operations, plus any owner, construction-order,
precedence, distance, route, or savings metadata it actually implements.

Missing capabilities are validation boundaries, not permission for the runtime
to synthesize an operation from weaker mutations. Dynamic nearby scalar sources
are lazy and receive a consumption limit; scalar legality and descriptor
resolution are checked before the compiled cursor uses the slot. Host compound
providers and candidate metrics are frozen in solve-owned registries instead of
being discovered from mutable schema, global maps, or thread-local state during
candidate execution.

### Lifecycle control settles at every boundary

Pause and cancel requests are polled inside long-running candidate work and
again around phase and terminal hooks. A pending command cannot be overwritten
by ordinary default completion. Paused jobs preserve resumable runtime state,
paused time is excluded from active phase elapsed telemetry, and long phases
emit metadata-only pulses with phase-local counters.

Retained telemetry now includes the active `PhaseTelemetry` snapshot and richer
move-level improvement counters in addition to selector, construction,
conflict-repair, and applied-move data.

### Release qualification has a controlled performance gate

Portable pre-release checks remain portable. Hot-path regression qualification
now has a separate pinned-CPU Linux gate that alternates independently linked
baseline/candidate trials and checks enumeration order, work, wall time,
allocations, peak memory, and available hardware counters. An unavailable or
noisy measurement is not silently treated as proof of zero regression.

## Install And Version Boundaries

For a direct Cargo project:

```toml
[dependencies]
solverforge = { version = "0.18.0", features = ["serde", "console"] }
```

The companion workspace crates are published on the same line:

```toml
solverforge-core = "0.18.0"
solverforge-scoring = "0.18.0"
solverforge-solver = "0.18.0"
solverforge-bridge = "0.18.0"
solverforge-cvrp = "0.18.0"
solverforge-console = "0.18.0"
solverforge-config = "0.18.0"
solverforge-macros = "0.18.0"
```

For a generated app, inspect the installed CLI before changing its manifest:

```bash
solverforge --version
```

The current published CLI reports `2.2.2` and scaffolds
`solverforge 0.15.2`, `solverforge-ui 0.6.5`, and
`solverforge-maps 2.1.4`. Upgrade a generated app to 0.18.0 deliberately and
run its model, config, and lifecycle tests; do not infer the runtime target from
the CLI package version.

## Upgrade Checklist

- Normal facade-based models should bump the Cargo dependency, rebuild, and run
  their solve and snapshot tests against the compiled runtime.
- Lower-level specialized list-construction callers must provide the stable
  `element_source_key` required by the 0.18.0 constructors.
- Direct Rust literals for leaf selector configs must account for
  `selection_order` and `selection_metric`; union literals must account for
  weighting and weights; local-search literals must account for
  `score_tie_break`.
- Dynamic binding layers should declare scalar/list capabilities and propagate
  `RuntimeBuildResult` errors instead of installing a binding-specific phase
  builder.
- Enable `[candidate_trace]` only when the diagnostic prefix is needed, and
  fetch it through `get_telemetry_detail(...)` rather than expecting it in
  ordinary events.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.18.0` | 2026-07-13 | Establishes the immutable compiled runtime graph, cursor-owned candidates, resolved selector policy, qualified candidate traces, explicit dynamic capabilities, and hardened lifecycle control. |

## Documentation Changes

- [SolverForge runtime docs](/docs/solverforge/) now describe the published
  0.18.0 line and the single compiled lifecycle.
- [Architecture](/docs/architecture/) maps the immutable runtime graph and its
  intentional dynamic-dispatch seams.
- [Configuration](/docs/solverforge/solver/configuration/) covers leaf order,
  candidate metrics, union weighting, score ties, and candidate tracing.
- [Construction](/docs/solverforge/solver/construction/) documents live placer
  cursors and stable list-source identity.
- [Local Search](/docs/solverforge/solver/local-search/) and
  [Composite Selectors](/docs/solverforge/solver/composite-move-selectors/)
  describe cursor ownership and the resolved default policy.
- [SolverManager](/docs/solverforge/solver/solver-manager/) documents phase
  telemetry, trace detail retrieval, and phase-boundary lifecycle settlement.
- [Status & Roadmap](/docs/status-and-roadmap/) keeps the core, CLI scaffold,
  Python, UI, maps, and worked-example release lines separate.
