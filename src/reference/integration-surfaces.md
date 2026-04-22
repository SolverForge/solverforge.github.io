---
title: "Integration Surfaces"
description: "A compact map of where runtime, scaffolding, UI, and map-backed planning responsibilities belong."
---

# Integration Surfaces

SolverForge is not one binary blob. The value is in knowing which layer should
own which concern.

## Boundary map

| Surface | Owns | Should not own |
|---|---|---|
| `solverforge` runtime | domain modeling, constraints, solving, retained lifecycle | project scaffolding, web components, routing datasets |
| `solverforge-cli` | app bootstrap and code generation | runtime truth, UI state, solver lifecycle semantics |
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
| browser-based planning app | `solverforge-cli` + `solverforge` + `solverforge-ui` |
| fleet or dispatch optimizer | `solverforge-cli` + `solverforge` + `solverforge-maps` |
| custom research harness | direct `solverforge` plus selected lower-level crates |

## Decision checklist

- Does this change affect solver truth or only product presentation?
- Does it belong in app code, or is it generic enough for SolverForge itself?
- Are you reaching for a companion repo because you need it, or because it
  happens to exist?
- Would a tutorial page or a compact reference page help future users more?

## See also

- [Crate & Runtime Map](/reference/crate-map/)
- [Extend the Solver](/reference/extend-solver/)
- [Docs: solverforge-ui](/docs/solverforge-ui/)
- [Docs: solverforge-maps](/docs/solverforge-maps/)
