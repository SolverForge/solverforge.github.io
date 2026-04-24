---
title: 'solverforge-ui'
linkTitle: 'solverforge-ui'
icon: fa-solid fa-display
weight: 21
description: >
  Embedded frontend components, scheduling views, backend adapters, and asset
  serving for SolverForge web applications.
---

<h1>solverforge-ui</h1>

<%= render Ui::Callout.new do %>
This section tracks the current `solverforge-ui` API: retained jobs, typed
lifecycle events, exact paused snapshots, and pause/resume/cancel controls.
<% end %>

`solverforge-ui` is SolverForge's frontend component library for
constraint-optimization applications. It ships embedded assets, UI primitives,
retained-job lifecycle helpers, and scheduling views without requiring npm in
the runtime integration path.

## What It Provides

- **Drop-in components** for headers, status bars, buttons, modals, tabs,
  tables, footers, API guides, and toasts
- **Scheduling views** with the canonical dense timeline surface plus low-level
  rail primitives and split-pane Gantt
- **Retained job lifecycle helpers** via `SF.createBackend(...)` and
  `SF.createSolver(...)` with pause, resume, cancel, and snapshot sync
- **Embedded asset serving** under `/sf/*` via
  `.merge(solverforge_ui::routes())`
- **Stable and versioned bundles** for compatibility and cache-friendly
  production deployments

## Installation

```toml
[dependencies]
solverforge-ui = { version = "0.6.1" }

# Pin a specific GitHub release tag when you need exact reproducibility.
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

  var backend = SF.createBackend({ type: 'axum' });
  var solver;

  var header = SF.createHeader({
    title: 'SolverForge UI',
    subtitle: 'Retained job lifecycle',
    tabs: [{ id: 'plan', label: 'Plan', active: true }],
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
      console.log('progress', meta.currentScore);
    },
    onSolution: function (snapshot) {
      console.log('solution', snapshot.solution);
    },
    onPaused: function (snapshot) {
      console.log('paused', snapshot.solution);
    },
    onComplete: function (snapshot) {
      console.log('complete', snapshot.solution);
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

- **[Getting Started](getting-started/)** — Mount `/sf/*`, include the bundled
  assets, and wire the verified primitives into an app
- **[Components](components/)** — Core factories, return values, and unsafe HTML
  opt-ins
- **[Scheduling Views](scheduling-views/)** — Canonical timeline, low-level rail
  primitives, and Gantt APIs with shipped examples
- **[Integration & Assets](integration-assets/)** — Backend adapters, asset
  serving, cache behavior, and example route contracts

## External References

- [GitHub repository](https://github.com/SolverForge/solverforge-ui)
- [API documentation on docs.rs](https://docs.rs/solverforge-ui)
