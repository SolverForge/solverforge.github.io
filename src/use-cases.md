---
title: Use cases
layout: use_cases
page_class: page-use-cases
description: >-
  Inspect SolverForge in practice: hospital workforce coverage, school
  timetabling, delivery routing, and field service routing, each with a narrated
  walkthrough, annotated screenshots, and a runnable app.
---

<section class="use-case-hero">
  <div>
    <p class="use-case-eyebrow">SolverForge in practice</p>
    <h1>Use cases you can inspect, not just read about.</h1>
  </div>
  <p class="use-case-hero__summary">
    Every SolverForge use case is open source, so what marks a case here is
    whether it ships a Hugging Face Space you can open and drive in the browser.
    Four of the eight do, and a Space is a running service that may be stopped
    between sessions, so the app source is the durable entry point either way.
    Each case carries source-backed data, explicit constraints, a retained-job
    workflow, a narrated runtime walkthrough, and annotated screenshots of the
    same solve.
  </p>
</section>

<%= render UseCase::Showcase.new(cases: site.data.use_cases) %>
