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

This map is aligned with the published `solverforge 0.18.0` crate and current
release workspace.

The facade re-exports the normal modeling, scoring, projection, configuration,
custom-search, and retained runtime surface, including
`solverforge_constraints`, `Projection`, `ProjectionSink`, `SolverConfig`,
`PhaseConfig`, `MoveSelectorConfig`, `SearchContext`, `CustomSearchPhase`,
`ScalarGroup`, `ScalarAssignmentRule`, `ScalarGroupLimits`,
`SharedNodeDiagnostics`, `SharedNodeId`, `SharedNodeOperation`, direct
cross-join `.group_by(|left, right| key, collector)`, cross-join
`.project(|left, right| row)` projected scoring, direct cross-join grouped
complements, symmetric and directed projected self-joins, projected grouped
complements, score weight helpers such as `fixed_weight` and `hard_weight`,
collector helpers such as `count`, `sum`, `load_balance`, `consecutive_runs`,
`collect_vec`, and `indexed_presence`, plus advanced grouped-scalar assignment,
conflict-repair extension types, phase and move-label telemetry, bounded
applied-move and candidate-pull traces, candidate-trace provenance types, and
CVRP profile helpers such as `domain = "cvrp"`, `route_hooks`,
`savings_hooks`, `savings_metric_class`, `route_distance`, `route_feasible`, and
`savings_feasible`. The lower-level solver crate also exposes dynamic
construction names such as `GroupedScalarCursor`, `GroupedScalarSelector`,
`ScalarAssignmentMoveCursor`, `ScalarAssignmentMoveOptions`, and
`ScalarAssignmentRequiredStreamingCursor`, plus immutable runtime model,
provider, and candidate-metric registries for integrations that intentionally
assemble runtime declarations outside the facade. That keeps app code on
`solverforge` unless it needs to implement lower-level solver internals
directly.

## Workspace crates

| Crate                 | Owns                                                                     | Reach for it when...                                                           |
| --------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `solverforge`         | the public facade and re-exports                                         | you are building an app and want the normal public API                         |
| `solverforge-core`    | score types, descriptors, domain traits, and dynamic capability contracts | you are extending lower-level abstractions or implementing core-facing helpers |
| `solverforge-macros`  | `#[planning_solution]`, `#[planning_entity]`, `#[problem_fact]`, `#[solverforge_constraints]` | you need derive behavior, model glue, or constraint-function compilation |
| `solverforge-scoring` | constraint streams, incremental scoring, and shared grouped node state    | you are working directly on scoring internals or advanced scoring extensions   |
| `solverforge-config`  | TOML/YAML parsing, resolved selector policy, candidate-trace config, acceptors, and builders | you need direct config construction or parsing outside the stock solve path    |
| `solverforge-solver`  | runtime compiler, phases, cursor selectors, retained lifecycle, and telemetry | you are building custom runtime behavior beyond facade-level use               |
| `solverforge-bridge`  | dynamic binding contracts, logical IDs, scores, explicit slot capabilities, and the compiled runner | you are implementing or maintaining a binding layer |
| `solverforge-console` | tracing-driven console output                                            | you want the standard terminal UX or progress formatting                       |
| `solverforge-cvrp`    | CVRP-specific helpers and distance utilities                             | your problem is route-centric and the domain benefits from these helpers       |

## Companion repositories

| Repo               | Owns                                                              | Use it when...                                              |
| ------------------ | ----------------------------------------------------------------- | ----------------------------------------------------------- |
| `solverforge-cli`  | scaffolding and code generation                                   | you are starting a new app or extending a generated shell   |
| `solverforge-py`   | the tagged `solverforge 0.5.0` Python source line, PyO3 binding, and embedded UI asset bridge | you want Python model authoring backed by the Rust solver engine |
| `solverforge-ui`   | retained-job frontend controls and scheduling-facing components   | you need a web UI around a retained solve lifecycle         |
| `solverforge-maps` | road networks, routing, matrices, and map-backed planning helpers | you need route costs, geometry, or spatial planning support |

## Practical dependency rules

- Start with `solverforge-cli` to scaffold the app shell.
- Start with the PyPI `solverforge` package when the application surface is
  Python and you do not need a generated Rust web/API/CLI shell. Until the
  `0.5.0` publish gate clears, PyPI latest is `0.4.0`; use the `solverforge-py`
  `v0.5.0` tag for the source-current Python surface.
- Keep application code on the `solverforge` facade unless a lower-level crate
  unlocks something you actually need.
- Keep scalar/list model declarations in the `planning_model!` manifest and
  variable attributes; solver config consumes declared hooks rather than
  inferring nearby or construction-order behavior.
- Keep reusable grouped constraint work inside a
  `#[solverforge_constraints]` function; do not add app-level caches or public
  sharing helpers.
- Add `solverforge-ui` only if the product needs retained-job UI flows.
- Add `solverforge-maps` only if routing or map-backed costs are part of the
  planning model.
- Use `solverforge-py` for Python classes, decorators, callbacks, route/list
  hooks, retained jobs, and embedded UI assets over the native Rust engine.
- Reach into `solverforge-solver` directly only when configuration and the
  public facade stop being enough.
- Reach into `solverforge-scoring` module-scoped names such as
  `stream::projected::DirectedBi` or `constraint::projected::DirectedBi` only
  when you are extending scoring internals; application constraints should use
  the fluent `join(equal_bi(...))` surface.

## Typical stacks

| Scenario                           | Typical stack                                          |
| ---------------------------------- | ------------------------------------------------------ |
| service or CLI planner             | `solverforge-cli` scaffold + `solverforge`             |
| Python-authored planner            | PyPI `solverforge` package or the `solverforge-py v0.5.0` source tag |
| web app with retained lifecycle UI | `solverforge-cli` + `solverforge` + `solverforge-ui`   |
| routing or fleet optimization      | `solverforge-cli` + `solverforge` + `solverforge-maps` |
| research or advanced runtime work  | `solverforge` plus selected lower-level crates         |

## What not to do

- Do not start on the lowest-level crates unless the public API is clearly
  insufficient.
- Do not push app-specific business rules into SolverForge crates just because
  the extension point exists.
- Do not treat `solverforge-ui` or `solverforge-maps` as part of this
  repository's workspace; they are companion repos with their own release lines.
## See also

- [SolverForge docs](/docs/solverforge/)
- [SolverForge Python docs](/docs/solverforge-python/)
- [Integration Boundaries](/reference/integration-surfaces/)
- [Modeling Cheat Sheet](/reference/modeling-cheat-sheet/)
