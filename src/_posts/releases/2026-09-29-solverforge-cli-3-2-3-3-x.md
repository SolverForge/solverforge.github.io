---
title: "solverforge-cli 3.2.x and 3.3.x: SolverForge 0.19.7 Scaffolds, rmcp 3.5.0, and a Current Dependency Baseline"
date: 2026-09-29
draft: false
description: >
  solverforge-cli 3.2.0 retargets fresh scaffolds to solverforge 0.19.7,
  3.3.0 moves the MCP shell to rmcp 3.5.0, and 3.3.1 aligns the CLI's own
  dependency baseline with the current releases.
---

**solverforge-cli 3.3.1** is published on crates.io and released on GitHub
(2026-09-29), so `cargo install solverforge-cli` installs 3.3.1 directly. The
previous package, `solverforge-cli 3.1.0`, scaffolded `solverforge 0.19.5`,
`solverforge-ui 0.9.0`, and `rmcp 3.4.0`. Use `solverforge --version` to confirm
exactly what an installed binary carries.

New projects target:

- `solverforge 0.19.7`
- `solverforge-ui 0.9.0` for the web shell
- `solverforge-maps 2.1.4` for the web shell
- `rmcp 3.5.0` for the MCP shell

## What Changed

### Scaffolds retarget to SolverForge 0.19.7

`3.2.0` moves the scaffold runtime target to the published `solverforge 0.19.7`
core, so a fresh project starts on the current runtime instead of the previous
line. The UI and maps targets are unchanged at `solverforge-ui 0.9.0` and
`solverforge-maps 2.1.4`.

```text
solverforge --version

solverforge solverforge-cli 3.3.1
CLI version: 3.3.1
Scaffold runtime target: SolverForge crate target 0.19.7
Scaffold UI target: solverforge-ui 0.9.0
Scaffold maps target: solverforge-maps 2.1.4
Scaffold MCP target: rmcp 3.5.0
```

### The MCP shell moves to rmcp 3.5.0

`3.3.0` retargets the `mcp` shell to `rmcp 3.5.0` as the Model Context Protocol
client and server SDK. Projects scaffolded with `--shell mcp` pick up 3.5.0 in
their own manifests, and the version output reports the target so an installed
binary never leaves the SDK implicit.

### The CLI's own dependency baseline is aligned

`3.3.1` brings the CLI's own dependencies onto the current releases, including
`clap 4.6.7`, `clap_complete 4.6.11`, `serde 1.0.229`, `serde_json 1.0.151`,
`owo-colors 4.4.0`, `syn 3.0.6`, `toml 1.1.6`, `toml_edit 0.25.15`, and
`jsonc-parser 0.34`. These are the CLI's own crates rather than scaffold
targets, so a generated project is unaffected.

## Published Version Boundaries

| Surface | Version | Scaffold target |
| ------- | ------- | --------------- |
| CLI | `solverforge-cli 3.3.1` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.3.0` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.2.0` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.4.0` |
| CLI (previous line) | `solverforge-cli 3.1.0` | `solverforge 0.19.5`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.4.0` |

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `3.3.1` | 2026-09-29 | Aligns the CLI dependency baseline with the current releases; no scaffold-target change. |
| `3.3.0` | 2026-09-29 | Retargets the MCP shell to `rmcp 3.5.0`. |
| `3.2.0` | 2026-09-29 | Retargets fresh scaffolds to `solverforge 0.19.7`. |
| `3.1.0` | 2026-09-16 | Targets the latest released scaffold crates, writes MCP configs for opencode, Claude Code, and Cursor, consolidates the agent skills behind the agent-centric installer with ownership receipts, and fixes the MCP solve result schema. |
| `3.0.0` | 2026-09-15 | Adds the `mcp` scaffold shell, `solverforge connect`, countable scalar ranges, the full list-metadata flags, and the `solverforge-modeling` agent skill; moves fresh scaffolds to `solverforge 0.19.4`. |

## Upgrade Checklist

- Re-run `solverforge --version` / `solverforge -V` after installing to confirm
  the binary's scaffold targets.
- Existing generated apps keep their own manifests; move them to
  `solverforge 0.19.7` deliberately and run their model, config, and lifecycle
  tests. Fresh scaffolds already target `0.19.7` and `solverforge-ui 0.9.0`.
- MCP-shell projects scaffolded before `3.3.0` pin `rmcp 3.4.0`; moving to
  `3.5.0` is a dependency update in the project manifest, not a re-scaffold.

## Where to read next

Use the [CLI manual](/docs/solverforge-cli/) for the current command surface,
the [command reference](/docs/solverforge-cli/command-reference/) for the
`--version` output this release reports, and the
[MCP Shell](/docs/solverforge-cli/mcp-shell/) page for the agent-facing
delivery surface built on `rmcp 3.5.0`.
