---
title: Integration & Assets
description: >
  Backend adapters, asset serving, cache behavior, and example route contracts
  for solverforge-ui.
weight: 4
---

# Integration & Assets

<%= render Ui::Callout.new do %>
The current `solverforge-ui` contract is job-oriented and lifecycle-typed. New integrations should expose
retained jobs, explicit `eventType` payloads, and exact paused or terminal
snapshots.
<% end %>

This page summarizes how `solverforge-ui` connects frontend code to backend APIs
and how static assets are delivered.

## Backend Adapters

Create adapters with `SF.createBackend(...)` and pass the result into
`SF.createSolver(...)`.

### Axum (default)

```js
var backend = SF.createBackend({ type: 'axum', baseUrl: '' });
```

Use this when your backend exposes the stock `solverforge-ui` lifecycle
contract. New integrations should model retained jobs and snapshots rather than
build around schedule-specific naming.

### Tauri Adapter

```js
var backend = SF.createBackend({
  type: 'tauri',
  invoke: window.__TAURI__.core.invoke,
  listen: window.__TAURI__.event.listen,
  eventName: 'solver-update',
});
```

Use this when solver traffic is bridged through Tauri IPC.

### Generic Fetch Adapter

```js
var backend = SF.createBackend({
  type: 'fetch',
  baseUrl: '/api/v1',
  headers: { 'X-CSRF-Token': csrfToken },
});
```

Use this when your app needs extra headers or a non-default base path while
still implementing the retained-job backend methods expected by
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

- a plain job id string, or
- an object containing one of `id`, `jobId`, or `job_id`

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

## Non-Rust Integration Path

`static/sf/` is self-contained. If you are not serving assets from Rust, copy,
submodule, or symlink it into your static-files directory so `/sf/*` resolves
the same way in production.
