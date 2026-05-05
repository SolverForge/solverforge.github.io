---
title: "solverforge-maps 2.1.4: Matrix Route Distances"
date: 2026-05-03
draft: false
description: >
  solverforge-maps 2.1.4 stores same-path route distances next to travel-time
  matrix data for routing and delivery applications.
---

**solverforge-maps 2.1.4** is available on
[crates.io](https://crates.io/crates/solverforge-maps/2.1.4), documented on
[docs.rs](https://docs.rs/solverforge-maps/2.1.4), and tagged in the
[source repository](https://github.com/SolverForge/solverforge-maps/tree/v2.1.4).

## What Changed

`TravelTimeMatrix` now stores route distances alongside travel times:

- `matrix.get(from, to)` returns travel time in seconds
- `matrix.distance_meters(from, to)` returns meters along the same fastest-time
  path
- `matrix.row(from)` returns a full row of travel times
- `matrix.row_distances(from)` returns the matching row of route distances
- `matrix.as_slice()` exposes the flat travel-time data
- `matrix.distances_as_slice()` exposes the flat distance data

The distance matrix preserves the same semantics as the travel-time matrix:
diagonal pairs are zero, unreachable pairs use `UNREACHABLE`, and out-of-bounds
access returns `None`.

## Upgrade

Use the crates.io package pin:

```toml
[dependencies]
solverforge-maps = "2.1.4"
```

## Example

```rust
let matrix = network.compute_matrix(&locations, None).await;

let time_seconds = matrix.get(0, 1);
let distance_meters = matrix.distance_meters(0, 1);
let all_times_from_depot = matrix.row(0);
let all_distances_from_depot = matrix.row_distances(0);
```

Use the new distance accessors for reporting, diagnostics, mileage displays, and
secondary route-cost views that need to stay aligned with the fastest-time
matrix used by the solver.
