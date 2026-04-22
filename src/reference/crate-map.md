---
title: "Crate & Runtime Map"
description: "A practical map of the SolverForge workspace and the companion repos around it."
---

# Crate & Runtime Map

Use this page when you need to decide which crate or companion repository should
own a piece of work.

## Default starting point

For most application code, depend on `solverforge` and stay on the facade until
you have a concrete reason to go lower-level.

## Workspace crates

| Surface | Owns | Reach for it when... |
|---|---|---|
| `solverforge` | the public facade and re-exports | you are building an app and want the normal public API |
| `solverforge-core` | score types, descriptors, domain traits | you are extending lower-level abstractions or implementing core-facing helpers |
| `solverforge-macros` | `#[planning_solution]`, `#[planning_entity]`, `#[problem_fact]` | you need derive behavior or macro-generated domain glue |
| `solverforge-scoring` | constraint streams and incremental scoring | you are working directly on scoring internals or advanced scoring extensions |
| `solverforge-config` | TOML and YAML config parsing/builders | you need direct config construction or parsing outside the stock solve path |
| `solverforge-solver` | phases, move selectors, acceptors, retained lifecycle | you are building custom runtime behavior beyond facade-level use |
| `solverforge-console` | tracing-driven console output | you want the standard terminal UX or progress formatting |
| `solverforge-cvrp` | CVRP-specific helpers and distance utilities | your problem is route-centric and the domain benefits from these helpers |

## Companion repositories

| Repo | Owns | Use it when... |
|---|---|---|
| `solverforge-cli` | scaffolding and code generation | you are starting a new app or extending a generated shell |
| `solverforge-ui` | retained-job frontend controls and scheduling-facing components | you need a web UI around a retained solve lifecycle |
| `solverforge-maps` | road networks, routing, matrices, and map-backed planning helpers | you need route costs, geometry, or spatial planning support |

## Practical dependency rules

- Start with `solverforge-cli` to scaffold the app shell.
- Keep application code on the `solverforge` facade unless a lower-level crate
  unlocks something you actually need.
- Add `solverforge-ui` only if the product needs retained-job UI flows.
- Add `solverforge-maps` only if routing or map-backed costs are part of the
  planning model.
- Reach into `solverforge-solver` directly only when configuration and the
  public facade stop being enough.

## Typical stacks

| Scenario | Typical stack |
|---|---|
| service or CLI planner | `solverforge-cli` scaffold + `solverforge` |
| web app with retained lifecycle UI | `solverforge-cli` + `solverforge` + `solverforge-ui` |
| routing or fleet optimization | `solverforge-cli` + `solverforge` + `solverforge-maps` |
| research or advanced runtime work | `solverforge` plus selected lower-level crates |

## What not to do

- Do not start on the lowest-level crates unless the public surface is clearly
  insufficient.
- Do not push app-specific business rules into SolverForge crates just because
  the extension point exists.
- Do not treat `solverforge-ui` or `solverforge-maps` as part of this
  repository's workspace; they are companion repos with their own release lines.

## See also

- [SolverForge docs](/docs/solverforge/)
- [Integration Surfaces](/reference/integration-surfaces/)
- [Modeling Cheat Sheet](/reference/modeling-cheat-sheet/)
