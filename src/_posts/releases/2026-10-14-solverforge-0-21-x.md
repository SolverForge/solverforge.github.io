---
title: "solverforge 0.21.x: Joined-Tuple Grouping and Live-Solution Lending"
date: 2026-10-14
draft: false
description: >
  The 0.21.x line adds fluent group_by on Tri, Quad, and Penta joins, lends
  the live working solution through custom cursor pulls, moves search state
  to single ownership, fixes selector-subgraph merging, and preserves net
  route deltas through deferred precedence retractions in 0.21.3.
---

<%= render Ui::Callout.new(title: "Historical release note", variant: "warning") do %>
This post records an older core release. The current core release is
`solverforge 0.23.0`; see the [0.23.x release note](/blog/releases/2026/10/27/solverforge-0-23-x/).
Versions, installation commands, and API descriptions below are historical.
<% end %>

**solverforge 0.21.x** follows `solverforge 0.20.4`; the line was published on
crates.io on 2026-10-14. `cargo add solverforge` installs 0.21.3 and
docs.rs serves the 0.21.3 API. The Rust `1.95` floor remains. The 0.20.x
line's guided scalar search keys, score-authoritative grouped neighborhoods,
and corrected late acceptance carry into this line unchanged.

## What Changed

### Fluent grouping on Tri, Quad, and Penta joins

Cross-source and same-source joined arities expose `.group_by(key,
collector)`. The key closure takes one entity argument per binding; collector
mappers take the borrowed tuple (`(&A, &B, &C)` for `Tri`); grouped terminals
receive `(&key, &result)`. The implementation adapts borrowed tuples to the
existing `GroupNode`, so the same grouped engine, filters, and collector
payloads behave as on unary and pair groups: authored filters stay binding
during full and incremental evaluation, empty groups reset, and collected
payloads need not implement `Clone`. The arbitrary-depth `Chain` does not
gain fluent grouping; custom operator composition covers it. The
[Shift-Group Uniformity](/docs/solverforge/constraints/shift-group-uniformity/)
worked example groups a joined triple per shift and per exact time/location
block.

### Live-solution lending through the selector stack

`MoveCursor::next_candidate` pulls take the caller's live working solution
(`&S`) instead of a clone taken at cursor open. Cursors retain only plain
derived state — indexes, coordinates, seeds — so a commit between pulls is
visible to the next pull and nothing the cursor holds goes stale. Cartesian
discovery goes further: the left leg applies on the caller's live score
director via `next_candidate_with_director(&mut D)`, right pulls reinstate
each row's preview, and trial state and score state restore before the pull
returns. Sequential moves check doability on the live preview with
`Move::is_doable_with_working_preview(&mut D)`; later legs see earlier legs'
effects and a rejected preview leaves nothing behind. Placers receive the
current director on every `next_placement` call, so model callbacks observe
earlier construction commits.

### Single-ownership search state

Compiled selector compositions index declarations in an arena addressed by
stable node IDs; leaf state returns to the solve-owned arena when a cursor
drops early, so concurrent solves and restarted scans carry their RNG
position and candidate state exactly. Assignment membership keys, group
candidates, undo journals, list payloads, and tabu identities move by
ownership through the hot path instead of being cloned per candidate:

- grouped assignment baselines persist across local-search steps and refresh
  only moved rows between steps;
- list kernels consume values exactly once through remove/insert, swap,
  reverse, ruin, permutation, and k-opt operations, with undo journals that
  inline short routes and recycle across trials;
- candidate identity deduplicates through an order-independent multiset key
  without sorting a vector per generated candidate;
- move candidates transfer to the trial engine by value; heap-owning compound
  and pillar move families no longer implement `Clone`;
- affected-entity reporting runs through a monomorphized visitor, and pillar
  swaps now report both pillars to pin checks, tabu bookkeeping, and
  telemetry;
- tabu memories store the move identity once for self-undoing moves and record
  the real identity in reverse memory; signatures reach `Acceptor::step_ended`
  by ownership;
- terminations own their counters (`Termination::is_terminated(&mut self)`)
  instead of sharing interior mutation.

Scores, match results, and candidate ordering semantics are unchanged;
regression suites pin seeded parity on every reworked family.

### Extension-surface signatures

Lower-level extension code updates to the new contracts: termination checks
take `&mut self`; accepts hand tabu signatures by value; custom moves expose
`for_each_affected_entity<V: FnMut(MoveAffectedEntity<'_>)>` and the
live-preview doability hook; cursor pulls use
`next_candidate_with_control(…, should_stop)` around batched control polling;
and `SolverRuntime::detached` reuses its per-thread lifecycle slot between
solves. A solver whose worker panics now surfaces as a `Failed` retained job
with the panic message, and other jobs keep their own lifecycle state.
Duplicate scalar group names are rejected at model resolution instead of
failing deep in compilation.

### Net route deltas through deferred retractions (0.21.3)

List-precedence scoring keeps the paired owner baseline across a deferred
retraction, so an insert/undo pair during construction diffs only the changed
adjacency edges instead of re-deriving the whole route. Unmatched owner
retractions flush before an insert scores, preserving interleaved notification
semantics, and deferred-seed generations advance monotonically with stamps
cleared only on wrap. On the native stock JSSP subset all four instances
reached feasibility at the 1-second budget, including `ta01` (1.011 s wall),
which left construction incomplete on the registry baseline.

### Selector subgraph merging (0.21.2)

`rebase_graph` shifted only the returned root id when merging a compiled
selector sub-graph into the parent arena, leaving child node contents at the
sub-graph's zero-based coordinates. A nested composite inside a merged
sub-graph — a union with a `limited_neighborhood` child, or the benchmark
CVRP selector union wrapping a sublist change leaf — carried stale node ids
into the parent arena and failed with
"each compiled selector node lowers exactly once" on every solve. The merge
now shifts every structural edge, and compiler plus end-to-end regressions
pin the merged-arena contract. Flat-leaf unions were unaffected, and no
public API or config changed.

The `0.21.1` version number failed its crates.io publication and was retired:
no artifact carries it, and `0.21.2` is the successor to `0.21.0`.

### Release tooling migrated to csemver

The workspace release process moved from commit-and-tag-version (JavaScript
updaters) to `csemver.toml`: an anchored regex updater per documented version
surface, internal path-dependency rewrites and `Cargo.lock` regeneration in
the postbump hook, and a dry-run validation step that resolves every
configured surface. Model APIs and scores are unaffected.

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.22.0` | Rust `1.95`; see the [0.22.x line note](/blog/releases/2026/10/18/solverforge-0-22-x/) |
| Previous core runtime | `solverforge 0.21.3` | Registry and release artifacts remain available |
| Python | `solverforge-py 0.6.15` / PyPI `solverforge 0.6.15` | Runtime `0.22.0`, UI `0.9.0` |
| CLI | `solverforge-cli 3.5.2` | Fresh scaffolds target runtime `0.21.3`; UI `0.9.0`, maps `2.1.4`, MCP `rmcp 3.5.1` |
| Worked use cases | Eight released apps | Runtime `0.22.0`, UI `0.9.0`; see the [app release table](/blog/releases/2026/09/27/solverforge-usecases-repository-apps/) |

The 0.21.0 tag is `v0.21.0`, commit
`70aa9f71ab305265cfe7d83753af2f86fb06acf9`; the 0.21.2 tag is `v0.21.2`,
commit `cb916a73d86c46c25b0e4182626f9adc2c9aa5ad`; the 0.21.3 tag is
`v0.21.3`, commit `1000a7d471aafe4aa10e900ad075230b9df51ca8`; and the 0.21.3
tag is `v0.21.3`, commit `1000a7d471aafe4aa10e900ad075230b9df51ca8`. Registry
publication, the GitHub Releases, and CI runs completed successfully for each
tag, and no artifact carries the retired `0.21.1` number. This line is closed.
The next core release was `solverforge 0.22.0` (commit
`df1ce37b4a69a61fe249e71852ea694de94b4493`, publish
[39109402359](https://github.com/SolverForge/solverforge/actions/runs/39109402359)
and release
[39109402581](https://github.com/SolverForge/solverforge/actions/runs/39109402581)
successful on the tag); Python 0.6.15 targeted it, and the October 18 app train
retargeted all eight apps to it.
Existing applications retain their own dependency pins until deliberately upgraded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.21.3` | 2026-10-14 | List-precedence scoring keeps the paired owner baseline across deferred retractions; net adjacency diffs, monotonic deferred-seed generations; JSSP `ta01` feasible at 1 s. |
| `0.21.2` | 2026-10-14 | `rebase_graph` shifts every structural edge when merging selector sub-graphs; fixes nested-composite selector unions (benchmark CVRP union shape). `0.21.1` failed publication and was retired — no artifact carries it. |
| `0.21.0` | 2026-10-14 | Fluent grouping on joined arities (#74); live-solution lending across selectors and placements; single-ownership search state and extension-surface signatures; release tooling migrated to csemver. |
| `0.20.4` | 2026-10-13 | Score-authoritative grouped-scalar neighborhoods, steered family budgets, sparse final-edit validation, corrected DLAS and best-anchored late acceptance. |
| `0.20.3` | 2026-10-12 | Native scalar `search_entity_order_key` / `search_value_order_key` hooks; reuse of blocker rule verdicts. |
| `0.20.2` | 2026-10-12 | Batched control polls, recycled assignment-index rows, forced-edge short-circuiting; no new model API. |
| `0.20.1` | 2026-10-12 | Pooled precedence-route and grouped-scalar construction scratch. |
| `0.20.0` | 2026-10-12 | Grouped-scalar default local search forages with `AcceptedCount(256)`. |
| `0.19.14` | 2026-10-12 | Dense-key existence bookkeeping; borrowed-row key rule on every later chained join. See the [0.19.x note](/blog/releases/2026/07/17/solverforge-0-19-x/) for the full 0.19.x line. |

## Upgrade Checklist

- Update direct Rust dependencies and confirm `Cargo.lock` resolves `0.21.3`.
- Custom `Move` implementations: replace `Clone` requirements where present
  with owner-stable candidates and value transfer, and implement the
  monomorphized affected-entity visitor; composite moves should use
  `is_doable_with_working_preview(&mut D)`.
- Custom `MoveCursor` implementations: adapt pulls to `next_candidate(&S)`
  (or `next_candidate_with_director` for preview-needing composition) and
  retain only derived state between pulls.
- Custom `Termination` and `Acceptor` implementations: take `&mut self` in
  termination checks and `Option<MoveTabuSignature>` by value in
  `step_ended`.
- Use `.group_by(key, collector)` directly on `Tri`/`Quad`/`Penta` streams;
  custom operator-tree grouping remains valid on `Chain`.
- Upgrade CLI-generated apps deliberately: fresh scaffolds from CLI 3.5.2
  target core 0.21.3, while existing apps keep their recorded pins until an
  explicit upgrade.
- Scores and decisions are unchanged; re-running your regression suite is
  sufficient for behavior parity beyond the signatures above.

## Where to read next

Read [Composite Move Selectors](/docs/solverforge/solver/composite-move-selectors/)
for the lending cursor contract, [Termination](/docs/solverforge/solver/termination/)
for owned termination state, [Extend Solver](/reference/extend-solver/) for
extension signatures, and
[Shift-Group Uniformity](/docs/solverforge/constraints/shift-group-uniformity/)
for the joined grouping example. The
[final tag diff](https://github.com/SolverForge/solverforge/compare/v0.20.4...v0.21.3)
and the [full range from 0.20.1](https://github.com/SolverForge/solverforge/compare/v0.20.1...v0.21.0)
record the exact code changes.