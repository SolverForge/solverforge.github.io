---
title: "SolverForge Use Cases: Four Repository-Only Apps on the 0.19.7 Line"
date: 2026-09-27
draft: false
description: >
  Eight runnable SolverForge apps: the September additions and the October 27
  releases on solverforge 0.23.0, per-phase telemetry, shared Cargo target
  support, and the furnace cancellation-latency fix.
---

**Published September 27, 2026; updated October 27, 2026.** The
`solverforge-usecases` bundle is the publication source for the runnable
SolverForge example applications. The September release carries **eight** apps instead of four:
`uc-furnace`, `uc-orders`, `uc-fleet`, and `uc-flightcrew` were added alongside
the published hospital, lessons, deliveries, and field-service cases.

The September releases target `solverforge 0.19.7` and `solverforge-ui 0.9.0`.
The October 27 releases below target `solverforge 0.23.0`. The four new
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

## October Runtime Updates

The October 14 releases moved all eight apps to `solverforge 0.21.2`; the
October 15 releases moved them to `solverforge 0.21.3`, carrying the corrected
net-adjacency updates for list-precedence scoring. The October 18 releases
move all eight to `solverforge 0.22.0`, carrying the shared grouping-accumulator
kernel and position-based membership updates. UI assets remain at `0.9.0`;
map-backed apps retain `solverforge-maps 2.1.4`. These are runtime dependency
updates: the domain models, constraints, and demo datasets are unchanged.

| App | October 14 (core 0.21.2) | October 15 (core 0.21.3) | October 18 (core 0.22.0) | October 27 (core 0.23.0) |
| --- | --- | --- | --- | --- |
| Hospital | `2.0.9` | `2.0.10` | `2.0.11` | `2.0.12` |
| Lessons | `2.0.11` | `2.0.12` | `2.0.13` | `2.0.14` |
| Deliveries | `2.0.10` | `2.0.11` | `2.0.12` | `2.0.13` |
| Field service | `2.0.11` | `2.0.12` | `2.0.13` | `2.0.14` |
| Furnace | `2.0.3` | `2.0.4` | `2.0.5` | `2.0.6`, then `2.0.7` |
| Orders | `0.1.3` | `0.1.4` | `0.1.5` | `0.2.0` |
| Fleet | `0.1.6` | `0.1.7` | `0.1.8` | `0.1.9` |
| Flight crew | `0.1.3` | `0.1.4` | `0.1.5` | `0.2.0` |

The October 15 hosted apps' release-tag sync workflows completed:
[Hospital](https://github.com/SolverForge/solverforge-usecases/actions/runs/38717387329),
[Lessons](https://github.com/SolverForge/solverforge-usecases/actions/runs/38717392646),
[Deliveries](https://github.com/SolverForge/solverforge-usecases/actions/runs/38717355641),
and [Field service](https://github.com/SolverForge/solverforge-usecases/actions/runs/38717375396).
The October 15 bundle [CI run](https://github.com/SolverForge/solverforge-usecases/actions/runs/38723058914)
passed at `c5a30f6113d3b4e60ea2e9b6b7f22c5eb6bdc8c3`, and the October 18 bundle
[CI run](https://github.com/SolverForge/solverforge-usecases/actions/runs/39113224930)
passed at `abc4905537bc38d7e0fbeeea9576084d27db274c`. The October 18 hosted
apps' release-tag sync workflows also completed:
[Hospital](https://github.com/SolverForge/solverforge-usecases/actions/runs/39113251530),
[Lessons](https://github.com/SolverForge/solverforge-usecases/actions/runs/39113256126),
[Deliveries](https://github.com/SolverForge/solverforge-usecases/actions/runs/39113229026),
and [Field service](https://github.com/SolverForge/solverforge-usecases/actions/runs/39113242845).
The release command rejects a detached HEAD before creating a release.

## What Changed on October 27

### Runtime and build integration

All eight apps target `solverforge 0.23.0`; field service and fleet also pin
`solverforge-core 0.23.0` directly. UI stays at `0.9.0`, and deliveries, field
service, and flight crew keep maps `2.1.4`. The domain constraints and demo
inputs are unchanged. The deliveries test helper supplies a constraint-set
constructor so each parallel evaluator replica can build its own set.

The browser test servers honor `CARGO_TARGET_DIR` rather than assuming an
app-local `target/release` directory. This covers the Playwright servers for
hospital, deliveries, field service, orders, and flight crew, plus the inline
smoke servers for lessons, fleet, and furnace. The release wrapper completes
the csemver migration, accepts bracketed prepared changelog headings, and
avoids duplicating app prefixes in new compare links.

### Per-phase telemetry in orders and flight crew

Orders `0.2.0` and flight crew `0.2.0` replace the optional telemetry `phase`
object with a `phases` array: one record per phase started, in execution order.
Clients must read the array rather than the former single-phase field. Both
aggregate and phase records expose `movesSpeculative`, and candidate traces
can report `discarded_speculative`. This is an API change, not a domain-model
or dataset change. The other six apps keep narrower, app-owned telemetry
summaries; they do not expose these new fields merely by upgrading the runtime.

### Furnace patch history

Furnace `2.0.6` retargets the runtime and fixes the shared-target smoke server.
Furnace `2.0.7` additionally caches expensive ordering keys when ranking
schedule-task alternatives and replacement operators. The schedule-task
provider retains the best hard-clean alternatives and stable tie ordering,
then truncates to the requested limit. Reducing work inside a candidate pull
reduces the delay before cancellation or a time limit can take effect; it does
not make that pull interruptible. A regression test compares the selected
alternatives with the stable reference ordering.

### Release and validation evidence

The October 27 hosted-app release-tag syncs all succeeded:
[Hospital](https://github.com/SolverForge/solverforge-usecases/actions/runs/40524550543),
[Lessons](https://github.com/SolverForge/solverforge-usecases/actions/runs/40524558093),
[Deliveries](https://github.com/SolverForge/solverforge-usecases/actions/runs/40524507822),
and [Field service](https://github.com/SolverForge/solverforge-usecases/actions/runs/40524530701).
These syncs are separate from bundle validation. The final bundle
[CI run 40537219778](https://github.com/SolverForge/solverforge-usecases/actions/runs/40537219778)
succeeded at `2da90f5e8d3994e8f91186bd268fc301472f9dfb`, the
`solverforge-furnace@2.0.7` tag. That released tree contains all eight latest
app manifests and is the site's bundle pin. The earlier October 27 bundle
[run 40524500379](https://github.com/SolverForge/solverforge-usecases/actions/runs/40524500379)
failed before the furnace fix; it is not the final bundle verdict.

Each row links the full compare from the previously documented app release.

| App tag | Source commit | Previous release → current |
| --- | --- | --- |
| `solverforge-hospital@2.0.12` | `aad77ee42cddd6130ac9938eb7bea7f65ea45faf` | [2.0.11 → 2.0.12](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-hospital@2.0.11...solverforge-hospital@2.0.12) |
| `solverforge-lessons@2.0.14` | `0a67ac951ccc1eabea1e3150b6396c661f32a368` | [2.0.13 → 2.0.14](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-lessons@2.0.13...solverforge-lessons@2.0.14) |
| `solverforge-deliveries@2.0.13` | `ccf82ad61252cac1df2c528d671eb4350f8c21b1` | [2.0.12 → 2.0.13](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-deliveries@2.0.12...solverforge-deliveries@2.0.13) |
| `solverforge-fsr@2.0.14` | `5726153b835c126ce8fbd02b4444edc2b7b2e032` | [2.0.13 → 2.0.14](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-fsr@2.0.13...solverforge-fsr@2.0.14) |
| `solverforge-furnace@2.0.7` | `2da90f5e8d3994e8f91186bd268fc301472f9dfb` | [2.0.5 → 2.0.7](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-furnace@2.0.5...solverforge-furnace@2.0.7) |
| `solverforge-orders@0.2.0` | `2238e8ee172703d49b329b4e82872d5b4336e240` | [0.1.5 → 0.2.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-orders@0.1.5...solverforge-orders@0.2.0) |
| `solverforge-fleet@0.1.9` | `cb9880a9794cf7b398e450986f5e6bf3784d1562` | [0.1.8 → 0.1.9](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-fleet@0.1.8...solverforge-fleet@0.1.9) |
| `solverforge-flightcrew@0.2.0` | `43ce9ab2f11428d0728c1bdea80f5c84f8e45db3` | [0.1.5 → 0.2.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-flightcrew@0.1.5...solverforge-flightcrew@0.2.0) |

Furnace `2.0.6` remains a released intermediate tag at
`ffc1423503e4de320f3ebb9e688b40d05653a3c8`.

The app-owned CLI provenance stays at `2.2.2` for hospital, lessons,
deliveries, field service, furnace, and fleet, and `3.1.0` for orders and
flight crew. It is not rewritten to the current CLI's version. Dependency
patches also remain app-specific: lessons uses Tokio `1.52.1` and tower-http
`0.6.8`; the other apps use Tokio `1.52.3`, with tower-http `0.6.10` except
orders and flight crew at `0.6.11`.

## Published Version Boundaries

The table below records the original September release. The October releases
above supersede these versions without changing which apps have hosted Spaces.

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

## Upgrade Checklist

- Select the app's own release tag from the October 27 column; use
  `solverforge-furnace@2.0.7` when checking out the complete current bundle.
- Keep the tagged dependency versions and recorded `cli_version` metadata;
  installing a newer CLI does not rewrite an app's scaffold provenance.
- Update orders and flight-crew telemetry consumers to iterate `phases` and
  accept the speculative-move fields and `discarded_speculative` disposition.
- Run the app's `make test` and `make ci-local`, including browser tests, with
  the same `CARGO_TARGET_DIR` used for its release build.

## Where to read next

Inspect all eight in the [use-case showcase](/use-cases/), which carries each
case's data shape, constraint summary, narrated walkthrough, and annotated
screenshots, or follow the written guides for
[hospital](/docs/getting-started/solverforge-hospital-use-case/),
[lessons](/docs/getting-started/solverforge-lessons-use-case/),
[deliveries](/docs/getting-started/solverforge-deliveries-use-case/), and
[field service](/docs/getting-started/solverforge-fsr-use-case/).
