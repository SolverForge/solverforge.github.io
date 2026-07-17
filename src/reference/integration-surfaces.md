---
title: "Integration Boundaries"
description: "A compact map of where runtime, scaffolding, UI, and map-backed planning responsibilities belong."
---

# Integration Boundaries

SolverForge works best when each responsibility is owned by the right crate,
tool, or application module. This keeps solver truth in the runtime, product
behavior in your app, and optional helpers limited to the problems they solve.

## Boundary map

| Component | Owns | Should not own |
|---|---|---|
| `solverforge` runtime | domain modeling, constraints, compiled search policy, solving, retained lifecycle | project scaffolding, web components, routing datasets |
| `solverforge-bridge` | dynamic binding contracts, logical model IDs, explicit scalar/list capabilities, dynamic score and slot surfaces | Python UX, scaffold templates, a second solver path |
| `solverforge-cli` | app bootstrap and code generation | runtime truth, UI state, solver lifecycle semantics |
| `solverforge-py` | Python decorators, explicit model metadata, callback binding, compiled-runtime adapters, retained diagnostics, Python package distribution, embedded UI asset access | a second selector/move engine, Rust crate docs, scaffold generation, generic web UI design, route data ownership |
| `solverforge-ui` | retained-job UI controls and frontend components | solver search logic, scoring rules, route-cost computation |
| `solverforge-maps` | routing, map tiles, matrices, and road-network helpers | generic solver lifecycle, scaffold generation |
| your app | business rules, imports, APIs, persistence, product behavior | generic runtime internals that belong upstream |

## Good integration patterns

### CLI first

Use `solverforge-cli` to bootstrap the project, then move quickly into ordinary
application modules and `solverforge` runtime code.

### Runtime truth

Treat retained lifecycle state as runtime-owned. UI and HTTP layers should read
it, not infer it.

Native and dynamic models both enter the same validated runtime compiler. A
binding declares slot access, list metadata, assignment metadata, providers,
and optional candidate metrics; the core freezes those capabilities into one
search graph before candidate work starts. Binding layers should surface a
declaration, compilation, preparation, or execution error rather than install a
parallel phase builder or fallback runner.

### Python as a binding

Use `solverforge-py` when the product needs Python model authoring. Python
classes, decorators, explicit scalar/list metadata, and callbacks describe the
problem; Rust still owns the indexed working state, compiled search graph,
cursor execution, safe native score specializations, snapshots, retained jobs,
candidate traces, and embedded shared UI asset bytes.

### UI as presentation and orchestration

`solverforge-ui` is best when the product needs a browser-facing retained-job
experience. It should consume authoritative lifecycle state and snapshots rather
than rebuilding solver semantics locally.

### Maps as a supporting subsystem

`solverforge-maps` belongs in projects where route cost, geometry, or road
network structure are real business inputs, not as a default dependency.

## Common architecture shapes

| Product shape | Typical composition |
|---|---|
| backend planner service | `solverforge-cli` scaffold + `solverforge` |
| Python planner service or notebook-backed prototype | PyPI `solverforge` package or the `solverforge-py v0.6.2` source tag |
| browser-based planning app | `solverforge-cli` + `solverforge` + `solverforge-ui` |
| fleet or dispatch optimizer | `solverforge-cli` + `solverforge` + `solverforge-maps` |
| custom research harness | direct `solverforge` plus selected lower-level crates |

## Decision checklist

- Does this change affect solver truth or only product presentation?
- Does it belong in app code, or is it generic enough for SolverForge itself?
- Are you reaching for a companion repo because you need it, or because it
  happens to exist?
- Would a tutorial or reference note help future users avoid the same mistake?

## See also

- [Crate & Runtime Map](/reference/crate-map/)
- [Extend the Solver](/reference/extend-solver/)
- [Docs: SolverForge Python](/docs/solverforge-python/)
- [Docs: solverforge-ui](/docs/solverforge-ui/)
- [Docs: solverforge-maps](/docs/solverforge-maps/)
