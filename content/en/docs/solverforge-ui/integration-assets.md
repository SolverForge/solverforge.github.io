---
title: Integration & Assets
description: Backend adapters, expected endpoints, and solverforge-ui asset delivery patterns.
weight: 4
---

# Integration & Assets

This page summarizes how `solverforge-ui` connects frontend code to backend APIs and how static assets are delivered.

## Backend Adapters

Create adapters with `SF.createBackend({ type })` and then pass the backend into `SF.createSolver(...)`.

### Axum Adapter

```js
const backend = SF.createBackend({ type: 'axum' });
const solver = SF.createSolver({ backend });
```

Use this when your backend is an Axum service exposing SolverForge scheduling endpoints.

### Tauri Adapter

```js
const backend = SF.createBackend({ type: 'tauri' });
```

Use this for desktop packaging where solver calls are bridged through Tauri.

### Generic Fetch Adapter

```js
const backend = SF.createBackend({ type: 'fetch' });
```

Use this when you need to call a custom HTTP API shape with standard browser fetch semantics.

## Expected Axum REST Endpoints

The standard Axum integration expects these routes:

- `POST /schedules`
- `GET /schedules/{id}`
- `GET /schedules/{id}/events`
- `GET /schedules/{id}/analyze`
- `DELETE /schedules/{id}`
- `GET /demo-data/{name}`

If your backend uses different paths, map or proxy routes so the UI adapter can call a compatible surface.

## Asset Serving Under `/sf/*`

When you merge `solverforge_ui::routes()`, the crate serves its static files from `/sf/*`.

Common assets include:

- `/sf/sf.css`
- `/sf/sf.js`
- `/sf/vendor/fontawesome/css/fontawesome.min.css`
- `/sf/vendor/fontawesome/css/solid.min.css`

## Stable vs Versioned Asset URLs

`solverforge-ui` provides both stable and versioned bundle URLs:

- stable: `/sf/sf.css`, `/sf/sf.js`
- versioned: `/sf/sf.<crate-version>.css`, `/sf/sf.<crate-version>.js`

A practical strategy is:

- use stable URLs for simple development environments
- use versioned URLs for stronger cache busting in production/CDN environments

## Optional Leaflet Map Module

`SF.map.*` is optional and can be enabled for map-enhanced pages.

For route geometry, travel-time, and map-data pipeline details, see the existing `solverforge-maps` docs, especially [Routing & Matrices](/docs/solverforge-maps/routing/) and [Caching & Operations](/docs/solverforge-maps/caching/).

## Non-Rust Integration Path

If you are not serving assets from Rust, copy or symlink `static/sf/` into your web server's static-files directory so `/sf/*` URLs resolve the same way in production.
