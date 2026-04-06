---
title: About SolverForge
linkTitle: About
description: Constraint solving for planning, scheduling, routing, and allocation applications in Rust.
menu: {main: {weight: 10}}
---

{{< blocks/cover title="About SolverForge" image_anchor="bottom" height="auto" >}}
<div class="sf-about-landing sf-about-hero">
  <p class="sf-kicker">AI Optimization Framework</p>
  <p class="sf-hero-summary">Rust-native optimization infrastructure for real planning systems.</p>
</div>
{{< /blocks/cover >}}

{{< blocks/section color="primary" >}}
<div class="sf-about-landing sf-about-section">
  <div class="sf-section-heading">
    <p class="sf-section-label">Core capabilities</p>
    <h2>A solver stack for planning applications</h2>
    <p>Build domain models in Rust, express hard and soft constraints as code, and integrate solving into scheduling, dispatch, allocation, and operational planning systems.</p>
  </div>

  <div class="sf-card-grid sf-card-grid--two-up">
    <div class="sf-feature-card sf-feature-card--static">
      <span class="sf-card-icon"><i class="fab fa-rust"></i></span>
      <h3>Rust Solver Core</h3>
      <p>A production-ready constraint solver with Constraint Streams, typed moves, score analysis, and a stable Rust API.</p>
      <span class="sf-card-link"><a href="/docs/overview/">Read the overview</a></span>
    </div>

    <div class="sf-feature-card sf-feature-card--static">
      <span class="sf-card-icon"><i class="fa-solid fa-calendar-days"></i></span>
      <h3>Employee Scheduling Tutorial</h3>
      <p>A worked example for modeling shifts, employee skills, preferences, and solver-driven updates end to end.</p>
      <span class="sf-card-link"><a href="/docs/getting-started/employee-scheduling-rust/">Open the tutorial</a></span>
    </div>

    <div class="sf-feature-card sf-feature-card--static">
      <span class="sf-card-icon"><i class="fa-solid fa-display"></i></span>
      <h3><code>solverforge-ui</code></h3>
      <p>Frontend components and integration helpers for scheduling-heavy products built on SolverForge.</p>
      <span class="sf-card-link"><a href="/docs/solverforge-ui/">Browse the UI docs</a></span>
    </div>

    <div class="sf-feature-card sf-feature-card--static">
      <span class="sf-card-icon"><i class="fa-solid fa-route"></i></span>
      <h3><code>solverforge-maps</code></h3>
      <p>Routing primitives, cached road-network data, and travel metrics for map-backed optimization workflows.</p>
      <span class="sf-card-link"><a href="/docs/solverforge-maps/">Read the maps docs</a></span>
    </div>
  </div>
</div>
<div class="text-center td-arrow-down"></div>
{{< /blocks/section >}}

{{< blocks/section color="dark" >}}
<div class="sf-about-landing sf-about-section">
  <div class="sf-section-heading">
    <p class="sf-section-label">How it works</p>
    <h2>Domain model, constraints, solver, application</h2>
  </div>

  <div class="sf-about-layout">
    <div class="sf-copy-block">
      <p>A SolverForge application starts with a planning solution and entities represented as ordinary Rust structs. Constraint Streams define what must be satisfied and what should be optimized, while score analysis helps explain tradeoffs.</p>
      <p>The solver searches for better solutions and emits progress, best-solution, and finished events that application code can consume.</p><p><code>solverforge-ui</code> and <code>solverforge-maps</code> extend that core into interactive scheduling and routing workflows.</p>
    </div>

    <div class="sf-callout-card">
      <p class="sf-section-label">Typical workflows</p>
      <ul class="sf-feature-list">
        <li>Workforce scheduling with hard compliance rules and soft preferences</li>
        <li>Routing and dispatch with travel-time-aware scoring</li>
        <li>Interactive planning applications that need solver feedback in the UI</li>
      </ul>
      <p class="sf-inline-links">
        <a href="/docs/getting-started/employee-scheduling-rust/">Scheduling walkthrough</a>
        <a href="/docs/solverforge-maps/">Routing surface</a>
      </p>
    </div>
  </div>
</div>
<div class="text-center td-arrow-down"></div>
{{< /blocks/section >}}

{{< blocks/section >}}
<div class="sf-about-landing sf-about-section sf-home-closing">
  <div class="sf-status-card">
    <p class="sf-section-label">Public surface</p>
    <h2>Built in public, inspectable from the start</h2>
    <p>SolverForge ships as open source Rust crates, examples, and documentation on GitHub. Teams can audit the solver, study the reference implementations, and extend the stack for their own operational domains.</p>
    <p class="sf-inline-links">
      <a href="https://github.com/SolverForge">GitHub organization</a>
      <a href="/docs/overview/">Project overview</a>
      <a href="/docs/">Docs</a>
    </p>
  </div>

  <div class="sf-quote-card">
    <p class="sf-section-label">Problem spaces</p>
    <h2>Designed for operational complexity</h2>
    <p>SolverForge is suited to scheduling, routing, capacity planning, assignment, and similar problems where feasibility and business value depend on many interacting rules.</p>
    <p class="sf-inline-links">
      <a href="/docs/getting-started/employee-scheduling-rust/">Employee scheduling</a>
      <a href="/docs/solverforge-maps/">Routing tools</a>
      <a href="/blog/">Blog</a>
    </p>
  </div>
</div>
{{< /blocks/section >}}
