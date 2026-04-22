---
title: Caching & Operations
description: Cache inspection, progress reporting, and production-oriented diagnostics.
weight: 4
---

# Caching & Operations

`solverforge-maps` is built for repeated routing over shared map regions. The operational APIs help you keep those workloads fast and observable.

## Cache Layers

`load_or_fetch` checks three places in order:

1. check the in-memory cache
2. check the file cache
3. fetch from the Overpass API when the region is not cached

Repeat runs for the same service area can become much faster after the first network build.

## Inspect Cache Stats

```rust
let stats = RoadNetwork::cache_stats().await;
println!("Networks cached: {}", stats.networks_cached);
println!("Nodes: {}, edges: {}", stats.total_nodes, stats.total_edges);
println!("In-memory hits: {}, misses: {}", stats.hits, stats.misses);
```

`cache_stats()` is most useful for understanding the current in-memory cache footprint.

The `hits` and `misses` counters are coarse process-level counters, not a precise breakdown of memory hits versus file-cache loads versus Overpass fetches.

## Progress Reporting

The crate exposes `RoutingProgress` so long-running operations can report status while a network is loading or a matrix is being built.

That is useful for:

- CLI tools that need progress output
- web backends that stream job status
- admin screens that expose long-running matrix builds

## Connectivity and Failure Analysis

When a route or matrix result is surprising, check the network before changing your solver model.

Good first questions are:

- Is the bounding box large enough for realistic detours?
- Is the graph strongly connected in the area you care about?
- Are some locations landing in disconnected subgraphs?
- Is the current process reusing cached regions for repeated work?

## Recommended Production Practices

- Use `Coord::try_new` and `BoundingBox::try_new` on external input.
- Keep a stable cache location for repeated workloads.
- Warm commonly used service areas ahead of large optimization jobs.
- Treat cache hit/miss counters as coarse indicators, not exact layer-specific metrics.
- Use connectivity diagnostics when a region produces many unreachable pairs.
