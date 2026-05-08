---
title: "solverforge-ui 0.6.x: Retained Job UI, Maps, and Scheduling Views"
date: 2026-04-26
draft: false
description: >
  solverforge-ui 0.6.x carries the retained job frontend contract, map helper
  fixes, exact rail timeline geometry, current dependency baseline, and
  create-job identifier normalization.
---

**solverforge-ui 0.6.x** is the current UI line for SolverForge generated apps.
The latest patch is [0.6.5](https://crates.io/crates/solverforge-ui/0.6.5).

Patch releases are folded into this line note instead of published as separate
release-note pages.

The optional `SF.map` module stores vehicle and visit
markers in a Leaflet feature group, so `map.fitBounds()` works even when the map
currently has markers but no route polylines.

## Map Helper

Before 0.6.2, the marker collection used a plain Leaflet layer group. That was
fine for adding and clearing markers, but plain layer groups do not expose
`getBounds()`. Calling `fitBounds()` on a marker-only map could therefore fail
before a route had been drawn.

In 0.6.2:

- marker collections use a Leaflet feature group
- `fitBounds()` can fit vehicle and visit markers directly
- the map helper API remains the same for consumers
- a focused frontend regression test covers the marker-only bounds path

### Map helper reminder

The optional map module still needs Leaflet plus the shipped map assets:

```html
<link rel="stylesheet" href="/sf/vendor/leaflet/leaflet.css" />
<script src="/sf/vendor/leaflet/leaflet.js"></script>
<link rel="stylesheet" href="/sf/modules/sf-map.css" />
<script src="/sf/modules/sf-map.js"></script>
```

Then:

```js
var map = SF.map.create({ container: "map", center: [45.07, 7.69], zoom: 13 });
map.addVehicleMarker({ lat: 45.07, lng: 7.69, color: "#10b981" });
map.addVisitMarker({ lat: 45.08, lng: 7.7, color: "#3b82f6" });
map.fitBounds();
```

That marker-only `fitBounds()` call is the path fixed in this release.

## Runtime And Dependency Baseline

The 0.6.x line keeps the retained job, lifecycle, scheduling, and optional
map-helper browser API shape while moving the package metadata and generated
assets onto the current dependency baseline:

- `solverforge-ui 0.6.5` is the current crate patch.
- The crate declares `rust-version = "1.95"`.
- Direct Rust dependencies are pinned to the current published baseline:
  `axum 0.8.9` and `include_dir 0.7.4`.
- Maintainer test dependencies include `tokio 1.52.1` and `tower 0.5.3`.
- Frontend maintainer dependencies include `eslint 10.2.1` and
  `playwright 1.59.1`.

## Scheduling Views

Dense rail timeline geometry was tightened in the 0.6.x line:

- Detailed rail timeline blocks preserve exact interval geometry.
- Adjacent intervals, such as `[60, 120]` and `[120, 180]`, remain visually
  disjoint on the same track.
- True interval overlaps are packed onto separate detailed track rows.
- Timeline blocks opt out of the low-level rail primitive minimum-width floor;
  primitive rail blocks keep their existing visibility-oriented default.
- Dense solved schedules use one vertical body viewport, with horizontal scroll
  and drag-pan synchronized with the sticky header.
- `zoomPresets` can be configured explicitly, and `[]` omits zoom controls for
  fixed-horizon app surfaces.

## Create-Job Identifier Normalization

The retained-job API shape stays on the 0.6 line. Create-job responses are
normalized before the solver attaches to the event stream:

- `createJob()` may resolve to a non-empty string id.
- `createJob()` may resolve to a finite numeric id, including `0`.
- `createJob()` may resolve to an object containing a scalar `id`, `jobId`, or
  `job_id` field.
- Empty strings, non-finite numbers, missing object fields, arrays, and nested
  object identifiers reject startup instead of being stringified.

## Current Upgrade

```toml
[dependencies]
solverforge-ui = { version = "0.6.5" }
```

Use the source tag directly when you need exact source-tag reproducibility:

```toml
[dependencies]
solverforge-ui = { git = "https://github.com/SolverForge/solverforge-ui", tag = "v0.6.5" }
```

Stable asset URLs stay unchanged:

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
```

For cache-pinned deployments, use the current versioned bundles:

```html
<link rel="stylesheet" href="/sf/sf.0.6.5.css" />
<script src="/sf/sf.0.6.5.js"></script>
```

`solverforge-cli 2.0.4` scaffolds `solverforge-ui 0.6.5`, so new generated apps
start on the latest 0.6.x UI patch.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.6.5` | 2026-05-03 | Normalizes create-job identifiers before stream attachment and regenerates versioned frontend bundles. |
| `0.6.4` | 2026-05-02 | Tightens exact rail timeline geometry and dense schedule scrolling behavior. |
| `0.6.3` | 2026-04-26 | Refreshes dependency metadata, raises Rust floor to 1.95, and publishes matching versioned bundles. |
| `0.6.2` | 2026-04-26 | Allows marker-only Leaflet maps to fit vehicle and visit markers without requiring a route polyline first. |
