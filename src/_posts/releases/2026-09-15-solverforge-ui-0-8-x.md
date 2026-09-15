---
title: "solverforge-ui 0.8.x: Null-Safe Lifecycle Callbacks and the Bundled Agent Skill"
date: 2026-09-15
draft: false
description: >
  solverforge-ui 0.8.0 makes the retained-job callback contract explicit and
  null-safe, keeps component content text-rendered by default, documents the
  timeline and Gantt model rules, and ships the crate version through SF.version
  and solverforge_ui::assets::version().
---

**solverforge-ui 0.8.0** is published on crates.io, with the matching
`v0.8.0` source tag. The release keeps the framework-neutral
`solverforge_ui::assets` API and the Axum `.merge(solverforge_ui::routes())`
integration, and it tightens the browser-facing contract around retained-job
callbacks, component content, and versioned asset identity.

Direct UI integrations can install the new line:

```toml
solverforge-ui = { version = "0.8.0" }
```

At publication, `solverforge-cli 2.2.3` still targets `solverforge-ui 0.7.0`.
That is a scaffold dependency choice, not a statement that the published UI
crate is still on 0.7.x. Generated apps move to `0.8.0` only when the app is
deliberately upgraded and validated.

## What Changed

### Solver lifecycle callbacks are explicit and null-safe

`SF.createSolver(...)` already distinguished lifecycle states. 0.8.0 documents
the exact callback argument shape and the snapshot rules that go with it:

| Callback | Arguments |
|---|---|
| `onProgress` | `(meta)` |
| `onSolution` | `(snapshot, meta)` |
| `onPauseRequested` | `(meta)` |
| `onPaused` | `(snapshot, meta)` |
| `onResumed` | `(meta)` |
| `onCancelled` | `(snapshot, meta)` |
| `onComplete` | `(snapshot, meta)` |
| `onFailure` | `(message, meta, snapshot, analysis)` |
| `onAnalysis` | `(analysis, meta)` |
| `onError` | `(message)` |

A snapshot-bearing callback must render only when `snapshot && snapshot.solution`
exists, and should synchronize application lifecycle markers in a `finally`
block. Cancellation, failure, or a failed snapshot synchronization can leave no
solution snapshot; the lifecycle markers must still update even if application
rendering throws. Keep the rendered plan deep-cloned before sending it back to
the solver or mutating it locally.

### Component content is text-rendered by default

Component content is text-rendered, and unsafe HTML is an explicit opt-in. A
`createTabs(...)` entry therefore passes an object, not a bare string:

```js
var tabs = SF.createTabs({
  tabs: [{ id: "plan", content: { unsafeHtml: "<div>Plan view</div>" }, active: true }],
});
```

The documented unsafe fields are `SF.el(...)` `unsafeHtml`, `createModal(...)`
`unsafeBody`, `createTabs(...)` `tabs[].content.unsafeHtml`, `createTable(...)`
`cells[].unsafeHtml`, and `SF.gantt.create(...)` `unsafePopupHtml` plus
`columns[].render(task).unsafeHtml`. `SF.escHtml(...)` remains the shipped
escape helper.

### Asset identity in both bundles

The crate still emits stable and versioned bundle filenames, with different
cache policies:

- stable: `/sf/sf.css`, `/sf/sf.js` — `Cache-Control: public, max-age=3600`
- versioned: `/sf/sf.0.8.0.css`, `/sf/sf.0.8.0.js` —
  `Cache-Control: public, max-age=31536000, immutable`
- `fonts/`, `vendor/`, and `img/` assets are served as immutable

`SF.version` in either bundle and `solverforge_ui::assets::version()` both
report the crate version that produced the embedded asset set, so a host can
assert that the loaded `sf.js` matches its Rust dependency.

For non-Axum Rust hosts, disable the default feature and serve the same embedded
assets through the framework-neutral API:

```toml
solverforge-ui = { version = "0.8.0", default-features = false }
```

<!-- sf-rust: profile="solverforge-ui-current" -->

```rust
let asset = solverforge_ui::assets::get("sf.js").expect("embedded sf.js");
let content_type = asset.content_type();
let cache_control = asset.cache_control();
let bytes = asset.bytes();
```

### Timeline and Gantt model rules

The dense rail timeline keeps its integer-minute model. Day entries may carry
`label`, `subLabel` or `meta`, and `isWeekend`; tick entries may be numbers or
`{ minute, label? }` objects. Timeline tones are `emerald`, `blue`, `amber`,
`rose`, `violet`, `cyan`, `red`, and `slate`; a raw CSS colour or a
`{ background, border, overlay, text }` object is also accepted. Detailed blocks
still render exact interval geometry, keep adjacent intervals disjoint on one
track, and pack true overlaps onto separate track rows.

`SF.gantt.create(...)` requires a laid-out, non-zero-size mount target.
`mount(target)` accepts an element or element id, `setTasks()` rebuilds both
panes, `refresh()` refreshes an existing Frappe chart, and `destroy()` removes
the wrapper and releases Split.js and resize observers.

### Adapter path and command overrides

The HTTP adapter accepts `type: "axum"` and `type: "fetch"`, and supports
`baseUrl`, `jobsPath` (default `/jobs`), `demoDataPath` (default `/demo-data`),
and extra request `headers`. The Tauri adapter uses `invoke` and `listen`, and
optional `commands` entries override the default command names.

### Bundled agent skill

`skills/solverforge-ui/` is a portable agent skill that maps a planning model
onto the shipped timeline, Gantt, map, rail, and table surfaces while
preserving the generated model and the `/sf` + `/jobs` + `/demo-data` backend
contract. Install it with `make install-skill` or
`scripts/install-skill --list`.

## Patch History

| Version | Date | Notes |
| ------- | ---- | ----- |
| `0.8.0` | 2026-09-15 | Documents explicit null-safe lifecycle callbacks, keeps component content text-rendered with documented unsafe opt-ins, publishes `SF.version` and `solverforge_ui::assets::version()`, tightens timeline and Gantt model rules, and ships the installable agent skill. |

## Where to read next

Use the [solverforge-ui manual](/docs/solverforge-ui/) for the current direct UI
integration surface. Use the [solverforge-cli manual](/docs/solverforge-cli/)
when you need to know which UI version fresh generated apps currently pin.
