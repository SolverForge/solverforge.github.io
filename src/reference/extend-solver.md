---
title: "Extend the Solver"
description: "Engineer-facing reference for tuning SolverForge behavior without losing the stock runtime path."
---

# Extend the Solver

Start with the stock runtime and make it earn the next abstraction. Most SolverForge
apps need better domain modeling and better constraints before they need custom
solver machinery.

## The default rule

Change the solver in this order:

1. fix the domain model
2. fix the constraints and score weights
3. tune `solver.toml`
4. add custom runtime pieces only when configuration stops being enough

That order keeps the application understandable and lets you keep using the
well-tested retained runtime path.

## What belongs where

| Concern | Best home |
|---|---|
| business rules and penalties | constraint code |
| search strategy and runtime limits | `solver.toml` |
| per-job adjustments | a `#[planning_solution(config = \"...\")]` callback layering on top of the loaded config |
| UI-specific progress display | the edge layer, not the runtime |
| experimental custom phases or selectors | app-side code using the lower-level crates |

## Canonical selector defaults

If `move_selector` is omitted, the stock runtime stays intentionally narrow:

- scalar-only models default to `ChangeMoveSelector`
- list-only models default to `NearbyListChangeMoveSelector(20)`,
  `NearbyListSwapMoveSelector(20)`, and `ListReverseMoveSelector`
- mixed models use the list defaults first, then scalar change

`limited_neighborhood` is the tool for putting a hard cap on one neighborhood
that is otherwise too broad. It is not a substitute for understanding the
search policy you are expressing.

## Tune in this order

| Tuning step | Use it for |
|---|---|
| construction phase choice | initial feasibility and seed quality |
| local search acceptor | exploration vs greediness |
| move selector choice | neighborhood breadth and cost |
| `accepted_count_limit` | how many accepted candidates are retained for final selection |
| termination limits | wall time, unimproved steps, or best-score goals |
| VND / exhaustive / partitioned search | explicit advanced search strategies, not a default reflex |

## When custom code is justified

Write custom solver code when one of these is true:

- the stock phases cannot express the search policy you need
- the neighborhood generator must encode domain-specific structure that config
  cannot capture
- you need app-specific orchestration around retained jobs and snapshots
- a lower-level crate gives you leverage that the facade intentionally hides

If you go there, keep the blast radius small. Prefer one app-side extension over
forking the scaffold or bypassing the retained runtime wholesale.

## Telemetry and lifecycle expectations

Retained jobs now expose exact counts and durations through structured events.
That means:

- generated, evaluated, and accepted move counts belong to runtime telemetry
- generation and evaluation durations stay exact in the event stream
- `moves/s` is a display-only derived metric at the UI edge
- pause, resume, snapshot fetch, and analysis should use the retained
  `SolverManager` contract rather than ad-hoc channels

## Practical checklist

- keep the domain model and config separate
- only use a config callback to decorate loaded config, not replace it blindly
- tune constraints before tuning search
- benchmark any custom neighborhood work before adopting it permanently
- preserve structured events so `solverforge-ui` and service layers stay honest

## See also

- [Docs: Solver](/docs/solverforge/solver/)
- [Lifecycle Contract](/reference/lifecycle-pause-resume-contract/)
- [Integration Surfaces](/reference/integration-surfaces/)
