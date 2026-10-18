---
title: "solverforge 0.22.x: The Canonical Grouping Kernel"
date: 2026-10-18
draft: false
description: >
  The 0.22.x line routes every grouped stream through one accumulator kernel,
  retracts group and hash memberships by position, owns each grouping key once,
  and drops stale key Clone bounds in complement weights.
---

**solverforge 0.22.x** follows `solverforge 0.21.3`; the line was published on
crates.io on 2026-10-18. `cargo add solverforge` installs 0.22.0 and
docs.rs serves the 0.22.0 API. The Rust `1.95` floor remains. The 0.21.x
line's joined-tuple grouping, live-solution lending, owned search state, and
net-route-delta precedence scoring carry into this line unchanged.

## What Changed

### One grouping execution path

Every grouped stream — unary groups, cross-join groups, projected groups, and
every complemented variant — lowers onto the same `GroupNode` accumulator in
`stream::relational::operator`. Earlier releases kept per-family grouped
engines; they are gone. Each group keeps an explicit contributor list with
per-input accumulator tokens, so a full evaluation publishes exactly one
replacement row per group and an incremental update touches only the groups
its inputs belong to. `#[solverforge_constraints]` compiles chained grouped
terminals against one shared terminal owner and scores, orders, and explains
each terminal independently.

The macro's grouped-sharing recognition for complemented sources no longer
requires `project(...)` or `join(...)` earlier in the chain: a plain
`group_by` chain qualifies. `SharedNodeDiagnostics`, `SharedNodeId`, and
`SharedNodeOperation` remain the shared-node diagnostic vocabulary, with the
cross-complemented and projected-complemented variants documented in the
facade.

### Membership retract by position

Group, hash-bucket, and relational-link membership changes unlink in O(1) by
stored position instead of scanning buckets for the unlinked row: removal
swaps the contributor's successor into place and patches its index, hash
buckets remove the exact slot, and complement/links restore through retained
keys. Grouping keys are owned once per group (no per-contribution clones), and
the retained grouping record is slimmer per row. Complement weight closures
dropped a stale `Clone` bound on the key, so key types that are neither `Copy`
nor `Clone` now work in complemented grouped weights.

Scores, match results, and candidate ordering semantics are unchanged;
regression suites pin seeded parity on every reworked family.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.22.0` | Rust `1.95`; docs.rs serves the 0.22.0 API |
| Previous core runtime | `solverforge 0.21.3` | Registry and release artifacts remain available |
| Python | `solverforge-py 0.6.15` / PyPI `solverforge 0.6.15` | Runtime `0.22.0`, UI `0.9.0` |
| CLI | `solverforge-cli 3.5.2` | Fresh scaffolds target runtime `0.21.3`; UI `0.9.0`, maps `2.1.4`, MCP `rmcp 3.5.1` |
| Worked use cases | Eight released apps | Runtime `0.22.0`, UI `0.9.0` |

The 0.22.0 crate artifact's SHA-256 is
`5c882fc55b59e28632a276df4e8f820ec0a3b52ecaf5d4a7afe69139c954db6b`, and
`.cargo_vcs_info.json` binds it to commit
`df1ce37b4a69a61fe249e71852ea694de94b4493` (the `v0.22.0` tag points at the
same commit's workspace snapshot). The
[publish](https://github.com/SolverForge/solverforge/actions/runs/39109402359)
and [release](https://github.com/SolverForge/solverforge/actions/runs/39109402581)
workflows completed on the tag commit. Independent CLI, Python, and app lines
move only through their own releases: CLI 3.5.2 still scaffolds core `0.21.3`;
Python `0.6.15` and the October 18 app train compile against core `0.22.0`.
Existing applications retain their own dependency pins until deliberately
upgraded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.22.0` | 2026-10-18 | One grouping accumulator kernel across all grouped families; membership unlink by exact position; grouping keys owned once; complement weights drop stale key `Clone` bounds. |

## Upgrade Checklist

- Update direct Rust dependencies and confirm `Cargo.lock` resolves `0.22.0`.
- Grouped complemented weight closures with non-`Clone` keys: remove the
  workaround clones.
- Grouped sharing recognition for a complemented source now accepts plain
  `group_by` chains; a `#[solverforge_constraints]` function that duplicated
  work to satisfy the old requirement can share again.
- Scores and decisions are unchanged; re-running your regression suite is
  sufficient for behavior parity.

## Where to read next

Read [Node Sharing](/docs/solverforge/constraints/node-sharing/) for the
shared terminal contract, [Collectors](/docs/solverforge/constraints/collectors/)
for accumulator shapes, and
[Joiners](/docs/solverforge/constraints/joiners/) for the join surfaces above
the shared kernel. The
[final tag diff](https://github.com/SolverForge/solverforge/compare/v0.21.3...v0.22.0)
records the exact code changes.
