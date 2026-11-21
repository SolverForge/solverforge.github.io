---
title: "SolverForge Workbench"
linkTitle: "SolverForge Workbench"
icon: fa-solid fa-flask
weight: 25
description: >
  A Hermes Agent plugin that runs four stock planning models, and the models
  you build with solverforge-cli, on your own machine: datasets, profiles,
  background solves, explanations, replanning and experiments.
---

<%= render Ui::Callout.new do %>
This section describes SolverForge Workbench with engine
`<%= site.data.workbench["engine_version"] %>`, the engine the plugin installs.
The source is [blackopsrepl/hermes-solverforge-workbench](https://github.com/blackopsrepl/hermes-solverforge-workbench).
<% end %>

SolverForge Workbench turns [Hermes Agent](https://github.com/NousResearch/hermes-agent)
into a planning workbench. You pick a model, load a dataset, set what matters
with constraint weights, solve in the background, and read which rule cost
what and why. Everything runs on your machine: the engine is one Rust program
built on the published `solverforge` crate, and every score, match and measure
comes from it.

## Install

You need Hermes Agent 0.22.2 or newer.

```sh
hermes plugins install blackopsrepl/hermes-solverforge-workbench --enable
hermes solverforge-workbench install
```

The second command downloads the engine for your platform (Linux x86_64 and
arm64, macOS on Apple silicon and Intel, Windows x86_64) and checks it against
the SHA-256 pinned in the plugin. Run `hermes chat -q hi` once afterwards so the
next session lists the plugin's tools. In Hermes Desktop, turn on the plugin's
Desktop features under **Capabilities → Plugins**; **SolverForge Workbench** then
appears in the sidebar.

## The four stock models

<%= render Workbench::Models.new(site: site) %>

Each model page explains what the model plans, lists every constraint by group
with what it costs, and documents every table and field of its datasets:

- [Employee scheduling](/docs/solverforge-workbench/employee-scheduling/)
- [Task scheduling](/docs/solverforge-workbench/task-scheduling/)
- [Pick-up and delivery routing](/docs/solverforge-workbench/pickup-delivery-routing/)
- [Field service routing](/docs/solverforge-workbench/field-service-routing/)

The [constraint explorer](/docs/solverforge-workbench/constraints/) searches all
<%= site.data.workbench["models"].sum { |m| m["constraints"].size } %>
constraints at once, with the same fuzzy match as the Workbench's own lists:
`rst btwn` finds *Rest between shifts*.

## How a plan is scored

A score has three levels, written `hard/medium/soft`; closer to zero is better.

- **Hard** rules must hold. A plan that breaks any is infeasible.
- **Medium** counts work left undone, such as a mandatory visit nobody serves.
  It decides between plans only after every hard rule holds.
- **Soft** rules weigh preferences and costs: travel, overtime, preferred
  employees, fairness.

Each constraint states its level and what one violation costs, in the unit
the description names (seconds, minutes, one hour per unit, the task's
priority). A **weight** multiplies that cost: 1 is as designed, 0 switches the
constraint off, 10 makes it ten times as important. A few constraints are off
unless a profile or dataset weighs them; the model pages and the explorer mark
them.

## The workflow

- **Datasets.** A dataset is one JSON document in the model's format. Every
  model's demo is ready as a dataset; add yours from a file or from JSON in the
  chat. A change makes a new dataset that remembers its parent. The Desktop
  opens each table in a grid with a typed editor for every field the model
  reads.
- **Profiles.** Constraint weights, model parameters and solve settings (time
  limit, stop after no improvement, step limits, target score) saved under a
  name. Every model has a read-only Standard profile. Settings apply in a fixed
  order, later winning: model defaults, parent dataset, profile, one-off
  overrides, the dataset's own settings.
- **Solving.** Solves run in a background worker, keep going after the chat
  turn ends and queue by priority. Stopping a solve keeps the best plan found.
  A dataset with errors is refused with each error named.
- **Explaining.** Per constraint, its score and the matches that caused it;
  per record, every match involving an employee, a shift, a task or a visit.
- **Filling.** For an item left unplanned, the best places it could still go,
  each with what it changes per level, applied as a new dataset.
- **Replanning.** Start from a solved plan, apply a change (an employee off,
  a new visit, a moved window), pin what must stay and keep everything that has
  already started.
- **Comparing.** Runs side by side: score, every constraint, the measures,
  profile and solve time. Experiments solve every dataset under every profile
  and rank the profiles; trends chart a model's solves over time.

## Routing on real roads

Pick-up and delivery routing and field service routing measure travel along
the OpenStreetMap road network with
[solverforge-maps](/docs/solverforge-maps/), at each road's own speed. A
dataset's area is fetched once and kept; a demo's network ships with the
engine release. A dataset may bring its own travel matrix instead.

- **Busy periods** make travel depend on the hour: a period names its hours,
  its days and the roads it slows by a factor (chosen road classes, anywhere or
  inside an area). A leg that runs into a busy period slows from that moment,
  so leaving later never arrives earlier.
- **Travel modes**: a technician or driver can go by bicycle or on foot, on
  that mode's own paths and speed.
- **Driving rests**: after so long at the wheel, a driver rests for a set time
  before going on; a break or a wait at least as long counts as the rest.

## Your own models

A project made with [solverforge-cli](/docs/solverforge-cli/) becomes a model
beside the stock ones: ask Hermes to register it, and the Workbench builds its
engine with cargo and gives it datasets, profiles, solves, analysis, fill,
experiments and trends. Constraint descriptions come from the doc comment on
each constraint, and weights from a `#[constraint_weights]` field on the plan.

## What it runs and stores

- One engine process per solve, reading one JSON request and writing JSON
  lines. It starts with only the environment a process needs.
- The scheduling models make no network calls. A routing dataset sends its
  area's bounding box to the Overpass API once; the places themselves are
  routed on your machine.
- Everything lives in one folder, `<hermes home>/plugin-data/solverforge-workbench/`:
  the SQLite database, the engine and custom model builds. Deleting a dataset,
  profile or experiment from the chat asks you first, every time.
