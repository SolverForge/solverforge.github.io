---
title: "solverforge-cli 3.1.0: 0.19.5 Scaffold Targets, Multi-Client connect, and the Agent-Centric Skill Installer"
date: 2026-09-16
draft: false
description: >
  solverforge-cli 3.1.0 retargets fresh scaffolds to solverforge 0.19.5,
  solverforge-ui 0.9.0, and rmcp 3.4.0, writes MCP client configs for opencode,
  Claude Code, and Cursor, and makes the agent skill installer agent-centric
  with ownership receipts.
---

**solverforge-cli 3.1.0** is published on crates.io and released on GitHub
(2026-09-16), so `cargo install solverforge-cli` installs 3.1.0 directly. The
previous package, `solverforge-cli 3.0.0`, scaffolded `solverforge 0.19.4`,
`solverforge-ui 0.7.0`, and `rmcp 3.3.0`. Use `solverforge --version` to
confirm exactly what an installed binary carries.

<%= render Ui::Callout.new(title: "Breaking change: skill installer", variant: "warning") do %>
The skill installer keeps the agent-centric contract only. `--only` and the
implicit `~/.agents/skills` default stay removed: pass repeatable
`--agent opencode|claude|codex` selectors, for example
`make install-skill ARGS='--agent <harness>'`. Nothing is installed into a
directory you did not ask for.
<% end %>

New projects target:

- `solverforge 0.19.5`
- `solverforge-ui 0.9.0` for the web shell
- `solverforge-maps 2.1.4` for the web shell
- `rmcp 3.4.0` for the MCP shell

Fresh scaffolds now align with the published `solverforge 0.19.5` core and the
documented `solverforge-ui 0.9.0` line. Apps scaffolded by `3.0.0` keep their
own manifests and upgrade deliberately.

## What Changed

### Latest scaffold crates

The web shell pins `solverforge 0.19.5` with `solverforge-ui 0.9.0` and
`solverforge-maps 2.1.4`; the MCP shell pins `rmcp 3.4.0`. The support
dependencies carry over from 3.0.0 (`axum 0.8.9`, `tokio 1.52.3`,
`tower-http 0.6.11`, `serde_json 1.0.150`, `uuid 1.23.5`,
`parking_lot 0.12.5`), and the shell-boundary rules are unchanged: only the web
shell generates `static/`, `static/generated/ui-model.json`, and `ui_source`.

```text
solverforge --version

solverforge solverforge-cli 3.1.0
CLI version: 3.1.0
Scaffold runtime target: SolverForge crate target 0.19.5
Scaffold UI target: solverforge-ui 0.9.0
Scaffold maps target: solverforge-maps 2.1.4
Scaffold MCP target: rmcp 3.4.0
```

### `connect --write` for opencode, Claude Code, and Cursor

`solverforge connect` now writes in-project MCP client configs beyond VS Code:

| Target | Written file |
| ------ | ------------ |
| `vscode` | `.vscode/mcp.json` |
| `cursor` | `.cursor/mcp.json` |
| `claude` | `.mcp.json` |
| `opencode` | `opencode.json` |

```bash
solverforge connect --write opencode
solverforge connect --write claude
solverforge connect --write cursor
```

Each write updates only the project's MCP server entry and replaces the config
file atomically; JSONC comments in an existing file are preserved. Global
client files (Claude Desktop) are still printed with their path instead of
being modified.

### The agent-centric skill installer

The repository bundles both SolverForge skills - `skills/solverforge-modeling/`
and `skills/solverforge-ui/` - behind one installer that resolves each
harness's own skills directory:

```bash
./scripts/install-skill --agent opencode
./scripts/install-skill --agent opencode --agent claude --layout covering
./scripts/install-skill --agent opencode --link
./scripts/install-skill --agent opencode --project ../my-app
make install-skill ARGS='--agent opencode'   # from the repository root
```

`--agent` is repeatable; `--layout covering` computes one duplicate-free
placement for overlapping harness selections, and `--link` symlinks instead of
copying. Installed copies carry a `.solverforge-skill` ownership receipt (a
sidecar receipt for symlinks), so the installer updates or removes only entries
it owns and leaves hand-copied skills untouched. `--skill` names are validated,
and the explicit layout contract is enforced.

### MCP result-contract fixes

MCP `solve` task results now match the advertised output schema, and the solve
result DTO is scoped to the MCP shell instead of the shared DTO contract. The
HTTP transport's trust model is documented in the CLI manual: it is
unauthenticated with one shared solver and task store across all callers, so a
non-loopback `--host` is trusted-network-only or belongs behind an
authenticating proxy; stdio has no such exposure.

## Published Version Boundaries

| Surface | Version | Scaffold target |
| ------- | ------- | --------------- |
| CLI | `solverforge-cli 3.1.0` | `solverforge 0.19.5`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.4.0` |
| CLI (previous package) | `solverforge-cli 3.0.0` | `solverforge 0.19.4`, web `solverforge-ui 0.7.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.3.0` |

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `3.1.0` | 2026-09-16 | Targets the latest released scaffold crates, writes MCP configs for opencode, Claude Code, and Cursor, consolidates the agent skills behind the agent-centric installer with ownership receipts, and fixes the MCP solve result schema. |
| `3.0.0` | 2026-09-15 | Adds the `mcp` scaffold shell, `solverforge connect`, countable scalar ranges, the full list-metadata flags, and the `solverforge-modeling` agent skill; moves fresh scaffolds to `solverforge 0.19.4`. |
| `2.2.3` | 2026-07-30 | Publishes the neutral scalar/list/mixed scaffold line targeting `solverforge 0.19.3`, `solverforge-ui 0.7.0`, and `solverforge-maps 2.1.4`. |
| `2.2.2` | 2026-06-12 | Publishes the `solverforge 0.15.2` scaffold contract. |
| `2.2.1` | 2026-06-10 | Retargets fresh generated apps to `solverforge 0.15.1` on the CI-green source line. |
| `2.2.0` | 2026-05-31 | Retargets fresh generated apps to `solverforge 0.15.0` and exposes scalar-group and conflict-repair model resources. |

## Upgrade Checklist

- Re-run `solverforge --version` / `solverforge -V` after installing to confirm
  the binary's scaffold targets.
- Existing generated apps keep their own manifests; move them to
  `solverforge 0.19.5` deliberately and run their model, config, and lifecycle
  tests. Fresh scaffolds already target `0.19.5` and `solverforge-ui 0.9.0`.
- If you scripted the old installer flags, replace `--only <harness>` and bare
  invocations with explicit `--agent <harness>` selections; use `--layout
  covering` when two selected harnesses would otherwise discover the same skill
  twice.
- Re-run `solverforge connect --write <target>` in MCP-shell projects to pick
  up the new write targets, and reload the harness so it rescans its config.

## Where to read next

Use the [CLI manual](/docs/solverforge-cli/) for the current command surface,
the [MCP Shell](/docs/solverforge-cli/mcp-shell/) page for the agent-facing
delivery surface and `connect` write targets, and the
[agent skill page](/docs/solverforge-cli/agent-skill/) for the installer
contract and the solve smoke test.
