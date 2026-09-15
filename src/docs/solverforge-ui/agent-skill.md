---
title: Agent Skill
description: >
  Install and use the portable solverforge-ui agent skill that teaches a coding
  agent to extend a solverforge-cli scaffold into a domain-faithful UI.
weight: 5
---

# Agent Skill

`solverforge-ui 0.8.0` ships a portable, harness-agnostic agent skill under
`skills/solverforge-ui/` in the
[solverforge-ui repository](https://github.com/SolverForge/solverforge-ui). The
skill teaches a coding agent to extend a thin `solverforge-cli` scaffold into a
domain-faithful interface using only the shipped `SF.*` components, so the
planning model stays the single source of truth and the generated backend stays
untouched.

It is a playbook over the library, not a second API: the crate `README.md` at
the matching version remains the authoritative contract. The skill's references
carry the judgment calls the API reference does not, such as which scheduling
surface expresses a given planning shape and how to map generated records onto
timeline, Gantt, map, rail, and table models.

## What It Covers

- Reading a `solverforge-cli` scaffold and extending its neutral shell instead
  of replacing it
- Choosing between the rail timeline, Gantt, the optional map module, low-level
  rail primitives, and tables for a given optimization shape
- Mapping generated entities, facts, scalar variables, list variables, and
  constraints onto component models with integer-minute axes, lanes, items,
  overlays, tones, and unassigned work
- The `SF.createBackend(...)` / `SF.createSolver(...)` lifecycle contract and
  the rules that keep it correct
- Validating the assembled UI in a real browser rather than trusting a
  successful build

## Install

The installer copies the skill into each selected harness's **own** skills
directory. There is no symlink and no shared central location, so every harness
gets an independent, self-contained copy.

```sh
# Default: user scope for opencode, Claude Code, and the Agent Skills standard
./scripts/install-skill

# Explicitly choose harnesses
./scripts/install-skill --only opencode
./scripts/install-skill --only claude
./scripts/install-skill --only agents

# Into a specific scaffolded app; each harness gets its own project directory
./scripts/install-skill --project ../my-scheduler

# Any other skills directory you want
./scripts/install-skill --dir ~/.config/some-harness/skills

# Inspect or remove
./scripts/install-skill --list
./scripts/install-skill --uninstall
```

| Harness | User scope | Project scope (`--project <dir>`) |
| --- | --- | --- |
| opencode | `~/.config/opencode/skills` | `<dir>/.opencode/skills` |
| Claude Code | `~/.claude/skills` | `<dir>/.claude/skills` |
| Agent Skills | `~/.agents/skills` | `<dir>/.agents/skills` |

From the repository root, `make install-skill` runs the same script. Restart the
agent after installing so it rescans skill directories.

Each installed copy includes an ownership receipt recording the copied payload.
Updates and uninstalls proceed only when that receipt is valid and the installed
files are unchanged. An unmanaged directory, an invalid receipt, or local
customizations are reported and left untouched; resolve those conflicts
manually before rerunning the command.

## How The Skill Is Structured

`skills/solverforge-ui/SKILL.md` is the workflow and the non-negotiable rules.
It points to focused reference files for the task at hand:

| Need | Reference |
| --- | --- |
| Scaffold anatomy, boot contract, `ui-model.json`, module layout, CSS | `references/app-architecture.md` |
| Exact `SF.*` factories, config keys, return values, tones | `references/components.md` |
| Backend seam, `createSolver` contract, lifecycle rules | `references/solver-lifecycle.md` |
| Turning domain records into timeline, Gantt, map, and table models | `references/data-mapping.md` |
| "Which surface should I build for this problem?" | `references/problem-shapes.md` |
| Proving the UI works end to end | `references/validation.md` |

The skill metadata records the `solverforge-ui` version it was written against;
check the version an app actually pins in `Cargo.lock` before relying on a
detail.

## Guardrails The Skill Enforces

The skill is written to keep the generated model and the `/sf`, `/jobs`, and
`/demo-data` contract intact:

- Keep the backend seam. Use `SF.createBackend(...)` and `SF.createSolver(...)`
  rather than hand-rolled `fetch` or `EventSource`.
- Render the app's records, not a reinvented domain model.
- Deep-clone every plan before it reaches the solver.
- Keep timeline time integer-only.
- Never hand-edit `static/generated/ui-model.json`.
- Treat component content as text by default and use the documented
  `unsafeHtml` fields only with trusted, escaped content.
- Surface real lifecycle state rather than optimistic results, and validate in a
  real browser.

## External References

- [solverforge-ui repository](https://github.com/SolverForge/solverforge-ui)
- [solverforge-ui 0.8.x release notes](/blog/releases/2026/09/15/solverforge-ui-0-8-x/)
- [Components](/docs/solverforge-ui/components/)
- [Scheduling Views](/docs/solverforge-ui/scheduling-views/)
- [Integration & Assets](/docs/solverforge-ui/integration-assets/)
