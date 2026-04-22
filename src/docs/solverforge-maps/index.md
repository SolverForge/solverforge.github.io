---
title: "solverforge-maps"
linkTitle: "solverforge-maps"
icon: fa-solid fa-route
weight: 20
description: >
  Road-network loading, routing, travel-time matrices, and route geometry utilities for vehicle routing applications.
---

`solverforge-maps` is SolverForge's Rust library for map-backed routing workflows. It is designed for vehicle routing and similar optimization problems where you need to turn geographic coordinates into travel times, route geometries, and network diagnostics.

## What It Provides

- **OSM-backed road networks** loaded from the Overpass API with local caching
- **Validated geographic primitives** such as `Coord` and `BoundingBox`
- **Routing on road graphs** for time- or distance-based objectives
- **Travel-time matrices** for feeding VRP and dispatch solvers
- **Route geometries** for frontend visualization and polyline transport
- **Connectivity diagnostics** for debugging unreachable pairs and bad map regions

## Installation

```toml
[dependencies]
solverforge-maps = "2"
tokio = { version = "1", features = ["full"] }
```

## Minimal Workflow

```rust
use solverforge_maps::{BoundingBox, Coord, NetworkConfig, RoadNetwork, RoutingResult};

#[tokio::main]
async fn main() -> RoutingResult<()> {
    let locations = vec![
        Coord::try_new(39.95, -75.16)?,
        Coord::try_new(39.96, -75.17)?,
        Coord::try_new(39.94, -75.15)?,
    ];

    let bbox = BoundingBox::from_coords(&locations).expand_for_routing(&locations);
    let config = NetworkConfig::default();
    let network = RoadNetwork::load_or_fetch(&bbox, &config, None).await?;

    let matrix = network.compute_matrix(&locations, None).await;
    let route = network.route(locations[0], locations[1])?;

    println!("{} locations", matrix.size());
    println!("Route duration: {} seconds", route.duration_seconds);
    Ok(())
}
```

`route()` snaps endpoints to nearby graph nodes. For frontend geometry that should stay anchored to the containing road segments, use `snap_to_edge` with `route_edge_snapped` instead.

## When To Use It

Use `solverforge-maps` when your optimization model needs **real road travel times** instead of crow-flies distance. Typical use cases include:

- vehicle routing and dispatch
- field-service scheduling
- technician assignment with travel
- territory planning and coverage analysis
- map-based optimization frontends that need route geometry

## Sections

- **[Getting Started](getting-started/)** — From coordinates to a computed matrix
- **[Core Types](core-types/)** — `Coord`, `BoundingBox`, `NetworkConfig`, and `RoadNetwork`
- **[Routing & Matrices](routing/)** — Routes, snapping, matrices, geometries, and objectives
- **[Caching & Operations](caching/)** — Cache management, progress updates, and diagnostics

## External References

- [GitHub repository](https://github.com/solverforge/solverforge-maps)
- [API documentation on docs.rs](https://docs.rs/solverforge-maps)
