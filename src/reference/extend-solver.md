---
title: "Extend the Solver"
description: "Engineer-facing reference for tuning SolverForge behavior without losing the stock runtime path."
---

# Extend the Solver

Start with the stock runtime and make it earn the next abstraction. Most SolverForge
apps need better domain modeling and better constraints before they need custom
solver machinery.

## The default rule

Change the solver in this order:

1. fix the domain model
2. fix the constraints and score weights
3. tune `solver.toml`
4. add custom runtime pieces only when configuration stops being enough

That order keeps the application understandable and lets you keep using the
well-tested retained runtime path.

## What belongs where

| Concern                                 | Best home                                                                              |
| --------------------------------------- | -------------------------------------------------------------------------------------- |
| business rules and penalties            | constraint code                                                                        |
| search strategy and runtime limits      | `solver.toml`                                                                          |
| per-job adjustments                     | a `#[planning_solution(config = "...")]` callback layering on top of the loaded config |
| UI-specific progress display            | the edge layer, not the runtime                                                        |
| experimental custom phases or selectors | app-side code using the lower-level crates                                             |

## Omitted Phase Defaults

When `phases` are omitted, the runtime runs state-aware construction: matching
specialized list construction, named grouped `FirstFit` for required assignment
rows followed by grouped `CheapestInsertion` for optional rows, and single-slot
construction for remaining non-assignment-owned scalars. One streaming default
local-search phase is eligible only when top-level termination contains an
effective parsed limit. Missing termination, an empty termination object, or an
invalid score-only limit leaves omitted phases construction-only. This is
separate from omitting `move_selector` inside an explicit local-search phase.
VND is never prepended implicitly.

Keeping an optional assignment unassigned completes that group-slot decision,
not the optional pass. Completed optional roots are excluded before candidate
domains are read or moves generated, preserving later rows' candidate budget.
Assigned occupants remain available for required augmenting rematches.

## Canonical selector defaults

If `move_selector` is omitted, the stock runtime stays intentionally narrow:

- scalar slots with nearby value/entity sources receive targeted nearby
  change/swap first; every non-assignment-owned slot still receives targeted
  plain change/swap fallbacks
- list slots with a cross-position metric receive nearby change and, when set
  access exists, nearby swap; slots without that metric receive the plain
  variants. Sublist, reverse, k-opt, permutation, and precedence repair are
  capability-gated, while every bound list slot receives list ruin
- mixed models declare list families first, then nearby scalar, grouped scalar,
  compound conflict repair, and ordinary scalar families
- omitted leaves use seeded random order; multiple families use a
  stratified-random union and a single family uses sequential union order

Assignment-owned scalar variables stay on their grouped scalar selector path.
Plain scalar defaults and conflict-repair defaults exclude slots owned by an
assignment-backed `ScalarGroup`. The configured names are
`grouped_scalar_move_selector` and `compound_conflict_repair_move_selector`,
not facade-importable selector types. Assignment augmenting depth and
sequence/position rematch size come from model-owned
`ScalarGroup::with_limits(...)`: defaults are 3 and 4, with rematch size clamped
to at least 2. They are distinct from config candidate and per-step move limits.
See [Assignment Limits](/docs/solverforge/solver/construction/#assignment-limits).

`limited_neighborhood` is the tool for putting a hard cap on one neighborhood
that is otherwise too broad. It is not a substitute for understanding the
search policy you are expressing.

## Tune in this order

| Tuning step                           | Use it for                                                    |
| ------------------------------------- | ------------------------------------------------------------- |
| construction phase choice             | initial feasibility and seed quality                          |
| local search acceptor                 | exploration vs greediness                                     |
| move selector choice                  | neighborhood breadth and cost                                 |
| leaf order / candidate metric         | original, random, shuffled, sorted, or probabilistic pulls     |
| union order / weighting               | how independent child neighborhoods share candidate pulls     |
| score tie-break                       | seeded random or first-equal best-candidate choice             |
| accepted-count `limit`                | finite accepted-candidate horizon for one selector step |
| `value_candidate_limit`               | bounded scalar value generation for selectors that support it |
| termination limits                    | wall time, unimproved steps, or best-score goals              |
| VND / typed exact / partitioned search | explicit advanced search strategies, not a default reflex     |

Nearby scalar selectors require model-declared candidate hooks. Use
`nearby_value_candidates` for nearby change, `nearby_entity_candidates` for
nearby swap, and distance meters only to rank or filter those bounded
candidates.

## When custom code is justified

Write custom solver code when one of these is true:

- the stock phases cannot express the search policy you need
- the neighborhood generator must encode domain-specific structure that config
  cannot capture
- you need app-specific orchestration around retained jobs and snapshots
- a lower-level crate gives you leverage that the facade intentionally hides

If you go there, keep the blast radius small. Prefer one app-side extension over
forking the scaffold or bypassing the retained runtime wholesale.

Custom search is compiled into the solution with
`#[planning_solution(search = "...")]`; `solver.toml` names registered phases
instead of loading arbitrary runtime classes. Partitioned search similarly
requires a typed `SolutionPartitioner`, not a partition count guessed from the
outside.

## Committed Mutation and Extension Contracts

Every committed working-solution change clears the cached current score and
advances the working-solution revision exactly once. This includes accepted
construction/local-search moves, configuration-list commits, partition merges,
and direct apply closures. Trial evaluation applies, scores, undoes with typed
undo data, and restores the snapshotted committed score state without advancing
that revision. `replace_working_solution_and_reinitialize(solution)` resets the
director, forces recalculation, resets the revision, and invalidates
descriptor-driven construction completion markers. The working revision is
internal mutation state, not a retained snapshot's `snapshot_revision`.

Public `MoveCursor` pulls lend `&S`; the runtime's hidden resource cursor pulls
lend `&mut D` and solve-owned resources. Implementors must restore preview
writes and score state before returning. Sequential moves override
`is_doable_with_working_preview(&mut D)` to check later legs after earlier legs.
`for_each_affected_entity<V: FnMut(MoveAffectedEntity<'_>)>(&self, &mut V)` uses a
concrete visitor and must report the complete mutated scope. Pillar swaps
report both pillars even though their primary `entity_indices()` slice is the
left pillar. Pin checks consume that complete visitor.

Heap-owning compound, pillar, ruin, list-union, and descriptor-union move
families do not provide a universal `Clone` contract. Keep candidates owned by
stable cursor IDs, evaluate by reference, and transfer the winner.
`Acceptor::step_ended` takes `Option<MoveTabuSignature>` by value.
`Move::tabu_signature<D: Director<S>>(&self, &D)` returns
`Cow<'_, MoveTabuSignature>`: lend a prebuilt signature or own one derived from
the working solution. Wrappers forward that value without forcing a clone;
there is no separate borrowed-signature hook.
`Termination::is_terminated` and `MaybeTermination::should_terminate` take
`&mut self`; stateful terminations own their counters rather than using shared
interior mutation.

Lower-level `Placement` exposes `candidates()` / `candidates_mut()` for its
cursor and `take_move(candidate_id)` for ownership transfer. Its
`keep_current_legal()` distinguishes a legal unchanged baseline from a mandatory
assignment. `EntityPlacerCursor::next_placement` receives the current director,
a completion predicate, and a stop predicate; app models normally stay on the
configured construction path rather than implementing a second placer engine.

### Precedence Score Notifications

Custom list mutations must call `before_variable_changed(descriptor_index,
entity_index)` before editing an owner list and `after_variable_changed(...)`
afterwards, including when undoing a trial. Report every changed owner with the
correct list descriptor.

The stock precedence scorer defers its score delta until insertion. Retraction
returns zero and retains the matching owner's old route as the baseline for a
net adjacency-edge diff. If several owners retract before one inserts, the
insertion first removes the other pending owners from its cached graph, then
scores the inserted owner's new route. Those other owners remain absent until
their own insertions; unchanged owners remain present. Do not treat the
intermediate score after a bare retraction as a freshly scored solution with
that owner removed.

After each complete edit or undo, compare incremental scoring with a fresh
score when testing a custom move. Include multi-owner interleaving, duplicate or
missing elements, and a cycle-forming trial: restoring the list must restore
both its hard penalties and its makespan. See
[List Variables](/docs/solverforge/modeling/list-variables/#precedence-makespan-scoring)
for the scoring model.

### Evaluator Replicas and Solve Entry Points

Compiled acceptor-forager local search uses top-level `move_thread_count` for
ordered parallel trials. `auto`, `none`, and counts 0 or 1 stay sequential;
larger counts are capped by the solve's Rayon pool and one 32-candidate window.
The main director counts as one evaluator. VND, lower-level `LocalSearchPhase`,
construction, exhaustive search, and partitioned children remain sequential.
See [Local Search](/docs/solverforge/solver/local-search/#parallel-candidate-evaluation)
before making cross-count reproducibility assumptions about ruin or lazy sources.

The configured `try_run_solver_with_config_and_search` entry point and bridge
runner accept a constraint-set constructor `fn(&S) -> C`, not an already-built
set. Each replica clones the working solution and constructs independent
constraint state from it. Macro-generated solves supply that constructor.

For lower-level scoring, `ScoreDirector<S, C, Desc = SolutionDescriptor>` accepts
an owned descriptor or a `ReplicaDescriptor::new(&descriptor, constraints)` via
`with_descriptor`. `Director::fork_replica()` returns an initialized independent
replica only for the borrowed replica descriptor; owned-descriptor directors
return `None`. `DirectorDescriptor` and `ReplicaDescriptor` are exported by
`solverforge-scoring`; they are not a second configured solve path.

### List-Shadow Notifications

An owner shadow update is also an element mutation. Before/after owner
notifications retract element rows with old shadows, rewrite derived state,
then reinsert refreshed owner and element rows. Elements left outside all lists
have configured inverse/index/previous/next fields cleared. Hand-written
`PlanningSolution` implementations must report these writes through
`list_shadow_elements`, `clear_list_shadows`, and `list_shadow_source`;
generated models provide the hooks. Test incremental-versus-fresh scoring after
edits and undo, including transfers between two owners and unassignment.

## Telemetry and lifecycle expectations

Retained jobs expose exact counts and durations through structured events.
That means:

- generated, evaluated, and accepted move counts belong to runtime telemetry
- not-doable, acceptor-rejected, forager-ignored, hard-delta, conflict-repair,
  and construction-slot counters belong there too
- selector telemetry carries stable selector indexes and labels for
  local-search and VND diagnosis
- `SolverTelemetry::phases` retains one indexed record per started phase in
  execution order, including the running phase in progress snapshots
- phase telemetry carries active elapsed, step, move, score-calculation,
  generation, and evaluation counters; run totals include phase sums and
  solve-level work such as initial scoring
- `moves_speculative` counts evaluated parallel trials discarded after the
  decision point, separately from consumed `moves_evaluated` and
  `score_calculations`; candidate traces mark them `DiscardedSpeculative`
- generation and evaluation durations stay exact in the event stream
- move-label telemetry and the bounded applied-move trace belong to runtime
  diagnostics, not benchmark-only instrumentation
- optional candidate-pull traces carry canonical execution plan/policy/input
  identity and dispositions; retrieve them through `get_telemetry_detail(...)`
  instead of bloating ordinary events and snapshots
- `moves/s` is a display-only derived metric at the UI edge
- configured limits remain binding during mandatory construction; incomplete
  list, required-assignment, or non-optional scalar work is a failed solve, not
  a best solution
- a pre-completion pause is resumable in-process but has no public solution
  snapshot; check optional snapshot metadata before fetching or analyzing it
- pause, resume, snapshot fetch, and analysis should use the retained
  `SolverManager` contract rather than ad-hoc channels

For custom instrumentation, `SolverStats` records counters once in its running
`PhaseStats`; `begin_phase` opens a record and `end_phase` freezes it.
`PhaseScope` owns that lifecycle through creation/drop and borrows the record
through `stats()` / `stats_mut()`. Read aggregate counters through methods such
as `step_count()`, `moves_evaluated()`, `moves_speculative()`, and
`score_calculations()`, not mutable aggregate fields. `phase()` / `phase_mut()`
and `phase_elapsed()` address the running phase. The solve's pause-aware clock
belongs to `SolverStats` (`start`, `pause`, `resume`, `elapsed`, `active_elapsed`,
`started_at`, `is_paused`); do not maintain a second competing timer or count
the same work at both scope levels.

## Practical checklist

- keep the domain model and config separate
- only use a config callback to decorate loaded config, not replace it blindly
- tune constraints before tuning search
- benchmark any custom neighborhood work before adopting it permanently
- preserve structured events so `solverforge-ui` and service layers stay honest

## See also

- [Docs: Solver](/docs/solverforge/solver/)
- [Lifecycle Contract](/reference/lifecycle-pause-resume-contract/)
- [Integration Boundaries](/reference/integration-surfaces/)
