---
title: Integration & Assets
description: >
  Backend adapters, asset serving, cache behavior, and example route contracts
  for solverforge-ui.
weight: 4
---

# Integration & Assets

This page summarizes how `solverforge-ui` connects frontend code to backend APIs
and how static assets are delivered.

## Backend Adapters

Create adapters with `SF.createBackend(...)` and pass the result into
`SF.createSolver(...)`.

### Axum (default)

```js
var backend = SF.createBackend({ type: 'axum', baseUrl: '' });
```

Use this when your backend exposes the default `solverforge-ui` scheduling
contract.

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

Use this when your app needs a custom HTTP shape, extra headers, or a
compatibility layer during a route transition.

## Default Axum Adapter Contract

The default Axum adapter expects these routes:

- `POST /schedules`
- `GET /schedules/{id}`
- `GET /schedules/{id}/events`
- `GET /schedules/{id}/analyze`
- `DELETE /schedules/{id}`
- `GET /demo-data/{name}`

The adapter also expects `createSchedule()` to resolve to either:

- a plain schedule/job id string, or
- an object containing one of `id`, `jobId`, `job_id`, `scheduleId`, or
  `schedule_id`

If your current app still uses a legacy quickstart route shape, add an
application-side compatibility layer or use the generic `fetch` adapter until
the routes converge.

## Solver Lifecycle

`SF.createSolver(...)` builds the client-side solver state machine on top of the
backend adapter.

```js
var solver = SF.createSolver({
  backend: backend,
  statusBar: statusBar,
  onUpdate: function (schedule) {
    render(schedule);
  },
});
```

The shipped solver helper exposes `start`, `stop`, `isRunning`, and `getJobId`.

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
