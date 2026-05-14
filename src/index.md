---
title: SolverForge
layout: default
page_class: page-home
description: Build inspectable planning, scheduling, routing, and allocation software in Rust.
---

<section class="home-shell">
  <section class="home-hero">
    <p class="page-shell__eyebrow">Planning software in Rust</p>
    <h1>Build planning systems your team can inspect, control, and run.</h1>
    <p class="home-hero__summary">
      SolverForge helps teams turn scheduling, routing, allocation, and dispatch rules into production software. Domain models, constraints, and runtime control stay in ordinary Rust code, so the behavior remains explicit from the first prototype to the running system.
    </p>

    <div class="home-actions">
      <a class="button button--primary" href="<%= relative_url '/docs/solverforge-cli/getting-started/' %>">
        Start with solverforge-cli <i class="fa-solid fa-arrow-right"></i>
      </a>
      <a class="button button--secondary" href="<%= relative_url '/docs/getting-started/' %>">
        Browse the Use Cases <i class="fa-solid fa-book-open"></i>
      </a>
    </div>

    <div class="home-proof">
      <span>Runnable app scaffold</span>
      <span>Readable domain constraints</span>
      <span>Hospital, lessons, delivery, and FSR examples</span>
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

  <section class="home-section home-section--split">
    <div>
      <p class="page-shell__eyebrow">Proof before a call</p>
      <h2>Review the docs, code, releases, and examples before trusting the work.</h2>
      <p>
        The documentation shows the operating model, the source shows implementation quality, the examples show behavior, and the release notes show active maintenance. You do not have to wait for a sales conversation to understand how SolverForge works.
      </p>
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
