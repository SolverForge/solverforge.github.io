---
title: Agent Skill
description: >
  Install and use the portable solverforge-modeling and solverforge-ui agent
  skills that turn a described planning problem into a runnable SolverForge
  app with the CLI.
weight: 10
---

# Agent Skill

The `solverforge-modeling` skill lets a coding agent turn a planning problem
described in plain language into a running SolverForge app. You describe what
has to be decided and what makes a plan valid and good; the agent scaffolds the
app with this CLI, writes the model and its constraints in Rust, generates demo
data, and solves it before handing it back.

## Quick Start

1. Install the CLI and check its scaffold targets:

   ```bash
   cargo install solverforge-cli
   solverforge --version
   ```

2. Install the skills from the CLI repository into your agent:

   ```bash
   git clone https://github.com/SolverForge/solverforge-cli
   cd solverforge-cli
   ./scripts/install-skill --agent claude     # or: --agent codex, --agent opencode
   ```

3. Restart the agent so it rescans its skill directories.

4. Describe the problem. The skill opens with the same four questions every
   time, so answering them up front lets the agent go straight to building:

   ```text
   Use the solverforge-modeling skill to build this planning problem.

   Problem: <what is decided, for whom or what, over which horizon>
   Output shell: api            (or web, cli, mcp)
   Hard constraints: <rules a valid plan must never break>
   Soft constraints: <what a better plan has more or less of>
   Score type: HardSoftScore
   Demo data: <the size and shape of a realistic instance>
   ```

5. The agent restates the problem as facts, entities, planning variables, and
   constraints, builds the app, and finishes with a real solve that reports a
   score.

The [maintenance planning walkthrough](/docs/getting-started/maintenance-planning-with-the-agent-skill/)
follows one complete run from a paragraph to a solved plan.

## What Ships

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

Run the installer from the root of a `solverforge-cli` checkout. `--project`
takes a directory that already exists; the installer creates the harness's
skills folder inside it.

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

## Parallel Evaluation Guidance

The modeling skill documents opt-in parallel local-search evaluation through
`solverforge config set move_thread_count.count 4`. It keeps the neutral
scaffold sequential, explains the shared Rayon pool and 32-evaluator cap, and
uses fixed-work parity rather than promising better scores or speedups from a
larger count. See [Configuration](/docs/solverforge-cli/configuration/#parallel-local-search-evaluation)
for the app-wide build-time setting.

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
