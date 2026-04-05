---
title: SolverForge
description: Rust constraint solving for scheduling, routing, and allocation software.
date: 2025-12-08
---

{{< blocks/cover title="SolverForge" image_anchor="top" height="min" >}}
<div class="sf-home-landing sf-home-hero">
  <p class="sf-kicker">Native Rust constraint solving for planning and optimization</p>
  <p class="sf-hero-summary">Model shifts, routes, visits, and assignments with ordinary Rust types, then optimize them with Constraint Streams, incremental scoring, and solver events that fit application code.</p>
  <div class="sf-hero-actions">
    <a class="btn btn-lg btn-primary" href="/docs/">
      Read the docs <i class="fas fa-arrow-alt-circle-right ms-2"></i>
    </a>
    <a class="btn btn-lg btn-secondary" href="https://github.com/SolverForge">
      View on GitHub <i class="fab fa-github ms-2"></i>
    </a>
  </div>
  <div class="sf-proof-strip">
    <span>Constraint Streams and incremental scoring</span>
    <span>Employee scheduling tutorial</span>
    <span>UI and routing companion crates</span>
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
let no_overlap = factory
    .shifts()
    .join(equal(|shift: &Shift| shift.employee))
    .filter(|a: &Shift, b: &Shift| {
        a.employee.is_some() && a.start < b.end && b.start < a.end
    })
    .penalize_hard()
    .named("No overlap");
```

    </div>
  </div>
</div>
{{% /blocks/section %}}

{{< blocks/section >}}
<div class="sf-home-landing sf-home-section">
  <div class="sf-section-heading">
    <p class="sf-section-label">Examples and companion crates</p>
    <h2>Start with scheduling, extend into UI and routing</h2>
    <p>Learn the solver through a complete employee scheduling example, embed scheduling views with <code>solverforge-ui</code>, or add travel-time and route modeling with <code>solverforge-maps</code>.</p>
  </div>

  <div class="sf-card-grid">
    <a class="sf-feature-card" href="/docs/getting-started/employee-scheduling-rust/">
      <span class="sf-card-icon"><i class="fa-solid fa-calendar-days"></i></span>
      <h3>Employee Scheduling</h3>
      <p>A full walkthrough covering employees, shifts, hard rules, soft preferences, and a live application loop.</p>
      <span class="sf-card-link">Open the quickstart</span>
    </a>

    <a class="sf-feature-card" href="/docs/solverforge-ui/">
      <span class="sf-card-icon"><i class="fa-solid fa-display"></i></span>
      <h3><code>solverforge-ui</code></h3>
      <p>Scheduling views, frontend primitives, and integration helpers for operational applications built on SolverForge.</p>
      <span class="sf-card-link">Browse the UI docs</span>
    </a>

    <a class="sf-feature-card" href="/docs/solverforge-maps/">
      <span class="sf-card-icon"><i class="fa-solid fa-route"></i></span>
      <h3><code>solverforge-maps</code></h3>
      <p>Road-network loading, travel-time matrices, and route geometry utilities for routing and dispatch workflows.</p>
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
    <p class="sf-section-label">Open source foundation</p>
    <h2>Inspect, test, and extend the solver</h2>
    <p>Constraint models, score calculations, and solving behavior stay visible in code, which makes it easier to debug planners, write targeted tests, and evolve domain rules over time.</p>
    <p>Start with the project overview or dive straight into the APIs and examples.</p>
    <p class="sf-inline-links">
      <a href="/about/">About SolverForge</a>
      <a href="/docs/overview/">Project overview</a>
    </p>
  </div>
</div>
{{< /blocks/section >}}
