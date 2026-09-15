---
title: Integration & Assets
description: >
  Backend adapters, asset serving, cache behavior, and example route contracts
  for solverforge-ui.
weight: 4
---

# Integration & Assets

<%= render Ui::Callout.new do %>
The current `solverforge-ui 0.8.0` contract is job-oriented, lifecycle-typed, and
framework-neutral at the asset boundary. New integrations should expose retained
jobs, explicit `eventType` payloads, exact paused or terminal snapshots,
null-safe snapshot callbacks, normalized create-job identifiers, and the shipped
optional map module when they need Leaflet route views.
<% end %>

This page summarizes how `solverforge-ui` connects frontend code to backend APIs
and how static assets are delivered.

## Backend Adapters

Create adapters with `SF.createBackend(...)` and pass the result into
`SF.createSolver(...)`.

### Axum (default)

```js
var backend = SF.createBackend({ type: "axum", baseUrl: "" });
```

Use this when your backend exposes the stock `solverforge-ui` lifecycle
contract. New integrations should model retained jobs and snapshots rather than
build around schedule-specific naming.

### Tauri Adapter

```js
var backend = SF.createBackend({
  type: "tauri",
  invoke: window.__TAURI__.core.invoke,
  listen: window.__TAURI__.event.listen,
  eventName: "solver-update",
});
```

Use this when solver traffic is bridged through Tauri IPC. The adapter uses
`invoke` and `listen` instead of HTTP. Optional `commands` entries override the
default command names (`create_job`, `get_job`, `get_snapshot`,
`analyze_snapshot`, `pause_job`, `resume_job`, `cancel_job`, `delete_job`, and
`demo_seed`). `listDemoData()` returns an empty list for this adapter because
Tauri exposes demo loading through `getDemoData(name)`.

### Generic Fetch Adapter

```js
var backend = SF.createBackend({
  type: "fetch",
  baseUrl: "/api/v1",
  jobsPath: "/jobs",
  demoDataPath: "/demo-data",
  headers: { "X-CSRF-Token": csrfToken },
});
```

The HTTP adapter accepts `type: "axum"` or `type: "fetch"` and supports
`baseUrl`, `jobsPath` (default `/jobs`), `demoDataPath` (default `/demo-data`),
and extra request `headers`. It sends JSON request bodies and parses JSON
responses when their content type is JSON; other successful responses are
returned as text. Use this when your app needs extra headers or a non-default
base path while still implementing the retained-job backend methods expected by
`SF.createSolver(...)`.

## Lifecycle Contract Expectations

The shared lifecycle model is job-oriented:

- create job
- get job
- get job status
- stream job events
- get snapshot
- analyze snapshot
- pause job
- resume job
- cancel job
- delete job
- get demo data

Older articles may mention schedule-named routes. Current generated apps expose
`/jobs/...`; new integrations should use the job vocabulary directly.

The create operation may resolve to either:

- a non-empty plain job id string
- a finite numeric job id, including `0`
- an object containing a scalar `id`, `jobId`, or `job_id`

`SF.createSolver(...)` normalizes accepted create-job identifiers to strings
before stream attachment. Empty strings, non-finite numbers, missing object
fields, arrays, and nested object identifiers reject startup instead of being
silently stringified.

Current backend expectations are:

- `getSnapshot()` and `analyzeSnapshot()` accept an optional `snapshotRevision`
- `pauseJob()` requests a pause, but `solver.pause()` resolves only after the
  authoritative `paused` event and snapshot sync complete
- `resumeJob()` settles on the authoritative `resumed` event
- `cancelJob()` is the backend operation behind user-facing **Stop** and
  settles after the terminal lifecycle event has been synchronized
- `deleteJob()` is required for every backend passed to `SF.createSolver(...)`
  and is destructive cleanup for terminal retained jobs only
- streamed events should use canonical camelCase fields: `eventType`, `jobId`,
  `eventSequence`, `lifecycleState`, `snapshotRevision`, `currentScore`,
  `bestScore`, `telemetry`, and `solution` where required
- supported `eventType` values are `progress`, `best_solution`,
  `pause_requested`, `paused`, `resumed`, `completed`, `cancelled`, and `failed`
- raw score-only progress payloads and implicit completion heuristics are not
  part of the supported stream contract

## Solver Lifecycle

`SF.createSolver(...)` builds the client-side retained-job state machine on top
of the backend adapter.

```js
var solver = SF.createSolver({
  backend: backend,
  statusBar: statusBar,
  onProgress: function (meta) {
    renderTelemetry(meta);
  },
  onSolution: function (snapshot, meta) {
    render(snapshot.solution, meta);
  },
  onPaused: function (snapshot, meta) {
    render(snapshot.solution, meta);
  },
  onComplete: function (snapshot, meta) {
    render(snapshot.solution, meta);
  },
});
```

Treat the shipped solver helper as a lifecycle controller for one retained job:
it starts work, observes authoritative lifecycle events, renders snapshots, and
coordinates pause, resume, cancel, analysis, and terminal cleanup through the
backend adapter.

`start()` never replaces an existing retained job. Even after completion,
cancel, or failure, call `delete()` and wait for successful backend cleanup
before starting the next solve.

The current solver surface returns:

- `start(data)`
- `pause()`
- `resume()`
- `cancel()`
- `delete()`
- `getSnapshot(snapshotRevision?)`
- `analyzeSnapshot(snapshotRevision?)`
- `isRunning()`
- `getJobId()`
- `getLifecycleState()`
- `getSnapshotRevision()`

Supported callbacks are `onProgress`, `onSolution`, `onPauseRequested`,
`onPaused`, `onResumed`, `onCancelled`, `onComplete`, `onFailure`, `onAnalysis`,
and `onError`.

| Callback | Arguments | Delivery |
|---|---|---|
| `onProgress` | `(meta)` | Scored metadata-only progress updates |
| `onSolution` | `(snapshot, meta)` | Live `best_solution` updates with a solution snapshot |
| `onPauseRequested` | `(meta)` | Runtime acknowledgement that pause was requested |
| `onPaused` | `(snapshot, meta)` | Authoritative paused state after snapshot synchronization |
| `onResumed` | `(meta)` | Authoritative resumed state |
| `onCancelled` | `(snapshot, meta)` | Authoritative cancellation; `snapshot` may be `null` |
| `onComplete` | `(snapshot, meta)` | Authoritative completion after a usable snapshot is synchronized |
| `onFailure` | `(message, meta, snapshot, analysis)` | Failed solve or synchronization; snapshot and analysis may be `null` |
| `onAnalysis` | `(analysis, meta)` | Analysis obtained during paused or terminal synchronization |
| `onError` | `(message)` | Transport or synchronization failure without inventing a lifecycle transition |

A snapshot-bearing callback must render only when `snapshot && snapshot.solution`
exists, and should synchronize application lifecycle markers in a `finally`
block so cancellation, failure, or a failed snapshot sync still updates the UI.

### Startup Stream Contract

Startup streams may begin with either a scored `progress` event or a scored
`best_solution` event. Consumers must not require `progress` to arrive first.

Runtime rules:

- `progress` is metadata-only and must not carry the solution payload
- `best_solution` must include both `solution` and `snapshotRevision`
- `pause_requested` means the runtime accepted the request, not that the exact
  checkpoint is already available
- `paused`, `completed`, `cancelled`, and `failed` are authoritative lifecycle
  events; `SF.createSolver()` synchronizes the retained snapshot before firing
  the corresponding callbacks
- the status bar uses `currentScore` as the live score during solving
- missing or malformed typed lifecycle fields are ignored instead of being
  silently normalized
- HTTP `EventSource.onerror` is transport state, not runtime lifecycle state;
  transient reconnecting errors do not change the lifecycle
- a closed SSE stream surfaces through `onError` while preserving the last
  authoritative lifecycle, retained job id, score metadata, and snapshot
  revision
- `delete()` waits for required terminal snapshot synchronization before
  calling `deleteJob()`; if synchronization or backend deletion fails, the
  retained job id and terminal lifecycle state remain intact
- **Stop** remains visible during `CANCELLING` so the UI can reattach a
  detached stream listen-only, but it must not send a duplicate `cancelJob()`

## Asset Serving Under `/sf/*`

`solverforge_ui::routes()` serves `GET /sf/{*path}` from the crate's embedded
asset directory.

Common assets include:

- `/sf/sf.css`
- `/sf/sf.js`
- `/sf/sf.0.8.0.css`
- `/sf/sf.0.8.0.js`
- `/sf/vendor/fontawesome/css/fontawesome.min.css`
- `/sf/vendor/fontawesome/css/solid.min.css`

## Cache Behavior and Versioned Bundles

The crate emits both stable and versioned bundle filenames:

- stable: `/sf/sf.css`, `/sf/sf.js`
- versioned: `/sf/sf.<crate-version>.css`, `/sf/sf.<crate-version>.js`

`src/lib.rs` serves them with different cache policies:

- stable bundles use `Cache-Control: public, max-age=3600`
- versioned bundles use `Cache-Control: public, max-age=31536000, immutable`
- `fonts/`, `vendor/`, and `img/` assets are also served as immutable

A practical strategy is to use stable URLs during development and versioned
bundles in production or CDN environments.

For non-Axum Rust hosts, disable the default feature and serve the same
embedded assets through the framework-neutral API:

```toml
solverforge-ui = { version = "0.8.0", default-features = false }
```

```rust
let asset = solverforge_ui::assets::get("sf.js").expect("embedded sf.js");
let content_type = asset.content_type();
let cache_control = asset.cache_control();
let bytes = asset.bytes();
```

`solverforge_ui::assets::paths()` lists the embedded asset paths, and
`solverforge_ui::assets::version()` returns the crate version that produced the
asset set. The browser bundle exposes the same value as `SF.version`, so a host
can assert that the loaded `sf.js` matches the version its Rust dependency
served.

## Optional Modules

When the optional map module is shipped in `static/sf/modules/`, include it
alongside Leaflet:

```html
<link rel="stylesheet" href="/sf/vendor/leaflet/leaflet.css" />
<script src="/sf/vendor/leaflet/leaflet.js"></script>
<link rel="stylesheet" href="/sf/modules/sf-map.css" />
<script src="/sf/modules/sf-map.js"></script>
```

For route geometry, travel-time, and map-data pipeline details, see the existing
[solverforge-maps](/docs/solverforge-maps/) docs.

### Map Helper Surface

The optional map module exposes `SF.map` after Leaflet and `sf-map.js` are
loaded:

```js
var map = SF.map.create({
  container: "map",
  center: [45.07, 7.69],
  zoom: 13,
});

map.addVehicleMarker({ lat: 45.07, lng: 7.69, color: "#10b981" });
map.addVisitMarker({
  lat: 45.08,
  lng: 7.7,
  color: "#3b82f6",
  icon: "fa-utensils",
});
map.addStopNumber({ lat: 45.08, lng: 7.7, number: 1, color: "#3b82f6" });
map.drawRoute({
  points: [
    [45.07, 7.69],
    [45.08, 7.7],
  ],
  color: "#10b981",
});
map.drawEncodedRoute({ encoded: "encodedPolylineString", color: "#3b82f6" });
map.fitBounds();
map.highlight("#10b981");
map.clearHighlight();
map.clearRoutes();
map.clearStops();
map.clearMarkers();
map.clearAll();
```

`fitBounds()` fits vehicle and visit markers. Since `0.6.2`, marker bounds are
backed by a Leaflet feature group, so marker-only maps can call `fitBounds()`
without needing route polylines first.

## Non-Rust Integration Path

`static/sf/` is self-contained. If you are not serving assets from Rust, copy,
submodule, or symlink it into your static-files directory so `/sf/*` resolves
the same way in production.
