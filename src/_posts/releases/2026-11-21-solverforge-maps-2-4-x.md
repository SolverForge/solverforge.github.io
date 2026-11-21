---
title: "solverforge-maps 2.4: Slowdowns for Busy Periods"
date: 2026-11-21
draft: false
description: >
  solverforge-maps 2.4 measures travel at busy times of day: chosen road
  classes, anywhere or inside an area, take longer to drive, and every edge
  carries the class of its road.
---

<%= render Ui::Callout.new(title: "Historical release note", variant: "warning") do %>
This post records an older maps line. The current release is
`solverforge-maps 2.5.0`; see the
[2.5 maps release note](/blog/releases/2026/11/21/solverforge-maps-2-5-x/).
<% end %>

**solverforge-maps 2.4.0 was published on November 21, 2026**, following
`solverforge-maps 2.3.4`. It is available on
[crates.io](https://crates.io/crates/solverforge-maps/2.4.0), documented on
[docs.rs](https://docs.rs/solverforge-maps/2.4.0), and tagged in the
[source repository](https://github.com/SolverForge/solverforge-maps/tree/v2.4.0).
Its [Publish](https://github.com/SolverForge/solverforge-maps/actions/runs/44889903862),
[Release](https://github.com/SolverForge/solverforge-maps/actions/runs/44889903928),
and [CI](https://github.com/SolverForge/solverforge-maps/actions/runs/44889902327)
workflows passed at `efaa2ed`.

This note covers the 2.4 line. Patch releases are folded into it instead of
published as separate release-note pages.

## What Changed

### Slowdowns for busy periods (2.4.0)

OpenStreetMap carries no traffic, so a busy period is described as roads that
take longer to drive. `RoadNetwork::slowed()` returns the same network with
each edge's travel time multiplied by the factors of the slowdowns that apply
to it:

```rust
use solverforge_maps::{BoundingBox, RoadClass, Slowdown};

let streets = Slowdown::new(1.6)
    .expect("a factor above zero")
    .roads([RoadClass::Primary, RoadClass::Secondary, RoadClass::Residential]);
let centre = Slowdown::new(1.3)
    .expect("a factor above zero")
    .roads([RoadClass::Trunk])
    .area(BoundingBox::new(45.04, 7.63, 45.10, 7.72));

let rush = network.slowed(&[streets, centre]);
let morning = rush.compute_matrix(&locations, None).await;
```

- A slowdown applies to the road classes it lists, or to every road when it
  lists none, and only to edges whose midpoint lies in its area when it has one.
- Slowdowns that overlap multiply.
- A factor must be a finite number above zero; `Slowdown::new` returns a
  `SlowdownError` otherwise. A factor below 1 makes roads faster.
- Nodes, distances, names and connectivity stay the same, so places snap to
  the same roads and every route still exists. Only the fastest path and its
  time change.

### Road classes on every edge (2.4.0)

Every edge carries a `RoadClass` taken from its OpenStreetMap `highway` tag.
Links (`motorway_link`, `trunk_link`, …) take the class of the road they
serve, and any other tag is `RoadClass::Other`. `RoadClass::parse()` and
`as_str()` convert to and from the names used in configuration (`motorway`,
`living_street`, `other`), and `RoadClass::ALL` lists every class.
`RoadNetwork::from_test_data_classed()` builds a test network whose edges carry
a class.

### Cache

The file cache moves to version `8`, which records each edge's road class.
Regions cached under an older version are fetched and rebuilt on first use.

## Published Version Boundaries

| Product | Version | Maps dependency |
| ------- | ------- | --------------- |
| `solverforge-maps` | `2.4.0` | current |
| `solverforge-cli` web scaffold | `4.2.2` | `solverforge-maps = { version = "2.3.3" }` |
| `solverforge-deliveries` | `3.0.1` | `solverforge-maps 2.1.5` |
| `solverforge-fsr` | `3.0.1` | `solverforge-maps 2.1.5` |

The released use-case apps keep the maps version their tags pin.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `2.4.0` | 2026-11-21 | `Slowdown`, `SlowdownError` and `RoadNetwork::slowed()`; `RoadClass` on every edge; cache version `8`. |

## Upgrade Checklist

```toml
[dependencies]
solverforge-maps = "2.4.0"
```

- The first run after upgrading rebuilds cached regions.
- Travel at usual speeds is unchanged: a network without slowdowns measures
  exactly as on 2.3.

## Where to read next

- [solverforge-maps documentation](/docs/solverforge-maps/)
- [Routing & Matrices](/docs/solverforge-maps/routing/)
- [solverforge-maps 2.2 and 2.3 release note](/blog/releases/2026/11/06/solverforge-maps-2-2-2-3-x/)
