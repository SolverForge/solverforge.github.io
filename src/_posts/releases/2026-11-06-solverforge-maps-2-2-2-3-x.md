---
title: "solverforge-maps 2.2 and 2.3: Car-Legal Graphs, Street Names, Access-Aware Snapping"
date: 2026-11-06
draft: false
description: >
  solverforge-maps 2.2 builds road graphs a car can legally drive, 2.3 reports
  the named streets along every route, and the 2.3 patches keep itinerary stops
  off one-way fragments and closed stubs.
---

**solverforge-maps 2.3.3 was published on November 6, 2026**, following
`solverforge-maps 2.1.5`. It is available on
[crates.io](https://crates.io/crates/solverforge-maps/2.3.3), documented on
[docs.rs](https://docs.rs/solverforge-maps/2.3.3), and tagged in the
[source repository](https://github.com/SolverForge/solverforge-maps/tree/v2.3.3).
Its [Publish](https://github.com/SolverForge/solverforge-maps/actions/runs/42302645377),
[Release](https://github.com/SolverForge/solverforge-maps/actions/runs/42302643785),
and [CI](https://github.com/SolverForge/solverforge-maps/actions/runs/42302638820)
workflows passed at `4ce9dd1`.

This note covers the 2.2 and 2.3 lines. Patch releases are folded into it
instead of published as separate release-note pages.

## What Changed

### Car-legal road graphs (2.2.0)

The road graph follows what a car may legally drive:

- `NetworkConfig::default().highway_types` includes the `motorway_link`,
  `trunk_link`, `primary_link`, `secondary_link` and `tertiary_link` ramps, so
  motorways can be entered and left.
- Roundabouts (`junction=roundabout` or `circular`) and motorways are one-way
  unless tagged otherwise. `oneway=yes`, `true` or `1` runs in drawing
  direction, `-1` or `reverse` runs against it, and `reversible` or
  `alternating` ways are left out.
- Ways closed to cars by `motorcar`, `motor_vehicle`, `vehicle` or `access`
  are left out, with the most specific tag winning; `destination` stays open.
- Graph nodes are OSM nodes, so a bridge passing over a road at the same
  position no longer becomes a junction.
- A route whose two points snap to the same node returns that node instead of
  a straight line between the raw points.

Travel times and matrices computed on 2.2 can differ from 2.1 for the same
coordinates: ramps join the graph, roundabouts and motorways are driven in one
direction only, and roads closed to cars are gone.

### Street names on every route (2.3.0)

OSM `name` tags are carried on graph edges, and every `RouteResult` reports
`streets`: the named streets in driving order, each as a `StreetRun` with the
meters driven on it.

```rust
let route = network.route(locations[0], locations[1])?;

for street in &route.streets {
    println!("{}: {:.0} m", street.name, street.distance_m);
}
```

Consecutive edges on the same street merge into one run, unnamed road pieces are
left out, and partial first and last edges count only the distance actually
driven. `network.edges_with_names_iter()` exposes the names on the raw edges.

### Access-aware snapping (2.3.1 to 2.3.3)

A stop whose nearest graph node sits on a one-way fragment, or on a closed stub
such as a parking loop, could make every ordering infeasible.
`compute_matrix_with_access()` takes one `SnapAccess` per location
(`Both` for stops a route arrives at and leaves, `Outgoing` for a pure start,
`Incoming` for a pure end) and snaps each location to a nearby node it can
traverse in that direction. Among those candidates it prefers the node on the
largest connected part of the network, and the plain nearest node wins ties;
when no candidate allows the direction, the plain nearest node is kept.

```rust
use solverforge_maps::SnapAccess;

let access = vec![SnapAccess::Outgoing, SnapAccess::Both, SnapAccess::Incoming];
let matrix = network.compute_matrix_with_access(&locations, &access, None).await;
```

`route()` uses the same rule: its start snaps as `Outgoing` and its end as
`Incoming`. `compute_matrix()` and `snap_to_road_detailed()` keep their exact
nearest-node behavior. `SnapAccess` is exported at the crate root, and
`snap_road_index_with_access()` exposes the snapping for one coordinate.

### Cache

The file cache moves to version `6` in 2.2.0 and to version `7` in 2.3.0.
Regions cached under an older version are fetched and rebuilt on first use.

## Published Version Boundaries

| Product | Version | Maps dependency |
| ------- | ------- | --------------- |
| `solverforge-maps` | `2.3.3` | current |
| `solverforge-cli` web scaffold | `4.0.2` | `solverforge-maps = { version = "2.3.3" }` |
| `solverforge-deliveries` | `3.0.1` | `solverforge-maps 2.1.5` |
| `solverforge-fsr` | `3.0.1` | `solverforge-maps 2.1.5` |

The released use-case apps keep the maps version their tags pin.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `2.3.3` | 2026-11-06 | Access-aware snapping prefers the candidate on the largest connected component, so a stop beside a closed stub stays reachable. |
| `2.3.2` | 2026-11-06 | `SnapAccess` is re-exported at the crate root. |
| `2.3.1` | 2026-11-06 | Adds `SnapAccess`, `compute_matrix_with_access()` and `snap_road_index_with_access()`; `route()` snaps its start as leaving and its end as arriving. |
| `2.3.0` | 2026-11-06 | Street names on graph edges and `RouteResult::streets`; cache version `7`. |
| `2.2.0` | 2026-11-06 | Car-legal road graph: ramps included, one-way roundabouts and motorways, car access tags honoured, OSM-node junctions; cache version `6`. |

## Upgrade Checklist

```toml
[dependencies]
solverforge-maps = "2.3.3"
```

- Expect different travel times than 2.1 in areas with ramps, roundabouts, or
  roads closed to cars; re-baseline any stored expectations.
- For itineraries, call `compute_matrix_with_access()` with each location's
  role instead of `compute_matrix()`.
- The first run after upgrading rebuilds cached regions.

## Where to read next

- [solverforge-maps documentation](/docs/solverforge-maps/)
- [Routing & Matrices](/docs/solverforge-maps/routing/)
- [solverforge-maps 2.1.x release note](/blog/releases/2026/05/03/solverforge-maps-2-1-x/)
