---
title: SolverForge
date: 2025-12-08
---

{{< blocks/cover title="SolverForge" image_anchor="top" height="full" >}}
<p class="lead mt-3 mb-3">Build planning and optimization systems with code.</p>
<p class="lead mt-4">SolverForge gives developers the tools to model business constraints explicitly, solve complex decision problems, and ship production-grade optimization systems for real products and operations.</p>
<a class="btn btn-lg btn-primary me-3 mb-4" href="/docs/">
  Learn More <i class="fas fa-arrow-alt-circle-right ms-2"></i>
</a>
<a class="btn btn-lg btn-secondary me-3 mb-4" href="https://github.com/SolverForge">
  View on GitHub <i class="fab fa-github ms-2 "></i>
</a>
{{< blocks/link-down color="info" >}}
{{< /blocks/cover >}}

{{% blocks/lead %}}
Write constraints like you write code. SolverForge is designed for developers building planning, scheduling, routing, and resource allocation systems with explicit models and programmable rules.

<a class="td-link-down" href="#td-block-2"><i class="fas fa-chevron-down"></i></a>
{{% /blocks/lead %}}

{{% blocks/section %}}

<div class="terminal-card">
  <div class="terminal-header">
    <span class="terminal-btn close"></span>
    <span class="terminal-btn minimize"></span>
    <span class="terminal-btn maximize"></span>
    <span class="terminal-title">constraints.rs</span>
  </div>
  <div class="terminal-body">

```rust
// =========================================================================
// HARD: One Shift Per Day
// =========================================================================
let one_per_day = factory
    .clone()
    .shifts()
    .for_each_unique_pair(joiner::equal(|shift: &Shift| (shift.employee_idx, shift.date())))
    .filter(|a: &Shift, b: &Shift| a.employee_idx.is_some() && b.employee_idx.is_some())
    .penalize(HardSoftDecimalScore::ONE_HARD)
    .named("One shift per day");
```

  </div>
</div>

<a class="td-link-down" href="#td-block-3"><i class="fas fa-chevron-down"></i></a>

<div class="text-center td-arrow-down"></div>

{{% /blocks/section %}}

{{% blocks/section %}}

<div class="text-center mb-4">
  <span class="install-badge">
    <i class="fas fa-rocket"></i> Get started in seconds
  </span>
</div>

<div class="terminal-card">
  <div class="terminal-header">
    <span class="terminal-btn close"></span>
    <span class="terminal-btn minimize"></span>
    <span class="terminal-btn maximize"></span>
    <span class="terminal-title">bash - solverforge</span>
  </div>
  <div class="terminal-body">
    <pre><code><span class="command-line">git clone https://github.com/SolverForge/solverforge-quickstarts</span>
<span class="command-line">cd solverforge-quickstarts/rust/employee-scheduling</span>
<span class="command-line">cargo run</span></code></pre>
  </div>
</div>

{{% /blocks/section %}}

{{% blocks/section %}}

<div class="testimonial-section">
  <h2 class="testimonial-heading">What people say</h2>
  <div class="testimonial-card">
    <img class="testimonial-photo" src="/images/testimonials/fawaz-halwani.jpeg" alt="Fawaz Halwani">
    <blockquote class="testimonial-quote">
      I have incorporated SolverForge in my new Rust application for staff scheduling and it's working like a charm, A+
    </blockquote>
    <div class="testimonial-author">Fawaz Halwani</div>
    <div class="testimonial-title">Pathologist, The Ottawa Hospital</div>
    <img class="testimonial-logo" src="/images/testimonials/ottawa-hospital.jpg" alt="The Ottawa Hospital">
  </div>
</div>

{{% /blocks/section %}}
