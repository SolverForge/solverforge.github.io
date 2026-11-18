---
title: "solverforge-cli 4.1.x and 4.2.x: Scaffolding SolverForge 0.31 and Reporting the Resolved Phase Plan"
date: 2026-11-18
draft: false
description: >
  solverforge-cli 4.1.0 adds the resolved phase plan, the policy a solve
  actually ran, to the telemetry generated apps expose over HTTP and SSE.
  4.2.0 moves fresh scaffolds to SolverForge 0.31.2.
---

**solverforge-cli 4.2.0 was published on November 18, 2026**, one day after
`4.1.0`. `solverforge-cli 4.2.0` targets
`solverforge 0.31.2`, and 4.1.0 targets `solverforge 0.31.1`. Both keep
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

## Published Version Boundaries

| Surface | Version | Role |
| ------- | ------- | ---- |
| CLI | `solverforge-cli 4.2.0` | Fresh scaffolds target `solverforge 0.31.2` |
| Runtime | `solverforge 0.31.2` | 0.31 line; see the [0.31.x release note](/blog/releases/2026/11/17/solverforge-0-31-x/) |
| Previous CLI line | `solverforge-cli 4.0.4` | Scaffolds `solverforge 0.26.1` with the same project layout; see the [4.0.x release note](/blog/releases/2026/11/10/solverforge-cli-4-0-x/) |
| Web UI | `solverforge-ui 0.9.1` | Web shell only |
| Maps | `solverforge-maps 2.3.3` | Web shell only |
| MCP SDK | `rmcp 3.9.0` | MCP shell only |

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
| `4.2.0` | 2026-11-18 | Fresh scaffolds target `solverforge 0.31.2`; nothing else changes. Exact-commit CI passed. |
| `4.1.0` | 2026-11-17 | Fresh scaffolds target `solverforge 0.31.1`; generated telemetry carries `resolvedPhasePlan`; UI, maps, and MCP targets and the project layout unchanged. Exact-commit CI passed. |

## Upgrade Checklist

- Install with `cargo install solverforge-cli --version 4.2.0 --locked --force`
  and inspect `solverforge --version`.
- Replace an installed `solverforge-modeling` skill by running
  `./scripts/install-skill` again, with the same `--agent`, `--project`, or
  `--dir` options, from a `solverforge-cli` checkout at `v4.2.0`.
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
- [4.2.0 GitHub Release](https://github.com/SolverForge/solverforge-cli/releases/tag/v4.2.0)
