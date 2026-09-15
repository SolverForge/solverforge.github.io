---
title: Agent Skill
description: >
  Install and use the portable solverforge-modeling agent skill that turns a
  described planning problem into a runnable SolverForge app with the CLI.
weight: 10
---

# Agent Skill

`solverforge-cli` ships a portable agent skill at `skills/solverforge-modeling/`
in the [solverforge-cli repository](https://github.com/SolverForge/solverforge-cli).
It teaches a coding agent to turn a described planning problem into a runnable
SolverForge app with this CLI, and it bundles a solve smoke-test helper. It is
harness-agnostic: the same folder is discovered by opencode, Claude Code,
Codex, and other Agent Skills harnesses.

## Install

The bundled installer copies the skill into each selected harness's own skills
directory. Nothing is symlinked; every destination receives an independent,
self-contained copy. It refuses to overwrite or remove an entry it did not
create.

```bash
./scripts/install-skill                    # ~/.agents/skills (cross-harness)
./scripts/install-skill --only opencode    # ~/.config/opencode/skills
./scripts/install-skill --only claude      # ~/.claude/skills
./scripts/install-skill --project <dir>    # per-harness project scope
./scripts/install-skill --dir <path>       # any explicit skills directory
./scripts/install-skill --list             # show install state
./scripts/install-skill --uninstall        # remove previously installed copies
```

From the repository root, `make install-skill` runs the same installer.

| Harness | User scope | Project scope (`--project <dir>`) |
| --- | --- | --- |
| opencode | `~/.config/opencode/skills` | `<dir>/.opencode/skills` |
| Claude Code | `~/.claude/skills` | `<dir>/.claude/skills` |
| Agent Skills | `~/.agents/skills` | `<dir>/.agents/skills` |

The default destination is `~/.agents/skills`, the Agent Skills standard
directory that opencode and Codex also discover. When `--dir` is given, `--only`
and `--project` are ignored.

## Solve Smoke Test

The skill's `scripts/solve-smoke-test.sh <app-dir>` verifies a generated app
after an agent edits it:

- for web and API shells it builds, boots, starts a real solve, and requires a
  clean `COMPLETED` result with published scores
- for MCP shells it boots the HTTP transport and requires a healthy,
  panic-free server
- for CLI shells it validates `demo-data` serialization

It is a development aid, not a replacement for the generated-app test suites
described in the CLI repository's validation flow.

## See Also

- [MCP Shell](/docs/solverforge-cli/mcp-shell/) - the agent-facing delivery surface
- [Modeling & Generation](/docs/solverforge-cli/modeling-and-generation/) - the workflow the skill automates
- [Getting Started](/docs/solverforge-cli/getting-started/) - the manual path through the same steps
