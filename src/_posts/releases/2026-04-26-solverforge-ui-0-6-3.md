---
title: "solverforge-ui 0.6.3: Dependency Refresh and Rust 1.95"
date: 2026-04-26
draft: false
description: >
  solverforge-ui 0.6.3 refreshes the crate and frontend dependency surface,
  raises the Rust floor to 1.95, and publishes the matching versioned bundles.
---

**solverforge-ui 0.6.3** is now available on
[crates.io](https://crates.io/crates/solverforge-ui/0.6.3) with API docs on
[docs.rs](https://docs.rs/solverforge-ui/0.6.3).

This is a release-surface refresh. The shipped browser API remains the retained
job, lifecycle, scheduling, and optional map-helper surface documented for the
0.6 line; the update moves the package metadata and generated assets onto the
current dependency baseline.

## What changed

- The crate version is `0.6.3`.
- The crate now declares `rust-version = "1.95"`.
- Direct Rust dependencies are pinned to the current published baseline:
  `axum 0.8.9` and `include_dir 0.7.4`.
- Maintainer test dependencies are refreshed to `tokio 1.52.1` and
  `tower 0.5.3`.
- Frontend maintainer dependencies are refreshed, including `eslint 10.2.1` and
  `playwright 1.59.1`.
- Versioned bundles are regenerated as `/sf/sf.0.6.3.css` and
  `/sf/sf.0.6.3.js`.

## Upgrade

```toml
[dependencies]
solverforge-ui = { version = "0.6.3" }
```

The stable asset URLs stay the same:

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
```

For cache-pinned deployments, use the versioned bundles:

```html
<link rel="stylesheet" href="/sf/sf.0.6.3.css" />
<script src="/sf/sf.0.6.3.js"></script>
```

`solverforge-cli 2.0.1` scaffolds `solverforge-ui 0.6.3`, so newly generated
apps already start on this UI patch line.
