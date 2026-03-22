---
title: Core Types
description: The building blocks used throughout solverforge-maps.
weight: 2
---

# Core Types

`solverforge-maps` is intentionally small at the API surface. A few types cover most workflows.

## Coord

`Coord` represents a validated latitude/longitude pair.

```rust
use solverforge_maps::Coord;

let coord = Coord::try_new(39.95, -75.16)?;
let trusted = Coord::new(39.95, -75.16);
let as_tuple: (f64, f64) = trusted.into();
```

### Use `try_new` for external input

Prefer `Coord::try_new` for:

- web forms
- uploaded CSV files
- JSON requests
- third-party geocoding responses

That keeps invalid coordinates from entering the routing pipeline.

## BoundingBox

`BoundingBox` describes the geographic region to fetch and index.

```rust
use solverforge_maps::{BoundingBox, Coord};

let locations = vec![
    Coord::try_new(39.95, -75.16)?,
    Coord::try_new(39.96, -75.17)?,
];

let bbox = BoundingBox::from_coords(&locations);
let expanded = bbox.expand_for_routing(&locations);
```

### When to expand

A box that exactly wraps the points is often too small for real routing. Expand when:

- roads detour around rivers, parks, or one-way systems
- your stops sit near the boundary of the fetched area
- you see unexpected unreachable pairs caused by clipped road data

## NetworkConfig

`NetworkConfig` controls how road data is fetched and interpreted.

```rust
use solverforge_maps::{NetworkConfig, SpeedProfile};
use std::time::Duration;

let config = NetworkConfig::new()
    .connect_timeout(Duration::from_secs(30))
    .read_timeout(Duration::from_secs(120))
    .speed_profile(SpeedProfile::default());
```

Typical uses for configuration:

- choosing a cache strategy
- changing Overpass endpoints
- adjusting network request timeouts
- supplying a custom speed profile for travel-time estimation

## SpeedProfile

`SpeedProfile` converts road metadata into travel speeds.

If OpenStreetMap provides a `maxspeed` tag, that value can inform routing. Otherwise the profile falls back to defaults by highway type, such as motorway, primary, or residential roads.

This matters for optimization because route order depends on **time**, not just distance.

## RoadNetwork and NetworkRef

`RoadNetwork` is the main routing graph. `NetworkRef` is the cached handle returned by `load_or_fetch`.

```rust
use solverforge_maps::{NetworkRef, RoadNetwork};

let network: NetworkRef = RoadNetwork::load_or_fetch(&bbox, &config, None).await?;
```

`NetworkRef` dereferences to `RoadNetwork`, so you can call the normal routing methods directly.

## RouteResult

`RouteResult` describes a single route between two locations.

It includes travel duration and route geometry, which makes it useful for:

- map display
- route-detail panels
- debugging route choices
- comparing estimated travel between alternatives

## TravelTimeMatrix

`TravelTimeMatrix` stores all-pairs results for a set of locations.

Use it when you need to:

- pass travel costs into a VRP solver
- compare many route alternatives
- precompute travel estimates for dispatch logic
- separate expensive routing work from later optimization passes
