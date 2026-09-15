---
title: "SolverForge 0.19.x: One Sequence Model"
date: 2026-07-17
draft: false
description: >
  SolverForge 0.19.x makes planning list variables the sole model for routes
  and ordered assignments, keeps the full list-shadow system, and leaves
  ordinary scalar search on direct single-slot mutation. Patch releases through
  0.19.4 tighten mandatory construction, control, telemetry, and assignment
  batching.
---

**SolverForge 0.19.x** starts with
[v0.19.0](https://github.com/SolverForge/solverforge/releases/tag/v0.19.0)
on 2026-07-17. The current core release is
[0.19.4](https://crates.io/crates/solverforge/0.19.4), published on 2026-08-11.
The workspace keeps its Rust `1.95` floor and publishes all nine crates on the
same version line.

> **Update, 2026-08-11:** SolverForge 0.19.4 commits the dense hard-first
> required-assignment batch from independent direct assignments, then leaves
> bounded augmenting rematches to a following cursor that can retain their
> multi-entity edits. Generic and specialized construction share the same
> engine-owned lifecycle and progress telemetry, including prompt first work
> and roughly one-second verbose progress during long phases.

> **Update, 2026-07-29:** SolverForge 0.19.3 restores shared assignment
> rotation. The independently released CLI 2.2.3 and Hospital, Lessons,
> Deliveries, and FSR 2.0.x patches target this 0.19.3 registry line.

> **Update, 2026-07-19:** SolverForge 0.19.2 unifies generic and specialized
> construction lifecycle handling, keeps buffered route telemetry atomic,
> publishes first and periodic phase progress, polls expensive construction
> work by control deadline, and preserves mandatory-completion semantics.

> **Update, 2026-07-18:** SolverForge 0.19.1 keeps configured solver and phase
> limits binding during mandatory construction. Best-solution publication now
> waits for structural completion; reaching a limit first fails instead of
> returning an incomplete plan. A pre-completion pause remains resumable
> in-process without exposing a partial solution snapshot.

> **Python update, 2026-07-18:** SolverForge Python 0.6.3 is published with the
> exact SolverForge 0.19.1 crate set and the same mandatory-completion boundary.
> PyPI provides its source distribution plus Linux, macOS, and Windows CPython
> 3.14 wheels.

> **Update, 2026-07-17:** SolverForge Python 0.6.2, Hospital 2.0.5,
> Lessons 2.0.5, Deliveries 2.0.5, and FSR 2.0.6 are now published with the
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
their published 0.18-based lines until their own releases moved. The current
published CLI is 2.2.3 and scaffolds SolverForge 0.19.3. Existing generated
applications still own their dependency manifests and should move to 0.19.4
only after app-level validation.

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

The published SolverForge CLI 2.2.3 exposes the same scalar/list modeling
boundary and scaffolds the SolverForge 0.19.3 runtime:

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
solverforge = { version = "0.19.4", features = ["serde", "console"] }
```

The companion workspace crates are all published at `0.19.4`:

```toml
solverforge-core = "0.19.4"
solverforge-macros = "0.19.4"
solverforge-scoring = "0.19.4"
solverforge-config = "0.19.4"
solverforge-solver = "0.19.4"
solverforge-bridge = "0.19.4"
solverforge-cvrp = "0.19.4"
solverforge-console = "0.19.4"
```

When the core release completed, the Python package was still on the previous
core line:

```bash
python3.14 -m pip install "solverforge==0.6.1"
```

That package embeds the exact SolverForge 0.18.0 crate set; publishing the Rust
0.19.0 workspace does not silently change an existing Python wheel.

SolverForge Python 0.6.2 was published later on 2026-07-17:

```bash
python3.14 -m pip install "solverforge==0.6.2"
```

Version 0.6.2 embeds the exact SolverForge 0.19.0 crate set without changing
the public Python API. SolverForge Python 0.6.3 followed on 2026-07-18:

```bash
python3.14 -m pip install "solverforge==0.6.3"
```

Version 0.6.3 embeds the exact SolverForge 0.19.1 crate set. Configured limits
remain binding during mandatory construction; reaching one first raises from a
direct solve or fails a retained job without publishing an incomplete snapshot.

Python 0.6.4 and 0.6.5 then consumed the 0.19.2 construction repair and 0.19.3
assignment-rotation repair. The current Python package is 0.6.6:

```bash
python3.14 -m pip install "solverforge==0.6.6"
```

Version 0.6.6 embeds the exact SolverForge 0.19.4 crate set, treats each row's
imported scalar candidate set as a hard native domain, and adds
`same_value_conflict_field` for callback-free static assignment conflict graphs.

The worked use cases were first republished on the SolverForge 0.19.3 line:

- `solverforge-hospital@2.0.6`
- `solverforge-lessons@2.0.6`
- `solverforge-deliveries@2.0.6`
- `solverforge-fsr@2.0.7`

All four target `solverforge 0.19.3` and retain `solverforge-ui 0.6.5`.
Deliveries and FSR also retain `solverforge-maps 2.1.4`. These patches align
dependency and release metadata without changing the application behavior,
datasets, or solver policies.

> **Update, 2026-09-13:** The use-case bundle was republished on the SolverForge
> 0.19.4 line: `solverforge-hospital@2.0.7`, `solverforge-lessons@2.0.7`,
> `solverforge-deliveries@2.0.7`, and `solverforge-fsr@2.0.8`. All four target
> `solverforge 0.19.4` and retain `solverforge-ui 0.6.5`; deliveries and FSR
> retain `solverforge-maps 2.1.4`. Bundle CI and the tag-triggered Space sync
> workflows passed.
>
> **Update, 2026-09-15:** `solverforge-ui 0.8.0` is published; the published
> `solverforge-cli 2.2.3` package still scaffolds the `solverforge-ui 0.7.0`
> line.

## Upgrade Checklist

- Bump SolverForge dependencies to `0.19.4` and regenerate `Cargo.lock` from
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
| `0.19.4` | 2026-08-11 | Commits direct required assignments in the dense hard-first batch, defers augmenting rematches to a retaining cursor, and exposes the unified construction progress contract. |
| `0.19.3` | 2026-07-29 | Restores shared assignment rotation. |
| `0.19.2` | 2026-07-19 | Repairs required construction completion and interruption, unifies construction lifecycle and progress, preserves committed scores, and commits route telemetry atomically. |
| `0.19.1` | 2026-07-18 | Keeps configured limits binding during mandatory construction, gates best-solution and snapshot publication on structural completion, and fails rather than returning an incomplete plan. |
| `0.19.0` | 2026-07-17 | Makes list variables the sole sequence model, removes chained-only metadata and anchor shadows, preserves list-derived shadows, and keeps ordinary scalar paths on direct mutation. |

## Documentation Changes

- [SolverForge runtime docs](/docs/solverforge/) describe the scalar/list
  boundary and current 0.19.4 runtime.
- [CLI command reference](/docs/solverforge-cli/command-reference/) records the
  published 2.2.3 scaffold targets separately from the 0.19.4 core.
- [Crate & Runtime Map](/reference/crate-map/) aligns Rust, CLI, Python, and
  companion repositories on the new release line.
- [SolverForge Python](/docs/solverforge-python/) records the published 0.6.6
  package and its exact SolverForge 0.19.4 runtime base.
- [Status & Roadmap](/docs/status-and-roadmap/) tracks each independently
  published package and use-case version.
