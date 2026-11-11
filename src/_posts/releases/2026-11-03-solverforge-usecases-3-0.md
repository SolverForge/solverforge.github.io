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

### November 9 releases: solverforge 0.25.0

On November 9 all eight apps released patch versions on `solverforge 0.25.0`;
see the [0.25.x release note](/blog/releases/2026/11/09/solverforge-0-25-x/).
Each app's HTTP error mapping answers `409 Conflict` for the new
`SnapshotAnalysisDisabled` error. Furnace's VND phase sets
`score_tie_break = "first"`, because 0.25.0's default random tie-break among
equally scored best moves left its standard demo hard-infeasible. Furnace
3.0.1 split its test build's debug info so the test binary links; 3.0.2 builds
tests without debug info, whose generic type names otherwise exceed 2.7 GB.
The UI and maps dependencies are unchanged.

| App tag | Source commit | Space sync |
| --- | --- | --- |
| `solverforge-hospital@3.0.1` | `fda057fed58debcc7a208c61b429c567a8ab5a59` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42564398195) |
| `solverforge-lessons@3.0.1` | `bc1f5008fd5534f19482a581e65f50404620acaa` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42564403026) |
| `solverforge-deliveries@3.0.2` | `13185ffedb0688697cb3c14d1002832be24e6e43` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42564377312) |
| `solverforge-fsr@3.0.2` | `0d75e3daa4aec136ffbe4fcf898795ba974ac956` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42564388464) |
| `solverforge-furnace@3.0.1` | `7012fd4bc0cb30736c7b1c7fc49e740ab929b7d3` | repository-only |
| `solverforge-furnace@3.0.2` | `4a14a2803149f5f44491825fec6c1430f35298ee` | repository-only |
| `solverforge-orders@0.3.1` | `9b6a90ce77f24e217327557eb00392a5e8962d7f` | repository-only |
| `solverforge-fleet@0.2.1` | `6d35a8d6909e65db1f27c7f6c32ef12d16cba937` | repository-only |
| `solverforge-flightcrew@0.3.2` | `eff28ad94eb3b7fb3d46bb12c753a33c11d964d4` | repository-only |

Bundle CI at `solverforge-orders@0.3.1`
([run 42564373829](https://github.com/SolverForge/solverforge-usecases/actions/runs/42564373829)) ran out of disk on the
hosted runner. The next commit frees the runner's preinstalled SDKs; its
[run 42567230688](https://github.com/SolverForge/solverforge-usecases/actions/runs/42567230688) was terminated while building
Furnace's tests, which `solverforge-furnace@3.0.2` fixes. Bundle CI passed at
that final app tag ([run 42571454634](https://github.com/SolverForge/solverforge-usecases/actions/runs/42571454634)).

### November 10 releases: solverforge 0.25.1 and the CLI 4 layout

On November 10 all eight apps released on `solverforge 0.25.1` and adopted the
`solverforge-cli 4.0` constraint layout: `src/constraints/mod.rs` declares the
rule modules and holds no code, and `create_constraints()` in
`src/constraints/assemble.rs` calls each one as `super::<id>::constraint()`,
the layout `solverforge generate constraint` edits and `solverforge check`
validates. Field service also pins `solverforge-core 0.25.1`. The UI and
maps dependencies are unchanged.

Furnace released `4.0.0`, a breaking change. Its constraint ids are the
snake_case module names, such as `changeover_gap` instead of `changeoverGap`,
in score analysis and in `GET /jobs/{id}/analysis/{constraint_name}`. Each of
its 30 constraints, 22 hard and 8 soft, lives in its own file; `shared.rs`
keeps only scoring helpers. Its domain holds one type per file, its scalar
groups and conflict repairs are registered through
`solverforge generate scalar-group` and `solverforge generate conflict-repair`,
and its `solver.toml` repair selectors name the new constraint ids.

| App tag | Source commit | Space sync |
| --- | --- | --- |
| `solverforge-hospital@3.0.2` | `fad59750ea5870685dcf9bf4c47ffd3be9b4be39` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42736874938) |
| `solverforge-lessons@3.0.2` | `d65009eabda22ccaab76b68162326412f358388a` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42736880673) |
| `solverforge-deliveries@3.0.3` | `b085f99a6b8107b9644556ce8d480856f9d89e8b` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42736842886) |
| `solverforge-fsr@3.0.3` | `e4ed1792721b5504d6250ccb61e5b10e0a715e7f` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42736861096) |
| `solverforge-furnace@4.0.0` | `d7b4898cdda5410927390d389b92f506c1f1ee11` | repository-only |
| `solverforge-orders@0.3.2` | `61c1f0c40ed5b6e5e3a2fb88fbfcfeb62ce9d617` | repository-only |
| `solverforge-fleet@0.2.2` | `e11835da374fdbdb59cb012df8de1819ee97a8f2` | repository-only |
| `solverforge-flightcrew@0.3.3` | `ded655a9487bf21ddbfa5a4eb88959e5da1a3492` | repository-only |

Bundle CI passed at the final app tag, `solverforge-orders@0.3.2`
([run 42736837747](https://github.com/SolverForge/solverforge-usecases/actions/runs/42736837747)).

### November 10 releases: solverforge 0.26.0

Later on November 10 all eight apps released on `solverforge 0.26.0`; see the
[0.26.x release note](/blog/releases/2026/11/10/solverforge-0-26-x/). Each app
moves its `solverforge` dependency, its lockfile, and the `[runtime]` lines of
`solverforge.app.toml` to 0.26.0; Field service and Fleet also pin
`solverforge-core 0.26.0`. The UI and maps dependencies, constraint ids, and
HTTP contracts are unchanged. On 0.26.0 debug-info type names stay
proportional to the constraint set, so `solverforge-furnace@4.0.1` builds its
tests with full debug info again.

| App tag | Source commit | Space sync |
| --- | --- | --- |
| `solverforge-hospital@3.0.3` | `944329d87a029aa61696ce74ce9fd660368bb72c` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42810005593) |
| `solverforge-lessons@3.0.3` | `922eb1d2e8712445572b7bfeb7df2de463009191` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42810012066) |
| `solverforge-deliveries@3.0.4` | `73dd1cf0fea6cd29fa584ec309d9d72d18c4916b` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42809974394) |
| `solverforge-fsr@3.0.4` | `93eeb265d050d15a542cb5b04fe225393b63f334` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42809991743) |
| `solverforge-furnace@4.0.1` | `2992c2f824bf75d393e21a5bd8c09a29de6b13d7` | repository-only |
| `solverforge-orders@0.3.3` | `48c73d626e0bd0758a2885bf4ef6014a32cb077c` | repository-only |
| `solverforge-fleet@0.2.3` | `98bd6bfb10072355d4df0068a44e172d755c4d57` | repository-only |
| `solverforge-flightcrew@0.3.4` | `bdd055e7814ce6974286d209dd7949304aa7cb09` | repository-only |

Bundle CI passed at the final app tag, `solverforge-orders@0.3.3`
([run 42809967938](https://github.com/SolverForge/solverforge-usecases/actions/runs/42809967938)).

### November 11 releases: solverforge 0.26.1

On November 11 all eight apps released on `solverforge 0.26.1`; see the
[0.26.x release note](/blog/releases/2026/11/10/solverforge-0-26-x/). Each app
moves its `solverforge` dependency, its lockfile, and the `[runtime]` lines of
`solverforge.app.toml` to 0.26.1; Field service and Fleet also pin
`solverforge-core 0.26.1`. The UI and maps dependencies, constraint ids,
solver configuration, and HTTP contracts are unchanged. Hospital, Lessons,
Deliveries, Orders, Fleet, and Flight crew configure `late_acceptance` phases,
which now keep their score history across soft-level improvements. The Flight crew README describes the app as preserving the
scheduling concepts of the original Java application.

| App tag | Source commit | Space sync |
| --- | --- | --- |
| `solverforge-hospital@3.0.4` | `54e37f83e263a3283ab609857e4a9b028db0fc79` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42958140633) |
| `solverforge-lessons@3.0.4` | `c2e40f912ddba49b41ed5a372d888b67e25faecb` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42958145776) |
| `solverforge-deliveries@3.0.5` | `2c1326dbb20ac44e0760bc6fd35a4991471ab36d` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42958112416) |
| `solverforge-fsr@3.0.5` | `3344a74cdb76981dc58143b2d38ee150135cf996` | [passed](https://github.com/SolverForge/solverforge-usecases/actions/runs/42958131088) |
| `solverforge-furnace@4.0.2` | `60250351a17358be9ab83731936ba6ffcfffed44` | repository-only |
| `solverforge-orders@0.3.4` | `28520582d57c012b3df1db64859311ec60186f3e` | repository-only |
| `solverforge-fleet@0.2.4` | `e02a6877c4382b85a6346b1d7d4d3bb9dcfd9403` | repository-only |
| `solverforge-flightcrew@0.3.5` | `d1ea42572f6b13115bfcd68029d48d66ef481c3e` | repository-only |

Bundle CI passed at the final app tag, `solverforge-orders@0.3.4`
([run 42958108105](https://github.com/SolverForge/solverforge-usecases/actions/runs/42958108105)).

## Upgrade Checklist

- Check out the app's own release tag from the tables above.
- Read Furnace score analysis by the snake_case constraint ids of
  `solverforge-furnace@4.0.0`.
- An app of your own that still assembles its constraints in
  `src/constraints/mod.rs` needs the move described in the
  [CLI 4.0.x release note](/blog/releases/2026/11/10/solverforge-cli-4-0-x/#upgrade-checklist)
  before CLI 4.0.x can edit it.
- An app that
  matches `SolverManagerError` exhaustively needs a `SnapshotAnalysisDisabled`
  arm on `solverforge 0.25.0`.
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
