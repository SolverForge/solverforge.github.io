---
title: "SolverForge Use Cases: Four Repository-Only Apps on the 0.19.7 Line"
date: 2026-09-27
draft: false
description: >
  The solverforge-usecases bundle now ships eight runnable apps. Heat-treatment
  scheduling, warehouse order picking, fleet readiness, and flight-crew
  assignment join the four published use cases, all on solverforge 0.19.7 with
  solverforge-ui 0.9.0.
---

The `solverforge-usecases` bundle is the publication source for the runnable
SolverForge example applications. It now carries **eight** apps instead of four:
`uc-furnace`, `uc-orders`, `uc-fleet`, and `uc-flightcrew` were added alongside
the published hospital, lessons, deliveries, and field-service cases.

All eight target `solverforge 0.19.7` and `solverforge-ui 0.9.0`. The four new
apps are **repository-only**: they are complete, runnable open-source
applications with Dockerfiles, tests, and browser workspaces, but they have no
hosted Hugging Face Space. The four published cases keep theirs.

## The New Apps

### Heat-treatment scheduling

`solverforge-furnace 2.0.2` plans 155 work orders across 11 furnaces and 39
operators over a seven-day horizon, with 467 planning entities and 30
constraints (22 hard, 8 soft).

This is the coupled-planning case: a valid plan has to decide which furnace can
process each order, when the batch runs, which operators own the related manual
tasks, whether monitoring capacity is available, and whether the roster can
support the work. Solving those layers separately produces schedules that look
legal in one layer and fail in another.

It answers one concrete question:

> Given furnaces, work orders, task operators, and a weekly shift roster, when
> should each order run, on which furnace, and which operator performs each
> manual task?

### Warehouse order picking

`solverforge-orders 0.1.2` plans 8 grocery orders, 145 pick steps, 37 products,
and 5 trolleys. It is a faithful port of its source application's single page,
including the isometric warehouse canvas with aisle-routed trolley paths,
numbered pickup markers, and trolleys animated while a solve runs.

The scoring is deliberately small and exact: hard `required_buckets` counts
buckets past four per order, soft `order_incidence` penalizes distinct
trolley/order incidences, and soft `route_distance` penalizes one point per
meter over the closed route. Warehouse distance reproduces every piecewise
branch of the source, and the source UI's historical 100x display error is not
reproduced.

### Fleet readiness planning

`solverforge-fleet 0.1.5` is a synthetic, non-operational readiness planner: 24
vessels, 24 work packages, 5 docks, 5 technician pools, 12 parts, 8 deliveries,
and 56 days grouped into eight display weeks, with 66 planning decisions and 15
constraints (9 hard, 6 soft).

The identifier `weekly_readiness_floor` is historical. Its hard score does not
sample once per week: it iterates every modeled day and enforces all three
readiness thresholds daily. The workspace renders all 56 days; the separate
weekly result summary samples the first day of each display week and does not
weaken that enforcement.

### Flight-crew assignment

`solverforge-flightcrew 0.1.2` assigns every required pilot and flight-attendant
seat across 6 airports, 24 crew members, 10 flight legs, and 42 required seats,
with 12 constraints (10 hard, 2 soft).

It preserves the executable scheduling concepts from its source Java/Timefold
application while using SolverForge's retained-job runtime and exact snapshot
analysis. Hard rules cover seat coverage, exact skill qualification, overlap
prevention, connection continuity, availability, home- and away-base minimum
rest, 36-hour extended recovery, and 48-hour recovery after long-haul duty. The
long-haul threshold follows the source's executable rule: at least 10 hours.

## How They Are Released

Each app keeps its own version in `uc-*/Cargo.toml`, its own `CHANGELOG.md`, and
its own app-prefixed tag stream, so a bare `v<version>` tag is never used in this
bundle because it would be ambiguous:

```text
solverforge-furnace@2.0.2
solverforge-orders@0.1.2
solverforge-fleet@0.1.5
solverforge-flightcrew@0.1.2
```

`uc-furnace`, `uc-orders`, `uc-fleet`, and `uc-flightcrew` are intentionally
excluded from the Hugging Face sync workflow. They are published from this
repository only, and an app joins the sync matrix only once its Space target
exists.

## Published Version Boundaries

| App | Version | Space |
| --- | ------- | ----- |
| `solverforge-hospital` | `2.0.8` | [SolverForge/solverforge-hospital](https://huggingface.co/spaces/SolverForge/solverforge-hospital) |
| `solverforge-lessons` | `2.0.10` | [SolverForge/solverforge-lessons](https://huggingface.co/spaces/SolverForge/solverforge-lessons) |
| `solverforge-deliveries` | `2.0.9` | [SolverForge/solverforge-deliveries](https://huggingface.co/spaces/SolverForge/solverforge-deliveries) |
| `solverforge-fsr` | `2.0.10` | [SolverForge/solverforge-fsr](https://huggingface.co/spaces/SolverForge/solverforge-fsr) |
| `solverforge-furnace` | `2.0.2` | repository-only |
| `solverforge-orders` | `0.1.2` | repository-only |
| `solverforge-fleet` | `0.1.5` | repository-only |
| `solverforge-flightcrew` | `0.1.2` | repository-only |

## Where to read next

Inspect all eight in the [use-case showcase](/use-cases/), which carries each
case's data shape, constraint summary, narrated walkthrough, and annotated
screenshots, or follow the written guides for
[hospital](/docs/getting-started/solverforge-hospital-use-case/),
[lessons](/docs/getting-started/solverforge-lessons-use-case/),
[deliveries](/docs/getting-started/solverforge-deliveries-use-case/), and
[field service](/docs/getting-started/solverforge-fsr-use-case/).
