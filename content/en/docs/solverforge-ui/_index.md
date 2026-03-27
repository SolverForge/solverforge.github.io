---
title: "solverforge-ui"
linkTitle: "solverforge-ui"
icon: fa-solid fa-display
weight: 21
description: >
  Embedded frontend components, scheduling views, backend adapters, and asset delivery for SolverForge web applications.
---

`solverforge-ui` is SolverForge's UI toolkit for web-based scheduling and optimization applications. It ships ready-to-use frontend components, timeline and Gantt views, backend adapters, and static assets that integrate cleanly with Rust backends.

## What It Provides

- **Drop-in frontend components** for headers, status bars, tabs, tables, modals, footers, and API guides
- **Scheduling-focused views** with both timeline rail and Gantt primitives
- **Backend adapters** for Axum, Tauri, and generic fetch-based APIs
- **Static asset delivery** under `/sf/*`, including stable and versioned bundles
- **Optional map module** (`SF.map.*`) for map-enabled pages

## Installation

```toml
[dependencies]
solverforge-ui = "0.3"
```

## Minimal Workflow

```rust
use axum::{routing::get, Router};

fn app() -> Router {
    Router::new()
        .route("/", get(index))
        .merge(solverforge_ui::routes()) // serves /sf/*
}
```

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
<script>
  const tabs = SF.createTabs(document.getElementById('tabs'));
  SF.createHeader(document.getElementById('header'), { title: 'SolverForge UI' });
</script>
```

## When To Use It

Use `solverforge-ui` when you want to deliver SolverForge-backed web interfaces quickly without building every UI primitive from scratch.

It is a strong fit for:

- operations dashboards and schedule review screens
- solver result exploration and troubleshooting tools
- embedded admin UIs in Axum- or Tauri-based applications

## Sections

- **[Getting Started](getting-started/)** — Wire up Axum routes, assets, and a minimal page
- **[Components](components/)** — Base component API for common UI building blocks
- **[Scheduling Views](scheduling-views/)** — Timeline rail and Gantt construction patterns
- **[Integration & Assets](integration-assets/)** — Backend adapters, REST expectations, and asset strategy

## External References

- [GitHub repository](https://github.com/SolverForge/solverforge-ui)
- [API documentation on docs.rs](https://docs.rs/solverforge-ui)
