---
title: "SolverForge 0.19.x: One Sequence Model"
date: 2026-07-17
draft: false
description: >
  SolverForge 0.19.x makes planning list variables the sole model for routes
  and ordered assignments, keeps the full list-shadow system, and leaves
  ordinary scalar search on direct single-slot mutation. Patch releases through
  0.19.5 tighten mandatory construction, control, telemetry, cancellation, and
  assignment batching.
---

**SolverForge 0.19.x** starts with
[v0.19.0](https://github.com/SolverForge/solverforge/releases/tag/v0.19.0)
on 2026-07-17. At the September 15 update, the core release was
[0.19.5](https://crates.io/crates/solverforge/0.19.5), published on 2026-09-15.
The workspace keeps its Rust `1.95` floor and publishes all nine crates on the
same version line.

<%= render Ui::Callout.new(title: "Update, October 27, 2026") do %>
This is a historical release note. `solverforge 0.23.0` is the current core
release; its line note is the [0.23.x release note](/blog/releases/2026/10/27/solverforge-0-23-x/).
For the 0.19.x line the 0.19 existence-engine rewrite (per-key occurrence counts
answering semi/anti joins from retained keys, after the buffered Clarke-Wright
interruption and in-place relationship bookkeeping of `0.19.11` and `0.19.12`)
is documented in the [0.19.x line note](/blog/releases/2026/07/17/solverforge-0-19-x/).
The `solverforge-cli 3.7.1` line scaffolds core `0.23.0` (3.6.0 targeted
`0.22.0`; 3.4.0 targeted
`0.20.4`, 3.5.0 targeted `0.21.0`, 3.5.1 targeted `0.21.2`, and 3.5.2 targeted
`0.21.3`); Python 0.7.0 targets core 0.23.0 (see the
[Python line note](/blog/releases/2026/10/27/solverforge-python-0-7-x/)); the
October 27 Rust app releases also target core 0.23.0 (see the
[use-case release note](/blog/releases/2026/09/27/solverforge-usecases-repository-apps/)).
<% end %>

> **Update, 2026-09-15:** SolverForge 0.19.5 retains the complete solution when
> a job is cancelled, initializes score history with a slice fill, and preserves
> complete Clarke-Wright construction.

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
their published 0.18-based lines until their own releases moved. At the September 16 update, the
published CLI was 3.1.0 and scaffolds SolverForge 0.19.5. Existing generated
applications still own their dependency manifests and should move to 0.19.5
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

## October 2026 Core Patches (0.19.8–0.19.14)

Each patch kept the Rust `1.95` floor, the planning model, and the CLI 3.3.3
scaffold (runtime `0.19.7`) unchanged; only the core runtime moved.

- **0.19.8** — Keyed cross streams gain a third join source and a retained
  cross-tri constraint over one arity-generic cross-join engine; change
  localization is symmetric across all three sources.
- **0.19.9** — Joins move onto the common typed operator tree
  (`JoinNode` + `OperatorTerminal`): each chained relationship compiles its
  own condition and key type, fluent joins continue past Penta into the
  arity-free `Chain`, groups can feed joins, and a resume could no longer
  lose the worker wakeup. The per-arity incremental engines are superseded.
- **0.19.10** — Optional construction continues past kept-unassigned root
  decisions without consuming later rows' candidate budget, and unary
  filters run before keyed equality initialization, so excluded rows never
  reach a key closure.
- **0.19.11** — Interrupted Clarke-Wright merges commit the complete buffered
  route assignment using retained feasibility evidence; relational buffers
  are reused across incremental updates; exact indexed equality stops
  re-extracting both keys per candidate.
- **0.19.12** — Occupied equality buckets and existence link lists update in
  place; generation checks, old-key retraction, residual predicates, and
  duplicate suppression keep their semantics.
- **0.19.13** — The existence engine answers semi/anti joins from per-key
  occurrence counts (dense for `usize` planning ids, hash otherwise) with no
  child rows or pair links; complements restore through retained keys, and
  incremental notifications emit into caller-owned buffers instead of
  `RowChanges`.
- **0.19.14** — Dense-key existence bookkeeping keeps its touched list unique
  inline, and every later chained join's borrowed-row key rule is documented
  as the existing contract.

Publish, GitHub Release, and CI workflows succeeded for every tag; run
links live in each patch's upstream release. The 0.19.x line's full
boundaries are in this note's Published Version Boundaries below.

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

The following installation examples record the historical package boundaries;
use the linked current manuals for new installations. For direct Rust
applications on the September 15 line:

```toml
[dependencies]
solverforge = { version = "0.19.5", features = ["serde", "console"] }
```

The companion workspace crates are all published at `0.19.5`:

```toml
solverforge-core = "0.19.5"
solverforge-macros = "0.19.5"
solverforge-scoring = "0.19.5"
solverforge-config = "0.19.5"
solverforge-solver = "0.19.5"
solverforge-bridge = "0.19.5"
solverforge-cvrp = "0.19.5"
solverforge-console = "0.19.5"
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
assignment-rotation repair. The August 11 Python package was 0.6.6:

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
> **Update, 2026-09-15:** `solverforge-ui 0.9.0` is published and moves the
> bundled agent skill into the `solverforge-cli` repository. The published
> `solverforge-cli 3.0.0` package scaffolds the `solverforge-ui 0.7.0` line.
>
> **Update, 2026-09-16:** `solverforge-cli 3.1.0` is published and scaffolds
> `solverforge 0.19.5` with `solverforge-ui 0.9.0` and `rmcp 3.4.0`, so fresh
> scaffolds align with this core line. See the
> [3.1.0 release note](/blog/releases/2026/09/16/solverforge-cli-3-1-x/).
>
> **Update, 2026-10-02:** `solverforge 0.19.8` was published as the
> core runtime line at that update, adding keyed cross-tri joins and the retained cross-tri
> incremental constraint. The published `solverforge-cli 3.3.3` package still
> scaffolds `solverforge 0.19.7`, so fresh scaffolds trail this core line until a
> CLI release deliberately retargets them. See the
> [0.19.8 release note]/blog/releases/2026/07/17/solverforge-0-19-x/.

## Upgrade Checklist

- Bump SolverForge dependencies to `0.19.5` and regenerate `Cargo.lock` from
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
| `0.19.14` | 2026-10-12 | Inlines dense-key existence bookkeeping and documents borrowed-row keys on every later chained join. |
| `0.19.13` | 2026-10-11 | Rewrites the existence engine to answer semi/anti joins from per-key occurrence counts, with retained-key complement restore and caller-owned notification buffers. |
| `0.19.12` | 2026-10-10 | Mutates occupied equality buckets and existence links in place; preserves retained relationship semantics. |
| `0.19.11` | 2026-10-10 | Retains complete buffered Clarke-Wright merges on interruption, reuses relational buffers, and avoids redundant exact indexed equality extraction. |
| `0.19.10` | 2026-10-09 | Fixes optional construction progress and unary keyed source filtering; clarifies contracts and corrects the internal zero-regression gate. |
| `0.19.9` | 2026-10-08 | Independent-key joins and Chain past Penta, grouped joins, composable low-level row producers over the common operator tree, and the lost resume wakeup fix. |
| `0.19.8` | 2026-10-02 | Adds a third join source to keyed cross streams and the retained cross-tri incremental constraint, both on one arity-generic cross-join engine; the local build gate runs the Rust checks CI runs. |
| `0.19.7` | 2026-09-25 | Owns every workspace version surface from the release tooling, so the workspace, crates, and tags are cut from one declaration. |
| `0.19.6` | 2026-09-25 | Exposes the typed planning pin predicate, rejects scalar edits to pinned entities, preserves pinned list owners across construction and search, retains pinned assignments in exhaustive search, and skips pin scanning for models without pins. |
| `0.19.5` | 2026-09-15 | Retains the complete solution on cancellation, initializes score history with a slice fill, and preserves complete Clarke-Wright construction. |
| `0.19.4` | 2026-08-11 | Commits direct required assignments in the dense hard-first batch, defers augmenting rematches to a retaining cursor, and exposes the unified construction progress contract. |
| `0.19.3` | 2026-07-29 | Restores shared assignment rotation. |
| `0.19.2` | 2026-07-19 | Repairs required construction completion and interruption, unifies construction lifecycle and progress, preserves committed scores, and commits route telemetry atomically. |
| `0.19.1` | 2026-07-18 | Keeps configured limits binding during mandatory construction, gates best-solution and snapshot publication on structural completion, and fails rather than returning an incomplete plan. |
| `0.19.0` | 2026-07-17 | Makes list variables the sole sequence model, removes chained-only metadata and anchor shadows, preserves list-derived shadows, and keeps ordinary scalar paths on direct mutation. |

## Documentation Changes

- [SolverForge runtime docs](/docs/solverforge/) describe the scalar/list
  boundary; this post records the historical 0.19.5 runtime.
- [CLI command reference](/docs/solverforge-cli/command-reference/) records the
  published 3.1.0 scaffold targets, which align with the 0.19.5 core.
- [Crate & Runtime Map](/reference/crate-map/) aligns Rust, CLI, Python, and
  companion repositories on the new release line.
- [SolverForge Python](/docs/solverforge-python/) records the published 0.6.6
  package and its exact SolverForge 0.19.4 runtime base.
- [Status & Roadmap](/docs/status-and-roadmap/) tracks each independently
  published package and use-case version.
