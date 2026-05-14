---
title: "How We Benchmark SolverForge"
date: 2026-05-14
draft: false
tags: [benchmarks]
description: >
  SolverForge benchmarks are built as reproducible engineering evidence: shared
  harness, explicit model parity, independent validation, scoped comparisons,
  and cataloged result artifacts.
---

Benchmarking an optimization engine is easy to do badly.

Run one solver on one case, copy the best number into a chart, and the result
looks objective. It is not. The harder part is proving that every solver saw the
same mathematical problem, received the same budget, returned a solution that
was independently validated, and was judged by a ranking rule that matches the
problem.

That is the standard we are building for SolverForge.

We are treating benchmarks as engineering evidence, not marketing copy. A good
benchmark should help us answer three questions:

- Does SolverForge model this class of problem correctly?
- Under an equal run policy, what solution quality does it return?
- When it loses, what solver capability is missing?

That third question matters most. The point is not to manufacture universal
winner tables. The point is to expose the next concrete runtime, modeling, or
move-selection capability SolverForge needs.

## Grouped by Solve Shape

The benchmark suite is organized by SolverForge solve shape, not by demo name.
That keeps each comparison tied to the part of the engine it exercises.

`list-variable/cvrp/` covers capacitated vehicle routing. It exercises route
construction, route mutation, list variables, route-cost validation, and
large-neighborhood behavior.

`scalar-variable/employee-scheduling/` covers nurse rostering on the bundled
INRC-II TXT corpus. It exercises nullable scalar assignment, hard feasibility,
coverage requirements, consecutive-run scoring, and soft objective weights.

Those categories are intentionally different. A routing benchmark that says
"SolverForge is good at list variables" does not prove that SolverForge is good
at nurse assignment. A nurse rostering benchmark that closes a scalar
assignment gap does not prove the list-variable runtime is competitive on large
CVRP instances. We keep the categories separate because the solver mechanics
are separate.

## One Harness, Thin Adapters

Each problem package is an adapter. It can load cases, select instances, create
solver callables, validate returned solutions, evaluate costs, and expose
native result fields.

The shared benchmark framework owns everything else:

- CLI and TOML configuration
- benchmark registration
- solver, instance, and time-limit matrices
- wall-clock timing
- overshoot calculation
- watchdog containment
- result rows
- CSV evidence files
- run logs and solver stdout/stderr capture
- optional PostgreSQL persistence

That boundary is deliberate. If each benchmark script owned its own timing,
logging, CSV schema, watchdog policy, and database loading, comparisons would
drift immediately. A result row from CVRP would not mean the same thing as a
result row from employee scheduling. A failed solver invocation might disappear
in one benchmark and become a row in another.

So orchestration lives in one place. Problem code stays focused on the problem.

## Parity Before Performance

For employee scheduling, `validate-employee-model-parity` is not a benchmark
run. It is a contract check.

It verifies that the SolverForge, Timefold, and OR-Tools adapters encode the
same mathematical model: hard feasibility clauses, candidate domains, generated
coverage slots, and soft objective weights. It also runs bundled reference
solutions through the shared Python validator.

That step matters because a fast wrong model is not a fast solver. If one
adapter quietly omits a hard rule, or if two adapters attach different weights
to the same soft rule, the timing comparison is already invalid.

The same principle applies to CVRP. The benchmark has to validate returned
routes against the instance data and recompute cost through the benchmark's
referee logic. Solver-reported cost is useful diagnostic data, but it is not
the final authority.

## Time Budgets Are Inputs, Not Kill Switches

The requested time limit is passed to the solver and measured around the solver
call. The benchmark records the actual wall-clock duration, computes overshoot,
and preserves late returned solutions.

That distinction is important. A solver that returns a valid solution slightly
after a nominal budget still produced evidence. Throwing that solution away
would hide useful behavior. Instead, the row records:

- requested time limit
- actual time
- overshoot in seconds
- overshoot ratio
- whether the run exceeded the configured wall-time tolerance

The watchdog is separate. It exists to contain runaway child processes. Only a
watchdog kill loses the returned solution, because the process was forcibly
terminated.

This gives us a more honest picture than treating the nominal budget as a hard
process kill. We can see both solution quality and time discipline.

## Ranking Must Match the Problem

Ranking rules are part of the benchmark, not an afterthought.

For employee scheduling, hard feasibility comes first. A lower soft cost does
not beat a schedule with invalid coverage, invalid shift assignment, or a
broken hard constraint. Once two results are hard-feasible, the validator cost
is the comparison value.

For routing, feasibility and route validity come before distance or objective
quality. A short route that violates capacity or drops required visits is not a
better route.

This is why SolverForge benchmark tables should not collapse every result into
one universal "quality ratio" without context. Some rows have reference costs.
Some rows do not. Some categories need feasibility-first ordering. Some need a
domain-specific validator cost. A defensible article or chart must state the
ranking rule beside the result.

## Run Kinds and Evidence

We separate run intent from run mechanics.

`quick` runs are smoke-scale checks. They are small enough to run frequently and
catch model, adapter, and harness regressions.

`candidate` runs are broader comparison runs before a release snapshot. They
exercise the normal solver set across the canonical benchmark selection.

`tag` runs are release snapshots and require an explicit release tag. They are
meant to answer "what did SolverForge version X do under this benchmark
contract?"

Nightly execution is a separate flag, not a separate kind. A nightly run can be
quick, candidate, or tag. That keeps scheduled automation distinct from the
meaning of the result.

The development loop is intentionally explicit:

```sh
make validate-cvrp
make validate-employee-scheduling
make validate-employee-model-parity

make bench-cvrp-quick
make bench-employee-scheduling-quick
make bench-nightly-db
```

Every serious run needs evidence attached to it: command arguments, git commit,
dirty-tree state, Python version, solver set, time limits, run logs, solver
stdout/stderr logs, and the emitted rows. CSV files remain useful portable
artifacts, but PostgreSQL is the warehouse for cataloged runs. Display
consumers should read the checked views rather than reconstructing joins or
parsing older native files themselves.

## What We Publish

When we publish benchmark results, the claim has to be scoped.

A defensible result says which dataset, which instance family, which time
budgets, which solvers, which validator, and which ranking rule were used. For
example, an employee-scheduling comparison over `n005w4` at `1s` and `10s`
budgets says something useful about a small static INRC-II slice. It does not
prove a universal solver ranking across all rostering instances.

That caveat is not weakness. It is what makes the result useful.

The benchmark should be strong enough that a loss is actionable. If SolverForge
loses because it cannot reassign already-assigned scalar entities efficiently,
that becomes a runtime feature target. If it loses because a list-variable move
selector gets trapped in a narrow neighborhood, that becomes a move-selection
target. If it loses because an adapter encoded the model differently, the
benchmark failed its own contract and the result should not be published as a
solver comparison.

## The Standard

SolverForge benchmarks should be boring in the right places.

The harness should be predictable. The schema should be stable. The validator
should be independent. The timing policy should be explicit. The ranking rule
should be visible. The published claim should be narrower than the data, not
broader.

That gives us something more valuable than a scoreboard: a feedback system for
building the solver.
