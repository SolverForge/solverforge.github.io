---
title: "Maintenance Planning with the Agent Skill"
linkTitle: "Maintenance Walkthrough"
icon: fa-solid fa-screwdriver-wrench
date: 2026-10-28
weight: 1
description: "One coding-agent run with the solverforge-modeling skill: a depot maintenance problem described in plain language becomes a solved plan behind a SolverForge API shell."
categories: [Quickstarts]
tags: [quickstart, rust, agent-skill, maintenance, scheduling]
---

# Maintenance Planning with the Agent Skill

## Table of Contents

1. [Introduction](#introduction)
2. [Before You Start](#before-you-start)
3. [Describe the Problem](#describe-the-problem)
4. [The Model](#the-model)
5. [Scaffold and Grow the App](#scaffold-and-grow-the-app)
6. [Writing Constraints](#writing-constraints)
7. [Demo Data](#demo-data)
8. [Solve It](#solve-it)
9. [Decisions to Review](#decisions-to-review)
10. [Complete Source](#complete-source)
11. [Where to Go Next](#where-to-go-next)

---

## Introduction

A city bus depot has 12 buses, 4 technicians, and 20 one-day maintenance jobs
to fit into the next 10 working days. Parts arrive on different days, every job
has a due day, and the depot has to keep at least 10 buses on the road every
day.

This walkthrough follows a coding agent with the
[`solverforge-modeling` skill](/docs/solverforge-cli/agent-skill/) from that
paragraph to a solved plan:

- the problem description and the answers to the skill's intake questions
- the model the agent derived: facts, entities, planning variables, constraints
- the `solverforge` commands that scaffold and grow the app
- the seven constraints the agent wrote, with what each one reads and scores
- deterministic demo data for the depot
- a real solve through the API shell, ending at `0hard/-100soft`: no hard
  violations, no late jobs, and the best possible workload balance

The run used Claude Code. The model is ordinary Rust in a CLI-managed project,
so every step below can also be done by hand with the
[CLI quickstart](/docs/solverforge-cli/getting-started/).

## Before You Start

- Rust stable `1.95+` and Cargo
- `solverforge-cli 3.7.1`, which scaffolds `solverforge 0.23.0`:

  ```bash
  cargo install solverforge-cli
  solverforge --version
  ```

- The skills installed into your agent, then a restart of the agent:

  ```bash
  git clone https://github.com/SolverForge/solverforge-cli
  cd solverforge-cli
  ./scripts/install-skill --agent claude     # or: --agent codex, --agent opencode
  ```

## Describe the Problem

The skill starts by asking for the problem in your words, the output shell, the
hard and soft constraints, and the score type. Answering all four in the first
message lets the agent build without stopping. This is the complete prompt for
the run:

```text
Use the solverforge-modeling skill to turn this planning problem into a runnable SolverForge app.

## The problem

We run a city bus depot with 12 buses. Over the next 10 working days we have 20
maintenance jobs to schedule. Each job belongs to one bus, needs one skill
(mechanical, electrical, or bodywork), and takes one full day. A job cannot
start before its parts arrive (an earliest day), and it has a due day.

We have 4 technicians. Each technician has one or more of the three skills and
can work on at most one job per day.

A bus that is in the workshop on a given day is out of service that day. The
depot must keep at least 10 of its 12 buses in service every day, so no more
than 2 different buses may be in the workshop on the same day.

For every job we need to decide which technician does it and on which day.

## Intake answers (treat these as confirmed; do not stop to ask)

- Output shell: `api` (headless HTTP API, no browser UI).
- Hard constraints (a plan that breaks any of these is invalid):
  1. The technician has the skill the job needs.
  2. A technician does at most one job per day.
  3. A job is not scheduled before its parts arrive.
  4. At most 2 different buses are in the workshop on any day.
  5. Every job gets a technician and a day.
- Soft constraints (optimize):
  1. Finish jobs by their due day; penalize each day late.
  2. Spread work evenly across technicians.
- Score type: `HardSoftScore`.
- Name the app `depot-maintenance` and create it in the current directory.
- Demo data: replace the generic sample data with the depot described above
  (12 buses, 20 jobs, 4 technicians, 10 days), deterministic, with a feasible
  plan possible.

When you echo the model back, keep going instead of waiting for confirmation.
Finish only after a real solve completes with a score, as the skill requires.
At the end, list every `solverforge` command you ran, in order, and the final
score of the verification solve.
```

Without the intake answers, the agent asks for them and restates the model for
you to confirm before it scaffolds anything.

## The Model

The agent turned the paragraph into this model:

| Part | In this app |
| --- | --- |
| Planning solution | `Plan`, scored with `HardSoftScore` |
| Problem facts (fixed input) | `Technician` with its `skills`, and `Bus` |
| Planning entity (what the solver changes) | `Job`, with its `bus_idx`, `skill`, `earliest_day`, and `due_day` |
| Planning variables | `Job.technician_idx`, a scalar over the `technicians` collection, and `Job.day`, a scalar over the integer range `0..10` |
| Hard constraints | `technician_skill`, `technician_one_per_day`, `parts_arrived`, `workshop_capacity`, `job_assigned` |
| Soft constraints | `late_job`, `balanced_workload` |

Two modeling choices carry the problem:

- **A job is one entity with two variables.** The decision is a pair:
  technician and day. Neither depends on a sequence, so both are scalar
  variables, not a list.
- **Both variables may stay unassigned.** `--allows-unassigned` lets the solver
  represent a job without a technician or a day, and the `job_assigned` hard
  constraint makes that state invalid. The other constraints skip
  unassigned values instead of guessing.

The readiness rule ("at least 10 of 12 buses in service") becomes "at most 2
different buses in the workshop on one day", a count the solver can check per
day.

## Scaffold and Grow the App

The agent first read the live CLI contract with `solverforge --version`,
`solverforge new --help`, `solverforge generate variable --help`, and
`solverforge generate constraint --help`. Then it scaffolded the API shell and
grew the model:

```bash
solverforge new depot-maintenance --shell api
cd depot-maintenance

solverforge generate fact technician --field index:usize --field 'skills:Vec<String>'
solverforge generate fact bus --field index:usize
solverforge generate entity job --field bus_idx:usize --field skill:String --field earliest_day:usize --field due_day:usize

solverforge generate variable technician_idx --entity Job --kind scalar --range technicians --allows-unassigned
solverforge generate variable day --entity Job --kind scalar --countable-range 0..10 --allows-unassigned

solverforge generate constraint technician_skill --join --hard
solverforge generate constraint technician_one_per_day --pair --hard
solverforge generate constraint parts_arrived --unary --hard
solverforge generate constraint workshop_capacity --collect-vec --hard
solverforge generate constraint job_assigned --unary --hard
solverforge generate constraint late_job --unary --soft
solverforge generate constraint balanced_workload --balance

solverforge check
```

- Quote field types that contain `<` or `>`. Unquoted, `skills:Vec<String>` is
  a shell redirection; the run's first attempt failed on exactly that.
- `--countable-range 0..10` gives `day` the values 0 through 9 without a
  separate day fact.
- Each `generate constraint` flag picks a stream shape: `--join` for an
  entity-fact match, `--pair` for two entities, `--unary` for one entity at a
  time, `--collect-vec` for grouped rows, `--balance` for load balancing. The
  generated file is wiring; the predicate and weight are still yours to write.

Everything these commands generate stays exactly as the CLI wrote it. The agent
then edited nine files by hand: the seven constraint files and two data files.

## Writing Constraints

Each constraint streams jobs from the `Plan::jobs()` accessor the CLI
generated, then filters, joins, or groups them before it scores.

### The technician has the skill

A join from each job to the technician its `technician_idx` points at. The
join key is the technician's index on both sides; an unassigned job has key
`None` and matches no technician.

```rust
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .join((
            Plan::technicians(),
            equal_bi(entity_join_key, fact_join_key),
        ))
        .penalize(hard_weight(join_weight))
        .named("technician_skill")
}

fn entity_join_key(job: &Job) -> Option<usize> {
    job.technician_idx
}

fn fact_join_key(technician: &Technician) -> Option<usize> {
    Some(technician.index)
}

fn join_condition(job: &Job, technician: &Technician) -> bool {
    !technician.skills.iter().any(|skill| skill == &job.skill)
}
```

### One job per technician per day

A self-join pairs jobs that share a technician; each pair on the same day is
one hard point. Three jobs for one technician on one day are three pairs, so
the penalty grows with the size of the clash.

```rust
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .join(joiner::equal(technician_idx_join_key))
        .penalize(hard_weight(pair_weight))
        .named("technician_one_per_day")
}

fn technician_idx_join_key(job: &Job) -> Option<usize> {
    job.technician_idx
}

fn pair_condition(left: &Job, right: &Job) -> bool {
    left.technician_idx.is_some() && left.day.is_some() && left.day == right.day
}
```

### Parts before work, every job assigned

Two unary rules read one job at a time. `parts_arrived` penalizes a day before
the job's `earliest_day`:

```rust
fn unary_condition(job: &Job) -> bool {
    job.day.is_some_and(|day| day < job.earliest_day)
}
```

`job_assigned` penalizes a job that is still missing either decision:

```rust
fn unary_condition(job: &Job) -> bool {
    job.technician_idx.is_none() || job.day.is_none()
}
```

### At most two buses in the workshop

This is the readiness rule, and the only one that needs grouping:

- **Input rows:** jobs that have a day.
- **Bucket key:** the day.
- **Collected value:** the job's bus.
- **Score:** one hard point for each distinct bus beyond two in that day's
  bucket.

Two jobs on the same bus on the same day keep one bus off the road, not two,
which is why the weight counts distinct buses instead of jobs.

```rust
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .filter(has_day)
        .group_by(day_group_key, collect_vec(collected_bus))
        .penalize(hard_weight(collected_values_weight))
        .named("workshop_capacity")
}
```

```rust
fn buses_over_limit(buses: &CollectedVec<usize>) -> usize {
    let distinct = buses.iter().collect::<HashSet<_>>().len();
    distinct.saturating_sub(MAX_BUSES_IN_WORKSHOP)
}
```

For example, if day 1 holds two jobs on Bus 101 and one on Bus 102, the day's
bucket collects three bus indexes but only two distinct buses, and scores
`0hard`. A job on Bus 103 the same day makes three distinct buses and scores
`-1hard`.

### Finish by the due day

A soft penalty of 10 points for every day a job lands after its due day. The
weight is a constant so you can retune it in one place.

```rust
const SOFT_PER_LATE_DAY: i64 = 10;
```

```rust
fn days_late(job: &Job) -> usize {
    job.day.map_or(0, |day| day.saturating_sub(job.due_day))
}
```

### Spread the work

All jobs go into one scope, and `load_balance` counts jobs per technician. The
penalty is the sum of each technician's job count squared, which is smallest
when the counts are equal and always improves when a job moves from a busier
technician to a less busy one.

```rust
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .group_by(
            balance_scope,
            load_balance(balance_group_key, balance_metric),
        )
        .penalize(balance_weight)
        .named("balanced_workload")
}
```

```rust
fn balance_weight(_scope: &usize, load: &LoadBalance<Option<usize>>) -> HardSoftScore {
    let squared_loads = load
        .loads()
        .iter()
        .filter(|(technician_idx, _)| technician_idx.is_some())
        .map(|(_, jobs)| jobs * jobs)
        .sum();
    HardSoftScore::of_soft(squared_loads)
}
```

With 20 jobs and 4 technicians the best split is 5, 5, 5, 5, which scores
`4 × 5² = 100`. A perfect plan therefore ends at `-100soft`, not zero.

Every constraint file also carries unit tests that build a small `Plan` and
check its exact score with `(constraint(),).evaluate_all(&plan)`.

## Demo Data

The depot lives in its own module, `src/data/depot.rs`, as two tables:

```rust
const TECHNICIANS: &[(&str, &[&str])] = &[
    ("Alice", &[MECHANICAL, ELECTRICAL]),
    ("Ben", &[MECHANICAL, BODYWORK]),
    ("Chloe", &[ELECTRICAL, BODYWORK]),
    ("Dev", &[MECHANICAL]),
];
```

```rust
/// (bus index, skill, earliest day parts arrive, due day)
const JOBS: &[(usize, &str, usize, usize)] = &[
    (0, MECHANICAL, 0, 2),
    (0, ELECTRICAL, 0, 3),
    (1, BODYWORK, 0, 3),
```

The 20 rows continue through day 9. The stable wrapper in `src/data/mod.rs`
routes every demo-data id to the depot, and the CLI-owned seed file stays
untouched so `solverforge generate data` can still regenerate it:

```rust
pub fn generate(_demo: DemoData) -> Plan {
    depot::depot_plan()
}
```

A `reference_plan_is_feasible` test in `depot.rs` assigns a hand-built schedule
and asserts it has no hard violations, so the dataset is known to be solvable.

## Solve It

Run the app's tests, then the skill's smoke test:

```bash
cargo test
bash ~/.claude/skills/solverforge-modeling/scripts/solve-smoke-test.sh .   # the skill's install path for your agent
```

`cargo test` runs the 20 unit tests. The smoke test builds the app in release
mode, boots it, solves the default demo data, and requires a `COMPLETED` job
with a score.

To drive the API yourself, start the server and run one job:

```bash
solverforge server
```

```bash
curl -s localhost:7860/demo-data/STANDARD > plan.json
curl -s -X POST -H 'content-type: application/json' --data @plan.json localhost:7860/jobs
# {"id":"0"}
curl -s localhost:7860/jobs/0          # lifecycleState, bestScore, telemetry
curl -s localhost:7860/jobs/0/snapshot # the solved Plan
curl -s localhost:7860/jobs/0/analysis # the score by constraint
```

The solve runs for the 30 seconds set in `solver.toml` and finishes with
`lifecycleState` `COMPLETED` and `bestScore` `0hard/-100soft`. The analysis
endpoint shows where that score comes from:

| Constraint | Score |
| --- | --- |
| `technician_skill` | `0hard/0soft` |
| `technician_one_per_day` | `0hard/0soft` |
| `parts_arrived` | `0hard/0soft` |
| `workshop_capacity` | `0hard/0soft` |
| `job_assigned` | `0hard/0soft` |
| `late_job` | `0hard/0soft` |
| `balanced_workload` | `0hard/-100soft` |

Every hard rule holds, no job is late, and each technician has five jobs. More
than one schedule reaches this score, so two runs can place jobs on different
days with the same result.

## Decisions to Review

The agent made three choices the prompt did not specify. Check them against
your own depot before you rely on the plan:

- **Lateness weight.** One late day costs 10 soft points, so meeting due days
  outranks an even split of work.
- **Balance never reaches zero.** The squared-load penalty bottoms out at
  `-100soft` for this dataset.
- **One dataset for every id.** `SMALL`, `STANDARD`, and `LARGE` all return the
  depot.

## Complete Source

The nine hand-written files from this run are published with the site source,
in the
[maintenance walkthrough source directory](https://github.com/SolverForge/solverforge.github.io/tree/main/scripts/fixtures/maintenance-walkthrough).
Copy them over a project produced by the commands in
[Scaffold and Grow the App](#scaffold-and-grow-the-app) to get the complete app:

| File | Contents |
| --- | --- |
| `src/constraints/technician_skill.rs` | skill match, join |
| `src/constraints/technician_one_per_day.rs` | technician clash, self-join |
| `src/constraints/parts_arrived.rs` | parts arrival, unary |
| `src/constraints/workshop_capacity.rs` | readiness floor, grouped |
| `src/constraints/job_assigned.rs` | every job assigned, unary |
| `src/constraints/late_job.rs` | lateness, weighted unary |
| `src/constraints/balanced_workload.rs` | workload balance, load balance |
| `src/data/depot.rs` | depot dataset and feasibility test |
| `src/data/mod.rs` | demo-data wrapper |

## Where to Go Next

- [Fleet readiness](/use-cases/fleet/) carries the same planning question to
  full scale: 24 vessels over 56 days, with docks, technician pools, parts
  deliveries, inspections, training, and daily readiness floors.
- Ask the agent for `--shell web` and the
  [`solverforge-ui` skill](/docs/solverforge-cli/agent-skill/) to put a browser
  workspace on the same model, or `--shell mcp` to hand the solver to another
  agent through the [MCP Shell](/docs/solverforge-cli/mcp-shell/).
- [Modeling & Generation](/docs/solverforge-cli/modeling-and-generation/)
  covers every generator the agent used.
