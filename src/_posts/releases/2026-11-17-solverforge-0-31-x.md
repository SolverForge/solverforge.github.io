---
title: "solverforge 0.31.x: List Element Groups, Joint Cascading Groups, and a Measured Default Policy"
date: 2026-11-17
draft: false
description: >
  The 0.31.x line moves and constructs pick-up and drop-off pairs and other
  list element groups as units, computes cascading values of elements that
  start together in one step, rescores only the list-shadow rows a move
  changes, completes fixed fleets after Clarke-Wright, and picks the default
  search effort, family weights and construction budget from benchmark runs.
---

**solverforge 0.31.x** follows `solverforge 0.30.1`; the line was published on
crates.io on 2026-11-17. The current release is
[0.31.2](https://crates.io/crates/solverforge/0.31.2), with a Rust `1.95`
floor. `cargo add solverforge` installs 0.31.2, and docs.rs serves the 0.31.2
API. The one breaking change, in 0.31.0, touches the lower-level list slot and
configuration structs: struct literals and exhaustive matches over them need
the new fields and variants. Models that only use the attribute macros and
`solver.toml` upgrade by moving the pin. `solverforge-cli 4.2.0` scaffolds
0.31.2, and the nine worked use cases pin 0.31.2.

## What Changed

### List element groups (0.31.0) — breaking change

Some elements must travel together: the pick-up and drop-off of one job, or
every stop of a multi-stop job.
`#[planning_list_variable(element_collection = "...", element_group_fn = "...")]`
names a hook `fn(&Solution, usize, &mut Vec<usize>)` that appends the members
of an element's group in order
([#274](https://github.com/SolverForge/solverforge/pull/274), issue
[#270](https://github.com/SolverForge/solverforge/issues/270)). A group's
members share one owner; other elements may sit between them.

- `list_group_change_move_selector` moves a whole group to positions of one
  owner, and `list_group_swap_move_selector` exchanges two groups of the same
  size on different owners.
- `list_ruin_move_selector` ruins whole groups and recreates each group
  jointly.
- `list_cheapest_insertion` and `list_regret_insertion` place a group as one
  unit; `list_round_robin`, `list_clarke_wright` and the global `first_fit`
  and `cheapest_insertion` reject a list with groups.
- Single-element list moves keep a grouped element on its owner, so no move
  splits a group.
- `max_member_distance` and `max_group_owners` (1 to 255) bound joint
  placement in construction, group change and ruin.
- A grouped list's defaults are `list_cheapest_insertion` with
  `max_group_owners = 4`, group change and group swap ahead of the other list
  families, and its own ruin with `max_member_distance = 7` and
  `max_group_owners = 4`.

`element_group_fn` cannot be combined with precedence hooks. Lists without the
hook keep the same move path, and every struct the change touches keeps its
0.30.1 size. `ListVariableSlot::precedence_successors_fn` became a method,
because the precedence and group hooks share one private field;
`ListRuinMoveSelectorConfig` and `ConstructionHeuristicConfig` gain
`max_member_distance` and `max_group_owners`, and `MoveSelectorConfig` gains
`ListGroupChangeMoveSelector` and `ListGroupSwapMoveSelector`. See
[List Variables](/docs/solverforge/modeling/list-variables/#element-groups)
and [List Move Selectors](/docs/solverforge/solver/list-move-selectors/#element-groups).

### Joint cascading groups (0.31.0)

A job that needs two technicians starts when the later of them arrives, so
each technician's visit waits on the other's arrival; declared as two
dependencies, that is a cycle. `cascading_peers` on
`#[shadow_variable_updates]` names a solution method returning the elements
computed together with an element
([#274](https://github.com/SolverForge/solverforge/pull/274), issue
[#272](https://github.com/SolverForge/solverforge/issues/272)). Peers are
joined transitively into a joint group that propagation treats as one node:
once the previous element and every dependency of every member hold their
final values, each member is computed once, in ascending element order. A
group whose members wait on each other through their lists is a cycle, and
its members are unset. See
[List Variables](/docs/solverforge/modeling/list-variables/#joint-groups).

### Rows rescored only when they change (0.31.1)

With a cascading shadow, every owner change retracted and reinserted the row
of every element that owner held, so one insertion rescored the whole route.
The score director now rescores an element only when its structure shadows
no longer describe its place, it arrived from or left every list, or its
cascading value changed
([#275](https://github.com/SolverForge/solverforge/pull/275)). The macro
generates the new `PlanningSolution::list_structure_unchanged` hook that
answers the structure question; its default (`false`) keeps the previous
behaviour for hand-written solutions. On the route-rows benchmark against
0.31.0, two passes drop from 96 ms to 57 ms with identical scores.

### Grouped ruin recreated in one pass (0.31.1)

Grouped recreate searched every remaining group in every round and committed
only the best one, about k(k+1)/2 searches for k groups. It now places the
groups in one pass in the plan's order, each at its best placement given the
groups before it, and a placement search keeps the members in the list
between trials. On the grouped-ruin benchmark against 0.31.0, two passes drop
from 1,361 ms to 107 ms; recreate order changed by design.

### Fixed fleets completed after Clarke-Wright (0.31.2)

When strict savings hooks reject merges and the Clarke-Wright routes outnumber
the vehicles that can take them, construction discarded every route, so a
fixed fleet ended construction with every element unassigned and the default
solve failed its completion gate. `list_clarke_wright` now commits the routes
that fit and leaves the rest of their elements unassigned; the default
construction then runs `list_cheapest_insertion` over them (reason
`list_elements_remain_unassigned`)
([#276](https://github.com/SolverForge/solverforge/pull/276)). An explicit
`list_clarke_wright` phase on a fixed fleet needs a `list_cheapest_insertion`
phase after it. The default Clarke-Wright also keeps 40 savings per element
when the slot declares a savings neighbour hook, as the `domain = "cvrp"`
profile does, so its memory grows linearly with the stop count. See
[Construction](/docs/solverforge/solver/construction/#default-construction).

### Measured default search effort (0.31.2)

The default local search collected 256 accepted moves before every step,
whatever the model, so a rostering solve made about 220 steps in 10 s. Five-seed
solverforge-bench runs of the CVRP, rostering and job-shop suites at 10 s pick
the count per model shape: list variables collect 4, scalar groups and scalar
models with nearby hooks or conflict repairs collect 32, other scalar models 1,
and the precedence forager's ceiling is 32. List ruin and unbounded k-opt
rebuild or scan whole routes per candidate, so the default union gives them
weight 1 against 4 for every other family; they stay in the neighborhood for
diversification. `resolved_phase_plan` reports the weights. See
[Local Search](/docs/solverforge/solver/local-search/#default-policy).

### Local search keeps its share of a time-limited budget (0.31.2)

The optional assignment pass is the one default construction step that can run
long without being needed: on the rostering bench it took about 7 s, leaving a
10 s solve 2 s of search. It now stops once a fifth of the solve's time limit
has passed and leaves optional rows to local search's optional-assignment
moves; the step reports the share it got as `time_budget_seconds`. A tenth
measurably cost quality at 60 s, and a fifth matched the uncapped pass there.
Required construction is never capped, and a solve without a time limit runs
the pass to completion.

On the solverforge-bench instances at 10 s and five seeds, the 0.31.2 default
scores better than the 0.31.1 default on 9 of 10 instances (JSPLIB la21 is the
exception) and better than the hand-tuned CVRP configuration on X-n101 and
X-n242, staying 0.2% behind it on X-n524
([#276](https://github.com/SolverForge/solverforge/pull/276) lists every
instance).

## Published Version Boundaries

| Surface | Version | Notes |
| ------- | ------- | ----- |
| Core runtime | `solverforge 0.31.2` | Rust `1.95`; list element groups; joint cascading groups; row-level cascading rescoring; one-pass grouped recreate; fixed fleets completed after Clarke-Wright; measured default search effort and family weights; a fifth of a time limit for the optional pass |
| Previous core release | `solverforge 0.31.1` | Row-level cascading rescoring and one-pass grouped recreate, on the 0.31.0 policy |
| Previous core line | `solverforge 0.30.1` | Cascading list shadows across owners; see the [0.30.x release note](/blog/releases/2026/11/15/solverforge-0-30-x/) |
| CLI | `solverforge-cli 4.2.0` | Fresh scaffolds target core `0.31.2`; see the [4.1.x and 4.2.x CLI release note](/blog/releases/2026/11/18/solverforge-cli-4-1-4-2-x/) |
| Python | `solverforge-py 0.8.1` / PyPI `solverforge 0.8.1` | Compiled onto core `0.31.2` from 2026-11-20; see the [Python 0.8.x release note](/blog/releases/2026/11/20/solverforge-python-0-8-x/). This core shipped while Python was `0.7.2` on core `0.23.0` |
| Worked use cases | November 18 app releases | All nine pin core `0.31.2` and UI `0.9.1`; see the [use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/#november-18-releases-solverforge-0312) |
| UI | `solverforge-ui 0.9.1` | Unchanged |
| Maps | `solverforge-maps 2.3.3` | Unchanged |

All nine workspace crates (`solverforge`, `solverforge-core`,
`solverforge-config`, `solverforge-scoring`, `solverforge-solver`,
`solverforge-macros`, `solverforge-bridge`, `solverforge-console`, and
`solverforge-cvrp`) publish `0.31.0`, `0.31.1`, and `0.31.2`.

| Release | Registry publication | Artifact SHA-256 | Tag commit | CI | Release workflow | GitHub Release |
| ------- | -------------------- | ---------------- | ---------- | -- | ---------------- | -------------- |
| `0.31.0` | `2026-11-17T02:14:13Z` | `f5b6940b80070446130a11b9288ae11c7f6b662800fe92afc2a36071bc729bdf` | `c2d4fa27bf0081a6b0db6a0c5ca5961802a3b93a` | [43996989765](https://github.com/SolverForge/solverforge/actions/runs/43996989765) | [43999401432](https://github.com/SolverForge/solverforge/actions/runs/43999401432) | [`2026-11-17T02:15:20Z`](https://github.com/SolverForge/solverforge/releases/tag/v0.31.0) |
| `0.31.1` | `2026-11-17T12:03:05Z` | `f594cb77fd5b91cfeb9fcd767c954be865660e5be1c487419e9f09429db88076` | `ff945a3bef3b53ef3ade3f70b86392a8a00137c2` | [44076144517](https://github.com/SolverForge/solverforge/actions/runs/44076144517) | [44076147858](https://github.com/SolverForge/solverforge/actions/runs/44076147858) | [`2026-11-17T12:03:28Z`](https://github.com/SolverForge/solverforge/releases/tag/v0.31.1) |
| `0.31.2` | `2026-11-17T22:20:11Z` | `a702c08aac207bd5e22763d7f70b1021efdccbb0149c8b82cd1c018ddf940b11` | `78889c3ff9fda158c70e6a1f67f8c7f0fdae922e` | [44182372301](https://github.com/SolverForge/solverforge/actions/runs/44182372301) | [44185759448](https://github.com/SolverForge/solverforge/actions/runs/44185759448) | [`2026-11-17T22:20:29Z`](https://github.com/SolverForge/solverforge/releases/tag/v0.31.2) |

Each artifact's `.cargo_vcs_info.json` names its tag commit. On each commit
the CI run passed, and the Release workflow re-ran the CI matrix on Linux,
macOS, and Windows with the Miri, MSRV, docs, and package jobs, verified the
release, published to crates.io, and created the GitHub Release; every job of
all six runs succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.31.2` | 2026-11-17 | Fixed fleets completed after Clarke-Wright; default Clarke-Wright keeps 40 savings per element with a neighbour hook; accepted counts per model shape (list 4, scalar groups and nearby/repair scalars 32, precedence ceiling 32); ruin and unbounded k-opt weighted 1 against 4; the optional assignment pass stops at a fifth of the time limit. |
| `0.31.1` | 2026-11-17 | Cascading moves rescore only the list-shadow rows they change (`PlanningSolution::list_structure_unchanged`); grouped ruin recreates in one pass with shared trial prefixes. |
| `0.31.0` | 2026-11-17 | List element groups (`element_group_fn`, group change and swap selectors, grouped ruin and construction, `max_member_distance`, `max_group_owners`); joint cascading groups (`cascading_peers`). |

## Upgrade Checklist

- Move the `solverforge` pin to `0.31.2`. Models built on the attribute
  macros and `solver.toml` need no code changes.
- Code that reads `ListVariableSlot::precedence_successors_fn` as a field
  calls it as a method.
- Struct literals of `ListRuinMoveSelectorConfig` and
  `ConstructionHeuristicConfig` set `max_member_distance` and
  `max_group_owners` (or use `..Default::default()`); exhaustive matches over
  `MoveSelectorConfig` handle `ListGroupChangeMoveSelector` and
  `ListGroupSwapMoveSelector`.
- A hand-written `PlanningSolution` with a cascading shadow can implement
  `list_structure_unchanged` to get row-level rescoring; the default keeps
  the previous behaviour.
- An explicit `list_clarke_wright` phase on a fixed fleet whose savings hooks
  reject merges is followed by a `list_cheapest_insertion` phase.
- An explicit `local_search` phase that omits its forager on a list model now
  collects 4 accepted moves per step instead of 256; set
  `[phases.forager] type = "accepted_count"` with `limit = 256` to keep the
  previous horizon.

## Where to read next

Read the [core manual](/docs/solverforge/),
[List Variables](/docs/solverforge/modeling/list-variables/#element-groups),
[Construction](/docs/solverforge/solver/construction/#default-construction),
and [Local Search](/docs/solverforge/solver/local-search/#default-policy).
The [0.31.0](https://github.com/SolverForge/solverforge/compare/v0.30.1...v0.31.0),
[0.31.1](https://github.com/SolverForge/solverforge/compare/v0.31.0...v0.31.1),
and [0.31.2](https://github.com/SolverForge/solverforge/compare/v0.31.1...v0.31.2)
compares cover the line's 12 commits, and the
[CHANGELOG](https://github.com/SolverForge/solverforge/blob/v0.31.2/CHANGELOG.md)
lists the breaking change.
