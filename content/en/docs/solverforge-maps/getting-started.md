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
5. optionally compute a route for visualization or debugging

## Prerequisites

- Rust stable toolchain
- An async runtime such as Tokio
- Internet access the first time a new road network is fetched

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
- fall back to the Overpass API only when necessary

## Step 4: Compute the Travel-Time Matrix

```rust
let matrix = network.compute_matrix(&locations, None).await;

println!("Matrix size: {}", matrix.size());
```

This matrix is the bridge between geospatial data and optimization. A VRP solver can use it as the cost model for sequencing stops, estimating arrival times, and comparing alternative route plans.

## Step 5: Route Individual Pairs

```rust
let route = network.route(locations[0], locations[1])?;

println!("Duration: {} seconds", route.duration_seconds);
println!("Geometry points: {}", route.geometry.len());
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

Read [Core Types](../core-types/), [Routing & Matrices](../routing/), and [Caching & Operations](../caching/) for those topics.
