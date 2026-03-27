---
title: 'solverforge-ui'
linkTitle: 'solverforge-ui'
icon: fa-solid fa-display
weight: 21
description: >
  Embedded frontend components, scheduling views, backend adapters, and asset
  serving for SolverForge web applications.
---

`solverforge-ui` is SolverForge's frontend component library for
constraint-optimization applications. It ships embedded assets, UI primitives,
solver lifecycle helpers, and scheduling views without requiring npm in the
runtime integration path.

## What It Provides

- **Drop-in components** for headers, status bars, buttons, modals, tabs,
  tables, footers, API guides, and toasts
- **Scheduling views** with both timeline rail and split-pane Gantt primitives
- **Solver lifecycle helpers** via `SF.createBackend(...)` and
  `SF.createSolver(...)`
- **Embedded asset serving** under `/sf/*` via
  `.merge(solverforge_ui::routes())`
- **Stable and versioned bundles** for compatibility and cache-friendly
  production deployments

## Installation

```toml
[dependencies]
solverforge-ui = "0.3.1"
```

## Minimal Workflow

```rust
let app = api::router(state).merge(solverforge_ui::routes()); // serves /sf/*
```

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
<script>
  var tabs = SF.createTabs({
    tabs: [{ id: 'plan', content: '<div>Plan view</div>', active: true }],
  });
  document.body.appendChild(tabs.el);

  var header = SF.createHeader({
    title: 'SolverForge UI',
    tabs: [{ id: 'plan', label: 'Plan', active: true }],
    onTabChange: function (id) {
      tabs.show(id);
    },
  });
  document.body.prepend(header);
</script>
```

## When To Use It

Use `solverforge-ui` when you want to ship SolverForge-backed web interfaces
quickly without rebuilding common UI primitives or bundling your own asset
pipeline.

It is a strong fit for:

- operations dashboards and schedule review screens
- solver result exploration and troubleshooting tools
- embedded admin UIs in Axum-, Tauri-, or static-asset-served applications

## Sections

- **[Getting Started](getting-started/)** — Mount `/sf/*`, include the bundled
  assets, and wire the verified primitives into an app
- **[Components](components/)** — Core factories, return values, and unsafe HTML
  opt-ins
- **[Scheduling Views](scheduling-views/)** — Timeline rail and Gantt APIs with
  shipped examples
- **[Integration & Assets](integration-assets/)** — Backend adapters, asset
  serving, cache behavior, and example route contracts

## External References

- [GitHub repository](https://github.com/SolverForge/solverforge-ui)
- [API documentation on docs.rs](https://docs.rs/solverforge-ui)
