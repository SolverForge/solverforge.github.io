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

At publication, `solverforge-cli 2.2.2` still targeted `solverforge-ui 0.6.5`.
That was a scaffold dependency choice, not a statement that the published UI
crate was still on 0.6.x.

> **Update, 2026-08-11:** The current `solverforge-cli 2.2.3` scaffold target
> now uses `solverforge-ui 0.7.0`.

<%= render Ui::Callout.new(title: "Update, September 15, 2026") do %>
`solverforge-ui 0.8.0` is now published for direct UI integrations. The
published `solverforge-cli 2.2.3` package still scaffolds `solverforge-ui
0.7.0`, so generated apps stay on this line until they are deliberately
upgraded. See [solverforge-ui 0.8.x](/blog/releases/2026/09/15/solverforge-ui-0-8-x/).
<% end %>

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
