---
title: "solverforge-maps 2.5: Bicycle and Foot Networks"
date: 2026-11-21
draft: false
description: >
  solverforge-maps 2.5 loads road networks for bicycles and walkers as well as
  cars: each mode rides its own ways, reads its own access tags, follows or
  ignores one-way streets, travels at its own speed and is cached apart.
---

**solverforge-maps 2.5.0 was published on November 21, 2026**, following
`solverforge-maps 2.4.0`. It is available on
[crates.io](https://crates.io/crates/solverforge-maps/2.5.0), documented on
[docs.rs](https://docs.rs/solverforge-maps/2.5.0), and tagged in the
[source repository](https://github.com/SolverForge/solverforge-maps/tree/v2.5.0).
Its [Publish](https://github.com/SolverForge/solverforge-maps/actions/runs/44897281664),
[Release](https://github.com/SolverForge/solverforge-maps/actions/runs/44897281646),
and [CI](https://github.com/SolverForge/solverforge-maps/actions/runs/44897279372)
workflows passed at `384bbd2`.

This note covers the 2.5 line. Patch releases are folded into it instead of
published as separate release-note pages.

## What Changed

### Bicycle and foot networks (2.5.0)

`RoadNetwork::load_or_fetch_for()` loads an area for a `TravelMode`;
`load_or_fetch()` stays the car's:

```rust
use solverforge_maps::{RoadNetwork, TravelMode};

let bikes = RoadNetwork::load_or_fetch_for(&bbox, &config, TravelMode::Bicycle, None).await?;
let walk = RoadNetwork::load_or_fetch_for(&bbox, &config, TravelMode::Foot, None).await?;
let by_bike = bikes.compute_matrix(&locations, None).await;
```

| Mode | Ways | One-way streets | Speed |
| ---- | ---- | --------------- | ----- |
| `Car` | `NetworkConfig::highway_types`, open to cars | followed | `SpeedProfile` |
| `Bicycle` | streets, tracks, paths and cycleways; footways and pedestrian streets where `bicycle` allows it | followed, unless `oneway:bicycle=no` | 15 km/h |
| `Foot` | every street and path but motorways and trunk roads, steps included | ignored | 5 km/h |

- A bicycle is shut out by `bicycle`, `vehicle` or `access` tags; a walker by
  `foot` or `access`.
- `TravelMode::parse("foot")` and `as_str()` convert to and from
  configuration names, and `TravelMode::ALL` lists every mode.

### A cache per mode

A bicycle or foot network is cached on its own: its cache key carries
`~bicycle` or `~foot` after the area, and an area is only ever served by a
cached network of the same mode. Car keys are unchanged, so regions cached by
2.4 stay valid and the cache stays at version `8`.

## Published Version Boundaries

| Product | Version | Maps dependency |
| ------- | ------- | --------------- |
| `solverforge-maps` | `2.5.0` | current |
| `solverforge-cli` web scaffold | `4.2.2` | `solverforge-maps = { version = "2.3.3" }`, which resolves to `2.5.0` |
| `solverforge-deliveries` | `3.0.1` | `solverforge-maps 2.1.5` |
| `solverforge-fsr` | `3.0.1` | `solverforge-maps 2.1.5` |

The released use-case apps keep the maps version their tags pin.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `2.5.0` | 2026-11-21 | `TravelMode` and `RoadNetwork::load_or_fetch_for()`; a cache per mode. |

## Upgrade Checklist

```toml
[dependencies]
solverforge-maps = "2.5.0"
```

- Nothing to change for cars: `load_or_fetch()` builds and caches the same
  networks as on 2.4.

## Where to read next

- [solverforge-maps documentation](/docs/solverforge-maps/)
- [Routing & Matrices](/docs/solverforge-maps/routing/)
- [solverforge-maps 2.4 release note](/blog/releases/2026/11/21/solverforge-maps-2-4-x/)
