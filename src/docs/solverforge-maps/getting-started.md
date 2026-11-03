---
title: Getting Started
description: Build your first road-network-backed travel-time matrix with solverforge-maps.
weight: 1
---

# Getting Started with solverforge-maps

This guide covers the standard `solverforge-maps` workflow:

1. validate input coordinates
2. derive a bounding box that covers the relevant area
3. load a road network from cache or Overpass
4. compute a travel-time matrix
5. read same-path route distances from the matrix
6. optionally compute a route for visualization or debugging

## Prerequisites

- Rust stable toolchain
- An async runtime such as Tokio
- HTTPS access to an Overpass API server the first time a region is fetched

## The Overpass Dependency

`solverforge-maps` builds road networks from OpenStreetMap data that it
downloads from an [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API)
server. `NetworkConfig::default()` uses the public instance at
`https://overpass-api.de/api/interpreter` and stores fetched regions in
`.osm_cache`, relative to the process's working directory.

The public instance is a shared community service with usage limits: it answers
busy periods with `429 Too Many Requests`, `502 Bad Gateway`, or
`503 Service Unavailable`, and large regions can take minutes. Every request
identifies the client as `solverforge-maps/<version> (+<repository>)`, as the
instance's usage policy requires. A failed request on a server error, `429`, or
`408` is retried up to `2` more times per endpoint, waiting longer after each
attempt; when every endpoint fails, `load_or_fetch` returns
`RoutingError::Network`. A region already in `.osm_cache` loads without network
access.

For production or CI, point the config at your own Overpass server, or list
fallbacks that are tried in order:

```rust
use solverforge_maps::NetworkConfig;

let config = NetworkConfig::default()
    .overpass_endpoints(vec![
        "https://overpass.example.internal/api/interpreter".to_string(),
        "https://overpass-api.de/api/interpreter".to_string(),
    ])
    .cache_dir("/var/cache/solverforge-maps");
```

## Add the Dependency

```toml
[dependencies]
solverforge-maps = "2"
tokio = { version = "1", features = ["full"] }
```

## Step 1: Start with Validated Coordinates

`Coord::try_new` is the right choice for user input, CSV imports, and API payloads because it rejects invalid latitude and longitude values.

```rust
use solverforge_maps::Coord;

let depot = Coord::try_new(39.9526, -75.1652)?;
let customer_a = Coord::try_new(39.9610, -75.1700)?;
let customer_b = Coord::try_new(39.9440, -75.1500)?;
let locations = vec![depot, customer_a, customer_b];
```

## Step 2: Build a Routing Bounding Box

Use `BoundingBox::from_coords` and then expand it for realistic road detours.

```rust
use solverforge_maps::BoundingBox;

let bbox = BoundingBox::from_coords(&locations).expand_for_routing(&locations);
```

That expansion matters because road routes rarely travel in a straight line. A tight bounding box can clip the roads needed for a valid path.

## Step 3: Load or Fetch the Road Network

```rust
use solverforge_maps::{NetworkConfig, RoadNetwork};

let config = NetworkConfig::default();
let network = RoadNetwork::load_or_fetch(&bbox, &config, None).await?;
```

`load_or_fetch` gives you the normal production behavior:

- reuse the in-memory cache when possible
- reuse the file cache when the region was fetched before
- fetch from the configured Overpass endpoints only when the region is not cached

## Step 4: Compute the Travel-Time Matrix

```rust
let matrix = network.compute_matrix(&locations, None).await;

println!("Matrix size: {}", matrix.size());
println!("Travel time 0 -> 1: {:?} seconds", matrix.get(0, 1));
println!("Distance 0 -> 1: {:?} meters", matrix.distance_meters(0, 1));
```

This matrix is the bridge between geospatial data and optimization. A VRP solver can use it as the cost model for sequencing stops, estimating arrival times, comparing alternative route plans, and reporting the route distance associated with the fastest-time path.

`TravelTimeMatrix` stores route distances next to travel times. `matrix.distance_meters(from, to)` returns meters for the same
fastest-time path used by `matrix.get(from, to)`. Unreachable pairs return
`Some(UNREACHABLE)`, and out-of-bounds indices return `None`.

## Step 5: Route Individual Pairs

```rust
let route = network.route(locations[0], locations[1])?;

println!("Duration: {} seconds", route.duration_seconds);
println!("Geometry points: {}", route.geometry.len());
```

`route()` snaps both endpoints to the nearest graph nodes before routing. That is a good default for travel-time analysis, but it can produce geometries that start and end at nearby intersections instead of the exact stop positions.

For frontend rendering where the route should stay on the containing road segments, use edge snapping:

```rust
let from = network.snap_to_edge(locations[0])?;
let to = network.snap_to_edge(locations[1])?;
let route = network.route_edge_snapped(&from, &to)?;
```

## Full Example

```rust
use solverforge_maps::{BoundingBox, Coord, NetworkConfig, RoadNetwork, RoutingResult};

#[tokio::main]
async fn main() -> RoutingResult<()> {
    let locations = vec![
        Coord::try_new(39.9526, -75.1652)?,
        Coord::try_new(39.9610, -75.1700)?,
        Coord::try_new(39.9440, -75.1500)?,
    ];

    let bbox = BoundingBox::from_coords(&locations).expand_for_routing(&locations);
    let config = NetworkConfig::default();
    let network = RoadNetwork::load_or_fetch(&bbox, &config, None).await?;

    let matrix = network.compute_matrix(&locations, None).await;
    let route = network.route(locations[0], locations[1])?;

    println!("Matrix size: {}", matrix.size());
    println!("Travel time 0 -> 1: {:?} seconds", matrix.get(0, 1));
    println!("Distance 0 -> 1: {:?} meters", matrix.distance_meters(0, 1));
    println!("Route duration: {} seconds", route.duration_seconds);

    Ok(())
}
```

## Common Next Steps

After the first matrix is working, most applications move on to one or more of these tasks:

- inspect route geometry in a frontend map
- check cache hit rates for repeated workloads
- compute full matrices for solver input
- tune `NetworkConfig` for production environments

Read [Routing & Matrices](/docs/solverforge-maps/routing/) and [Caching & Operations](/docs/solverforge-maps/caching/) for those topics.
