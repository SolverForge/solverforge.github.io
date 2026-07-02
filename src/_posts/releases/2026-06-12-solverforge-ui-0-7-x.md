---
title: "solverforge-ui 0.7.x: Framework-Neutral Embedded Assets"
date: 2026-06-12
draft: false
description: >
  solverforge-ui 0.7.0 publishes framework-neutral embedded asset access while
  retaining the Axum routes adapter and stable /sf asset URLs.
---

**solverforge-ui 0.7.0** is published on crates.io. The release keeps the
existing Axum `.merge(solverforge_ui::routes())` integration, and adds a
framework-neutral `solverforge_ui::assets` API for Rust hosts that do not use
Axum.

Direct UI integrations can install the new line:

```toml
solverforge-ui = { version = "0.7.0" }
```

The current `solverforge-cli 2.2.2` scaffold target still uses
`solverforge-ui 0.6.5`. That is a scaffold dependency choice, not a statement
that the published UI crate is still on 0.6.x.

## What Changed

### Embedded assets are framework-neutral

Use the default `axum` feature when your backend is an Axum app:

<!-- sf-rust: profile="solverforge-ui-current" -->

```rust
let app = api::router(state).merge(solverforge_ui::routes());
```

For other Rust HTTP hosts, disable default features and translate the asset
metadata into your framework's response type:

```toml
solverforge-ui = { version = "0.7.0", default-features = false }
```

<!-- sf-rust: profile="solverforge-ui-current" -->

```rust
let asset = solverforge_ui::assets::get("sf.js").expect("embedded sf.js");
let content_type = asset.content_type();
let cache_control = asset.cache_control();
let bytes = asset.bytes();
```

The asset API validates `/sf`-relative paths, distinguishes invalid paths from
missing assets, exposes stable sorted asset paths through `assets::paths()`,
and exposes the embedded asset crate version through `assets::version()`.

### Stable URLs remain

Stable asset URLs are unchanged:

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
```

For cache-pinned deployments, use the current versioned bundles:

```html
<link rel="stylesheet" href="/sf/sf.0.7.0.css" />
<script src="/sf/sf.0.7.0.js"></script>
```

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.7.0` | 2026-06-12 | Adds framework-neutral embedded asset lookup through `solverforge_ui::assets`, keeps the Axum route adapter, and preserves stable and versioned `/sf` asset URLs. |

## Where to read next

Use the [solverforge-ui manual](/docs/solverforge-ui/) for the current direct
UI integration surface. Use the [solverforge-cli manual](/docs/solverforge-cli/)
when you need to know which UI version fresh generated apps currently pin.
