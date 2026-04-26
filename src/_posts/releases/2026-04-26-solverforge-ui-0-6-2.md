---
title: "solverforge-ui 0.6.2: Marker Bounds for Map-Backed Route Views"
date: 2026-04-26
draft: false
description: >
  solverforge-ui 0.6.2 is a focused map-helper patch: marker-only Leaflet maps
  can now fit vehicle and visit markers without requiring a route polyline first.
---

**solverforge-ui 0.6.2** is now available on
[crates.io](https://crates.io/crates/solverforge-ui/0.6.2) with API docs on
[docs.rs](https://docs.rs/solverforge-ui/0.6.2).

This is a small release, but it matters for map-backed planning UIs such as
delivery routing. The optional `SF.map` module now stores vehicle and visit
markers in a Leaflet feature group, so `map.fitBounds()` works even when the map
currently has markers but no route polylines.

## What changed

Before 0.6.2, the marker collection used a plain Leaflet layer group. That was
fine for adding and clearing markers, but plain layer groups do not expose
`getBounds()`. Calling `fitBounds()` on a marker-only map could therefore fail
before a route had been drawn.

In 0.6.2:

- marker collections use a Leaflet feature group
- `fitBounds()` can fit vehicle and visit markers directly
- the map helper API remains the same for consumers
- a focused frontend regression test covers the marker-only bounds path

## Upgrade

```toml
[dependencies]
solverforge-ui = { version = "0.6.2" }
```

The stable asset URLs stay the same:

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
```

For cache-pinned deployments, use the versioned bundles:

```html
<link rel="stylesheet" href="/sf/sf.0.6.2.css" />
<script src="/sf/sf.0.6.2.js"></script>
```

## Map helper reminder

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
