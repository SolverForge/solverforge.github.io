---
title: "solverforge-cli 4.1.x and 4.2.x: Scaffolding SolverForge 0.31 and Reporting the Resolved Phase Plan"
date: 2026-11-18
draft: false
description: >
  solverforge-cli 4.1.0 adds the resolved phase plan, the policy a solve
  actually ran, to the telemetry generated apps expose over HTTP and SSE.
  4.2.0 moves fresh scaffolds to SolverForge 0.31.2; 4.2.1 and 4.2.2 make
  `check` and `config set` load solver.toml with the runtime's own parser.
---

**solverforge-cli 4.2.2 was published on November 21, 2026**, a day after
`4.2.1`. `solverforge-cli 4.2.2` targets
`solverforge 0.31.2`, as 4.2.0 and 4.2.1 do, and 4.1.0 targets `solverforge 0.31.1`. All of them keep
`solverforge-ui 0.9.1` and `solverforge-maps 2.3.3` in the web shell and
`rmcp 3.9.0` in the MCP shell. The project layout is the 4.0 layout:
constraint modules declared in `src/constraints/mod.rs` and assembled in
`src/constraints/assemble.rs`.

## What Changed

### The resolved phase plan in generated telemetry (4.1.0)

Generated web and API apps already expose every compact `SolverTelemetry`
aggregate. Since 4.1.0 their status, snapshot, and typed SSE payloads also
carry `resolvedPhasePlan`: the policy the solve actually ran (every phase, the
construction chosen for each default stage, the move families and their
limits, the acceptor and forager), `null` until the solve ends. Generated
list and scalar templates map it from the runtime's
`SolverTelemetry::resolved_phase_plan`; see
[Solver Phases](/docs/solverforge/solver/phases/#resolved-phase-plan).

### Fresh scaffolds target SolverForge 0.31

4.1.0 declares `solverforge = { version = "0.31.1", ... }` in new projects.
4.2.0 declares `0.31.2`, and `solverforge --version` reports
`Scaffold runtime target: SolverForge crate target 0.31.2`. The README, the
wireframe, the upstream feature audit, and the `solverforge-modeling` skill
name the new target; the rules the skill and generated code rely on
(`BendableScore` refused by `generate score`, no `for_each_unique_pair`, the
self-join pair pattern) are unchanged. 4.2.0 changes nothing else. See the
[0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/) for what
the runtime line adds.

### `solver.toml` checked by the runtime's parser (4.2.1, 4.2.2)

`solverforge check` and `solverforge config set` load `solver.toml` with
`solverforge-config`, the configuration type the generated app uses, pinned
to the scaffold runtime target. A key the runtime does not know, such as a
stray `[app]` table, now fails `check` with the runtime's own message instead
of passing it and failing every solve at start. `config set` refuses to write
a file the runtime would reject. The two hand-written checks for
`move_thread_count` and `candidate_trace` are gone; the runtime parser covers
both. Scaffold targets and generated files are unchanged. In 4.2.1 a rejected
`config set` printed the parse error without the key; 4.2.2 starts the message
with `cannot set` and the dotted key, for example
`` cannot set `move_thread_count.count` ``.

## Published Version Boundaries

| Surface | Version | Role |
| ------- | ------- | ---- |
| CLI | `solverforge-cli 4.2.2` | Fresh scaffolds target `solverforge 0.31.2` |
| Runtime | `solverforge 0.31.2` | 0.31 line; see the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/) |
| Previous CLI line | `solverforge-cli 4.0.4` | Scaffolds `solverforge 0.26.1` with the same project layout; see the [4.0.x release note](/blog/releases/2026/11/10/solverforge-cli-4-0-x/) |
| Web UI | `solverforge-ui 0.9.1` | Web shell only |
| Maps | `solverforge-maps 2.3.3` | Web shell only |
| MCP SDK | `rmcp 3.9.0` | MCP shell only |

The `4.2.2` [GitHub Release](https://github.com/SolverForge/solverforge-cli/releases/tag/v4.2.2)
was published at `2026-11-21T07:34:40Z`, and crates.io records the package at
`2026-11-21T07:41:59Z`. Its artifact (SHA-256
`84ae9fc20bb838d42e7954404c5adf24ca9ee47f13b6e7a3a2da0e66641762c7`) was built
from the tag commit `bd0b5427cc985067a905d4a9361a9fc160429551`, where the
[CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/44878598757)
passed and the
[Publish](https://github.com/SolverForge/solverforge-cli/actions/runs/44878601505)
and [Release](https://github.com/SolverForge/solverforge-cli/actions/runs/44878601542)
workflows succeeded.

The `4.2.1` [GitHub Release](https://github.com/SolverForge/solverforge-cli/releases/tag/v4.2.1)
was published at `2026-11-20T23:51:43Z`, and crates.io records the package at
`2026-11-20T23:41:00Z`. Its artifact (SHA-256
`74cfe8f3a3f4a1d5182f594f646897fa85f8f63557a58f4a7c7e45da420ddb51`) was built
from the tag commit `9428468cd009bdea80fd24f0eaba9c79dcfd36cc`, where the
[CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/44835073190)
passed and the
[Publish](https://github.com/SolverForge/solverforge-cli/actions/runs/44835077788)
and [Release](https://github.com/SolverForge/solverforge-cli/actions/runs/44835077773)
workflows succeeded.

The `4.2.0` [GitHub Release](https://github.com/SolverForge/solverforge-cli/releases/tag/v4.2.0)
was published at `2026-11-18T09:19:15Z`, and crates.io records the package at
`2026-11-18T09:21:38Z`. Its artifact (SHA-256
`cedbfb4ff9ab1b08934ac7e1e88255bbba0a0631bae561f0c31d53b6bfe9801f`) was built
from the tag commit `8a5c3e206fcbcffb5c44f68b5b23f29d263c185d`, where the
[CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/44268676566)
passed and the
[Publish](https://github.com/SolverForge/solverforge-cli/actions/runs/44268681409)
and [Release](https://github.com/SolverForge/solverforge-cli/actions/runs/44268681516)
workflows succeeded.

The `4.1.0` [GitHub Release](https://github.com/SolverForge/solverforge-cli/releases/tag/v4.1.0)
was published at `2026-11-17T19:34:40Z`. Its artifact (SHA-256
`13e9d9ff39b28442affc9004d202926d52f956bc937cb3bc0183e03cf54bbe41`) was built
from `b0d2bf99006c581a144ccdcb9e71e672878dc5ae`, where the
[CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/44152833105)
passed on Linux, macOS, and Windows plus the integration tests, and the
[Publish](https://github.com/SolverForge/solverforge-cli/actions/runs/44152837060)
and [Release](https://github.com/SolverForge/solverforge-cli/actions/runs/44152836862)
workflows succeeded.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `4.2.2` | 2026-11-21 | A rejected `config set` names the key it was setting; scaffold targets unchanged. Exact-commit CI passed. |
| `4.2.1` | 2026-11-20 | `check` and `config set` load `solver.toml` with the runtime's configuration parser; scaffold targets unchanged. Exact-commit CI passed. |
| `4.2.0` | 2026-11-18 | Fresh scaffolds target `solverforge 0.31.2`; nothing else changes. Exact-commit CI passed. |
| `4.1.0` | 2026-11-17 | Fresh scaffolds target `solverforge 0.31.1`; generated telemetry carries `resolvedPhasePlan`; UI, maps, and MCP targets and the project layout unchanged. Exact-commit CI passed. |

## Upgrade Checklist

- Install with `cargo install solverforge-cli --version 4.2.2 --locked --force`
  and inspect `solverforge --version`.
- Replace an installed `solverforge-modeling` skill by running
  `./scripts/install-skill` again, with the same `--agent`, `--project`, or
  `--dir` options, from a `solverforge-cli` checkout at `v4.2.2`.
- Upgrading the CLI does not change existing apps. To move an app to the 0.31
  line, change its `solverforge` dependency (and any direct `solverforge-*`
  dependency) and the `[runtime]` lines of `solverforge.app.toml`, then follow
  the [0.31.x upgrade checklist](/blog/releases/2026/11/17/solverforge-0-31-x/#upgrade-checklist).
- An app generated by an earlier CLI gains `resolvedPhasePlan` only by adding
  the field to its own telemetry DTOs.

## Where to read next

- [CLI Getting Started](/docs/solverforge-cli/getting-started/)
- [Command Reference](/docs/solverforge-cli/command-reference/)
- [Solver Phases](/docs/solverforge/solver/phases/#resolved-phase-plan)
- [4.0.4 to 4.1.0 comparison](https://github.com/SolverForge/solverforge-cli/compare/v4.0.4...v4.1.0)
- [4.1.0 to 4.2.0 comparison](https://github.com/SolverForge/solverforge-cli/compare/v4.1.0...v4.2.0)
- [4.2.0 to 4.2.1 comparison](https://github.com/SolverForge/solverforge-cli/compare/v4.2.0...v4.2.1)
- [4.2.1 to 4.2.2 comparison](https://github.com/SolverForge/solverforge-cli/compare/v4.2.1...v4.2.2)
- [4.2.2 GitHub Release](https://github.com/SolverForge/solverforge-cli/releases/tag/v4.2.2)
