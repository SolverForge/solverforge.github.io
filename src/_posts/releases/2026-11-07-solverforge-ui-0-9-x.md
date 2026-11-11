---
title: "solverforge-ui 0.9.x: The Agent Skill Moves to solverforge-cli, Dashed Routes"
date: 2026-11-07
draft: false
description: >
  solverforge-ui 0.9.0 moves the solverforge-ui agent skill into the
  solverforge-cli package, and 0.9.1 lets map routes draw a dashed stroke.
---

**solverforge-ui 0.9.1 was published on November 7, 2026**, following
`solverforge-ui 0.9.0`. It is available on
[crates.io](https://crates.io/crates/solverforge-ui/0.9.1), documented on
[docs.rs](https://docs.rs/solverforge-ui/0.9.1), and tagged in the
[source repository](https://github.com/SolverForge/solverforge-ui/tree/v0.9.1).
Its [Publish](https://github.com/SolverForge/solverforge-ui/actions/runs/42411875031),
[Release](https://github.com/SolverForge/solverforge-ui/actions/runs/42411875086),
and [CI](https://github.com/SolverForge/solverforge-ui/actions/runs/42411873082)
workflows passed at `94cfd9e`.

Patch releases are folded into this line note instead of published as separate
release-note pages.

## What Changed

### Dashed map routes (0.9.1)

`drawRoute()` passes an optional `dashArray` to the Leaflet polyline:

```js
map.drawRoute({
  points: [
    [45.08, 7.7],
    [45.07, 7.69],
  ],
  color: "#10b981",
  dashArray: "6 8",
});
```

Without `dashArray` the stroke stays solid, as before. A dashed stroke suits a
leg that differs from the rest of the route, such as the closing leg of a round
trip.

### The agent skill ships with solverforge-cli (0.9.0)

The `solverforge-ui` agent skill moved to the
[solverforge-cli repository](https://github.com/SolverForge/solverforge-cli)
(`skills/solverforge-ui/`) and installs with that repository's
`./scripts/install-skill --agent <harness>`. The crate no longer carries the skill files or the
`make install-skill` target. The asset API, the Axum routes, and the browser
contract are the same as `0.8.0`.

## Published Version Boundaries

| Product | Version | UI dependency |
| ------- | ------- | ------------- |
| `solverforge-ui` | `0.9.1` | current |
| `solverforge-cli` web scaffold | `4.0.4` | `solverforge-ui = { version = "0.9.1" }` |
| Released use-case apps | `3.0.x` / `0.3.x` | `solverforge-ui 0.9.0` |

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.9.1` | 2026-11-07 | `drawRoute()` accepts an optional `dashArray` for a dashed stroke. |
| `0.9.0` | 2026-09-15 | The agent skill moves to `solverforge-cli`; no runtime or asset change. |

## Upgrade Checklist

```toml
[dependencies]
solverforge-ui = { version = "0.9.1" }
```

- The versioned bundles are `/sf/sf.0.9.1.css` and `/sf/sf.0.9.1.js`, and
  `SF.version` reports `"0.9.1"`.
- Install the agent skill from a `solverforge-cli` checkout with
  `./scripts/install-skill --agent claude` (or `codex`, `opencode`).

## Where to read next

- [solverforge-ui documentation](/docs/solverforge-ui/)
- [Integration and assets](/docs/solverforge-ui/integration-assets/)
- [solverforge-ui agent skill](/docs/solverforge-ui/agent-skill/)
