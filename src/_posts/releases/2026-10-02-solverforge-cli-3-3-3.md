---
title: "solverforge-cli 3.3.3: Score Rewrites and Demo-Data Resync"
date: 2026-10-02
draft: false
description: >
  solverforge-cli 3.3.3 makes generate score rewrite every surface that carries
  the score type — constraint modules, the service, the DTO contract, lib.rs,
  and the MCP files — so a score change leaves a project that still compiles,
  and makes destroy resync the generated demo data so removed types do not stay
  behind in the seed.
---

**solverforge-cli 3.3.3** is published on crates.io and released on GitHub
(2026-10-02), so `cargo install solverforge-cli` installs 3.3.3 directly. The
previous package, `solverforge-cli 3.3.2`, carried the same scaffold targets;
this release fixes two generator defects and changes no dependency. Use
`solverforge --version` to confirm exactly what an installed binary carries.

New projects target:

- `solverforge 0.19.7`
- `solverforge-ui 0.9.0` for the web shell
- `solverforge-maps 2.1.4` for the web shell
- `rmcp 3.5.0` for the MCP shell

## What Changed

### `generate score` rewrites every score-bearing surface

`generate score` updated only the solution file. The score type is not local to
the solution: it appears in every generated `constraints/*.rs` module, in
`solver/service.rs`, in `api/dto.rs`, in `lib.rs`, and in the MCP files. A score
change therefore produced a project that no longer compiled, while the command
reported success.

The command now precomputes its rewrites before writing anything — the solution,
every constraint module, and the generated contract files — so the rename lands
atomically or not at all. A run that asks for the score type
the project already uses is a no-op instead of an error.

Neutral-scaffold replacement shares that same contract path list. That closes
the identical gap for `src/mcp/dto.rs` and `src/mcp/tasks.rs` when
`generate solution` replaces the neutral shell, which previously rewrote the
solution type and left the MCP contract referencing the old one.

### `destroy` resyncs the generated demo data

`destroy fact`, `destroy entity`, and `destroy constraint` rewrote the domain
and the app spec but skipped the data-seed re-render, so a removed type stayed
behind in `src/data/data_seed.rs` and broke the build.

Destroy now runs the same demo-data sync the generate paths use. It skips that
render after `destroy solution`, where no planning solution remains to render
the seed against — the one case where re-rendering would be wrong rather than
merely unnecessary.

## Published Version Boundaries

| Surface | Version | Scaffold target |
| ------- | ------- | --------------- |
| CLI | `solverforge-cli 3.3.3` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.3.2` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.3.1` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.3.0` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.2.0` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.4.0` |
| CLI (previous line) | `solverforge-cli 3.1.0` | `solverforge 0.19.5`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.4.0` |

The scaffold targets are unchanged since 3.3.0, and none of the 3.3.x patches
retargets the core runtime: the current core release, `solverforge 0.19.8`, is
ahead of the `solverforge 0.19.7` scaffold line by design.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `3.3.3` | 2026-10-02 | Rewrites every score-bearing surface on `generate score` and resyncs the generated demo data on `destroy`; no scaffold-target change. |
| `3.3.2` | 2026-10-01 | Streams generated constraint skeletons from the `#[planning_solution]` accessors and aligns the bundled skill docs; no scaffold-target change. |
| `3.3.1` | 2026-09-29 | Aligns the CLI dependency baseline with the current releases; no scaffold-target change. |
| `3.3.0` | 2026-09-29 | Retargets the MCP shell to `rmcp 3.5.0`. |
| `3.2.0` | 2026-09-29 | Retargets fresh scaffolds to `solverforge 0.19.7`. |
| `3.1.0` | 2026-09-16 | Targets the latest released scaffold crates, writes MCP configs for opencode, Claude Code, and Cursor, consolidates the agent skills behind the agent-centric installer with ownership receipts, and fixes the MCP solve result schema. |
| `3.0.0` | 2026-09-15 | Adds the `mcp` scaffold shell, `solverforge connect`, countable scalar ranges, the full list-metadata flags, and the `solverforge-modeling` agent skill; moves fresh scaffolds to `solverforge 0.19.4`. |

## Upgrade Checklist

- Re-run `solverforge --version` / `solverforge -V` after installing to confirm
  the binary's scaffold targets; 3.3.3 changed no target.
- If a generated project does not compile after a `generate score` run made with
  an older CLI, re-run `solverforge generate score <SCORE_TYPE>` with 3.3.3 to
  rewrite the remaining surfaces, and check `solverforge.app.toml` still names
  the score type you intend.
- If a `destroy` made with an older CLI left a removed type in
  `src/data/data_seed.rs`, re-run the destroy command with 3.3.3 or run
  `solverforge generate data` to re-render the seed.
- Projects already consistent need no change; both fixes are generator-side.

## Where to read next

Use the [CLI manual](/docs/solverforge-cli/) for the current command surface,
the [generator commands](/docs/solverforge-cli/generator-commands/) page for
`generate score`, `generate solution`, and the `destroy` subcommands, and the
[configuration](/docs/solverforge-cli/configuration/) page for
`solverforge.app.toml`.
