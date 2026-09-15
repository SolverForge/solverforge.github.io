---
title: "solverforge-ui"
linkTitle: "solverforge-ui"
icon: fa-solid fa-display
weight: 21
description: >
  Embedded frontend components, scheduling views, backend adapters, and asset
  serving for SolverForge web applications.
---

<h1>solverforge-ui</h1>

<%= render Ui::Callout.new do %>
This section tracks the published `solverforge-ui 0.8.0` crate: retained jobs,
typed lifecycle events, exact paused snapshots, pause/resume/cancel controls,
null-safe snapshot callbacks, exact dense scheduling geometry, normalized
create-job identifiers, optional map helpers, framework-neutral embedded asset
access, and the bundled agent skill. The published `solverforge-cli 2.2.3`
scaffold still pins `solverforge-ui 0.7.0`, so generated apps move to `0.8.0`
only when that app is deliberately upgraded.
<% end %>

`solverforge-ui` is SolverForge's frontend component library for
constraint-optimization applications. It ships embedded assets, UI primitives,
retained-job lifecycle helpers, and scheduling views without requiring npm in
the runtime integration path.

## What It Provides

- **Drop-in components** for headers, status bars, buttons, modals, tabs,
  tables, footers, API guides, and toasts
- **Scheduling views** with the canonical dense timeline surface, exact detailed
  interval geometry, low-level rail primitives, and split-pane Gantt
- **Optional map helpers** for Leaflet-backed vehicle markers, visit markers,
  route geometry, marker bounds, and route highlighting
- **Retained job lifecycle helpers** via `SF.createBackend(...)` and
  `SF.createSolver(...)` with pause, resume, cancel, and snapshot sync
- **Embedded asset serving** under `/sf/*` via
  `.merge(solverforge_ui::routes())`
- **Stable and versioned bundles** for compatibility and cache-friendly
  production deployments
- **Bundled agent skill** that maps a planning model onto the shipped timeline,
  Gantt, map, rail, and table surfaces

## Installation

```toml
[dependencies]
solverforge-ui = { version = "0.8.0" }

# Pin a specific GitHub release tag when you need exact reproducibility.
# solverforge-ui = { git = "https://github.com/SolverForge/solverforge-ui", tag = "v0.8.0" }
```

Use the Git tag form when you need exact source-tag reproducibility instead of
the crates.io package.

`solverforge-ui 0.8.0` declares `rust-version = "1.95"`.

Production cache pinning uses the versioned bundles for the installed crate
version, `/sf/sf.0.8.0.css` and `/sf/sf.0.8.0.js`. `SF.version` in either
bundle and `solverforge_ui::assets::version()` both report the crate version
that produced the embedded asset set.

## Minimal Workflow

```rust
let app = api::router(state).merge(solverforge_ui::routes()); // serves /sf/*
```

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
<script>
  var tabs = SF.createTabs({
    tabs: [{ id: "plan", content: { unsafeHtml: "<div>Plan view</div>" }, active: true }],
  });
  document.body.appendChild(tabs.el);

  var backend = SF.createBackend({ type: "axum" });
  var solver;

  var header = SF.createHeader({
    title: "SolverForge UI",
    subtitle: "Retained job lifecycle",
    tabs: [{ id: "plan", label: "Plan", active: true }],
    onTabChange: function (id) {
      tabs.show(id);
    },
    actions: {
      onSolve: function () {
        solver.start();
      },
      onPause: function () {
        solver.pause();
      },
      onResume: function () {
        solver.resume();
      },
      onCancel: function () {
        solver.cancel();
      },
    },
  });
  document.body.prepend(header);

  var statusBar = SF.createStatusBar({ header: header, constraints: [] });
  header.after(statusBar.el);

  solver = SF.createSolver({
    backend: backend,
    statusBar: statusBar,
    onProgress: function (meta) {
      console.log("progress", meta.currentScore);
    },
    onSolution: function (snapshot, meta) {
      if (snapshot && snapshot.solution) {
        console.log("solution", snapshot.solution, meta.snapshotRevision);
      }
    },
    onPaused: function (snapshot, meta) {
      if (snapshot && snapshot.solution) {
        console.log("paused", snapshot.solution, meta.snapshotRevision);
      }
    },
    onComplete: function (snapshot, meta) {
      if (snapshot && snapshot.solution) {
        console.log("complete", snapshot.solution, meta.currentScore);
      }
    },
    onCancelled: function (snapshot, meta) {
      console.log("cancelled", meta.lifecycleState, snapshot && snapshot.solution);
    },
    onFailure: function (message, meta, snapshot, analysis) {
      console.error(message, analysis);
    },
  });
</script>
```

The header labels the cancel action as **Stop** in the UI. The JavaScript
configuration key remains `onCancel`, and it should call `solver.cancel()`.

## When To Use It

Use `solverforge-ui` when you want to ship SolverForge-backed web interfaces
quickly without rebuilding common UI primitives or bundling your own asset
pipeline.

It is a strong fit for:

- operations dashboards and schedule review screens
- solver result exploration and troubleshooting tools
- embedded admin UIs in Axum-, Tauri-, or static-asset-served applications

## Sections

- **[Getting Started](/docs/solverforge-ui/getting-started/)** — Mount `/sf/*`, include the bundled
  assets, and wire the verified primitives into an app
- **[Components](/docs/solverforge-ui/components/)** — Core factories, return values, and unsafe HTML
  opt-ins
- **[Scheduling Views](/docs/solverforge-ui/scheduling-views/)** — Canonical timeline, low-level rail
  primitives, and Gantt APIs with exact-geometry examples
- **[Integration & Assets](/docs/solverforge-ui/integration-assets/)** — Backend adapters, asset
  serving, cache behavior, and example route contracts

## External References

- [GitHub repository](https://github.com/SolverForge/solverforge-ui)
- [API documentation on docs.rs](https://docs.rs/solverforge-ui)
