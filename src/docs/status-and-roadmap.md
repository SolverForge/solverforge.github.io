---
title: "Status & Roadmap"
description:
  Current SolverForge release, published package status, completed runtime
  surface, and roadmap.
weight: 2
---

# Status & Roadmap

<%= render Ui::Callout.new do %>
SolverForge is a **production-ready constraint solver** written in Rust. This
documentation tracks the `solverforge 0.31.2` release and keeps core,
CLI scaffold targets, UI assets, maps, and Python bindings separate.
`cargo add solverforge` installs 0.31.2, and docs.rs serves the 0.31.2 API.
Rust `1.95` remains the workspace floor.

`v0.31.2` points to `78889c3ff9fda158c70e6a1f67f8c7f0fdae922e`. Its
[CI run](https://github.com/SolverForge/solverforge/actions/runs/44182372301)
passed, and its [Release workflow](https://github.com/SolverForge/solverforge/actions/runs/44185759448)
re-ran CI on Linux, macOS, and Windows with the Miri, MSRV, docs, and package
jobs, verified the release, published all nine crates to crates.io, and
created the GitHub Release. The 0.31 line moves and constructs list element
groups as units, computes joint cascading groups together, rescores only the
list-shadow rows a move changes, completes fixed fleets after Clarke-Wright,
and picks the default search effort, family weights, and construction budget
from benchmark runs. Constraint matches name each entity by its planning id
(0.29.0), describe it without a copy (0.28.0), and cascading list shadows
follow dependencies across owners (0.30.0). See the
[0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/) for the
upgrade checklist; the
[0.30.x](/blog/releases/2026/11/15/solverforge-0-30-x/),
[0.29.x](/blog/releases/2026/11/14/solverforge-0-29-x/), and
[0.28.x](/blog/releases/2026/11/14/solverforge-0-28-x/) release notes cover the
lines since 0.27.0.

The independently published CLI line is `solverforge-cli 4.2.2`. Fresh
scaffolds target `solverforge 0.31.2`, with `solverforge-ui 0.9.1` and
`solverforge-maps 2.3.3` for the web shell and `rmcp 3.9.0` for the MCP shell.
A generated project declares its constraint modules in
`src/constraints/mod.rs` and assembles them in `src/constraints/assemble.rs`;
every `mod.rs` and `lib.rs` holds only declarations, which `check` enforces,
and `check` loads `solver.toml` with the runtime's own configuration parser.
A fresh scaffold solves its empty plan through the runtime's default pipeline,
generated code is rustfmt-clean, `--field` types are imported, and `check`
states that it does not compile the project. Generated constraint skeletons
still panic until their placeholders are replaced, and generated telemetry
carries the resolved phase plan once a solve ends. The 4.2.2
[Publish](https://github.com/SolverForge/solverforge-cli/actions/runs/44878601505)
and [Release](https://github.com/SolverForge/solverforge-cli/actions/runs/44878601542)
workflows and the exact-commit
[CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/44878598757)
on Linux, macOS, Windows, and integration tests passed at
`bd0b5427cc985067a905d4a9361a9fc160429551`. See the
[4.1.x and 4.2.x CLI release note](/blog/releases/2026/11/18/solverforge-cli-4-1-4-2-x/).
Apps scaffolded by earlier releases pin older cores (`0.31.1` from 4.1.0, `0.26.1` from
4.0.4, `0.26.0` from 4.0.2 and 4.0.3, `0.25.1` from 4.0.0 and 4.0.1, `0.25.0` from 3.9.0,
`0.24.0` from 3.8.x, `0.23.0` from 3.7.x, `0.22.0` from 3.6.0) and keep
constraint assembly in `src/constraints/mod.rs` until moved, and an app moves
to a newer core line only when deliberately upgraded and validated.

The worked-use-case bundle ships nine apps on `solverforge 0.31.2` and
`solverforge-ui 0.9.1`, in the CLI 4 constraint layout:
`solverforge-hospital@3.0.6`, `solverforge-lessons@3.0.6`,
`solverforge-deliveries@3.0.7`, `solverforge-fsr@3.0.7`,
`solverforge-furnace@4.0.3`, `solverforge-orders@0.3.5`,
`solverforge-fleet@0.2.5`, `solverforge-flightcrew@0.3.6`, and
`solverforge-ev@0.1.0`. Furnace reports snake_case constraint ids. The four
Space-backed apps' release-tag sync workflows succeeded. Bundle CI passed at
the final app tag, `solverforge-lessons@3.0.6`
([run 44286382345](https://github.com/SolverForge/solverforge-usecases/actions/runs/44286382345)); see the
[use-case release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/#november-18-releases-solverforge-0312).
Furnace, Orders, Fleet, and Flight crew are repository-only. See the
[use-case 3.0 release note](/blog/releases/2026/11/03/solverforge-usecases-3-0/).

SolverForge Python has a tagged `solverforge-py 0.8.1` source line for CPython
3.14, compiled onto the `solverforge 0.31.2` runtime with embedded
`solverforge-ui 0.9.1` assets; PyPI serves `solverforge 0.8.1`. Python's
exact-tag [CI](https://github.com/SolverForge/solverforge-py/actions/runs/44814575001)
and [release/PyPI publication](https://github.com/SolverForge/solverforge-py/actions/runs/44814580348)
passed at `6776c18c76134b40ecc8a459c6d74fe771c49210`. The `0.8.0` number was
tagged but never published: its release run could not build the macOS wheel.
See the [0.8.x Python release note](/blog/releases/2026/11/20/solverforge-python-0-8-x/).
The current UI line is `solverforge-ui 0.9.1`, and the current maps line is
`solverforge-maps 2.3.4`; both SolverForge agent skills live in the
`solverforge-cli` repository.
<% end %>

## Current Status

| Component     | Status              | Description |
| ------------- | ------------------- | ----------- |
| **Rust Core** | Published; CI and release passed | Native Rust constraint solver published as `solverforge 0.31.2`: every termination criterion applied with no hidden time limit, measured automatic parallel evaluation, seeded and checked assert modes, framework partitioned search, validated configuration, replica directors built by `ScoreDirector::with_replicas`, late acceptance that keeps its history across soft-level improvements, pluggable CVRP route metrics, bounded Clarke-Wright savings, list element groups, cascading list shadows across owners, constraint matches with planning ids, and a measured default search policy; Rust `1.95` |
| **CLI Scaffold** | Published; CI and release passed | `solverforge-cli 4.2.2` targets `solverforge 0.31.2`, web `solverforge-ui 0.9.1` + `solverforge-maps 2.3.3`, MCP `rmcp 3.9.0`; constraints declared in `src/constraints/mod.rs` and assembled in `src/constraints/assemble.rs` |
| **Python** | Published; CI and release passed | `solverforge-py 0.8.1` compiles dynamic CPython 3.14 models into the `solverforge 0.31.2` runtime with `solverforge-ui 0.9.1`; PyPI publishes `solverforge 0.8.1` |
| **Worked Use Cases** | Released; tag Space syncs passed | `solverforge-hospital@3.0.6`, `solverforge-lessons@3.0.6`, `solverforge-deliveries@3.0.7`, `solverforge-fsr@3.0.7`, plus the repository-only `solverforge-furnace@4.0.3`, `solverforge-orders@0.3.5`, `solverforge-fleet@0.2.5`, `solverforge-flightcrew@0.3.6`, and `solverforge-ev@0.1.0`; all nine target `solverforge 0.31.2` and `solverforge-ui 0.9.1` |
| **UI** | Published | `solverforge-ui 0.9.1` exposes framework-neutral embedded assets; `solverforge-cli 4.2.2` scaffolds it directly |
| **Maps** | Published | `solverforge-maps 2.3.3` builds car-legal road graphs, reports street names on routes, snaps itinerary stops by access direction, and identifies its client to Overpass |

## Try It Today

- Start with [solverforge-cli Getting Started](/docs/solverforge-cli/getting-started/)
  for the generic app shell.
- Use [SolverForge Python](/docs/solverforge-python/) when you want to define
  models with Python classes, decorators, and callbacks while using the native
  SolverForge engine.
- Continue with the worked use-case bundle:
  [Hospital](/docs/getting-started/solverforge-hospital-use-case/),
  [Lessons](/docs/getting-started/solverforge-lessons-use-case/),
  [Deliveries](/docs/getting-started/solverforge-deliveries-use-case/), or
  [FSR](/docs/getting-started/solverforge-fsr-use-case/).
- Use [Constraint Node Sharing](/docs/solverforge/constraints/node-sharing/)
  when a constraint function reuses the same grouped stream across several
  named terminal constraints.
- Use [Projected Scoring Rows](/docs/solverforge/constraints/projected-scoring-rows/)
  when scoring needs retained rows derived from source entities, joined pairs,
  or oriented relationships between projected rows.

## Completed Runtime Surface

- **Constraint Streams API**: source-aware generated source methods, `for_each`,
  `filter`, unified `join(...)`, direct cross-join `group_by(...)`,
  direct cross-join grouped complements, `flatten_last`, `project(...)`,
  projected grouped complements, `balance`, `complement(...)`,
  `if_exists(...)`, `if_not_exists(...)`,
  `collect_vec(...)`, `indexed_presence(...)`, explicit score weighting, and
  `.named(...)`
- **Projected Scoring Rows**: bounded single-source rows, joined-pair projected
  rows, symmetric projected self-joins through `equal(...)`, and directed
  projected self-joins through `equal_bi(left_key, right_key)`
- **Constraint Compiler Node Sharing**: `#[solverforge_constraints]` can share
  grouped, projected grouped, direct cross grouped, and complemented grouped
  stream nodes across repeated terminal constraints while preserving terminal
  names, order, metadata, and score explanation
- **Score Types**: SoftScore, HardSoftScore, HardMediumSoftScore,
  HardSoftDecimalScore, BendableScore
- **Score Analysis**: facade-level `ScoreAnalysis` and `ConstraintAnalysis`,
  plus lower-level detailed match/explanation APIs in `solverforge-scoring`
- **SERIO Engine**: retained incremental scoring for real-time optimization
- **Solver Phases**: scalar/list construction heuristics, assignment-backed
  grouped scalar construction, streaming local search, VND as a local-search
  type, precedence-list neighborhoods, and typed custom, exact, or partitioned
  search extensions
- **Move System**: scalar, list, grouped scalar, assignment repair,
  conflict repair, cartesian, and composite move families
- **Runtime Compiler**: one immutable resolved graph for native and dynamic
  construction, selector trees, providers, stable list sources, defaults, and
  execution errors
- **SolverManager API**: retained job lifecycle with progress, structurally
  complete best-solution publication, pause/resume, completion, cancellation,
  failure, snapshots, snapshot-bound analysis, ordered per-phase telemetry, and
  explicit candidate-trace detail retrieval
- **Configuration**: stock `solver.toml` embedded through `solver_toml` or
  loaded with `SolverConfig::load`, strict TOML parsing that rejects unknown
  keys, bounded
  scalar candidates, grouped scalar selectors, per-leaf ordering and metrics,
  weighted unions, seeded score ties, parallel move evaluation, candidate tracing, level-aware simulated
  annealing, and per-solution config overlays

## Python Package

- **Install**: `python3.14 -m pip install "solverforge==0.8.1"`; use the
  matching `solverforge-py` `v0.8.1` tag for source and example development.
- **Modeling**: Python classes, decorators, scalar variables, list variables,
  explicit assignment metadata, scoped route/savings bundles, named candidate
  metrics, hard per-row scalar candidate domains, native static same-value
  conflict fields, and callback constraints.
- **Callback failures and interrupts**: optional attribute probes treat only
  `AttributeError` as absence. Other exceptions, including `KeyboardInterrupt`,
  propagate. Direct solves preserve the Python traceback; retained jobs record
  failure. Recognized callback-error payloads do not print a redundant Rust
  panic preamble, while unrelated Rust panics reach the previous hook.
- **Runtime entry points**: `Solver.solve(...)`, `Solver.analyze(...)`, and
  `SolverManager(config=None)` over one compiled SolverForge 0.31.2 runtime graph,
  with `score_director.constraint_provider` naming the solution's provider.
- **Termination and config**: every configured termination criterion applies
  with no implicit time limit; the core rejects unknown keys and zero-valued
  count fields before solving. `move_thread_count = "auto"` decides per step
  whether to evaluate in parallel.
- **Constraint surface**: callback-authored unary streams, binary stream-level
  joins, grouped counts, balance scoring, fixed or callback-computed weights,
  unassigned-list scoring, list precedence/makespan scoring, indexed-presence
  grouped collectors, and `joiner.equal(...)` / `joiner.equal_bi(...)`.
- **Dynamic move parity**: supported scalar and list local-search selectors,
  including grouped scalar, conflict repair, compound conflict repair, k-opt,
  list precedence, list permute, list ruin, union, limited neighborhood, and
  two-child cartesian composition.
- **Parallel evaluation**: config dictionaries and `solver.toml` pass
  `move_thread_count` to the core acceptor-forager runtime. Explicit counts of
  two or more enable evaluator replicas, capped by the Rayon pool and 32;
  `auto` stays sequential. The synchronous solve releases the GIL so workers
  can attach; callbacks serialize on GIL-enabled Python and must avoid shared
  mutable state on free-threaded Python.
- **Retained diagnostics**: ordered `phases` telemetry, run/per-phase
  `moves_speculative`, `discarded_speculative` trace outcomes, bounded format-3 candidate traces,
  atomic `telemetry_detail(...)`, and optional immutable
  `QualifiedCandidateTraceProvenance` supplied per managed job.
- **Compiled scoring boundary**: proven fixed-weight unary, unassigned-list,
  precedence, and stable string-key equality plans can evaluate natively while
  callback-dependent shapes preserve the Python path.
- **Examples**: hospital scheduling with row-filtered scalar candidates and
  nearby metadata, plus deliveries routing with unassigned seed routes and
  explicit route/savings bundles; both expose retained jobs, exact snapshots,
  phase telemetry, analysis, and shared `solverforge-ui` assets from the native
  bridge.

## Runtime Notes

- **Core runtime line**: these manuals describe `solverforge 0.31.2`, with
  Rust `1.95`. The
  published `solverforge-cli 4.2.2` package targets `solverforge 0.31.2` for
  fresh scaffolds, as 4.2.0 and 4.2.1 did; apps scaffolded by earlier releases pin older cores
  (`0.31.1` from 4.1.0, `0.26.1` from 4.0.4, `0.26.0` from 4.0.2 and 4.0.3, `0.25.1` from 4.0.0 and 4.0.1, `0.25.0` from 3.9.0, `0.24.0` from 3.8.x, `0.23.0` from 3.7.x, `0.22.0` from 3.6.0, `0.19.7` from 3.3.x),
  and an app should
  move to a newer core line only when that app is deliberately upgraded and
  validated.
- **Replica directors**: a lower-level score director that forks evaluator
  replicas is built with `ScoreDirector::with_replicas` from a borrowed
  `SolutionDescriptor` and a `fn(&S) -> C` constraint-set constructor; stream
  closure types stay proportional to the constraint set, so debug info for
  large constraint sets links.
- **Termination**: every configured solver-level criterion applies, and the
  first one reached stops the solve. Nothing adds a time limit the
  configuration does not set, and a zero time limit stops at once.
- **Explicit configuration**: a model reads `solver.toml` only from the file
  its `solver_toml` argument embeds; nothing is read from the working
  directory. Unknown keys fail the load, YAML is not supported, and invalid
  acceptor, forager, and `best_score_limit` values fail the solve.
- **Constraint weights and problem changes**: a `#[constraint_weights]`
  solution field scales each named constraint, and analysis reports its
  `weight_multiplier`. `ProblemChange` values submitted to a running job are
  applied at runtime safe points in submission order.
- **Parallel local search**: the default `move_thread_count = "auto"` uses up
  to four evaluators and chooses, per step, between sequential evaluation and
  acceptor-forager evaluation windows from measured costs; an explicit count of
  two or more uses that many. Candidate generation and acceptor/forager
  decisions remain serial and ordered. Each additional evaluator owns a
  solution copy and independent incremental scoring state. `"none"` and a count
  of one are sequential, and a count of zero is a configuration error;
  construction and VND are not parallelized by this setting. Fixed-work scalar/list selectors
  without cross-step stream state preserve the sequential trajectory; ruin
  selectors and lazy providers remain reproducible at a fixed evaluator count.
  Time-limited runs are not a cross-count trajectory guarantee.
- **Per-phase telemetry**: `SolverTelemetry.phases` retains every started phase
  in execution order. Run totals sum phase records plus between-phase work.
  `moves_speculative` and `DiscardedSpeculative` distinguish discarded trials
  from consumed candidates. `SolverStats` counters are accessor methods.
- **List-shadow scoring**: inverse, index, previous, and next shadow writes
  retract and reinsert element rows, including clearing elements that leave all
  lists. Constraints over those rows observe the updated shadows.
- **Measured default policy**: default local search collects a measured
  number of accepted moves per step for each model shape — `AcceptedCount(4)`
  for list models, `AcceptedCount(32)` for scalar groups and for scalar models
  with nearby hooks or conflict repairs, 1 for other scalar models, and a
  precedence forager ceiling of 32 — and weights list ruin and unbounded k-opt
  1 against 4 for every other family. Explicitly configured foragers keep
  their pinned behavior.
- **Joined-tuple grouping**: cross-source and same-source `Tri`, `Quad`, and
  `Penta` streams expose `group_by(key, collector)`. Key closures receive one
  entity argument per binding; collector mappers receive a borrowed tuple;
  grouped weights receive `(&key, &result)`. Filters keep their semantic source
  indexes, and collected payloads need not implement `Clone`.
- **Guided native scalar search**: `search_entity_order_key` and
  `search_value_order_key` guide change enumeration; swap uses the entity key
  for its left traversal. Lower keys come first, missing keys come last, and
  equal keys retain seeded order. Construction-order hooks remain separate.
- **Score-authoritative grouped search**: candidate ordering steers a bounded
  round-robin family scan without substituting a heuristic score for the
  model's score. Final edits obey declared domains, required rows, capacity,
  and assignment rules. Sparse hypothetical overlays leave committed indexes
  untouched; acceptors and foragers decide among scored legal candidates.
- **Late acceptance**: DLAS compares each evaluated candidate with the step
  score and the exact worst history score, advancing its ring per candidate;
  it has no tolerance parameter. Plain late acceptance advances per step and
  refills its window with a new phase best only when a hard or medium level of
  the best score changes; soft-only improvements leave the window as it is.
- **Lending extensions**: move cursor pulls take the live solution; Cartesian
  pulls use `next_candidate_with_director(&mut director)` to discover right
  candidates with the left leg applied, then restore the solution and score
  state. Placers receive the current director on every `next_placement` call.
  Custom moves expose generic affected-entity visitors and live-preview
  doability; termination checks take `&mut self`, and acceptors receive the
  accepted tabu signature by ownership.
- **Owned runtime state**: compiled selector declarations use indexed arenas,
  leaf state returns on early cursor drop, assignment bases are retained across
  local-search steps, and list payloads move through mutation and undo without
  per-trial payload cloning. Cartesian row storage and undo journals reuse
  capacity. Pillar swaps report both halves to pin checks, and self-undoing tabu
  moves enter both configured memories. See the
  [0.21.x release note](/blog/releases/2026/10/14/solverforge-0-21-x/).
- **Composable joins**: each later join uses `equal_on(left_row_key,
  right_row_key)` over the complete prior borrowed row and the new entity's
  `Leaf` view, with its own key type. Entity-key `equal_bi` closures belong to
  the first unary join; they do not typecheck on later joins. Named
  cross `Bi`, `Tri`, `Quad`, and `Penta` adapters use the same typed operator
  tree; `stream::cross::Penta::join` continues into `stream::chain::Chain` with no fixed arity
  ceiling. That continuation discards an authored penta filter; apply it on the
  returned `Chain`. Same-source `PentaConstraintStream` is terminal. Fluent
  targets implement `CollectionExtract`, including filtered unary streams;
  arbitrary derived producers belong at the low-level `JoinNode` boundary.
  Grouped results can join another collection. Equality, comparison,
  overlap, and composed relationships compile into concrete index plans.
- **Operator-tree boundary**: `JoinNode` and `OperatorTerminal` replace the
  historical cross-bi/cross-tri and per-arity self-join engines. Low-level
  collection, filter, bag-union, owned projection, grouping, semi/anti join,
  flatten, complement, and self-join producers compose borrowed views with
  generational identities and source provenance. Specialized stream families
  still exist; arbitrary derived-consumer sharing is not supplied by these
  producers. Existing compiler-owned grouped terminal sharing remains supported.
- **Optional construction progress**: keeping an optional assignment unassigned
  completes that decision, not the whole optional pass. Completed optional roots
  are skipped before candidate-domain reads and move generation, preserving the
  candidate budget for later rows; assigned occupants remain available to
  required augmenting rematches.
- **Unary keyed source membership**: the first unary keyed equality cross-join
  applies source filters before key extraction and pair creation, preserving
  original source indexes and descriptor-local change metadata. Post-join filters
  operate on joined rows. Left-source pushdown does not extend to comparison,
  overlap, composed-condition, predicate, or same-source self-join dispatch.
- **0.19.11 construction and scoring fixes**: interrupted Clarke-Wright merge
  work can publish a complete buffered assignment using existing owner-feasibility
  evidence, without extending the search budget. Interrupted savings generation
  preserves the committed complete assignment. Relational operators reuse retired
  buffers and probe scratch; exact typed equality buckets avoid repeating both
  key extractors for each candidate pair.
- **0.19.13 existence-engine rewrite**: `ExistenceNode` answers semi/anti joins
  from one occurrence count per right-side key (dense for `usize` planning ids,
  hash otherwise) with stored key contributions and one key bucket of left rows.
  Threshold crossings publish or retract every left row carrying that key
  idempotently per event; right-side children never become rows and never
  receive handles. `JoinerExistenceNode` keeps pair joins for residual
  predicates, and complements restore through retained `KeyOf` keys, not stale
  row handles. Incremental notifications append into caller-owned
  `&mut Vec<RowHandle>` buffers and `RowChanges` is gone: one memcpy per hop and
  no heap allocation on this path. These implementation changes do not imply new
  benchmark results or measured performance gains. See the
  [0.19.11 release note](/blog/releases/2026/07/17/solverforge-0-19-x/),
  [0.19.12 release note](/blog/releases/2026/07/17/solverforge-0-19-x/), and
  [0.19.13 release note](/blog/releases/2026/07/17/solverforge-0-19-x/).
- **0.19.14 dense-key refinement**: count additions and removals inline the
  touched-key update and grow storage only when the key exceeds its current
  length. Membership semantics stay unchanged. The release also documents the
  borrowed-row key-shape rule at every later chained join. See the
  [0.19.14 release note](/blog/releases/2026/07/17/solverforge-0-19-x/).
- **0.20.1 pooled scratch**: precedence-route cycle checks reuse graph-owned
  buffers and the grouped-scalar construction feasibility path pools its probe
  scratch, removing per-candidate and per-event allocation. Scores, decisions,
  and public APIs are unchanged. See the
  [0.20.x release note](/blog/releases/2026/10/12/solverforge-0-20-x/).
- **0.19.12 retained bookkeeping**: occupied equality buckets and existence link
  lists are updated in place. Empty buckets still retire their buffers for reuse;
  generation checks, old-key retraction, residual predicates, and duplicate
  suppression remain intact.
- **Internal zero-regression gate**: deterministic allocation counters are checked
  exactly without a noise allowance; noisy metric medians have a default 5%
  regression tolerance through `BENCH_TOLERANCE_PERCENT`. Both sides share a
  harness package name and equal-length staging paths, and record `.text` SHA-256
  fingerprints. Simulated cache metrics are medians across several link
  layouts, and branch behaviour is graded on the hardware branch-miss counter,
  so a change in function placement alone does not fail the gate. The paired bootstrap upper bound is diagnostic, not an acceptance
  criterion. This changes internal qualification, not historical site benchmark
  measurements or their tested versions.
- **Lost resume wakeup fixed**: resume and cancellation clear the pause request
  and notify while holding the worker's pause gate, closing the race between
  its predicate check and condition-variable wait without changing snapshot
  publication boundaries.
- **One sequence model**: planning list variables are the canonical model for
  routes and ordered assignments. They own the sequence directly and retain
  inverse, index, previous, next, custom, cascading, and piggyback shadows.
  Scalar variables remain direct single-slot assignments; the former
  predecessor-chain surface and its chain-only anchor shadow are no longer
  part of the public runtime.
- **One compiled runtime graph**: native Rust and dynamic bridge models resolve
  construction stages, recursive selector trees, providers, stable list-source
  identities, defaults, and termination into one immutable graph before
  solving. Declaration, compilation, preparation, and execution errors are
  explicit; there is no parallel configured-search fallback.
- **Resolved selector policy**: leaf selectors can use original, seeded random,
  shuffled, sorted, or probabilistic order; sorted/probabilistic leaves require
  a registered candidate metric. Unions support sequential, round-robin,
  rotating-round-robin, random, and default stratified-random scheduling with
  equal, fixed, or candidate-count weighting. Equal best scores use seeded
  random tie-breaking by default.
- **Cursor-owned candidate execution**: shared scalar/list kernels expose stable
  candidate IDs, let foragers short-circuit without draining a neighborhood,
  and transfer only the selected winner by value. Generated counts represent
  actual cursor yields, including speculative parallel pulls, rather than an
  unrequested logical tail. Speculative trials discarded after a decision point
  are counted separately from consumed evaluations.
- **Construction control and progress**: generic and specialized construction
  share one lifecycle and phase-telemetry path, publish first work promptly,
  continue roughly once per second under verbose logging, poll control during
  expensive generation, and commit route counters atomically.
- **Required assignment batches**: the default hard-first required pass commits
  dense independent assignments directly, then leaves bounded augmenting
  rematches to a following cursor that can retain their multi-entity edits.
- **Qualified candidate traces**: `[candidate_trace]` retains a bounded ordered
  prefix with canonical config, resolved plan, execution policy, input,
  operation identity, and disposition provenance. Detailed traces are fetched
  atomically through `SolverManager::get_telemetry_detail(...)`; routine events
  and snapshots keep only compact telemetry.
- **Dynamic capability contracts**: bridge models declare scalar legality and
  nearby sources, list mutation operations, immutable list metadata bundles,
  and scalar-assignment metadata explicitly. Host compound providers and
  optional candidate metrics are frozen per solve instead of discovered through
  mutable schema or thread-local state in cursor execution.
- **Lifecycle settlement**: pause and cancellation are polled around phases and
  terminal hooks as well as inside long candidate work. Paused time is excluded
  from active phase telemetry, and pending control cannot be overwritten by
  ordinary completion. Configured limits remain binding during mandatory
  construction; incomplete work fails without publishing an incomplete
  best/completed snapshot, and a pre-completion pause remains resumable without
  publishing a partial snapshot.
- **Grouped-scalar construction policy**: applications drive grouped
  construction and repair through `ScalarGroup::assignment(...)`, grouped
  construction `group_name`, and `grouped_scalar_move_selector`. The
  grouped-scalar construction cursors remain solver-internal rather than a
  public import surface. Required assignment construction streams state instead
  of relying only on a closed internal batch path.
- **0.17.1 route safety fixes**: stock CVRP helpers reject unreachable
  travel-time legs during strict feasibility checks, convert unreachable or
  malformed distance entries into a large finite cost for construction/search,
  and clamp route-distance arithmetic used by Clarke-Wright and k-opt.
- **CVRP list profile**: stock CVRP list variables can declare
  `domain = "cvrp"`. The profile supplies the CVRP solution trait, distance
  meters, strict route-local hooks, relaxed Clarke-Wright savings hooks,
  savings metric class, and savings neighbour hook.
- **Route metrics**: `ProblemData` reads legs from a `RouteMetric` named by
  `VrpSolution::Metric`: `DenseMatrix` holds supplied distance and travel-time
  tables, and `EuclideanMetric` computes straight-line legs from coordinates
  in memory linear in the stops.
- **Bounded Clarke-Wright savings**: `savings_neighbors = K` on a
  `list_clarke_wright` phase scores a pair only when one element is among the
  other's K nearest, so the savings list holds about K entries per element.
  With `EuclideanMetric` the stock profile finds neighbours on a spatial grid.
  With `phases` omitted, the default Clarke-Wright keeps 40 savings per element
  whenever the slot declares a savings neighbour hook.
- **List element groups**: `element_group_fn` on a list variable declares
  elements that share one owner, such as a pick-up and its drop-off. Group
  change, group swap, grouped ruin, and joint insertion construction move them
  as units, bounded by `max_member_distance` and `max_group_owners`.
- **Cascading list shadows**: `cascading_field`, `cascading_compute`, and
  `cascading_dependencies` keep a value such as a start time correct across
  owners after every move, recomputing only the changed elements' downstream
  cone and rescoring only rows whose value or list structure changed;
  `cascading_peers` computes joint groups together.
- **Constraint matches**: `ScoreDirector::constraint_analyses()` reports every
  constraint's matches, grouped and complemented ones included, with each
  entity's type name, `Debug` rendering, and planning id; analysis keeps no
  entity copies and no stream requires `Clone`.
- **Resolved phase plan**: final telemetry reports the policy a solve ran,
  with the reason for each default construction choice, in
  `resolved_phase_plan`. The optional assignment pass of a time-limited solve
  stops at a fifth of the time limit.
- **Route and savings hooks**: custom routing list variables can still split
  route-local behavior from Clarke-Wright construction explicitly.
  `route_hooks` exports `get`, `set`, `depot`, `distance`, and `feasible`;
  `savings_hooks` exports `depot`, `distance`, and `feasible`;
  `savings_metric_class_fn` is the optional construction sharing hook and
  `savings_neighbors_fn` the optional nearest-neighbour hook for bounded
  savings.
- **Strict K-opt route feasibility**: stock CVRP route hooks reject capacity and
  time-window violations before k-opt commits a route. The stock savings hooks
  stay relaxed enough for Clarke-Wright construction to assign scoreable
  capacity or time-window violations when that is better than leaving work
  unassigned.
- **Clarke-Wright completion**: `ListClarkeWright` completes unmatched
  route elements instead of dropping work when no saving merge can place them.
  When strict savings hooks leave more routes than a fixed fleet can take, it
  commits the routes that fit, and the default construction places the rest
  with `list_cheapest_insertion`.
- **Dynamic bridge crate**: `solverforge-bridge` carries host-language binding
  contracts for logical entity/fact/variable IDs, dynamic score families, and
  descriptor-resolved scalar/list slots. Python remains the first published
  binding, but the bridge contract is a Rust workspace crate.
- **Constraint node sharing**: annotate reusable constraint factory functions
  with `#[solverforge_constraints]`. Reused same-binding grouped streams and
  syntax-proved identical grouped chains share retained incremental node work;
  separate terminal constraints keep their own names, impact direction,
  metadata, and explanation rows.
- **Generated source methods**: `#[planning_solution]` now exposes collection
  sources as solution-associated functions such as `Schedule::shifts()`.
  Constraint streams use those generated methods through
  `ConstraintFactory::for_each(...)`.
- **Assignment-backed scalar groups**: `ScalarGroup::assignment(...)` declares
  required nullable scalar slots, capacity keys, sequence/position hooks, and
  construction ordering; grouped construction and `grouped_scalar_move_selector`
  consume the same `group_name` from `solver.toml`.
- **Collectors**: `consecutive_runs(...)`, `collect_vec(...)`, and
  `indexed_presence(...)` cover streaks, owned grouped payloads, and ordinal
  presence/complement checks. The underlying `Collector<Input>` contract is
  generic over the stream match shape, so unary rows, projected rows, and direct
  cross-join pairs use the same collector protocol.
- **Scoring terminals**: the current stream surface uses `penalize(score)`,
  `reward(score)`, typed dynamic closures, `fixed_weight(...)`, and
  `hard_weight(...)`; the older `penalize_hard`, `penalize_with`, and
  `reward_soft` helper family is historical.
- **Public runtime names**: direct runtime assembly APIs use `RuntimeModel`,
  `VariableSlot`, `ScalarVariableSlot`, `ListVariableSlot`, `ScalarGroup`,
  `ScalarAssignmentRule`, `ConflictRepair`, `RepairCandidate`, and
  `RepairLimits`.
- **Facade configuration exports**: app code can import `SolverConfig`,
  `PhaseConfig`, `MoveSelectorConfig`, `AcceptorConfig`, `ForagerConfig`,
  `SolverConfigOverride`, and related enums directly from `solverforge`.
- **Typed custom search**: solutions can compile in search code with
  `#[planning_solution(search = "...")]`, register named phases through
  `SearchContext`, and order those names from `solver.toml`.
- **Joined-pair projected rows**: cross joins can use
  `.project(|left, right| row)` to retain one scoring row per joined pair.
- **Directed projected self-joins**: projected rows can use
  `.join(equal_bi(left_key, right_key))` when the left and right side of a
  same-row-type relationship are semantically different, such as parent-child
  projected rows.
- **Direct cross-join grouping**: cross joins can group joined pairs with
  `.group_by(|left, right| key, collector)` without projecting first.
- **Projected grouped complements**: projected grouped streams can continue into
  `complement(...)` or `complement_with_key(...)` for missing-key scoring rows.
- **Direct cross-join grouped complements**: direct cross joins can group joined
  pairs and then call `complement(...)` against a generated fact or entity
  source for zero-match target rows.
- **Filtered keyed joins**: filtered right-hand join sources, flattened keyed
  targets, custom keyed extractors, and filtered complement sources retain only
  rows that still satisfy their source filters.
- **Clone-free projected paths**: projected outputs, projected self-join keys,
  and grouped collector values no longer need `Clone` in the `0.11.x` release
  line.
- **Joined filter indexes**: low-level joined filters receive semantic source
  indexes for direct, grouped, projected, flattened, and higher-arity joins.
- **CVRP profile and custom hook split**: stock CVRP routes should use
  `domain = "cvrp"`; custom route domains can wire `route_hooks`,
  `savings_hooks`, and optional `savings_metric_class_fn` and
  `savings_neighbors_fn` explicitly.
  Construction savings can share a metric class without collapsing route-local
  assignment semantics.
- **Assignment value-pattern neighborhoods**: assignment-backed grouped scalar
  local search includes bounded value-window swaps, longer value-window swaps,
  same-sequence run-gap swaps, block reassignments, optional run releases, and
  three-value rotations. Required assignment construction still has a hard-first
  fill path for required slots, with public streaming state available for
  advanced construction integrations.
- **Borrowed constraint identity**: scoring metadata preserves full
  `ConstraintRef` identity borrowed from the owning constraint.
- **Model-owned scalar hooks**: `candidate_values`,
  `nearby_value_candidates`, `nearby_entity_candidates`,
  `construction_entity_order_key`, and `construction_value_order_key` declare
  bounded scalar neighborhoods and construction ordering on the model.
- **Model-aware defaults**: omitted phases run state-aware construction. A default
  streaming local-search phase requires effective parsed top-level termination;
  absent termination, an empty termination object, or invalid score-only
  termination remains construction-only. Capability-matched leaves use seeded random
  order, multi-family unions use stratified-random scheduling, and
  assignment-owned scalar slots remain exclusively on their grouped path.
- **Exact retained telemetry**: generated, evaluated, accepted, not-doable,
  acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
  construction-slot, per-phase, speculative-work, move-label, and bounded applied-move counters
  are retained as authoritative counters; bounded candidate-pull detail is
  retained separately on explicit request.

## Roadmap

### Native Solver Complete

The Rust-native constraint solver, derive macros, SERIO scoring engine,
retained runtime lifecycle, and stock configuration surface are in place.

### Rust API Refinement

Current work focuses on tightening public API contracts, making scoring and
runtime paths easier to explain, and keeping source, docs, examples, and CLI
scaffolds aligned as releases move.

### Python Package

`solverforge-py 0.8.1` is the current tagged SolverForge Python source line for
CPython 3.14. It compiles explicit Python model metadata into the
`solverforge 0.31.2` runtime, applies every configured termination criterion
with no implicit time limit, follows the core's measured `"auto"` parallel
evaluation policy, selects the constraint provider by name, reports the
resolved phase plan in detailed retained telemetry, and keeps shared
`solverforge-ui 0.9.1` assets. The 0.7.x line moved retained telemetry from the
single `phase` dictionary to the ordered `phases` list. The automatic release workflow
publishes the source distribution and CPython 3.14 wheels to PyPI for every
tagged patch. `0.6.6` (2026-08-11) enforces each row's imported candidate set
as the hard domain for every native scalar mutation and adds
`same_value_conflict_field` for static assignment conflict graphs; the
0.6.7–0.6.10 patches carry the SolverForge `0.19.7` construction and telemetry
behavior, and the 0.6.11–0.6.15 patches retarget to the `0.21.0`, `0.21.3`, and
`0.22.0` registry bases. Its source archive
contains only the package metadata and Python/Rust build inputs; repository
tests, examples, guidance, and tooling remain source-checkout assets.

### Additional Language Bindings

Other language bindings remain future-facing. The Rust core remains the source
of truth for solver behavior, while Python is the first published dynamic
binding.

## How You Can Help

- [Follow the getting started guides](/docs/getting-started/) and share
  feedback.
- [Open an issue](https://github.com/solverforge/solverforge/issues) for bugs
  or unclear docs.
- Star the [GitHub repo](https://github.com/solverforge/solverforge) and share
  real planning use cases.
