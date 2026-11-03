---
title: Getting Started
description: >
  Create an Axum app that serves the bundled solverforge-ui assets and wires
  the shipped components and retained-job solver helpers into a page.
weight: 1
---

# Getting Started with solverforge-ui

This guide builds a small Axum app that serves the `solverforge-ui` assets and
renders a page with a header, tabs, a status bar, and the retained-job solver
controller:

1. create a crate with the published dependencies
2. serve an HTML page and mount `/sf/*` with `.merge(solverforge_ui::routes())`
3. include the bundled CSS and JS in that page
4. instantiate components plus the retained-job backend and solver helpers

`solverforge-ui 0.9.0` declares `rust-version = "1.95"`, so use Rust 1.95 or
newer.

## Create the Project

```bash
cargo new sf-ui-quickstart
cd sf-ui-quickstart
cargo add solverforge-ui@0.9.0 axum@0.8
cargo add tokio@1 --features macros,rt-multi-thread,net
mkdir static
```

`solverforge-ui` depends on `axum 0.8`, so the app and the crate share one Axum
version and `solverforge_ui::routes()` merges into the app's `Router`.

## Serve the Page and Mount `/sf/*`

Replace `src/main.rs`:

```rust
use axum::{response::Html, routing::get, Router};

async fn index() -> Html<&'static str> {
    Html(include_str!("../static/index.html"))
}

fn app() -> Router {
    Router::new()
        .route("/", get(index))
        .merge(solverforge_ui::routes())
}

#[tokio::main]
async fn main() {
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let listener = tokio::net::TcpListener::bind(format!("127.0.0.1:{port}"))
        .await
        .expect("bind the HTTP port");
    println!("serving http://127.0.0.1:{port}/");
    axum::serve(listener, app()).await.expect("serve the app");
}
```

The `Html` wrapper sends the page as `text/html`; a bare `&'static str` handler
would send `text/plain`, and the browser would show the HTML source instead of
running it.

`solverforge_ui::routes()` serves the embedded `/sf/*` assets. Your application
still owns its HTML pages and any job/solver API routes.

## Include Required Assets in HTML

Save this as `static/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>solverforge-ui quickstart</title>
    <link rel="icon" href="/sf/img/ouroboros.svg" />

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
          { id: "plan", content: { unsafeHtml: "<div>Plan view</div>" }, active: true },
          { id: "gantt", content: { unsafeHtml: "<div>Gantt view</div>" } },
        ],
      });
      document.body.appendChild(tabs.el);

      var backend = SF.createBackend({ type: "axum" });
      var solver;

      var header = SF.createHeader({
        title: "SolverForge Scheduler",
        subtitle: "by SolverForge",
        tabs: [
          { id: "plan", label: "Plan", active: true },
          { id: "gantt", label: "Gantt" },
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
          console.log("progress", meta.currentScore, meta.bestScore);
        },
        onSolution: function (snapshot, meta) {
          renderAndSync(snapshot, meta);
        },
        onPaused: function (snapshot, meta) {
          renderAndSync(snapshot, meta);
        },
        onComplete: function (snapshot, meta) {
          renderAndSync(snapshot, meta);
        },
        onCancelled: function (snapshot, meta) {
          renderAndSync(snapshot, meta);
        },
        onFailure: function (message, meta, snapshot, analysis) {
          console.error(message, analysis);
          renderAndSync(snapshot, meta);
        },
      });

      function renderAndSync(snapshot, meta) {
        try {
          if (snapshot && snapshot.solution) {
            render(snapshot.solution);
          }
        } finally {
          syncMarkers(meta);
        }
      }

      function render(solution) {
        // Replace this with the app's domain-specific renderer.
        console.log("solution", solution);
      }

      function syncMarkers(meta) {
        document.body.dataset.jobId = (meta && meta.jobId) || "";
        document.body.dataset.snapshotRevision =
          meta && meta.snapshotRevision != null ? String(meta.snapshotRevision) : "";
        document.body.dataset.lifecycleState = (meta && meta.lifecycleState) || "IDLE";
      }
    </script>
  </body>
</html>
```

`SF.createSolver(...)` follows the retained-job lifecycle. Use
`onProgress(...)` for score and telemetry updates, `onSolution(...)` for
snapshot-bearing `best_solution` events, and `onPaused(...)`, `onCancelled(...)`,
or `onComplete(...)` when you need the exact retained snapshot after the runtime
reaches an authoritative lifecycle state. Snapshot-bearing callbacks are
null-safe: cancellation, failure, or a failed snapshot synchronization can leave
no solution snapshot, so render only when `snapshot && snapshot.solution` exists
and synchronize lifecycle markers in a `finally` block.

The header renders the cancel action as **Stop**. Keep using the `onCancel`
configuration key and call `solver.cancel()`; `delete()` is reserved for
terminal retained-job cleanup.

## Run the App

```bash
cargo run
```

Open `http://127.0.0.1:3000/`. The page shows the header with its **Plan** and
**Gantt** tabs, the status bar, and the active tab panel, and
`SF.version` in the browser console reports `"0.9.0"`. Set `PORT` to serve on
another port.

The **Solve** button calls `POST /jobs` through the Axum backend adapter. This
app does not define that route yet, so a solve fails until the app adds its job
API.

## Application Routes

`solverforge-ui` does not generate your scheduling API. The crate ships the UI
surface and a set of backend helpers. If you use
`SF.createBackend({ type: 'axum' })`, implement the retained-job routes listed
in [Integration & Assets](/docs/solverforge-ui/integration-assets/#retained-job-http-routes).
Apps scaffolded by `solverforge-cli` already expose them.

## Next Steps

- Read [Components](/docs/solverforge-ui/components/) to build richer page layouts.
- Read [Scheduling Views](/docs/solverforge-ui/scheduling-views/) for timeline rail and Gantt
  examples.
- Read [Integration & Assets](/docs/solverforge-ui/integration-assets/) for backend adapters,
  optional map modules, asset serving, and versioned bundle behavior.
