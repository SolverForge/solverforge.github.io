---
title: "solverforge 0.20.x: Guided Search and Grouped-Scalar Neighborhoods"
date: 2026-10-12
draft: false
description: >
  Accepted-count foraging, pooled construction scratch, guided scalar search,
  corrected late acceptance, and score-authoritative grouped neighborhoods
  across solverforge 0.20.0–0.20.4.
---

**solverforge 0.20.x** follows `solverforge 0.19.14` and was published on
crates.io (2026-10-12 through 2026-10-13). The line starts with accepted-count
foraging and covers patches through `0.20.4`. Rust `1.95` remains the workspace
floor. For the current
manuals, use the [core overview](/docs/solverforge/) and
[0.21.x release note](/blog/releases/2026/10/14/solverforge-0-21-x/).

## What Changed

### Accepted-count foraging and pooled scratch (0.20.0–0.20.2)

Grouped-scalar default local search uses `AcceptedCount(256)`: each step
compares up to 256 accepted candidates, or drains the union, before applying
the best. Explicitly configured foragers keep their chosen policy. The
previous default stepped with `FirstLastStepScoreImproving` and no cap,
stopping at the first step-improving candidate and discarding the remaining
accepted work; the forager change alters default search depth, not a
configuration contract.

Precedence-route cycle checks, precedence scoring, and grouped-scalar
construction reuse scratch buffers. Construction and search batch inner-loop
control polls and latch observed stop requests; phase-boundary limits remain
binding. Assignment indexes recycle empty row buffers, and fully forced rule
edges avoid redundant membership reads. These patches do not add model APIs.

### Guided native scalar search (0.20.3)

`search_entity_order_key` and `search_value_order_key` on
`#[planning_variable]`, with matching `ScalarVariableSlot` builders, guide
native change enumeration. Swap uses the entity key for its left traversal.
Lower keys are tried first, equal keys retain seeded order, and missing keys
sort last. Construction-order hooks remain construction-only. Construction
also reuses rule verdicts already computed during blocker discovery.

### Score-authoritative neighborhoods and late acceptance (0.20.4)

Grouped-scalar families use pressure and scarcity to order bounded discovery,
not to replace the model's score. The final edit set still obeys domains,
required rows, capacity, and assignment rules; the score, acceptor, and forager
decide among legal candidates. Families share the candidate budget by
round-robin pulls. Pair and cycle coordinates stream without eager Cartesian
materialization or unrelated internal walk cutoffs.

Sparse hypothetical overlays preserve committed membership during augmenting,
ejection/reinsert, and required-batch discovery. Final validation subtracts
departures before arrivals and checks post-edit sequence edges, including
vacated source edges.

Diversified late acceptance accepts equality with the step score or strict
improvement over the worst history score. Its ring advances per evaluated
candidate, with exact worst-score occurrence tracking; the former `tolerance`
configuration and `with_default_tolerance` constructor are removed. Plain late
acceptance resets its entire history on a new phase-best score.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Historical core line | `solverforge 0.20.0`–`0.20.4` | Rust `1.95`; use matching source and crate APIs; 0.20.0–0.20.1 registry and release artifacts remain available for those patches |
| CLI | `solverforge-cli 3.3.3` | Scaffolds core `0.19.7`, UI `0.9.0`, maps `2.1.4`, MCP `rmcp 3.5.0` |
| Python | `solverforge-py 0.6.10` / PyPI `solverforge 0.6.10` | Runtime `0.19.7` and UI `0.9.0` |
| Worked use cases | Eight released apps | Runtime `0.19.7` and UI `0.9.0` |

Independent CLI, Python, and app packages do not inherit a core upgrade.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.20.4` | 2026-10-13 | Score-authoritative grouped-scalar neighborhoods, steered family budgets, sparse final-edit validation, corrected DLAS and best-anchored late acceptance; removes DLAS tolerance. |
| `0.20.3` | 2026-10-12 | Native scalar `search_entity_order_key` / `search_value_order_key` hooks and reuse of blocker rule verdicts. |
| `0.20.2` | 2026-10-12 | Batched control polls, recycled assignment-index rows, and forced-edge short-circuiting; no new model API. |
| `0.20.1` | 2026-10-12 | Pooled precedence-route and grouped-scalar construction scratch; no API change. |
| `0.20.0` | 2026-10-12 | Grouped-scalar default local search forages with `AcceptedCount(256)`; no API change. |
| `0.19.14` | 2026-10-12 | Dense-key existence bookkeeping and the borrowed-row key rule on every later chained join. |
| `0.19.13` | 2026-10-11 | Per-key occurrence existence engine and caller-owned notification buffers. |

## Upgrade Checklist

- Remove DLAS `tolerance` settings and replace custom uses of the removed
  tolerance constructor with `DiversifiedLateAcceptanceAcceptor::new(size)`.
- Compare late-acceptance and grouped-scalar solve quality at your own time
  limit; candidate ordering and acceptance trajectories can differ.
- Use search-order hooks for local-search guidance, not construction hooks.
- Upgrade CLI-generated apps deliberately: CLI 3.3.3 still targets core 0.19.7.
- For an upgrade to the current source line, follow the
  [0.21.x checklist](/blog/releases/2026/10/14/solverforge-0-21-x/#upgrade-checklist).

## Where to read next

Read [Local Search](/docs/solverforge/solver/local-search/) and
[Configuration](/docs/solverforge/solver/configuration/). The
[full 0.20.x range](https://github.com/SolverForge/solverforge/compare/v0.19.14...v0.20.4)
and [upstream changelog](https://github.com/SolverForge/solverforge/blob/v0.21.0/CHANGELOG.md)
record the patch boundaries.
