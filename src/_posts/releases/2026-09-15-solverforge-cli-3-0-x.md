---
title: "solverforge-cli 3.0.0: MCP Shell, connect, and the Modeling Agent Skill"
date: 2026-09-15
draft: false
description: >
  solverforge-cli 3.0.0 adds an MCP server shell, the connect command, countable
  scalar ranges, the full list-metadata flags, and the portable
  solverforge-modeling agent skill, and moves fresh scaffolds onto
  solverforge 0.19.4.
---

**solverforge-cli 3.0.0** is published on crates.io and released on GitHub
(2026-09-15), so `cargo install solverforge-cli` installs 3.0.0 directly. The
previous crates.io package, `solverforge-cli 2.2.3`, scaffolded
`solverforge 0.19.3`, `solverforge-ui 0.7.0`, and `solverforge-maps 2.1.4`. Use
`solverforge --version` to confirm exactly what an installed binary carries.

The 3.0.0 line is a major release for one reason: the CLI no longer produces
only web, API, and CLI applications. It can also produce an MCP server, so the
solver is reachable from any MCP-capable agent harness.

New projects target:

- `solverforge 0.19.4`
- `solverforge-ui 0.7.0` for the web shell
- `solverforge-maps 2.1.4` for the web shell
- `rmcp 3.3.0` for the MCP shell

## What Changed

### Four public shells

The public shell set is exactly `web`, `api`, `cli`, and `mcp`. A Tauri shell is
intentionally deferred. Every shell shares one generated core
(`domain/`, `constraints/`, `solver/`, `data/`, and the DTO contract), so
`solverforge generate` and `solverforge destroy` mutate an MCP-shell project
exactly like any other shell.

```bash
solverforge new my-scheduler
solverforge new api-optimizer --shell api
solverforge new batch-optimizer --shell cli
solverforge new agent-optimizer --shell mcp
```

Only the web shell generates `static/`, `static/generated/ui-model.json`, and
`ui_source`. Every shell declares `rust-version = "1.95"` and `schemars` as an
optional dependency behind a `schema` feature; only the MCP shell enables it,
so it can publish typed tool schemas over the shared DTO contract.

### The MCP shell

`--shell mcp` produces a planning application whose delivery surface is an MCP
server. The retained solver job lifecycle is exposed as annotated, schema-typed
tools: `list_demo_data`, `get_demo_data`, `solve`, `get_status`,
`get_best_solution`, `analyze_solution`, `get_telemetry`, `get_candidate_trace`,
`pause`, `resume`, `cancel`, and `delete`.

To a task-capable client (MCP 2026-07-28), `solve` returns an MCP task handle
with the retained `jobId` in result metadata; every other client receives an
immediate job summary. Either client can drive the lifecycle through the polling
and control tools while the solve runs. MCP tasks have no TTL, so task expiry
cannot orphan an active solve.

The server speaks stdio by default and serves stateless Streamable HTTP at
`/mcp` with `--http`. HTTP binds the loopback interface unless `--host` selects
a concrete IP address, and wildcard binds (`0.0.0.0` and `::`) are rejected so
`rmcp` Host validation remains active. One solver service and one task store are
shared by every request.

```bash
solverforge new agent-scheduler --shell mcp
cd agent-scheduler
solverforge generate fact resource
solverforge generate entity task
solverforge generate variable resource_idx --entity Task --kind scalar --range resources
solverforge generate data
cargo run --release          # stdio MCP server
cargo run --release -- --http  # Streamable HTTP on http://127.0.0.1:7860/mcp
solverforge connect          # client configs for Claude Code, Claude Desktop, Cursor, VS Code
```

### `solverforge connect`

`connect` prints ready-to-paste MCP client configuration for an MCP-shell
project: the stdio command plus the Streamable HTTP URL. `--write vscode` merges
the project entry into `.vscode/mcp.json`; global client files are printed with
their path instead of being modified. `--port` sets the printed HTTP URL and
otherwise falls back through `.solverforgerc` to `7860`.

### Countable scalar ranges and list metadata

Scalar variables can now use a half-open integer range instead of a fact
collection. The field stays `Option<usize>` and stores the chosen candidate
index:

```bash
solverforge generate variable hour --entity Shift --kind scalar --countable-range 0..24
```

List variables expose the full list-metadata surface through flags such as
`--domain cvrp`, `--distance-meter`, `--intra-distance-meter`, `--route-hooks`,
`--savings-hooks`, `--savings-metric-class-fn`, `--element-owner-fn`,
`--construction-element-order-key`, `--precedence-duration-fn`,
`--precedence-successors-fn`, and `--solution-trait`. These name user-owned Rust
implementations and are projected into `solverforge.app.toml`.

### The modeling agent skill

The repository ships a portable agent skill at `skills/solverforge-modeling/`
that teaches a coding agent to turn a described planning problem into a runnable
SolverForge app with this CLI. It bundles `scripts/solve-smoke-test.sh`, which
builds and drives a generated app (web/API), boots the MCP HTTP transport, or
validates CLI `demo-data` serialization depending on the shell.

```bash
./scripts/install-skill                    # ~/.agents/skills (cross-harness)
./scripts/install-skill --only opencode    # ~/.config/opencode/skills
./scripts/install-skill --only claude      # ~/.claude/skills
./scripts/install-skill --project <dir>    # per-harness project scope
./scripts/install-skill --list
make install-skill                         # from the repository root
```

The installer copies an independent, self-contained skill into each selected
directory and refuses to overwrite or remove an entry it did not create. See the
[agent skill page](/docs/solverforge-cli/agent-skill/).

## Published Version Boundaries

| Surface | Version | Scaffold target |
| ------- | ------- | --------------- |
| CLI | `solverforge-cli 3.0.0` | `solverforge 0.19.4`, web `solverforge-ui 0.7.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.3.0` |
| CLI (last crates.io package) | `solverforge-cli 2.2.3` | `solverforge 0.19.3`, `solverforge-ui 0.7.0`, `solverforge-maps 2.1.4` |

The web shell's direct support dependencies also moved: `tower-http 0.6.11`,
`serde_json 1.0.150`, and `uuid 1.23.5`. The API shell keeps
`solverforge` and Axum without frontend or map assets; the CLI shell keeps
`solverforge` and Clap; the MCP shell keeps `solverforge` with `rmcp`, Axum,
and `tracing`, and leaves the runtime `console` feature off so the stdout stdio
transport channel stays pure JSON-RPC.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `3.0.0` | 2026-09-15 | Adds the `mcp` scaffold shell, `solverforge connect`, countable scalar ranges, the full list-metadata flags, and the `solverforge-modeling` agent skill; moves fresh scaffolds to `solverforge 0.19.4`. |
| `2.2.3` | 2026-07-30 | Publishes the neutral scalar/list/mixed scaffold line targeting `solverforge 0.19.3`, `solverforge-ui 0.7.0`, and `solverforge-maps 2.1.4`. |
| `2.2.2` | 2026-06-12 | Publishes the `solverforge 0.15.2` scaffold contract. |
| `2.2.1` | 2026-06-10 | Retargets fresh generated apps to `solverforge 0.15.1` on the CI-green source line. |
| `2.2.0` | 2026-05-31 | Retargets fresh generated apps to `solverforge 0.15.0` and exposes scalar-group and conflict-repair model resources. |

## Upgrade Checklist

- Re-run `solverforge --version` / `solverforge -V` after installing to confirm
  the binary's scaffold targets.
- Existing generated apps keep their own manifests; move them to
  `solverforge 0.19.4` deliberately and run their model, config, and lifecycle
  tests.
- Choose `--shell mcp` only for agent-facing servers; add `solverforge connect`
  and the agent skill for the MCP workflow.

## Where to read next

Use the [CLI manual](/docs/solverforge-cli/) for the current command surface,
the [MCP Shell](/docs/solverforge-cli/mcp-shell/) page for the agent-facing
delivery surface, and the [agent skill page](/docs/solverforge-cli/agent-skill/)
for the installable modeling skill.
