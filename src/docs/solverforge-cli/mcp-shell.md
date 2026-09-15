---
title: MCP Shell
description: >
  Scaffold an MCP server shell that exposes the retained solver lifecycle as
  schema-typed tools, and connect an MCP-capable agent to it.
weight: 9
---

# MCP Shell

`solverforge new --shell mcp` produces a planning application whose delivery
surface is a Model Context Protocol server. It shares the same generated core
(`domain/`, `constraints/`, `solver/`, `data/`, and the DTO contract) as the
web, API, and CLI shells, so generator commands mutate it identically.

## Scaffold And Run

```bash
solverforge new agent-scheduler --shell mcp
cd agent-scheduler
solverforge generate fact resource
solverforge generate entity task
solverforge generate variable resource_idx --entity Task --kind scalar --range resources
solverforge generate data
cargo run --release              # stdio MCP server
cargo run --release -- --http    # Streamable HTTP on http://127.0.0.1:7860/mcp
solverforge connect              # client configs for Claude Code, Claude Desktop, Cursor, VS Code
```

The server speaks stdio by default. With `--http` it serves stateless
Streamable HTTP at `/mcp`. HTTP binds the loopback interface unless `--host`
selects a concrete IP address; wildcard binds (`0.0.0.0` and `::`) are rejected
so `rmcp` Host validation remains active. One solver service and one task store
are shared by every request, so jobs and tasks survive individual negotiations.

## Tool Surface

The retained solver job lifecycle is exposed as annotated, schema-typed tools:

| Tool | Purpose |
| ---- | ------- |
| `list_demo_data` | List available demo dataset identifiers |
| `get_demo_data` | Load one demo dataset |
| `solve` | Start a solve |
| `get_status` | Read the retained job status |
| `get_best_solution` | Read the best solution snapshot |
| `analyze_solution` | Analyze a snapshot revision |
| `get_telemetry` | Read compact retained telemetry |
| `get_candidate_trace` | Fetch the bounded candidate-pull publication after enabling `[candidate_trace]` |
| `pause` | Request a pause |
| `resume` | Resume a paused job |
| `cancel` | Cancel a live or paused job |
| `delete` | Delete a terminal retained job |

For a task-capable client (MCP 2026-07-28), `solve` returns an MCP task handle
with the retained `jobId` in result metadata; every other client receives an
immediate job summary. Either client can drive the lifecycle through the polling
and control tools while the solve runs. MCP tasks have no TTL, so task expiry
cannot orphan an active solve, and task records remain available for the server
process lifetime.

## `solverforge connect`

```text
solverforge connect [OPTIONS]
```

Prints ready-to-paste MCP client configuration for an MCP-shell project: the
stdio command plus the Streamable HTTP URL for Claude Code, Claude Desktop,
Cursor, VS Code, and other clients.

| Option              | Meaning |
| ------------------- | ------- |
| `--write <TARGET>`  | Write the in-project client config for the target; only `vscode` is currently supported |
| `-p, --port <PORT>` | Port used in the printed Streamable HTTP URL; when omitted, use `.solverforgerc` and then `7860` |

`--write vscode` merges the project entry into `.vscode/mcp.json`; global client
files are printed with their path instead of being modified.

```bash
solverforge connect
solverforge connect --write vscode
solverforge connect --port 8080
```

## Diagnostics And Qualified Jobs

Generated MCP, web, and API apps expose every compact `SolverTelemetry`
aggregate, including applied, not-doable, and rejected moves, hard-score
direction counts, conflict-repair counters, construction counters, current
phase detail, per-selector and per-move breakdowns, and the bounded applied-move
trace. Candidate-pull traces are not copied into ordinary control-plane
payloads; enable `[candidate_trace]` and then fetch the retained diagnostic
publication through `get_candidate_trace` (MCP) or
`GET /jobs/{id}/telemetry` (web/API).

The web/API surface also accepts `POST /jobs/qualified`, which starts the same
retained lifecycle with externally attested SHA-256 schema, instance,
initial-state, core-tree, and loaded-build digests. `POST /jobs` remains the
default entry point.

## See Also

- [Scaffold Commands](/docs/solverforge-cli/scaffold-commands/) - `new` and `server`
- [Agent Skill](/docs/solverforge-cli/agent-skill/) - the bundled modeling skill and its solve smoke test
- [Command Reference](/docs/solverforge-cli/command-reference/) - the full command surface
