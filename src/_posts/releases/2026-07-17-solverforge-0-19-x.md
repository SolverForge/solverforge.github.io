---
title: "SolverForge 0.19.x: One Sequence Model"
date: 2026-07-17
draft: false
description: >
  SolverForge 0.19.x makes planning list variables the sole model for routes
  and ordered assignments, keeps the full list-shadow system, and leaves
  ordinary scalar search on direct single-slot mutation.
---

**SolverForge 0.19.x** starts with
[v0.19.0](https://github.com/SolverForge/solverforge/releases/tag/v0.19.0)
on 2026-07-17. The current core release is
[0.19.0](https://crates.io/crates/solverforge/0.19.0). The workspace keeps its
Rust `1.95` floor and publishes all nine crates on the same version line.

> **Update, 2026-07-17:** SolverForge Python 0.6.2 is now published with the
> exact SolverForge 0.19.0 crate set. The version table below preserves the
> package boundaries when the core release completed.

This is a deliberately narrow breaking release: SolverForge now has one
representation for a planning-owned ordered sequence. A planning list variable
owns assignment and order directly. Ordinary scalar variables continue to
model one independently chosen value. The predecessor-based chained-variable
surface has been removed instead of maintaining a second route topology beside
the list runtime.

No released SolverForge use case, Python model, or benchmark workload depended
on chained variables. Those independently released surfaces therefore did not
need a domain-model rewrite. At the time of the core release, they remained on
their published 0.18-based lines until their own releases moved. The published
CLI remains 2.2.2 and still scaffolds SolverForge 0.15.2; generated apps can
upgrade their runtime manifest to 0.19.0 deliberately.

## Why One Sequence Model

A predecessor field appears compact, but it does not make a route mutation a
scalar mutation. Changing one predecessor can displace a suffix, create a
second successor, form a cycle, or invalidate anchor-derived state. Preserving
those invariants requires topology-aware construction, selectors, providers,
undo, descriptor access, dynamic bindings, group resolution, and shadow
maintenance as one atomic subsystem.

SolverForge already has that subsystem for list variables. The list owner is
the canonical sequence, and every move family operates on explicit owner and
position coordinates. Bounds, ownership, ordering, exact undo, and shadow
refresh therefore share one representation instead of being reconstructed from
scalar predecessor links in each generic path.

Keeping both models would duplicate the hardest runtime contracts while making
their behavior diverge. SolverForge 0.19 removes that ambiguity:

- use a scalar variable when an entity independently chooses one value
- use a list variable when planning chooses membership, ownership, or order
- derive lookup-oriented views with shadows instead of storing a second
  topology

## List Variables Keep Their Shadows

The sequence architecture was simplified; the shadow-variable architecture was
not removed. List models continue to support:

- inverse-relation shadows for element-to-owner lookup
- index shadows for element position
- previous-element and next-element shadows
- custom and cascading shadows
- piggyback shadows
- retained list-state supplies used by list construction and local search

Only the chain-specific anchor shadow and `AnchorSupply` have gone away. Those
types existed to recover an anchor from a predecessor graph; a list owner
already provides the canonical ownership relation.

## Ordinary Scalar Search Stays Direct

Scalar construction, change, and swap paths remain single-slot operations.
This release does not add a cursor-owned topology cache or a generic atomic
batch layer to compensate for chained semantics. Compound scalar moves remain
available where a declared grouped assignment or conflict-repair provider
actually needs multiple edits, but ordinary scalar search does not pay that
cost.

Keeping the proposed chained runtime out of 0.19 also avoids the repeated
whole-topology scans its candidate legality and successor discovery required.
Route-sized sequence work stays in the list cursors, where membership and
position are native coordinates rather than repeatedly reconstructed graph
state.

## Removed APIs

The following chained-only APIs are no longer part of the 0.19 line:

- `#[planning_variable(chained = true)]`
- `VariableType::Chained` and `VariableType::is_chained()`
- `ChainedVariableInfo`
- `VariableDescriptor::chained(...)`
- `ShadowVariableKind::Anchor`
- `AnchorSupply`
- `#[anchor_shadow_variable]`

The macro test suite includes a compile-fail contract for the removed
`chained` argument, so stale model syntax fails at the declaration instead of
silently lowering to an ordinary scalar variable.

## Modeling Ordered Work

A route or ordered assignment now has one owner-side field:

```rust
// sf-rust: fragment profile="solverforge-current" fixture="modeling"
#[planning_entity]
pub struct Route {
    #[planning_id]
    pub id: usize,

    #[planning_list_variable(element_collection = "visits")]
    pub visit_order: Vec<usize>,
}
```

List construction assigns unassigned elements to owners. List change, swap,
sublist, reverse, k-opt, ruin/recreate, nearby, precedence, and CVRP-specific
selectors then operate on the same sequence representation. Configure only the
shadows that constraints or application code actually need.

The published SolverForge CLI 2.2.2 already exposes the same scalar/list
modeling boundary, even though its fresh-project runtime target remains 0.15.2:

```bash
solverforge generate variable visit_order \
  --entity Route \
  --kind list \
  --elements visits
```

## Published Version Boundaries

The independently published package versions at the time of the 0.19.0 core
release are:

| Surface | Version | Runtime target |
| ------- | ------- | -------------- |
| Rust workspace | `solverforge 0.19.0` | `0.19.0` |
| CLI | `solverforge-cli 2.2.2` | scaffolds `solverforge 0.15.2` |
| Python | `solverforge 0.6.1` | exact SolverForge `0.18.0` crate set |
| Hospital | `solverforge-hospital@2.0.4` | `solverforge 0.18.0` |
| Lessons | `solverforge-lessons@2.0.4` | `solverforge 0.18.0` |
| Deliveries | `solverforge-deliveries@2.0.4` | `solverforge 0.18.0` |
| FSR | `solverforge-fsr@2.0.5` | `solverforge 0.18.0` |

## Install And Version Boundaries

For direct Rust applications:

```toml
[dependencies]
solverforge = { version = "0.19.0", features = ["serde", "console"] }
```

The companion workspace crates are all published at `0.19.0`:

```toml
solverforge-core = "0.19.0"
solverforge-macros = "0.19.0"
solverforge-scoring = "0.19.0"
solverforge-config = "0.19.0"
solverforge-solver = "0.19.0"
solverforge-bridge = "0.19.0"
solverforge-cvrp = "0.19.0"
solverforge-console = "0.19.0"
```

When the core release completed, the Python package was still on the previous
core line:

```bash
python3.14 -m pip install "solverforge==0.6.1"
```

That package embeds the exact SolverForge 0.18.0 crate set; publishing the Rust
0.19.0 workspace does not silently change an existing Python wheel.

SolverForge Python 0.6.2 was published later on 2026-07-17 and is now the
current package:

```bash
python3.14 -m pip install "solverforge==0.6.2"
```

Version 0.6.2 embeds the exact SolverForge 0.19.0 crate set without changing
the public Python API.

## Upgrade Checklist

- Bump SolverForge dependencies to `0.19.0` and regenerate `Cargo.lock` from
  the registry.
- Replace predecessor-chain entities with an owner-side planning list variable.
- Replace anchor lookup with the list owner or an inverse-relation shadow.
- Keep index, previous, next, custom, cascading, and piggyback shadows that are
  still consumed by constraints or application code.
- Remove chained-only model attributes; do not translate them into ordinary
  scalar variables.
- Run construction and local-search tests that exercise assignment, ordering,
  shadow refresh, and exact undo on the resulting list model.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.19.0` | 2026-07-17 | Makes list variables the sole sequence model, removes chained-only metadata and anchor shadows, preserves list-derived shadows, and keeps ordinary scalar paths on direct mutation. |

## Documentation Changes

- [SolverForge runtime docs](/docs/solverforge/) describe the scalar/list
  boundary and current 0.19.0 runtime.
- [CLI command reference](/docs/solverforge-cli/command-reference/) records the
  published 2.2.2 scaffold targets separately from the 0.19.0 core.
- [Crate & Runtime Map](/reference/crate-map/) aligns Rust, CLI, Python, and
  companion repositories on the new release line.
- [Status & Roadmap](/docs/status-and-roadmap/) tracks each independently
  published package and use-case version.
