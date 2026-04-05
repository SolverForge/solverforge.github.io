---
title: SolverForge
description: Native Rust constraint solving for scheduling, routing, and operations software.
date: 2025-12-08
---

{{< blocks/cover title="SolverForge" image_anchor="top" height="min" >}}
<div class="sf-home-landing sf-home-hero">
  <p class="sf-kicker">Native Rust constraint solving for planning and optimization</p>
  <p class="sf-hero-summary">Model scheduling, routing, and allocation problems with explicit domain types, inspect score behavior, and ship optimization workflows without hiding the rules in a separate math DSL.</p>
  <div class="sf-hero-actions">
    <a class="btn btn-lg btn-primary" href="/docs/">
      Read the docs <i class="fas fa-arrow-alt-circle-right ms-2"></i>
    </a>
    <a class="btn btn-lg btn-secondary" href="https://github.com/SolverForge">
      View on GitHub <i class="fab fa-github ms-2"></i>
    </a>
  </div>
  <div class="sf-proof-strip">
    <span>Production-ready Rust core</span>
    <span>Published employee scheduling quickstart</span>
    <span>UI and maps docs live now</span>
  </div>
</div>
{{< /blocks/cover >}}

{{% blocks/section %}}
<div class="sf-home-landing sf-home-section sf-home-code">
  <div class="sf-copy-block">
    <p class="sf-section-label">What the API feels like</p>
    <h2>Readable constraints, explicit business rules</h2>
    <p>SolverForge keeps the model close to the domain. You work with shifts, employees, routes, and scores instead of translating everything into a separate optimization language.</p>
    <ul class="sf-feature-list">
      <li>Constraint Streams for composable rules and score analysis</li>
      <li>Typed Rust models that stay recognizable as application code</li>
      <li>Optimization infrastructure that can power real product workflows</li>
    </ul>
  </div>

  <div class="terminal-card sf-code-card">
    <div class="terminal-header">
      <span class="terminal-btn close"></span>
      <span class="terminal-btn minimize"></span>
      <span class="terminal-btn maximize"></span>
      <span class="terminal-title">constraints.rs</span>
    </div>
    <div class="terminal-body">

```rust
let one_per_day = factory
    .clone()
    .shifts()
    .for_each_unique_pair(joiner::equal(|shift: &Shift| {
        (shift.employee_idx, shift.date())
    }))
    .filter(|a: &Shift, b: &Shift| {
        a.employee_idx.is_some() && b.employee_idx.is_some()
    })
    .penalize(HardSoftDecimalScore::ONE_HARD)
    .named("One shift per day");
```

    </div>
  </div>
</div>
{{% /blocks/section %}}

{{< blocks/section >}}
<div class="sf-home-landing sf-home-section">
  <div class="sf-section-heading">
    <p class="sf-section-label">Published examples and modules</p>
    <h2>Start from what already ships</h2>
    <p>The current public surface is Rust-first. These are the pages and modules that already have runnable or documented workflows behind them.</p>
  </div>

  <div class="sf-card-grid">
    <a class="sf-feature-card" href="/docs/getting-started/employee-scheduling-rust/">
      <span class="sf-card-icon"><i class="fa-solid fa-calendar-days"></i></span>
      <h3>Employee Scheduling</h3>
      <p>The current onboarding path: a complete quickstart with domain modeling, constraints, and a web app.</p>
      <span class="sf-card-link">Open the quickstart</span>
    </a>

    <a class="sf-feature-card" href="/docs/solverforge-ui/">
      <span class="sf-card-icon"><i class="fa-solid fa-display"></i></span>
      <h3><code>solverforge-ui</code></h3>
      <p>Embedded scheduling views, UI primitives, and solver lifecycle helpers for SolverForge-backed web applications.</p>
      <span class="sf-card-link">Browse the UI docs</span>
    </a>

    <a class="sf-feature-card" href="/docs/solverforge-maps/">
      <span class="sf-card-icon"><i class="fa-solid fa-route"></i></span>
      <h3><code>solverforge-maps</code></h3>
      <p>Road-network loading, travel-time matrices, and route geometry utilities for vehicle routing workflows.</p>
      <span class="sf-card-link">Read the maps docs</span>
    </a>
  </div>
</div>
{{< /blocks/section >}}

{{< blocks/section >}}
<div class="sf-home-landing sf-home-section sf-home-closing">
  <div class="sf-quote-card">
    <p class="sf-section-label">Field signal</p>
    <blockquote>
      I have incorporated SolverForge in my new Rust application for staff scheduling and it's working like a charm, A+
    </blockquote>
    <p class="sf-quote-attribution">Fawaz Halwani, Pathologist, The Ottawa Hospital</p>
  </div>

  <div class="sf-status-card">
    <p class="sf-section-label">Current posture</p>
    <h2>Rust is the public path today</h2>
    <p>The site should lead with what is ready: the Rust solver, the published quickstart, and the supporting crates around it.</p>
    <p>Python remains a future track. When there is a real public onboarding path for it, it can return as a primary message instead of a roadmap note.</p>
    <p class="sf-inline-links">
      <a href="/about/">About SolverForge</a>
      <a href="/docs/overview/">Project overview</a>
    </p>
  </div>
</div>
{{< /blocks/section >}}
