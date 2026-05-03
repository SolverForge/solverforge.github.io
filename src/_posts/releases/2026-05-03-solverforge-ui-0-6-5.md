---
title: "solverforge-ui 0.6.5: Create-Job Identifier Normalization"
date: 2026-05-03
draft: false
description: >
  solverforge-ui 0.6.5 normalizes create-job responses before stream attachment
  and regenerates the versioned frontend bundles.
---

**solverforge-ui 0.6.5** is available on
[crates.io](https://crates.io/crates/solverforge-ui/0.6.5) and tagged in the
[source repository](https://github.com/SolverForge/solverforge-ui/tree/v0.6.5).
API documentation will be available on
[docs.rs](https://docs.rs/solverforge-ui/0.6.5) when the docs.rs build for the
new crate finishes indexing.

This is a focused frontend lifecycle patch. The retained-job API shape stays on
the 0.6 line; create-job responses are now normalized before the solver attaches
to the event stream.

## What Changed

- `createJob()` may resolve to a non-empty string id.
- `createJob()` may resolve to a finite numeric id, including `0`.
- `createJob()` may resolve to an object containing a scalar `id`, `jobId`, or
  `job_id` field.
- Empty strings, non-finite numbers, missing object fields, arrays, and nested
  object identifiers reject startup instead of being stringified.
- Versioned bundles are regenerated as `/sf/sf.0.6.5.css` and
  `/sf/sf.0.6.5.js`.

## Upgrade

Use the crates.io version pin:

```toml
[dependencies]
solverforge-ui = { version = "0.6.5" }
```

Use the source tag directly when you need exact source-tag reproducibility:

```toml
[dependencies]
solverforge-ui = { git = "https://github.com/SolverForge/solverforge-ui", tag = "v0.6.5" }
```

Stable asset URLs stay unchanged:

```html
<link rel="stylesheet" href="/sf/sf.css" />
<script src="/sf/sf.js"></script>
```

For cache-pinned deployments built from the 0.6.5 source tag, use the 0.6.5
bundle names:

```html
<link rel="stylesheet" href="/sf/sf.0.6.5.css" />
<script src="/sf/sf.0.6.5.js"></script>
```
