---
title: SolverForge
layout: default
page_class: page-home
description: Build inspectable planning, scheduling, routing, and allocation software in Rust.
---

<section class="home-shell">
  <section class="home-hero">
    <p class="page-shell__eyebrow">Open source planning software in Rust</p>
    <h1>Describe your problem → a&nbsp;running solver, today.</h1>
    <p class="home-hero__summary">
      Tell your coding agent what has to be decided, what makes a plan invalid, and what makes it good. The <code>solverforge-modeling</code> skill turns that description into a SolverForge app with its domain model, hard and soft constraints, demo data, and an API, web, CLI, or MCP shell, and solves it before handing it back. The model stays in ordinary Rust you can read and change.
    </p>

    <div class="home-actions">
      <a class="button button--primary" href="<%= relative_url '/docs/solverforge-cli/agent-skill/' %>" data-home-primary-cta>
        Install the modeling skill <i class="fa-solid fa-arrow-right"></i>
      </a>
      <a class="button button--secondary" href="<%= relative_url '/docs/getting-started/maintenance-planning-with-the-agent-skill/' %>">
        Follow a maintenance walkthrough <i class="fa-solid fa-screwdriver-wrench"></i>
      </a>
    </div>

    <div class="home-proof">
      <span>Apache-2.0, no account or licence key</span>
      <span>Scalar and list planning variables</span>
      <span>Eight worked planning apps</span>
    </div>
  </section>

  <section class="home-section home-section--split">
    <div>
      <p class="page-shell__eyebrow">Write constraints like you write code</p>
      <h2>Readable rules, explicit tradeoffs, real application shapes.</h2>
      <p>
        Model shifts, routes, tasks, workers, vehicles, and inventories as ordinary application code. SolverForge keeps rule definitions, score analysis, and solver control close to the domain types your team already understands.
      </p>
      <div class="card-grid">
        <%= render Ui::Card.new(title: "Getting Started", href: relative_url('/docs/getting-started/'), icon: "fa-solid fa-rocket") do %>
Start with the generic CLI path, then continue into a concrete worked example.
        <% end %>
        <%= render Ui::Card.new(title: "Reference", href: relative_url('/reference/'), icon: "fa-solid fa-book") do %>
Check the crate map, modeling checklist, and extension guidance before choosing an implementation path.
        <% end %>
      </div>
    </div>

    <div class="terminal-card">
      <div class="terminal-card__bar">
        <span class="terminal-card__dot"></span>
        <span class="terminal-card__dot"></span>
        <span class="terminal-card__dot"></span>
        <strong>constraints.rs</strong>
      </div>
      <%= render Ui::CodeBlock.new(language: "rust") do %>
        let required_skill = ConstraintFactory::<Plan, HardSoftDecimalScore>::new()
            .shifts()
            .filter(|shift: &Shift| shift.employee_idx.is_some())
            .join((
                Plan::employees_slice,
                equal_bi(
                    |shift: &Shift| shift.employee_idx,
                    |employee: &Employee| Some(employee.index),
                ),
            ))
            .filter(|shift: &Shift, employee: &Employee| {
                !employee.skills.contains(&shift.required_skill)
            })
            .penalize(HardSoftDecimalScore::of_hard_scaled(1_000_000))
            .named("Required skill");
      <% end %>
    </div>
  </section>

  <section class="home-section">
    <p class="page-shell__eyebrow">Open source implementation</p>
    <h2>Solver core, app scaffolding, UI controls, and routing helpers you can inspect.</h2>
    <div class="card-grid">
      <%= render Ui::Card.new(title: "solverforge-cli", href: relative_url('/docs/solverforge-cli/'), icon: "fa-solid fa-terminal") do %>
Scaffold a neutral project shell, then grow the domain with generators.
      <% end %>
      <%= render Ui::Card.new(title: "solverforge-ui", href: relative_url('/docs/solverforge-ui/'), icon: "fa-solid fa-display") do %>
Ship scheduling views, retained-job controls, and embedded frontend assets.
      <% end %>
      <%= render Ui::Card.new(title: "solverforge-maps", href: relative_url('/docs/solverforge-maps/'), icon: "fa-solid fa-route") do %>
Model matrices, route geometry, and map-backed planning systems.
      <% end %>
      <%= render Ui::Card.new(title: "Core Solver", href: relative_url('/docs/solverforge/'), icon: "fa-brands fa-rust") do %>
Inspect the zero-erasure runtime, phases, moves, and score analysis tools.
      <% end %>
    </div>
  </section>

  <section class="home-section">
    <p class="page-shell__eyebrow">Use cases</p>
    <h2>Eight planning surfaces you can watch, inspect, and run.</h2>
    <p>
      Machine scheduling, warehouse picking, crew rotas, asset readiness, hospital
      coverage, school timetabling, delivery routing, and field service routing.
      Each case carries its data shape, its constraints, a narrated walkthrough of
      the running app, and annotated screenshots of the same retained solve.
    </p>
    <div class="card-grid">
      <% site.data.use_cases.each do |use_case| %>
        <% next if use_case["variant"] == "demoscene" %>
        <%= render Ui::Card.new(title: use_case["label"], href: relative_url("/use-cases/#{use_case["id"]}/"), eyebrow: use_case["teaser_metric"], icon: use_case["icon"]) do %>
<%= use_case["teaser_copy"] %>
        <% end %>
      <% end %>
    </div>
    <% product = site.data.use_cases.find { |use_case| use_case["variant"] == "demoscene" } %>
    <% if product %>
      <div class="home-demoscene" data-home-demoscene>
        <a class="home-demoscene__poster" href="<%= relative_url("/use-cases/#{product["id"]}/") %>" aria-label="Watch <%= product["label"] %> plan a week">
          <img src="<%= relative_url(product["runtime"]["poster"]) %>" alt="" width="1280" height="720" loading="lazy" />
          <span class="home-demoscene__play"><i class="fa-solid fa-play"></i> 1:47</span>
        </a>
        <div>
          <p class="page-shell__eyebrow">Built on SolverForge</p>
          <h3><%= product["label"] %>: a calendar that plans your week.</h3>
          <p><%= product["teaser_copy"] %> It runs in your terminal, keeps your events in a local file, and changes nothing until you approve the proposal.</p>
          <a class="button button--secondary" href="<%= relative_url("/use-cases/#{product["id"]}/") %>">
            Watch it plan a week <i class="fa-solid fa-play"></i>
          </a>
        </div>
      </div>
    <% end %>
    <div class="button-row">
      <a class="button button--primary" href="<%= relative_url '/use-cases/' %>">
        Compare every use case <i class="fa-solid fa-arrow-right"></i>
      </a>
    </div>
  </section>

  <section class="home-section home-section--split">
    <div>
      <p class="page-shell__eyebrow">Evaluate SolverForge</p>
      <h2>Everything you need to decide is public.</h2>
      <ul class="home-evaluate" data-home-evaluate>
        <li>
          <strong>Licence</strong>
          <span>The solver and the CLI are Apache-2.0: read the <a href="https://github.com/SolverForge/solverforge/blob/main/LICENSE" target="_blank" rel="noopener">solver licence</a> and the <a href="https://github.com/SolverForge/solverforge-cli/blob/main/LICENSE" target="_blank" rel="noopener">CLI licence</a>.</span>
        </li>
        <li>
          <strong>Self-serve</strong>
          <span><code>cargo install solverforge-cli</code> from <a href="https://crates.io/crates/solverforge-cli" target="_blank" rel="noopener">crates.io</a>, then the <a href="<%= relative_url '/docs/solverforge-cli/agent-skill/' %>">agent skill</a> from the CLI repository. No account or licence key.</span>
        </li>
        <li>
          <strong>Your problem shape</strong>
          <span>Facts, entities, scalar and list planning variables, and hard and soft constraints you write yourself, delivered as an API, web, CLI, or MCP app. See <a href="<%= relative_url '/docs/solverforge-cli/modeling-and-generation/' %>">Modeling &amp; Generation</a> and the <a href="<%= relative_url '/docs/getting-started/maintenance-planning-with-the-agent-skill/' %>">maintenance walkthrough</a>.</span>
        </li>
        <li>
          <strong>Track record</strong>
          <span>Eight worked <a href="<%= relative_url '/use-cases/' %>">use cases</a>, the <a href="<%= relative_url '/blog/' %>">release notes</a> for every line, and the full source on GitHub.</span>
        </li>
      </ul>
      <div class="button-row">
        <a class="button button--primary" href="<%= relative_url '/docs/overview/' %>">
          Project overview <i class="fa-solid fa-arrow-right"></i>
        </a>
        <a class="button button--secondary" href="https://github.com/SolverForge" target="_blank" rel="noopener">
          GitHub organization <i class="fa-solid fa-up-right-from-square"></i>
        </a>
      </div>
    </div>

    <div>
      <p class="page-shell__eyebrow">In practice</p>
      <div class="testimonial-slider" data-testimonial-slider>
        <div class="testimonial-slider__viewport" aria-live="polite">
          <figure class="testimonial-slider__slide is-active" data-testimonial-slide>
            <blockquote>"Working like a charm, A+"</blockquote>
            <figcaption><strong>Dr. Fawaz Halwani</strong>, Pathologist, The Ottawa Hospital</figcaption>
          </figure>
          <figure class="testimonial-slider__slide" data-testimonial-slide hidden>
            <blockquote>"High-level abstractions, zero-cost implementation. A masterclass in Rust architecture."</blockquote>
            <figcaption><strong>Prof. Benjamin Abel</strong>, Computer Science, Côte d'Azur University, Nice</figcaption>
          </figure>
        </div>
      </div>
      <%= render Ui::Card.new(title: "About SolverForge", href: relative_url('/about/'), icon: "fa-solid fa-circle-info") do %>
See the problems SolverForge is built for and how the open source work is maintained.
      <% end %>
    </div>
  </section>
</section>
