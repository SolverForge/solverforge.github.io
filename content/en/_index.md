---
title: SolverForge
description: Rust constraint solving for scheduling, routing, and allocation software.
date: 2025-12-08
---

{{< blocks/cover title="SolverForge" image_anchor="top" height="min" >}}
<div class="sf-home-landing sf-home-hero">
  <p class="sf-kicker">Write constraints like you write code</p>
  <p class="sf-hero-summary">Build planning software in Rust. Model the domain with ordinary types, express the rules in code, and ship optimization systems without switching to a separate solver language.</p>
  <div class="sf-hero-actions">
    <a class="btn btn-lg btn-primary" href="/docs/solverforge-cli/getting-started/">
      Start with solverforge-cli <i class="fas fa-arrow-alt-circle-right ms-2"></i>
    </a>
    <a class="btn btn-lg btn-secondary" href="/docs/getting-started/employee-scheduling-rust/">
      See the employee scheduling tutorial <i class="fas fa-book-open ms-2"></i>
    </a>
  </div>
  <div class="sf-proof-strip">
    <span>Neutral app shell from the CLI</span>
    <span>Incremental domain generation after scaffolding</span>
    <span>Step-by-step employee scheduling tutorial</span>
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
      <li>Solver components you can embed in real applications</li>
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
// Prevent assigning overlapping shifts to the same employee.
let no_overlap = factory
    .shifts()
    .join(equal(|shift: &Shift| shift.employee))
    .filter(|a: &Shift, b: &Shift| {
        a.employee.is_some() && a.start < b.end && b.start < a.end
    })
    .penalize_hard()
    .named("No overlap");

// Require every assigned employee to satisfy the shift's required skill.
let required_skill = factory
    .shifts()
    .join(equal(|shift: &Shift| shift.employee))
    .filter(|shift: &Shift, other: &Shift| {
        shift.employee == other.employee
            && shift.required_skill.is_some()
            && !shift.employee
                .as_ref()
                .is_some_and(|employee| employee.skills.contains(&shift.required_skill.unwrap()))
    })
    .penalize_hard()
    .named("Employee skill match");
```
  </div>
</div>
<div class="text-center td-arrow-down"></div>
{{% /blocks/section %}}

{{< blocks/section >}}
<div class="sf-home-landing sf-home-section">
  <div class="sf-section-heading">
    <p class="sf-section-label">Examples and companion libraries</p>
    <h2>Start with a working planner. Extend into product and routing.</h2>
    <p>Begin with employee scheduling, then add scheduling interfaces through <code>solverforge-ui</code> or travel-time and route modeling through <code>solverforge-maps</code>.</p>
  </div>

  <div class="sf-card-grid">
    <a class="sf-feature-card" href="/docs/getting-started/employee-scheduling-rust/">
      <span class="sf-card-icon"><i class="fa-solid fa-calendar-days"></i></span>
      <h3>Build your first scheduler</h3>
      <p>Follow a complete employee scheduling walkthrough with shifts, hard rules, soft preferences, and a live application loop.</p>
      <span class="sf-card-link">Start the tutorial</span>
    </a>

    <a class="sf-feature-card" href="/docs/solverforge-ui/">
      <span class="sf-card-icon"><i class="fa-solid fa-display"></i></span>
      <h3>Add scheduling UI</h3>
      <p>Use <code>solverforge-ui</code> for scheduling views, frontend primitives, and integration helpers in operational products.</p>
      <span class="sf-card-link">Explore UI docs</span>
    </a>

    <a class="sf-feature-card" href="/docs/solverforge-maps/">
      <span class="sf-card-icon"><i class="fa-solid fa-route"></i></span>
      <h3>Model routes and travel time</h3>
      <p>Use <code>solverforge-maps</code> for road-network loading, travel-time matrices, and route geometry in dispatch systems.</p>
      <span class="sf-card-link">Read maps docs</span>
    </a>
  </div>
</div>
<div class="text-center td-arrow-down"></div>
{{< /blocks/section >}}

{{< blocks/section >}}
<div class="sf-home-landing sf-home-section sf-home-closing">
  <div class="sf-quote-card">
    <p class="sf-section-label">In practice</p>
    <blockquote>
      I have incorporated SolverForge in my new Rust application for staff scheduling and it's working like a charm, A+
    </blockquote>
    <p class="sf-quote-attribution">Fawaz Halwani, Pathologist, The Ottawa Hospital</p>
  </div>

  <div class="sf-status-card">
    <p class="sf-section-label">Public docs and code</p>
    <h2>Everything important is visible</h2>
    <p>The docs, APIs, tutorials, and source are public, so you can inspect SolverForge directly before deciding whether it fits your system.</p>
    <ul class="sf-feature-list">
      <li>CLI-first setup with generated project scaffolds</li>
      <li>Reference tutorials for scheduling and routing problems</li>
      <li>Open-source crates and docs you can verify directly</li>
    </ul>
    <p class="sf-inline-links">
      <a href="/docs/overview/">Project overview</a>
      <a href="https://github.com/SolverForge">GitHub organization</a>
      <a href="/about/">About SolverForge</a>
    </p>
  </div>
</div>
{{< /blocks/section >}}

