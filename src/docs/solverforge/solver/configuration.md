---
title: "Configuration"
linkTitle: "Configuration"
weight: 10
description: >
  Runtime configuration with SolverConfig, solver.toml, and parsing helpers.
---

A model reads a `solver.toml` only when it names one. Add `solver_toml` to
`#[planning_solution]` with a path relative to the source file that declares
the solution. With the solution in `src/domain/schedule.rs` and the file next
to `Cargo.toml` (the scaffold layout), that is
`solver_toml = "../../solver.toml"`; the full declaration is under
[Per-Solution Overlays](#per-solution-overlays).

The file is embedded at compile time, so the binary does not depend on its
working directory. Without `solver_toml`, a solve starts from
`SolverConfig::default()`; no file is read from the working directory. An
embedded file that does not parse fails the job with one `Failed` event whose
error starts with `solver configuration invalid: TOML parse error`.

The `solverforge` facade exports the configuration API, so app code that
inspects or builds configs needs no other dependency:

```rust
use solverforge::{
    AcceptorConfig, CandidateTraceConfig, ForagerConfig, MoveSelectorConfig, PhaseConfig,
    SolverConfig, SolverConfigOverride,
};
```

Configuration has three levels:

| Level | Scope | Typical owner |
| ----- | ----- | ------------- |
| Global config | environment mode, random seed, thread count, top-level termination, score director, candidate tracing | app/operator |
| Phase config | construction, local search, score ties, VND via `local_search_type`, partitioned search, custom phase names, phase-specific termination | app/operator |
| Model capabilities | candidate providers and metrics, nearby hooks, list operations/metadata, construction order keys, scalar groups | Rust model or binding |

The important rule is that config selects declared capabilities. It does not
invent model hooks. If a selector asks for nearby scalar candidates, grouped
scalar candidates, assignment-backed scalar groups, or conflict repair
providers, the model must expose those capabilities through the generated model
support layer.

Every table rejects keys it does not know, so a misspelt key fails to parse
instead of silently running on a default:

<!-- sf-toml: expect="parse-error" message="unknown field `seconds_spent_limt`" -->
```toml
[termination]
seconds_spent_limt = 30
```

SolverForge compiles the complete resolved policy before any phase runs. A bad
target, missing operation bundle, unknown provider or metric, invalid selector
composition, out-of-range value, or inconsistent construction source fails the
job with one `Failed` event that names its config path; the runtime does not
defer schema discovery until a hot candidate loop. On a model whose variable is
`employee_idx`, this config:

<!-- sf-toml: expect="solve-error" message="runtime compilation failed at phases[1].local_search.move_selector" -->
```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"

[phases.move_selector]
type = "change_move_selector"
variable_name = "employee_id"
```

fails with `runtime compilation failed at phases[1].local_search.move_selector:
... no scalar planning slot matches entity_class=None
variable_name=Some("employee_id")`.

## Loading Configuration

### Embedded in the model

`solver_toml = "..."` on `#[planning_solution]` embeds the file at compile
time and every `SolverManager` solve of that solution starts from it. This is
the normal setup; see the top of this page.

### From a TOML file at run time

`SolverConfig::load` reads a path relative to the process's working directory:

```rust
let config = SolverConfig::load("solver.toml").expect("solver.toml should parse");
```

To solve with a file chosen at run time, load it and return it from the
solution's [`config` callback](#per-solution-overlays), or pass it to
[`solve_with_config`](/docs/solverforge/solver/solver-manager/#solving-without-a-manager).

### From a TOML string

```rust
let config = SolverConfig::from_toml_str(r#"
    environment_mode = "reproducible"
    move_thread_count = { count = 4 }

    [termination]
    seconds_spent_limit = 120

    [[phases]]
    type = "construction_heuristic"
    construction_heuristic_type = "first_fit"

    [[phases]]
    type = "local_search"
    [phases.acceptor]
    type = "late_acceptance"
    late_acceptance_size = 400
"#).expect("config should parse");
```

TOML is the only configuration format.

## Example TOML File

This is a complete `solver.toml` for a model with a scalar `employee_idx`
variable:

```toml
environment_mode = "non_reproducible"
move_thread_count = "auto"

[termination]
seconds_spent_limit = 300
unimproved_seconds_spent_limit = 60

[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "preserve_unassigned"
value_candidate_limit = 32

[[phases]]
type = "local_search"

[phases.acceptor]
type = "simulated_annealing"
level_temperatures = [5.0, 500.0]
hard_regression_policy = "never_accept_hard_regression"

[phases.move_selector]
type = "change_move_selector"
variable_name = "employee_idx"
value_candidate_limit = 32

[phases.termination]
step_count_limit = 100000
```

## Configuration Options

### Environment Mode

Controls reproducibility and assertion levels.

| Mode               | Description                                                         |
| ------------------ | ------------------------------------------------------------------- |
| `non_reproducible` | Default. No checks; without `random_seed` each run draws its seed from the operating system. |
| `reproducible`     | No checks; without `random_seed` the solve uses the fixed seed `REPRODUCIBLE_RANDOM_SEED`, so step- or move-bounded runs repeat exactly. Wall-clock budgets can still change the result. |
| `fast_assert`      | As `reproducible`, plus every committed step and best-solution update is checked against a fresh full score calculation; drift panics. |
| `full_assert`      | As `fast_assert`, plus every score-director calculation is checked, including each evaluated move on the main director and on evaluator replicas. Slowest; for development. |

```toml
environment_mode = "non_reproducible"
```

Every mode except `non_reproducible` seeds a solve without `random_seed` with
`REPRODUCIBLE_RANDOM_SEED` (`0`). The assertion modes compare the kept score
with a fresh full calculation and panic with a `score director drift` message
that prints both scores; step-level checks also name the check, such as
`after update_best_solution`.

### Move Thread Count

Controls candidate evaluation in the compiled runtime's acceptor-forager local
search, independently of partitioned search's `thread_count`.

```toml
move_thread_count = { count = 4 }    # Request up to four evaluators
# move_thread_count = "auto"         # Default: sequential or parallel per step
# move_thread_count = "none"         # Sequential
```

The commented lines are alternative values for the same key; a file may set it
once.

| Value | Acceptor-forager local search |
| ----- | ----------------------------- |
| `"auto"` (default) | up to `min(4, rayon::current_num_threads())` evaluators; each step runs sequentially or in parallel windows, whichever is faster by the step's measured trial time, the previous step's candidate count, the calibrated cost of one window, and the last replica rebuild |
| `"none"` | sequential |
| `{ count = 1 }` | sequential |
| `{ count = N }`, N ≥ 2 | `min(N, rayon::current_num_threads(), 32)` evaluators |

The evaluator count includes the main score director; each further evaluator
holds a persistent replica, so `auto` forks at most three working-solution
replicas. `auto` switches mode only after 8 consecutive steps favour the other
one, and leaving parallel mode releases the replicas. `{ count = 0 }` is
rejected when the configuration is read. The thread count is read when the
local-search phase starts, on the Rayon pool it solves in, so a solve in a
one-thread pool stays sequential under every value, and compiling a
configuration starts no thread pool.

Only compiled acceptor-forager local search uses this setting, including the
child phases of a configured `partitioned_search`, which resolve it on the
partition's pool. Lower-level `LocalSearchPhase`, VND, construction, and
exhaustive search evaluate sequentially. Candidate generation and acceptance
stay ordered; parallel trials can pull candidates beyond the eventual decision
point. See
[Parallel Candidate Evaluation](/docs/solverforge/solver/local-search/#parallel-candidate-evaluation)
for reproducibility, speculative work, and budget semantics.

### Random Seed

`random_seed` fixes the seed in every environment mode, including
`non_reproducible`:

```toml
random_seed = 42
```

Without it, `reproducible`, `fast_assert`, and `full_assert` use
`REPRODUCIBLE_RANDOM_SEED`, and `non_reproducible` seeds each run from the
operating system. `SolverConfig::resolved_random_seed()` returns the seed a
solve uses, or `None` for an operating-system seed.

### Score Director

`[score_director]` selects the constraint provider a solve scores with and
whether its snapshots can be analyzed:

```toml
[score_director]
constraint_provider = "define_constraints"
constraint_match_enabled = true
```

`constraint_provider` names a `constraints` or `constraint_provider` path as
written in `#[planning_solution]`. When it is omitted, the solve scores with
the `constraints` function. A solution declares further providers with the
repeatable `constraint_provider = "path"` argument next to `constraints`. A
name the solution does not declare fails the job before solving with
`RuntimeBuildError::UnknownConstraintProvider`:

<!-- sf-toml: expect="solve-error" message="unknown constraint provider `define_relaxed_constraints`" -->
```toml
[score_director]
constraint_provider = "define_relaxed_constraints"
```

Each provider is its own monomorphized solve, and
`SolverManager::analyze_snapshot` analyzes a job's snapshots with the provider
the job scored with. `Analyzable::analyze` always uses the `constraints`
function.

`constraint_match_enabled` defaults to `true`. With `false`,
`SolverManager::analyze_snapshot` fails for that job with
`SolverManagerError::SnapshotAnalysisDisabled`.

### Candidate Trace

Candidate tracing is an opt-in diagnostic surface. It records a bounded ordered
prefix at the engine candidate-pull boundary:

```toml
[candidate_trace]
max_entries = 4096
```

Each retained pull can carry its phase and step, selector/source index, logical
operation identity, construction target, and ordered disposition transitions
such as evaluated, rejected, selected, and applied. The header owns canonical
config, execution policy, resolved phase plan, and optional externally attested
input/qualification provenance. `max_entries` must be nonzero; truncation is
reported explicitly.

Ordinary events, status, and snapshots stay compact. Read the trace together
with the exact aggregate publication using
`SolverManager::get_telemetry_detail(job_id)`.

### Phases

Phases run in sequence. A typical configuration uses a construction heuristic
followed by local search:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"

[[phases]]
type = "local_search"
score_tie_break = "random"
[phases.acceptor]
type = "tabu_search"
entity_tabu_size = 7
```

When `phases` are omitted, the runtime runs state-aware construction: matching
specialized list construction, named grouped `FirstFit` for required assignment
rows followed by grouped `CheapestInsertion` for optional rows, and single-slot
construction for remaining non-assignment-owned scalars. One streaming default
local-search phase is eligible only when top-level termination contains an
effective parsed limit. Missing termination or an empty termination object
leaves omitted phases construction-only. A `best_score_limit` that does not
parse as the model's score fails the solve. This is separate from omitting
`move_selector` inside an explicit local-search phase. VND is never prepended
implicitly.

See [Phases](/docs/solverforge/solver/phases/) for all phase types and their options.

### Phase Anatomy

Most production configs have this shape:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "preserve_unassigned"
value_candidate_limit = 32

[[phases]]
type = "local_search"

[phases.acceptor]
type = "late_acceptance"
late_acceptance_size = 400

[phases.forager]
type = "accepted_count"
limit = 4

[phases.move_selector]
type = "union_move_selector"
selection_order = "stratified_random"
weighting = "equal"

[[phases.move_selector.selectors]]
type = "change_move_selector"
value_candidate_limit = 32
selection_order = "random"

[[phases.move_selector.selectors]]
type = "swap_move_selector"

[phases.termination]
step_count_limit = 100000
```

Construction creates the first workable solution. Local search improves it.
The acceptor decides whether a scored candidate can be accepted. The forager
decides which accepted candidate is committed. The move selector decides which
candidate moves are pulled. `score_tie_break = "random"` is the seeded default
for equally scored best candidates; use `first` to retain the first equal best
candidate instead. Variable neighborhood descent applies the same setting to
equally scored best improving moves of a neighborhood.

### Move Selectors

For config-driven local search, move selection lives under
`[phases.move_selector]`.

```toml
[phases.move_selector]
type = "nearby_list_change_move_selector"
max_nearby = 12
variable_name = "visits"
```

Nearby selection is configured by choosing a nearby selector variant, not by
top-level `nearby_selection = true` flags.

Every non-composite leaf selector accepts an optional `selection_order`:

| Value | Behavior |
| ----- | -------- |
| `original` | preserve the canonical cursor order |
| `random` | seeded random pull order; used by omitted local-search defaults |
| `shuffled` | seeded full shuffle |
| `sorted` | sort a complete stream by a registered `selection_metric` |
| `probabilistic` | sample a complete stream by non-negative weights from a registered `selection_metric` |

```toml
[phases.move_selector]
type = "change_move_selector"
variable_name = "employee_idx"
selection_order = "sorted"
selection_metric = "assignment_priority"
```

`sorted` and `probabilistic` require a named runtime candidate metric;
`selection_metric` is rejected for the other orders. Advanced native or binding
runtimes register immutable metrics on
`RuntimeModel::with_candidate_metrics(...)`. Unknown names, non-finite results,
and negative probabilistic weights fail explicitly.

Union selectors have their own scheduling policy. `selection_order` can be
`sequential`, `round_robin`, `rotating_round_robin`, `random`, or the default
`stratified_random`. `weighting` is `equal` by default, `fixed` with a `weights`
vector, or `candidate_count` to derive child weights from declared candidate
counts. With `fixed`, a zero weight disables its child: the union never opens
it and leaves it out of the union's size. At least one weight must be
positive:

```toml
[phases.move_selector]
type = "union_move_selector"
selection_order = "stratified_random"
weighting = "fixed"
weights = [3, 1]

[[phases.move_selector.selectors]]
type = "change_move_selector"

[[phases.move_selector.selectors]]
type = "swap_move_selector"
```

Nearby scalar selectors require model-declared candidate hooks on the matching
`#[planning_variable]`: `nearby_value_candidates` for
`nearby_change_move_selector` and `nearby_entity_candidates` for
`nearby_swap_move_selector`. Distance meters only rank or filter those bounded
candidates.

List selectors likewise select declared list capabilities. `list_permute_move_selector`
permutes a bounded window in one list. `list_precedence_move_selector` targets
list variables that expose `precedence_duration_fn` and
`precedence_successors_fn` hooks through `#[planning_list_variable]`; it streams
critical-path support moves for generic precedence makespan models.

```toml
[phases.move_selector]
type = "list_permute_move_selector"
variable_name = "operations"
min_window_size = 2
max_window_size = 5
```

```toml
[phases.move_selector]
type = "list_precedence_move_selector"
entity_class = "Route"
variable_name = "operations"
```

When you need to cap one neighborhood deliberately, use the
`limited_neighborhood` selector variant and wrap the concrete selector inside
it:

```toml
[phases.move_selector]
type = "limited_neighborhood"
selected_count_limit = 24

[phases.move_selector.selector]
type = "change_move_selector"
variable_name = "employee_idx"
```

That cap applies to the wrapped neighborhood itself. It is separate from the
accepted-count forager `limit`, which stops a selector step after that many
accepted candidates and then picks the best candidate inside that step horizon.

Scalar `change_move_selector`, `nearby_change_move_selector`,
`pillar_change_move_selector`, and `ruin_recreate_move_selector` accept
`value_candidate_limit`. Scalar `cheapest_insertion` requires a bounded
candidate source: either `candidate_values` on the model or this config limit.

Numeric selector and construction values are range-checked when the config is
compiled, before any phase runs; a value outside its range fails the job at its
key path. Every candidate, group, move, match, and repair limit is at least 1
when set, as are `max_nearby` on nearby selectors and `selected_count_limit`.
Ranges are `1 <= min_sublist_size <= max_sublist_size`,
`2 <= min_window_size <= max_window_size <= 8`,
`1 <= min_ruin_count <= max_ruin_count`, k-opt `k` from 2 to 5 with
`min_segment_len >= 1`, and pillar sizes either both 0 (whole pillars) or
`1 <= minimum_sub_pillar_size <= maximum_sub_pillar_size`. Acceptor and forager
values are checked the same way: tabu and late-acceptance sizes, the
accepted-count `limit`, and `step_counting_hill_climbing.step_count_limit`
must be positive; `great_deluge.water_level_increase_ratio` must be positive
and finite; simulated annealing needs one temperature per score level, and
its `level_temperatures` and `calibration` are alternatives that cannot be set
together.

Construction keys are checked against the heuristic. `group_candidate_limit`
requires `group_name`. List heuristics (`list_round_robin`,
`list_cheapest_insertion`, `list_regret_insertion`, `list_clarke_wright`, and
`list_k_opt`) reject `value_candidate_limit`, `group_candidate_limit`, and any
`construction_obligation` other than the default. `k` is `2` by default;
`list_k_opt` accepts 2 to 5, and every other heuristic rejects any value but
`2`.

Grouped scalar construction and grouped scalar local search use `group_name`
when the model provides a scalar group through the generated model support
surface. Grouped local search also supports `require_hard_improvement` when a
compound candidate must improve the hard score before it can be accepted.

Assignment-backed scalar construction and repair use the same `group_name`
surface. The model declares `ScalarGroup::assignment(...)`; construction
generates stock nullable scalar assignment candidates and local search repairs
uncovered required entities, capacity conflicts, bounded reassignments, and
sequence/position rematches:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
group_name = "required_shift_assignment"
value_candidate_limit = 8
group_candidate_limit = 64

[[phases]]
type = "local_search"

[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "required_shift_assignment"
max_moves_per_step = 64
require_hard_improvement = true
```

Assignment augmenting depth and sequence/position rematch size are declared
with `ScalarGroup::with_limits(ScalarGroupLimits { ... })`, not as additional
TOML selector fields. `max_augmenting_depth` defaults to 3; `max_rematch_size`
defaults to 4 and is clamped to at least 2. Construction config candidate limits
override corresponding model limits; grouped local search exposes
`value_candidate_limit` and `max_moves_per_step`. See
[Assignment Limits](/docs/solverforge/solver/construction/#assignment-limits).

Keeping an optional assignment unassigned completes that group-slot decision
without ending the optional pass. Completed roots are excluded before candidate
domains are read, preserving later rows' candidate budget. Assigned occupants
remain available for required augmenting rematches.

Grouped construction example:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
group_name = "task_operator_assignment"
value_candidate_limit = 32
group_candidate_limit = 128
```

Grouped local-search example:

```toml
[phases.move_selector]
type = "grouped_scalar_move_selector"
group_name = "task_operator_assignment"
value_candidate_limit = 32
max_moves_per_step = 256
require_hard_improvement = true
```

Conflict-repair selectors configure `constraints` by exact scoring metadata
identity. Use `ConstraintRef::full_name()` for package-qualified constraints and
the short name for package-less constraints. With `include_soft_matches = false`,
soft constraints are rejected before providers run; setting it to `true`
explicitly allows soft repair providers. Conflict repair operates on
non-assignment-owned scalar variables; assignment-backed scalar slots stay on
their owning grouped scalar selector path.

Compound repair example:

```toml
[phases.move_selector]
type = "compound_conflict_repair_move_selector"
constraints = ["schedule/no_overlapping_operator_assignment"]
max_matches_per_step = 16
max_repairs_per_match = 32
max_moves_per_step = 256
require_hard_improvement = true
```

### Variable Neighborhood Descent

VND is a local-search type, not a standalone `type = "vnd"` phase:

```toml
[[phases]]
type = "local_search"
local_search_type = "variable_neighborhood_descent"

[[phases.neighborhoods]]
type = "change_move_selector"
variable_name = "employee_idx"

[[phases.neighborhoods]]
type = "swap_move_selector"
variable_name = "employee_idx"
```

The `variable_neighborhood_descent` mode uses ordered `neighborhoods` and rejects
`acceptor`, `forager`, and `move_selector`. The default `acceptor_forager`
local-search mode uses `acceptor`, `forager`, and `move_selector`.

### Partitioned And Custom Search

`partitioned_search` requires a named partitioner compiled into the solution's
typed search surface. SolverForge does not infer partitions from a count:

```toml
[[phases]]
type = "partitioned_search"
partitioner = "by_vehicle"
thread_count = "auto"
log_progress = true

[[phases.child_phases]]
type = "construction_heuristic"
construction_heuristic_type = "list_cheapest_insertion"

[phases.termination]
seconds_spent_limit = 20
```

The search function registers the partitioner with
`SearchBuilder::partitioner("by_vehicle", |context| partitioner)`, and the
framework builds and runs the phase. Each partition is solved with the parent
configuration, `child_phases` as its phases (an empty list runs the default
phases), and a director forked over that partition. A child phase that does
not compile fails the solve at its
`phases[i].partitioned_search.child_phases[j]` path.

`thread_count = "auto"` runs one thread per partition, up to the available
cores and the partitioner's `recommended_partition_count`; `"none"` runs one
thread, and `{ count = N }` (N ≥ 1) at most N. The phase's `termination`
bounds the partitions: its time limit, counted from the phase's start, holds
for all partitions, and its `step_count_limit` for each partition's solve. A
partition that reaches the bound keeps its best solution, the partitions are
merged, and the solve continues with the next phase. `best_score_limit`,
`unimproved_step_count_limit`, and `unimproved_seconds_spent_limit` need the
merged solution's score, so a `partitioned_search` termination that sets one
fails the solve at its `phases[i].partitioned_search.termination.<key>` path.

Custom phases are also compiled into the solution with
`#[planning_solution(search = "...")]` and selected by name:

```toml
[[phases]]
type = "custom"
name = "weekend_repair"
```

There is no arbitrary `custom_phase_class` loader or erased plugin registry.

### Construction Obligation

Nullable scalar variables default to `preserve_unassigned`: construction may
leave `None` in place when that is legal and scores best. Use
`assign_when_candidate_exists` when construction should assign a doable value
whenever one exists:

```toml
[[phases]]
type = "construction_heuristic"
construction_heuristic_type = "first_fit"
construction_obligation = "assign_when_candidate_exists"
```

### Termination

Controls when the solver stops. Every configured criterion applies, and the
first one reached stops the solve; nothing is added that the file does not
set. See [Termination](/docs/solverforge/solver/termination/) for all options.

```toml
[termination]
seconds_spent_limit = 300
```

Configured solver and phase limits remain binding during required scalar and
list construction. SolverForge publishes a best solution only after every
mandatory list element, required assignment row, and non-optional scalar slot
is assigned. If a limit fires first, the retained job ends as `Failed` without
publishing an incomplete solution or snapshot.

### Programmatic Builders

`SolverConfig` also exposes simple builder helpers:

```rust
let config = SolverConfig::new()
    .with_random_seed(42)
    .with_termination_seconds(30);
```

## Per-Solution Overlays

Retained solves can layer per-solution policy on top of the embedded
`solver.toml` with `config = "..."` on `#[planning_solution]`:

```rust
#[planning_solution(
    constraints = "define_constraints",
    solver_toml = "../../solver.toml",
    config = "solver_config_for_solution"
)]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[problem_fact_collection]
    pub rooms: Vec<Room>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
    pub time_limit_secs: u64,
}

fn solver_config_for_solution(solution: &Schedule, config: SolverConfig) -> SolverConfig {
    config.with_termination_seconds(solution.time_limit_secs)
}
```

The callback receives the embedded `solver.toml` config, or
`SolverConfig::default()` when the solution names no file, and returns the
config the job runs. Decorate the base config rather than replace it, unless
the callback loads a file of its own. `with_termination_seconds` sets
`seconds_spent_limit` and keeps the other termination keys, so with the example
file above a solution with `time_limit_secs = 2` stops after two seconds.

## Runtime Overrides

`SolverConfigOverride` changes a configuration at run time without editing
it. `SolverConfig::with_override(&overrides)` replaces each field the override
sets. Its one field is `termination`, which replaces the solver-level
`[termination]` and leaves phase terminations unchanged.
`SolverConfigOverride::with_termination(termination)` builds one.
`SolverManager::solve_with_override(solution, overrides)` starts a retained job
whose solve applies the override after the embedded `solver.toml` and the
`config` callback, before it builds its phases and termination. Jobs started
with `solve(...)` run their configuration unchanged.

## See Also

- [Construction](/docs/solverforge/solver/construction/) — Construction policy and grouped scalar construction
- [Local Search](/docs/solverforge/solver/local-search/) — Acceptors, foragers, and move selectors
- [Moves](/docs/solverforge/solver/moves/) — Selector families and move behavior
- [Termination](/docs/solverforge/solver/termination/) — Termination conditions
- [SolverManager](/docs/solverforge/solver/solver-manager/) — Running the solver
