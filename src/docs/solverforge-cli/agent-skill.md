---
title: Agent Skill
description: >
  Install and use the portable solverforge-modeling and solverforge-ui agent
  skills that turn a described planning problem into a runnable SolverForge
  app with the CLI.
weight: 10
---

# Agent Skill

`solverforge-cli` ships portable agent skills in the
[solverforge-cli repository](https://github.com/SolverForge/solverforge-cli):

- `skills/solverforge-modeling/` turns a described planning problem into a
  runnable SolverForge app with this CLI - facts, entities, scalar and list
  planning variables, constraints, demo data, output shells, and verification
  - and bundles a solve smoke-test helper.
- `skills/solverforge-ui/` extends a generated web shell into a domain-faithful
  interface with the shipped `solverforge-ui` components.

Both are plain directory trees: `SKILL.md`, `references/`, and any bundled
`scripts/`. Each is harness-agnostic: the same folder is discovered by opencode,
Claude Code, Codex, and other Agent Skills harnesses.

## Install

The bundled installer is agent-centric: you name the agent harnesses you use,
and it resolves each harness's own skills directory. It never installs into a
directory you did not ask for, never assumes `~/.agents` as a default, and only
updates or removes entries it owns - installed copies carry a
`.solverforge-skill` marker, and a skill copied by hand has no marker, so the
installer treats it as foreign and leaves it untouched.

```bash
./scripts/install-skill --agent opencode            # one copy per harness (default layout)
./scripts/install-skill --agent claude
./scripts/install-skill --agent codex
./scripts/install-skill --agent opencode --agent claude --layout covering
./scripts/install-skill --agent opencode --link     # symlink instead of copy
./scripts/install-skill --agent opencode --project <dir>   # project instead of user scope
./scripts/install-skill --dir <path>                # any explicit skills directory
./scripts/install-skill --agent opencode --list     # show install state
./scripts/install-skill --agent opencode --uninstall
```

`--agent` is repeatable and accepts `--agent opencode|claude|codex`; when
omitted on a TTY the installer prompts. `--skill
<name>` (repeatable) selects a subset; the default is every skill under
`skills/`. From the repository root, `make install-skill` runs the same
installer; pass harness selections with
`make install-skill ARGS='--agent <harness>'`.

| Harness | User scope | Project scope (`--project <dir>`) | Scanned by |
| --- | --- | --- | --- |
| opencode | `~/.config/opencode/skills` | `<dir>/.opencode/skills` | opencode |
| Claude Code | `~/.claude/skills` | `<dir>/.claude/skills` | opencode, Claude Code |
| Codex / Agent Skills | `~/.agents/skills` | `<dir>/.agents/skills` | opencode, Codex |

Because opencode scans all three directories, per-harness copies for selections
that include opencode would make opencode discover the same skill more than
once. `--layout covering` computes one duplicate-free placement shared by the
selected harnesses; the default `--layout per-harness` writes one copy per
harness (and refuses duplicate discovery unless `--force` is passed). The
`{opencode, claude, codex}` combination has no duplicate-free placement, so the
installer reports it and asks you to choose two, or to accept duplicates with
`--layout per-harness --force`. Restart the agent after installing so it
rescans skill directories.

## Solve Smoke Test

The modeling skill's `scripts/solve-smoke-test.sh <app-dir>` verifies a
generated app after an agent edits it:

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
