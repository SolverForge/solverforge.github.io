---
title: Use cases
layout: use_cases
page_class: page-use-cases
description: >-
  Explore planning problems across workforce scheduling, timetabling, routing,
  manufacturing, order picking, fleet readiness, and flight crew planning.
  See how SolverForge handles resource limits, required rules, and competing goals.
---

<section class="use-case-hero">
  <div>
    <p class="use-case-eyebrow">SolverForge in practice</p>
    <h1>Turn competing demands into a workable plan.</h1>
  </div>
  <p class="use-case-hero__summary">
    Cover shifts with qualified staff. Fit lessons into rooms and timeslots.
    Route deliveries within capacity and time windows. Coordinate maintenance
    without sacrificing fleet readiness. These examples show how to model the
    rules a plan must obey and the goals worth improving — so you can find a
    starting point for your own scheduling, routing, or allocation problem.
  </p>
</section>

<%= render UseCase::Showcase.new(cases: site.data.use_cases) %>
