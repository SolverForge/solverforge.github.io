---
title: Getting Started
description: >
  Mount the bundled assets and wire verified solverforge-ui primitives into an
  Axum app.
weight: 1
---

# Getting Started with solverforge-ui

<%= render Ui::Callout.new do %>
This guide follows the current `solverforge-ui` surface: retained jobs, typed
lifecycle events, and exact paused or terminal snapshot sync.
<% end %>

This guide covers the verified integration path:

1. add the crate
2. mount `/sf/*` assets with `.merge(solverforge_ui::routes())`
3. include the bundled CSS and JS
4. instantiate components plus the retained-job backend and solver helpers

## Add the Dependency

```toml
[dependencies]
axum = "0.8"
solverforge-ui = "0.5"

# Pin a specific GitHub release tag when you need exact reproducibility.
```

## Mount `/sf/*` Routes in Axum

```rust
use axum::{routing::get, Router};

async fn index() -> &'static str {
    include_str!("../static/index.html")
}

fn app() -> Router {
    Router::new()
        .route("/", get(index))
        .merge(solverforge_ui::routes())
}
```

`solverforge_ui::routes()` serves the embedded `/sf/*` assets. Your application
still owns its HTML pages and any schedule/solver API routes.

## Include Required Assets in HTML

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>solverforge-ui quickstart</title>

    <link
      rel="stylesheet"
      href="/sf/vendor/fontawesome/css/fontawesome.min.css"
    />
    <link rel="stylesheet" href="/sf/vendor/fontawesome/css/solid.min.css" />
    <link rel="stylesheet" href="/sf/sf.css" />
  </head>
  <body class="sf-app">
    <script src="/sf/sf.js"></script>
    <script>
      var tabs = SF.createTabs({
        tabs: [
          { id: 'plan', content: '<div>Plan view</div>', active: true },
          { id: 'gantt', content: '<div>Gantt view</div>' },
        ],
      });
      document.body.appendChild(tabs.el);

      var backend = SF.createBackend({ type: 'axum' });
      var solver;

      var header = SF.createHeader({
        title: 'SolverForge Scheduler',
        subtitle: 'by SolverForge',
        tabs: [
          { id: 'plan', label: 'Plan', active: true },
          { id: 'gantt', label: 'Gantt' },
        ],
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
          console.log('progress', meta.currentScore, meta.bestScore);
        },
        onSolution: function (snapshot) {
          console.log('best solution', snapshot.solution);
        },
        onPaused: function (snapshot, meta) {
          console.log('paused', meta.snapshotRevision, snapshot.solution);
        },
        onComplete: function (snapshot, meta) {
          console.log('completed', meta.currentScore, snapshot.solution);
        },
      });
    </script>
  </body>
</html>
```

`SF.createSolver(...)` now follows the retained-job lifecycle. Use
`onProgress(...)` for score and telemetry updates, `onSolution(...)` for
snapshot-bearing `best_solution` events, and `onPaused(...)` or
`onComplete(...)` when you need the exact retained snapshot after the runtime
reaches an authoritative lifecycle state.

## Application Routes

`solverforge-ui` does not generate your scheduling API. The crate ships the UI
surface and a set of backend helpers. If you use
`SF.createBackend({ type: 'axum' })`, follow the canonical retained-job contract
documented in [Integration & Assets](../integration-assets/). Older
`/schedules/...` route shapes should be treated as application-side
compatibility shims while your backend converges on `/jobs/...`.

## Next Steps

- Read [Components](../components/) to build richer page layouts.
- Read [Scheduling Views](../scheduling-views/) for timeline rail and Gantt
  examples.
- Read [Integration & Assets](../integration-assets/) for backend adapters,
  asset serving, and versioned bundle behavior.
