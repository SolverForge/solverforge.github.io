---
title: "solverforge-maps 2.1.x: Matrix Route Distances"
date: 2026-05-03
draft: false
description: >
  solverforge-maps 2.1.x stores same-path route distances next to travel-time
  matrix data for routing and delivery applications.
---

<%= render Ui::Callout.new(title: "Historical release note", variant: "warning") do %>
This post records an older maps line. The current release is
`solverforge-maps 2.3.3`; see the
[2.2 and 2.3 maps release note](/blog/releases/2026/11/06/solverforge-maps-2-2-2-3-x/).
<% end %>

**solverforge-maps 2.1.x** was the maps line for routing and delivery
applications from May to November 2026. Its last patch, **2.1.5**, is available on
[crates.io](https://crates.io/crates/solverforge-maps/2.1.5), documented on
[docs.rs](https://docs.rs/solverforge-maps/2.1.5), and tagged in the
[source repository](https://github.com/SolverForge/solverforge-maps/tree/v2.1.5).
Its [Publish](https://github.com/SolverForge/solverforge-maps/actions/runs/41714196655),
[Release](https://github.com/SolverForge/solverforge-maps/actions/runs/41714196766),
and [CI](https://github.com/SolverForge/solverforge-maps/actions/runs/41714194281)
workflows passed at `dc1b86a`.

Patch releases are folded into this line note instead of published as separate
release-note pages.

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

The last 2.1 package pin was:

```toml
[dependencies]
solverforge-maps = "2.1.5"
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

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `2.1.5` | 2026-11-03 | Overpass requests send `User-Agent: solverforge-maps/<version> (+<repository>)` instead of the fixed `SolverForge/0.5.0`; the Overpass usage policy requires a User-Agent that identifies the client. |
| `2.1.4` | 2026-05-03 | Stores route distances beside travel-time matrix data and exposes aligned distance rows and slices. |
