---
title: "solverforge-cli 3.7.x: Parallel Evaluation and Per-Phase Telemetry"
date: 2026-10-27
draft: false
description: >
  solverforge-cli 3.7.1 targets SolverForge 0.23.0 and rmcp 3.8.0, validates
  parallel settings, and projects per-phase telemetry and speculative work.
---

**solverforge-cli 3.7.1 was published on October 27, 2026**, following
`3.7.0`, which introduced this line's runtime and telemetry changes after
`3.6.0` scaffolded `solverforge 0.22.0`. The current package targets
`solverforge 0.23.0`; the web UI, maps, and MCP targets remain independent.
Existing applications keep their own manifests and generated source.

## What Changed

### MCP scaffolds use rmcp 3.8.0 and ServerConfig

The `3.7.1` patch updates the MCP shell from `rmcp 3.5.1` to `rmcp 3.8.0`
and replaces the deprecated `ServerInfo` alias with `ServerConfig` in generated
server code. Existing MCP apps should update their manifest and the import,
return type, and constructor in `src/mcp/server.rs`; installing the CLI does
not rewrite existing source.

The generated server remains stateless over Streamable HTTP and makes no
server-to-client sampling, elicitation, or roots requests. The twelve tools,
task-capable and legacy lifecycle paths, and stdio JSON-RPC contract remain
unchanged. Runtime `0.23.0`, UI `0.9.0`, and maps `2.1.4` targets are unchanged.

The patch also corrects the scaffold test to compare the commented thread-count
block line by line, accepting Windows CRLF endings without changing the
configuration template or accepted settings.

### Parallel local-search evaluation is available, not enabled by default

Fresh scalar and list templates document an opt-in setting:

```bash
solverforge config set move_thread_count.count 4
solverforge check
```

The default `auto` stays sequential. Parallel local search scores candidates
on several evaluators while one coordinator preserves sequential acceptance
order. Construction remains sequential. The effective count is capped by the
Rayon pool and by 32; concurrent jobs share one process-wide pool controlled
by `RAYON_NUM_THREADS`. Small models can be slower with more evaluators.

The CLI's `check` and `config set` commands accept only `"auto"`, `"none"`,
or a table containing one non-negative integer `count`. Bare integer values,
negative counts, extra table fields, and non-integer counts are rejected.
Generated apps embed `solver.toml` and parse it when solving, so rebuild and
restart an app after changing the setting. There is no per-job thread override.

### Telemetry records every started phase and speculative work

Generated telemetry replaces the single `phase` object with a `phases` array
in execution order. Run totals and each phase carry `movesSpeculative`;
candidate traces label discarded ahead-of-decision work as
`discarded_speculative`. This is a breaking wire-shape change for consumers
of generated status, snapshot, and typed SSE payloads. The web UI target
remains `solverforge-ui 0.9.0`, which reads neither phase key.

`movesGenerated` includes speculative work. Use `movesEvaluated` when comparing
logical evaluation work. Detailed candidate pulls remain separate from ordinary
control-plane payloads and require opt-in candidate tracing.

### The verification scenarios cover fixed-work parity

The updated mixed runtime scenario compares seeded, step-bounded sequential
and parallel solves: solution, score, logical counters, and ordered consumed
candidate pulls must match. Only the parallel local-search run may report
speculative work. MCP scenarios enable parallel evaluation on a pinned Rayon
pool, including the byte-level check that stdio stdout remains JSON-RPC only.
The `3.7.0` artifact's exact-commit CI failure and the successful `3.7.1`
validation are recorded separately below.

### Publication and exact-commit validation are separate

The current [3.7.1 crate](https://crates.io/crates/solverforge-cli/3.7.1) carries
source SHA `fcaad8e3ef59444cb28f7e4742494e2b0cbb64ca` in `.cargo_vcs_info.json`.
Its SHA-256 is
`ba476ea2862d6e0a6e2f0a9a434428d2887f8863abdd1e932b6ef87598d7d538`,
matching the crates.io index. The exact-commit
[publication workflow](https://github.com/SolverForge/solverforge-cli/actions/runs/40546507692),
[GitHub Release workflow](https://github.com/SolverForge/solverforge-cli/actions/runs/40546507680),
and [CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/40546499568)
all completed successfully. CI passed Linux, macOS, Windows, and Integration Tests.

The [3.7.0 crate](https://crates.io/crates/solverforge-cli/3.7.0) carries source
SHA `ab79f437bf7694bbb166d1247cde30c5c5a00e42` in `.cargo_vcs_info.json`.
Its SHA-256 is
`41e70042260d7ed88e7f310822f3c0f583dea2d5dd28fa92e48820919d72841e`,
matching the crates.io index. The [publication workflow](https://github.com/SolverForge/solverforge-cli/actions/runs/40525393646)
and [GitHub Release workflow](https://github.com/SolverForge/solverforge-cli/actions/runs/40525393731)
succeeded for that commit.

The exact-commit [CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/40525390383)
failed: Linux and macOS Rust jobs passed, but Windows failed
`test_new_creates_neutral_project_files` on the commented thread-count block
assertion. Windows reported 42 scaffold tests passed and one failed; its
network-retry step and the dependent Integration Tests job were skipped.
The later [main-branch CI run](https://github.com/SolverForge/solverforge-cli/actions/runs/40531468127)
succeeded at `8c9d62d780730e61d53ab7e882d48ec5e77d2886`; that is not validation
of the original artifact commit.

## Published Version Boundaries

| Surface | Version | Role |
| ------- | ------- | ---- |
| CLI | `solverforge-cli 3.7.1` | Fresh scaffolds target `solverforge 0.23.0` |
| Runtime | `solverforge 0.23.0` | Modeling, search, parallel evaluation, telemetry |
| Web UI | `solverforge-ui 0.9.0` | Web shell only |
| Maps | `solverforge-maps 2.1.4` | Web shell only |
| MCP SDK | `rmcp 3.8.0` | MCP shell only; generated server uses `ServerConfig` |
| Previous CLI | `solverforge-cli 3.7.0` | Targets `solverforge 0.23.0` and MCP `rmcp 3.5.1`; exact-commit CI failed on Windows |
| Python binding | `solverforge 0.7.2` | Independent package; not a CLI scaffold dependency |

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `3.7.1` | 2026-10-27 | Updates MCP to `rmcp 3.8.0`, names `ServerConfig` instead of `ServerInfo`, and corrects the Windows CRLF-sensitive scaffold test. Runtime/UI/maps targets are unchanged; exact-commit CI passed. |
| `3.7.0` | 2026-10-27 | Targets `solverforge 0.23.0`, validates `move_thread_count`, projects `phases` and speculative work, and adds parallel runtime/MCP test contracts. |
| `3.6.0` | 2026-10-18 | Targets `solverforge 0.22.0`; the compare from `3.5.2` contains the runtime retarget and release commit, not new CLI commands. |

## Upgrade Checklist

- Install with `cargo install solverforge-cli --version 3.7.1 --locked --force`
  and inspect `solverforge --version`.
- Upgrade existing applications deliberately: installing the CLI does not
  regenerate their telemetry DTOs or change their dependency manifests.
- For an existing MCP app, update `rmcp` to `3.8.0` and replace `ServerInfo`
  with `ServerConfig` in the server metadata implementation; run `cargo check`.
- Replace consumer assumptions about a single `phase` record with the `phases`
  array and retain speculative counters separately from logical work.
- Leave parallel evaluation off until a fixed-work comparison and real-instance
  timing justify it; rebuild after changing `solver.toml`.
- Run model, configuration, lifecycle, and transport tests after upgrading.

## Where to read next

- [CLI manual](/docs/solverforge-cli/)
- [Configuration](/docs/solverforge-cli/configuration/#parallel-local-search-evaluation)
- [MCP shell](/docs/solverforge-cli/mcp-shell/)
- [Complete 3.6.0 to 3.7.0 comparison](https://github.com/SolverForge/solverforge-cli/compare/v3.6.0...v3.7.0)
- [Complete 3.7.0 to 3.7.1 comparison](https://github.com/SolverForge/solverforge-cli/compare/v3.7.0...v3.7.1)
- [GitHub Release](https://github.com/SolverForge/solverforge-cli/releases/tag/v3.7.1)
