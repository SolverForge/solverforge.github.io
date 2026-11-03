---
title: "SolverForge Use Cases 3.0: All Eight Apps on solverforge 0.24.0"
date: 2026-11-03
draft: false
description: >
  The November 3 use-case releases move all eight apps to solverforge 0.24.0,
  report constraint analysis by module id with a weightMultiplier, and run
  their tests from a standalone clone.
---

**Published November 3, 2026.** The `solverforge-usecases` bundle released all
eight runnable apps on `solverforge 0.24.0` and `solverforge-ui 0.9.0`,
following the October 27 releases on core `0.23.0` recorded in the
[2.x use-case release note](/blog/releases/2026/09/27/solverforge-usecases-repository-apps/).
Hospital, Lessons, Deliveries, Field service, and Furnace released `3.0.0`;
Orders and Flight crew released `0.3.0`; Fleet released `0.2.0`. The analysis
payload changed shape in every app, which is why each one took a major
version.

## What Changed

### Every app targets solverforge 0.24.0

Each app pins `solverforge 0.24.0`, which reads solver configuration only from
the model's embedded `solver_toml` file and rejects unknown configuration
keys; see the [0.24.x release note](/blog/releases/2026/11/01/solverforge-0-24-x/).
The web UI stays on `solverforge-ui 0.9.0`.

### Score analysis reports `weightMultiplier` — breaking change

The runtime replaced `ConstraintAnalysis::weight` with a numeric
`weight_multiplier`, so every app's `/jobs/{id}/analysis` row carries a
numeric `weightMultiplier` instead of a weight string. The analysis tables in
Deliveries, Fleet, Flight crew, Field service, and Furnace read the new field;
Hospital, Lessons, and Orders never displayed the weight. Flight crew,
Furnace, and Orders also drop the six per-selector `conflictRepair*` selector
counters, which the runtime removed because they were always zero; the
run-level counters remain.

### Constraints are named by module id — breaking change

Hospital, Lessons, Deliveries, and Field service name each constraint after
its module, as `solverforge check` from `solverforge-cli 3.8.x` requires, so
analysis reports ids such as `minimum_rest` or `late_lesson` instead of
display labels. Each app's frontend maps the ids back to readable labels.
Hospital's `plan.rs` now carries the managed blocks the CLI scaffold uses, so
later `solverforge generate` commands can edit its model. Fleet declares each rule's id with
`.named(...)`; its ids are unchanged.

### Tests run from a standalone clone

Each app ships its own `package.json` and lockfile pinned to Playwright
`1.60.0` and a `make install-e2e` target, so a Hugging Face Space checkout or
any single-app clone can run `make test` and `make ci-local`. Chromium comes
from `PLAYWRIGHT_CHROMIUM_EXECUTABLE`, then `/usr/bin/chromium`, then
Playwright's bundled browser. Every `make test-slow` target runs its
acceptance solve in the release profile, because a debug build reaches a
worse score inside the same 30-second limit.

### Routing failures name their cause

Deliveries and Field service download road data from the public Overpass API
on first use. When that download fails, `POST /jobs` and the routing endpoints
keep their error status and answer with a JSON body,
`{"error": "routing data unavailable: ..."}`, instead of an empty body.
Deliveries' live road-network tests stop polling once a cancelled job reaches
its terminal state.

## Published Version Boundaries

| App tag | Source commit | Previous release → current | Space |
| --- | --- | --- | --- |
| `solverforge-hospital@3.0.0` | `4519bf09b583c407f7b238337b7d29bb34d868ec` | [2.0.12 → 3.0.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-hospital@2.0.12...solverforge-hospital@3.0.0) | [SolverForge/solverforge-hospital](https://huggingface.co/spaces/SolverForge/solverforge-hospital) |
| `solverforge-lessons@3.0.0` | `9ea781ced785d3db3028257d569e051e576fd1f3` | [2.0.14 → 3.0.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-lessons@2.0.14...solverforge-lessons@3.0.0) | [SolverForge/solverforge-lessons](https://huggingface.co/spaces/SolverForge/solverforge-lessons) |
| `solverforge-deliveries@3.0.0` | `20be4b8c2b51a4dd804a120c85e3824addc59ccd` | [2.0.13 → 3.0.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-deliveries@2.0.13...solverforge-deliveries@3.0.0) | [SolverForge/solverforge-deliveries](https://huggingface.co/spaces/SolverForge/solverforge-deliveries) |
| `solverforge-fsr@3.0.0` | `0d005e02b81699bc6a452bfabfe65961d785d24d` | [2.0.14 → 3.0.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-fsr@2.0.14...solverforge-fsr@3.0.0) | [SolverForge/solverforge-fsr](https://huggingface.co/spaces/SolverForge/solverforge-fsr) |
| `solverforge-furnace@3.0.0` | `20579348bcb689f4472c7e645c1b2e38f24f6bad` | [2.0.7 → 3.0.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-furnace@2.0.7...solverforge-furnace@3.0.0) | repository-only |
| `solverforge-orders@0.3.0` | `10c8513abcf38fa0b7b48f5d8c546ae3cc85438d` | [0.2.0 → 0.3.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-orders@0.2.0...solverforge-orders@0.3.0) | repository-only |
| `solverforge-fleet@0.2.0` | `f170630becdd2f1cd6df5916c9c9e6d488d7ef85` | [0.1.9 → 0.2.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-fleet@0.1.9...solverforge-fleet@0.2.0) | repository-only |
| `solverforge-flightcrew@0.3.0` | `97b93b1edd32286be48a84335f130d0edb22ba9a` | [0.2.0 → 0.3.0](https://github.com/SolverForge/solverforge-usecases/compare/solverforge-flightcrew@0.2.0...solverforge-flightcrew@0.3.0) | repository-only |

### Patch releases

| App tag | Source commit | Change | Space sync |
| --- | --- | --- | --- |
| `solverforge-deliveries@3.0.1` | `5785901d2e8a03a69b46c7e88979cb1c6dce4f7b` | Requires `solverforge-maps 2.1.5`, which identifies the app to Overpass | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/41718266892) |
| `solverforge-fsr@3.0.1` | `b696484e288e62aae71761a056b3c7c2b8ddb435` | Requires `solverforge-maps 2.1.5`, which identifies the app to Overpass | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/41718285190) |
| `solverforge-flightcrew@0.3.1` | `484990d56ce5053bcb3ee281252db8285eca647b` | Requires `solverforge-maps 2.1.5`, which identifies the app to Overpass | repository-only |

Bundle CI passed at the final patch tag, `solverforge-flightcrew@0.3.1`
([run 41718256141](https://github.com/SolverForge/solverforge-usecases/actions/runs/41718256141)).

The app-owned `cli_version` provenance in each `solverforge.app.toml` stays at
`2.2.2` for Hospital, Lessons, Deliveries, Field service, Furnace, and Fleet,
and `3.1.0` for Orders and Flight crew; installing a newer CLI does not
rewrite it.

### Release and validation evidence

The release-tag syncs to the four Spaces all succeeded:
[Hospital](https://github.com/SolverForge/solverforge-usecases/actions/runs/41637155114),
[Lessons](https://github.com/SolverForge/solverforge-usecases/actions/runs/41637164072),
[Deliveries](https://github.com/SolverForge/solverforge-usecases/actions/runs/41637120152),
and [Field service](https://github.com/SolverForge/solverforge-usecases/actions/runs/41637141120).
A sync pushes the tagged app to its Space; it does not start a paused Space.

Bundle CI at the final app tag, `solverforge-orders@0.3.0`
([run 41637114103](https://github.com/SolverForge/solverforge-usecases/actions/runs/41637114103)),
failed before building any app: the metadata check called `rg`, which the
runner does not have. The next commit,
`50371ec410b363864420ba97d6c5ee94771709d4`, runs that check with `grep` and
changes no app; its
[CI run 41637463799](https://github.com/SolverForge/solverforge-usecases/actions/runs/41637463799)
passed. That commit is not an app release tag.

## Upgrade Checklist

- Check out the app's own release tag from the table above.
- Update analysis consumers to read the numeric `weightMultiplier` and, for
  Hospital, Lessons, Deliveries, and Field service, to match constraints by
  module id.
- In a standalone clone, run `make install-e2e` before `make test`.
- Allow outbound HTTPS to the Overpass API for Deliveries and Field service
  routing, and read the JSON `error` field when a routing request fails.

## Where to read next

Inspect all eight in the [use-case showcase](/use-cases/), or follow the
written guides for
[hospital](/docs/getting-started/solverforge-hospital-use-case/),
[lessons](/docs/getting-started/solverforge-lessons-use-case/),
[deliveries](/docs/getting-started/solverforge-deliveries-use-case/), and
[field service](/docs/getting-started/solverforge-fsr-use-case/).
