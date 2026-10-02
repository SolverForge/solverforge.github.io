---
title: "solverforge-cli 3.3.2: Accessor-Wired Constraint Skeletons"
date: 2026-10-01
draft: false
description: >
  solverforge-cli 3.3.2 streams generated constraint skeletons from the
  #[planning_solution] accessors, fixing the mid-solve "source Unknown cannot
  localize entity indexes" panic on the first solver-applied move, and aligns
  the bundled solverforge-modeling skill with the accessor-wired skeletons.
---

**solverforge-cli 3.3.2** was published on crates.io and released on GitHub
(2026-10-01), so `cargo install solverforge-cli` installed 3.3.2 directly. The
previous package, `solverforge-cli 3.3.1`, carried the same scaffold targets;
this release changed generated constraint skeletons and the bundled skill, not
the dependency line. Use `solverforge --version` to confirm exactly what an
installed binary carries.

<%= render Ui::Callout.new(title: "Update, October 2, 2026") do %>
This is a historical 3.3.2 release note. `solverforge-cli 3.3.3` is now
published and is the current CLI line; it carries the same scaffold targets and
fixes `generate score` and `destroy` in the generator. See the
[3.3.3 release note](/blog/releases/2026/10/02/solverforge-cli-3-3-3/).
<% end %>

New projects target:

- `solverforge 0.19.7`
- `solverforge-ui 0.9.0` for the web shell
- `solverforge-maps 2.1.4` for the web shell
- `rmcp 3.5.0` for the MCP shell

## What Changed

### Generated constraint skeletons stream from planning-solution accessors

Every `solverforge generate constraint` pattern emitted a hand-written
extractor such as `fn entity_items(solution: &Plan) -> &[Task]`. That extractor
carries `ChangeSource::Unknown`, and the incremental engine cannot localize
per-move updates through it: `initialize()` evaluates, but the first
solver-applied move panicked with `source Unknown cannot localize entity
indexes` — unary and reward included. The stub compiled, `solverforge check`
passed, and the panic only surfaced mid-solve.

Skeletons now stream from the accessors `#[planning_solution]` generates for
each collection (`Plan::tasks()`, `Plan::resources()`, ...), which carry the
change-source metadata the incremental engine needs, and the hand-written
extractors are gone from all ten patterns. Join and complement positions accept
the accessor streams directly. The generated stub still needs its placeholder
predicates and weights replaced before it means anything — but the stream
wiring is now correct the moment the file is generated, and no hand-written
extractor may be swapped back in.

Existing apps that already replaced their skeleton placeholders with working
constraints over generated accessors are unaffected. An app that still carries
a hand-written extractor should move its `for_each(...)` streams onto the
generated `Plan::<collection>()` accessors.

### The solverforge-modeling skill matches the accessor-wired skeletons

The bundled skill still described the pre-fix skeleton: its "two mandatory
edits" told users to swap `fn entity_items` for the generated accessors, and
one line claimed `for_each`-only streams tolerate `ChangeSource::Unknown`. Both
are now wrong. The skill states the stub needs only its placeholders replaced
and warns that no hand-written extractor may be swapped back in. It also adds a
fence for a second failure: `nearby_change_move_selector` and
`nearby_swap_move_selector` require `nearby_value_candidates` /
`nearby_entity_candidates` hooks on the targeted scalar variable, with both
remediations documented.

## Published Version Boundaries

| Surface | Version | Scaffold target |
| ------- | ------- | --------------- |
| CLI | `solverforge-cli 3.3.3` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` — current package |
| CLI | `solverforge-cli 3.3.2` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.3.1` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.3.0` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.0` |
| CLI | `solverforge-cli 3.2.0` | `solverforge 0.19.7`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.4.0` |
| CLI (previous line) | `solverforge-cli 3.1.0` | `solverforge 0.19.5`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.4.0` |

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
  the binary's scaffold targets.
- Regenerate any constraint skeleton you have not finished yet
  (`solverforge generate constraint ... --force`) so it streams from the
  accessors; replace the placeholders as before.
- Existing constraints already written over generated
  `Plan::<collection>()` accessors need no change.
- Move any remaining hand-written extractor functions onto the generated
  accessors deliberately and re-run the app's model and solve tests.

## Where to read next

Use the [CLI manual](/docs/solverforge-cli/) for the current command surface,
the [generator commands](/docs/solverforge-cli/generator-commands/) page for
the `generate constraint` patterns this release rewires, and the
[agent skill](/docs/solverforge-cli/agent-skill/) page for the bundled
`solverforge-modeling` skill.
