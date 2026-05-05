---
title: "solverforge-ui 0.6.4: Exact Rail Timeline Geometry"
date: 2026-05-02
draft: false
description: >
  solverforge-ui 0.6.4 fixes dense rail timeline geometry so detailed schedule
  blocks preserve exact intervals while true overlaps pack onto separate tracks.
---

**solverforge-ui 0.6.4** is now available on
[crates.io](https://crates.io/crates/solverforge-ui/0.6.4) with API docs on
[docs.rs](https://docs.rs/solverforge-ui/0.6.4).

This is a focused UI patch for dense scheduling views. The retained job
lifecycle, typed event stream, backend adapter, and asset-serving contracts stay
compatible with the 0.6 line.

## What Changed

- Detailed rail timeline blocks now preserve exact interval geometry.
- Adjacent intervals, such as `[60, 120]` and `[120, 180]`, remain visually
  disjoint on the same track.
- True interval overlaps are packed onto separate detailed track rows.
- Timeline blocks opt out of the low-level rail primitive minimum-width floor;
  primitive rail blocks keep their existing visibility-oriented default.
- Dense solved schedules use one vertical body viewport, with horizontal scroll
  and drag-pan synchronized with the sticky header.
- `zoomPresets` can now be configured explicitly, and `[]` omits zoom controls
  for fixed-horizon app surfaces.
- Versioned bundles are regenerated as `/sf/sf.0.6.4.css` and
  `/sf/sf.0.6.4.js`.

## Upgrade

```toml
[dependencies]
solverforge-ui = { version = "0.6.4" }
```

Stable asset URLs stay unchanged:

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
```

For cache-pinned deployments, use the 0.6.4 bundle names:

```html
<link rel="stylesheet" href="/sf/sf.0.6.4.css" />
<script src="/sf/sf.0.6.4.js"></script>
```

`solverforge-ui 0.6.4` was the UI crate used by the `solverforge-cli 2.0.2`
scaffold target. Current `solverforge-cli 2.0.4` scaffolds
`solverforge-ui 0.6.5`.
