---
title: About SolverForge
linkTitle: About
description: What SolverForge publishes today, how the pieces fit together, and what remains on the roadmap.
menu: {main: {weight: 10}}
---

{{< blocks/cover title="About SolverForge" image_anchor="bottom" height="auto" >}}
<div class="sf-about-landing sf-about-hero">
  <p class="sf-kicker">Constraint solving for operations software</p>
  <p class="sf-hero-summary">SolverForge is a Rust-native constraint solver ecosystem for planning, scheduling, routing, and allocation systems. The public story today is the Rust core plus the examples and companion crates that are already documented.</p>
</div>
{{< /blocks/cover >}}

{{< blocks/section color="primary" >}}
<div class="sf-about-landing sf-about-section">
  <div class="sf-section-heading">
    <p class="sf-section-label">What exists today</p>
    <h2>The published surface is Rust-first</h2>
    <p>SolverForge is not a generic brochure about future possibilities. These are the pieces you can actually read, evaluate, and build with on the site right now.</p>
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
      <h3>Employee Scheduling Quickstart</h3>
      <p>The current runnable onboarding path for learning the model, the constraints, and the application integration.</p>
      <span class="sf-card-link"><a href="/docs/getting-started/employee-scheduling-rust/">Open the quickstart</a></span>
    </div>

    <div class="sf-feature-card sf-feature-card--static">
      <span class="sf-card-icon"><i class="fa-solid fa-display"></i></span>
      <h3><code>solverforge-ui</code></h3>
      <p>Embedded frontend components, scheduling views, and backend adapters for SolverForge-backed web apps.</p>
      <span class="sf-card-link"><a href="/docs/solverforge-ui/">Browse the UI docs</a></span>
    </div>

    <div class="sf-feature-card sf-feature-card--static">
      <span class="sf-card-icon"><i class="fa-solid fa-route"></i></span>
      <h3><code>solverforge-maps</code></h3>
      <p>Road-network routing, travel-time matrices, and route geometry utilities for map-backed optimization workflows.</p>
      <span class="sf-card-link"><a href="/docs/solverforge-maps/">Read the maps docs</a></span>
    </div>
  </div>
</div>
{{< /blocks/section >}}

{{< blocks/section color="dark" >}}
<div class="sf-about-landing sf-about-section">
  <div class="sf-section-heading">
    <p class="sf-section-label">How the pieces fit together</p>
    <h2>Core solver, published examples, application building blocks</h2>
  </div>

  <div class="sf-about-layout">
    <div class="sf-copy-block">
      <p>The core Rust solver is the foundation. The employee scheduling quickstart shows how a real application is modeled and solved. The companion crates extend that story into UI and routing workflows that match the kinds of systems SolverForge is meant to power.</p>
      <p>That is why the home and about pages should lead with these concrete pieces instead of generic domain claims. The public site is strongest when it points directly at what already exists.</p>
    </div>

    <div class="sf-callout-card">
      <p class="sf-section-label">Published examples</p>
      <ul class="sf-feature-list">
        <li>Employee scheduling for a complete end-to-end SolverForge walkthrough</li>
        <li><code>solverforge-ui</code> for scheduling screens and integration patterns</li>
        <li><code>solverforge-maps</code> for routing cost models and map-backed workflows</li>
      </ul>
    </div>
  </div>
</div>
{{< /blocks/section >}}

{{< blocks/section >}}
<div class="sf-about-landing sf-about-section sf-home-closing">
  <div class="sf-status-card">
    <p class="sf-section-label">Roadmap note</p>
    <h2>Python is not the headline yet</h2>
    <p>Python remains part of the roadmap, but it should not be marketed on these pages as if it were the current primary experience. The site should stay honest: the public onboarding path today is Rust.</p>
    <p>When Python has a real published getting-started flow, stable package story, and example set, it can move back into the main narrative.</p>
  </div>

  <div class="sf-quote-card">
    <p class="sf-section-label">Open source posture</p>
    <p>SolverForge is built in public, with docs, examples, and code hosted openly on GitHub. The site should reflect that by pointing people toward concrete artifacts instead of speculative product copy.</p>
    <p class="sf-inline-links">
      <a href="https://github.com/SolverForge">GitHub organization</a>
      <a href="/blog/">Engineering blog</a>
    </p>
  </div>
</div>
{{< /blocks/section >}}
