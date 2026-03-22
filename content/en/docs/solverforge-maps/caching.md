---
title: Caching & Operations
description: Cache inspection, progress reporting, and production-oriented diagnostics.
weight: 4
---

# Caching & Operations

`solverforge-maps` is built for repeated routing over shared map regions. The operational APIs help you keep those workloads fast and observable.

## Cache Layers

A typical `load_or_fetch` call works through three stages:

1. check the in-memory cache
2. check the file cache
3. fetch from the Overpass API when the region is not cached

That means repeat runs for the same service area can become much faster after the first network build.

## Inspect Cache Stats

```rust
let stats = RoadNetwork::cache_stats().await;
println!("Hits: {}, misses: {}", stats.hits, stats.misses);
```

These numbers are useful for:

- understanding warm-cache versus cold-cache behavior
- verifying that repeated jobs are reusing network data
- spotting workloads that are dominated by remote fetches

## Progress Reporting

The crate exposes `RoutingProgress` so long-running operations can report status while a network is loading or a matrix is being built.

That is useful for:

- CLI tools that need progress output
- web backends that stream job status
- admin screens that expose long-running matrix builds

## Connectivity and Failure Analysis

When a route or matrix result is surprising, check the network before changing your solver model.

Good first questions are:

- Did the request hit cache or fetch new data?
- Was the bounding box large enough for realistic detours?
- Is the graph strongly connected in the area you care about?
- Are some locations landing in disconnected subgraphs?

## Recommended Production Practices

- Use `Coord::try_new` and `BoundingBox::try_new` on external input.
- Keep a stable cache location for repeated workloads.
- Warm commonly used service areas ahead of large optimization jobs.
- Track cache hits and misses so you know whether performance issues are network-bound or compute-bound.
- Use connectivity diagnostics when a region produces many unreachable pairs.
