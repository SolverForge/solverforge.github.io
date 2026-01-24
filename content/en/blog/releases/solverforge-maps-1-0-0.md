---
title: "solverforge-maps 1.0: Routing Infrastructure for VRP Solvers"
date: 2026-01-24
draft: false
tags: [rust, release, maps, vrp]
description: >
  solverforge-maps 1.0 provides zero-erasure road network and routing infrastructure for VRP solvers, with OSM data, R-tree indexing, and 3-tier caching.
---

{{< alert title="Sidecar Release" color="info" >}}
solverforge-maps is a standalone utility library that provides routing infrastructure for vehicle routing problems. It complements the main [SolverForge](/blog/releases/solverforge-0-5-0/) constraint solver but can be used independently with any VRP implementation.
{{< /alert >}}

We're releasing **solverforge-maps 1.0**, our Rust library for road network routing in vehicle routing problems. This library handles the map-related infrastructure that VRP solvers need: fetching road networks, computing travel time matrices, and generating route geometries.

## What It Does

solverforge-maps provides a simple workflow for VRP applications:

```rust
use solverforge_maps::{BoundingBox, Coord, RoadNetwork};

let locations = vec![
    Coord::new(39.95, -75.16),
    Coord::new(39.96, -75.17),
    Coord::new(39.94, -75.15),
];

let bbox = BoundingBox::from_coords(&locations).expand_for_routing(&locations);
let network = RoadNetwork::load_or_fetch(&bbox, &Default::default(), None).await?;
let matrix = network.compute_matrix(&locations, None).await;
```

That's it. Load a road network for your delivery locations, compute the travel time matrix, feed it to your solver.

## Key Features

**Zero-Erasure Architecture**: Following the [SolverForge design philosophy](/blog/releases/solverforge-0-5-0/#zero-erasure-architecture), solverforge-maps uses no `Arc`, no `Box<dyn>`, and no trait objects in hot paths. The `NetworkRef` type provides zero-cost access to cached networks via `Deref`.

**R-Tree Spatial Indexing**: Coordinate snapping to the road network runs in O(log n) via R-tree, making it practical to route thousands of delivery points.

**3-Tier Caching**: Network data flows through in-memory cache, file cache, and Overpass API. Repeated requests for the same region are instant. Cache statistics are exposed for monitoring:

```rust
let stats = RoadNetwork::cache_stats().await;
println!("Hits: {}, Misses: {}", stats.hits, stats.misses);
```

**Dynamic Speed Profiles**: Travel times respect OSM `maxspeed` tags when available, falling back to sensible defaults by road type (motorway: 100 km/h, residential: 30 km/h, etc.).

**Route Geometries**: Full road-following geometries for visualization, with Douglas-Peucker simplification and Google Polyline encoding for efficient transmission to frontends.

**Graph Connectivity Analysis**: Debug routing failures with strongly connected component analysis:

```rust
let components = network.strongly_connected_components();
let largest_fraction = network.largest_component_fraction();
```

**Input Validation**: `Coord` and `BoundingBox` validate on construction with typed errors. No silent NaN propagation or out-of-range coordinates.

## API Surface

The public API consists of:

| Type | Purpose |
|------|---------|
| `Coord` | Validated geographic coordinate |
| `BoundingBox` | Validated rectangular region |
| `RoadNetwork` | Core routing graph |
| `NetworkRef` | Zero-cost cached network reference |
| `TravelTimeMatrix` | N x N travel times with statistics |
| `RouteResult` | Single route with geometry |
| `RoutingProgress` | Progress updates for long operations |

Error handling is explicit via `RoutingError` variants that distinguish snap failures, unreachable pairs, network errors, and invalid input.

## Installation

```toml
[dependencies]
solverforge-maps = "1.0"
tokio = { version = "1", features = ["full"] }
```

## Production Use

We run solverforge-maps in production for the [Vehicle Routing Quickstart](https://github.com/solverforge/solverforge-quickstarts). It handles routing for real delivery optimization scenarios and has proven reliable for our use cases.

The 1.0 version represents API stability. We don't anticipate breaking changes to the public interface.

## Source

- [GitHub Repository](https://github.com/solverforge/solverforge-maps)
- [API Documentation](https://docs.rs/solverforge-maps)
