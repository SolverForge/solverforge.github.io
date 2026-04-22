---
title: SolverForge
layout: default
page_class: page-home
description: Native Rust constraint solving for planning, scheduling, routing, and allocation software.
---

<section class="home-shell">
  <section class="home-hero">
    <p class="page-shell__eyebrow">Rust-native optimization infrastructure</p>
    <h1>Build planning software without switching to a solver language.</h1>
    <p class="home-hero__summary">
      SolverForge keeps domain models, constraints, runtime control, and static documentation in one inspectable codebase. You write the business rules in Rust, the solver stays zero-erasure all the way down, and the docs remain readable both on disk and on the web.
    </p>

    <div class="home-actions">
      <a class="button button--primary" href="<%= relative_url '/docs/solverforge-cli/getting-started/' %>">
        Start with solverforge-cli <i class="fa-solid fa-arrow-right"></i>
      </a>
      <a class="button button--secondary" href="<%= relative_url '/docs/getting-started/employee-scheduling-rust/' %>">
        See the employee scheduling tutorial <i class="fa-solid fa-book-open"></i>
      </a>
    </div>

    <div class="home-proof">
      <span>Neutral app shell from the CLI</span>
      <span>Incremental domain generation after scaffolding</span>
      <span>Step-by-step employee scheduling tutorial</span>
    </div>
  </section>

  <section class="home-section home-section--split">
    <div>
      <p class="page-shell__eyebrow">Constraint code</p>
      <h2>Readable rules, explicit tradeoffs, real application shapes.</h2>
      <p>
        Model shifts, routes, tasks, workers, vehicles, and inventories as ordinary application code. SolverForge keeps the runtime concrete and inspectable while Bridgetown turns the same repository into a polished documentation site.
      </p>
      <div class="card-grid">
        <%= render Ui::Card.new(title: "Getting Started", href: relative_url('/docs/getting-started/'), icon: "fa-solid fa-rocket") do %>
Follow the CLI-first path and the longer employee scheduling walkthrough.
        <% end %>
        <%= render Ui::Card.new(title: "Reference", href: relative_url('/reference/'), icon: "fa-solid fa-book") do %>
Open the engineering handbooks, crate maps, extension playbooks, and clearly labeled maintainer notes.
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
        let required_skill = factory
            .shifts()
            .join((
                |s: &Schedule| &s.employees,
                equal_bi(
                    |shift: &Shift| shift.employee,
                    |emp: &Employee| Some(emp.id),
                ),
            ))
            .filter(|shift: &Shift, emp: &Employee| {
                !emp.skills.contains(&shift.required_skill)
            })
            .penalize_hard()
            .named("Required skill");
      <% end %>
    </div>
  </section>

  <section class="home-section">
    <p class="page-shell__eyebrow">Ecosystem</p>
    <h2>Solver core, UI primitives, routing helpers, and reference docs in one surface.</h2>
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
Inspect the zero-erasure runtime surface, phases, moves, and score analysis tools.
      <% end %>
    </div>
  </section>

  <section class="home-section home-section--split">
    <div>
      <p class="page-shell__eyebrow">Public docs and code</p>
      <h2>Everything important is visible.</h2>
      <p>
        The docs, APIs, tutorials, and source are public, so teams can inspect SolverForge directly before deciding whether it fits their system.
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
      <div class="ui-callout ui-callout--success">
        <p class="ui-callout__title">Operator feedback</p>
        <p>I have incorporated SolverForge in my new Rust application for staff scheduling and it's working like a charm, A+</p>
        <p><strong>Fawaz Halwani</strong>, Pathologist, The Ottawa Hospital</p>
      </div>
      <%= render Ui::Card.new(title: "About SolverForge", href: relative_url('/about/'), icon: "fa-solid fa-circle-info") do %>
Read the project framing, companion libraries, and common operational problem spaces.
      <% end %>
    </div>
  </section>
</section>
