---
title: Routing & Matrices
description: Compute routes, choose objectives, and build matrix data for optimization.
weight: 3
---

# Routing & Matrices

This page covers the methods most applications call after the network is loaded.

## Route a Single Pair

```rust
let route = network.route(locations[0], locations[1])?;

println!("Duration: {} seconds", route.duration_seconds);
println!("Geometry points: {}", route.geometry.len());
```

This is the simplest path from validated coordinates to a route result.

`route()` snaps both endpoints to the nearest graph nodes first. That is usually fine for travel-time estimation, but it can shift the visible start or end of the geometry to a nearby intersection.

## Preserve Road-Segment Endpoints

When you need the rendered geometry to begin and end on the containing road segments, use edge snapping instead of node snapping.

```rust
let from = network.snap_to_edge(locations[0])?;
let to = network.snap_to_edge(locations[1])?;
let route = network.route_edge_snapped(&from, &to)?;
```

This is the better choice for map previews, route-detail UIs, and stop-level visualizations.

## Choose a Routing Objective

The crate exposes an `Objective` type for routing decisions. In practice, most optimization workflows choose between:

- **time-oriented routing** for dispatch and service scheduling
- **distance-oriented routing** for mileage comparisons and diagnostics

When your solver minimizes time windows, lateness, or shift utilization, time-based routing is usually the right default.

```rust
use solverforge_maps::Objective;

let route = network.route_with(locations[0], locations[1], Objective::Distance)?;
```

## Compute a Travel-Time Matrix

```rust
let matrix = network.compute_matrix(&locations, None).await;
println!("Locations: {}", matrix.size());
```

The matrix is the most common output for optimization systems because it lets the solver compare every stop against every other stop using realistic road travel instead of straight-line distance.

### Travel Times and Same-Path Distances

The `2.1.4` release stores two aligned row-major matrices:

- `matrix.get(from, to)` returns travel time in seconds
- `matrix.distance_meters(from, to)` returns meters along the same fastest-time
  path
- `matrix.row(from)` returns the full travel-time row
- `matrix.row_distances(from)` returns the full same-path distance row
- `matrix.as_slice()` exposes the flat travel-time data
- `matrix.distances_as_slice()` exposes the flat distance data

```rust
let time_seconds = matrix.get(0, 1);
let distance_meters = matrix.distance_meters(0, 1);
let all_times_from_depot = matrix.row(0);
let all_distances_from_depot = matrix.row_distances(0);
```

Distances follow the path chosen by the time objective in `compute_matrix`.
That means distance data is suitable for reporting, diagnostics, and secondary
cost displays without recomputing every pair as a separate route. If a pair is
unreachable, both matrices use `UNREACHABLE`. If the indices are outside the
matrix bounds, the accessors return `None`.

## Geometry for Frontend Visualization

`RouteResult` includes geometry that can be rendered directly on a web map. For compact transmission, `solverforge-maps` also exposes Google polyline helpers.

```rust
use solverforge_maps::{decode_polyline, encode_polyline};

let encoded = encode_polyline(&route.geometry);
let decoded = decode_polyline(&encoded);
```

This is a good fit when your architecture computes routes in Rust but renders them in a browser or mobile client.

## Connectivity Diagnostics

A routing failure does not always mean the input is invalid. It may mean the graph is fragmented.

```rust
let components = network.strongly_connected_components();
let largest_fraction = network.largest_component_fraction();
```

These metrics are useful when evaluating a new operating area or diagnosing a matrix with many unreachable pairs.

## Practical Advice

- Use matrices when your solver will evaluate many alternative stop orders.
- Use matrix distance accessors when you need mileage for the same fastest-time
  paths the solver is scoring.
- Use single-route calls when you need a detailed geometry or debugging trace.
- Expand your bounding box if you see unexpected routing failures at the edges of a region.
- Inspect graph connectivity before assuming the optimization layer is at fault.
