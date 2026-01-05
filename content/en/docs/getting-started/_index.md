---
title: Getting Started
linkTitle: "Getting Started"
description: Quickstart Guides — repository layout, prerequisites, and how to run examples locally.
categories: [Quickstarts]
tags: [quickstart, python]
weight: 2
---

{{% pageinfo color="warning" %}}
**Legacy Implementation Guides**

These quickstart guides use **solverforge-legacy**, a fork of Timefold 1.24 that bridges Python to Java via JPype. This legacy implementation is **already archived** and will no longer be maintained once SolverForge's native Python bindings are production-ready.

**SolverForge has been completely rewritten as a native constraint solver in Rust**, with its own solving engine built from scratch. These guides are preserved as:
- Reference material for understanding constraint solving concepts
- Educational examples of constraint modeling patterns
- Demonstration of optimization problem domains

The JPype bridge and Timefold-based architecture described in these guides **do not apply to current SolverForge**.

Native Python bindings for the Rust implementation are under active development.
{{% /pageinfo %}}

## Choose a Quickstart

{{< cardpane >}}
{{< card header="**Employee Scheduling**" >}}
Assign staff to shifts based on skills and availability.
Perfect for learning core optimization concepts.

[Start Tutorial →](employee-scheduling/)
{{< /card >}}
{{< card header="**Meeting Scheduling**" >}}
Find optimal times and rooms for meetings while avoiding conflicts.

[Start Tutorial →](meeting-scheduling/)
{{< /card >}}
{{< card header="**Vehicle Routing**" >}}
Plan delivery routes that minimize travel time with capacity constraints.

[Start Tutorial →](vehicle-routing/)
{{< /card >}}
{{< /cardpane >}}

{{< cardpane >}}
{{< card header="**School Timetabling**" >}}
Schedule lessons to rooms and timeslots without teacher or room conflicts.

[Start Tutorial →](school-timetabling/)
{{< /card >}}
{{< card header="**Portfolio Optimization**" >}}
Select stocks for a diversified portfolio while maximizing expected returns.

[Start Tutorial →](portfolio-optimization/)
{{< /card >}}
{{< card header="**VM Placement**" >}}
Place virtual machines on servers respecting capacity, affinity, and consolidation goals.

[Start Tutorial →](vm-placement/)
{{< /card >}}
{{< /cardpane >}}

{{< cardpane >}}
{{< card header="**Rust Quickstart**" footer="Experimental" >}}
Build a solver using the core Rust library directly. For advanced users interested in the internals.

[Start Tutorial →](rust-quickstart/)
{{< /card >}}
{{< /cardpane >}}

---

This page covers:
- Repository layout and quickstart variants
- Prerequisites and installation notes
- How to run an example locally
- Where to find benchmarks, technical notes and individual quickstart READMEs

## Repository layout

The repository is organised so you can choose between pedagogical, reference implementations and optimized, performance-minded variants:

- `legacy/` — Refactored quickstarts that minimize runtime overhead by constraining Pydantic to the API boundary and using lighter-weight models during solver moves.
- `benchmarks/` — Benchmarks, results and a short performance report comparing implementations and use cases.

Common quickstarts available now:
- `legacy/meeting-scheduling-fast`
- `legacy/vehicle-routing-fast`
- `legacy/employee-scheduling-fast`
- `legacy/portfolio-optimization-fast`
- `legacy/vm-placement-fast`

Each use case folder includes a README describing how to run the example, expected inputs, and any implementation-specific details.

## Prerequisites

Typical requirements (may vary per quickstart):
- Python 3.8+ (use a virtual environment)
- pip to install dependencies
- Optional: Docker if you prefer containerised execution

Some examples expose a small FastAPI UI or HTTP API and will list FastAPI and related packages in their `requirements.txt` or `pyproject.toml`.

## Installation

1. Clone or download the SolverForge quickstarts repository.

2. Create and activate a virtual environment:
   - Unix/macOS:
     - `python -m venv .venv`
     - `source .venv/bin/activate`
   - Windows:
     - `python -m venv .venv`
     - `.\\.venv\\Scripts\\activate`

3. Install dependencies from the chosen quickstart directory:
   - `pip install -r requirements.txt`
   - Or follow the quickstart's `pyproject.toml` instructions if provided.

Each quickstart README documents any extra dependencies or optional tooling.

## Setup

- Inspect the quickstart folder for example data, configuration files, and environment variables.
- If the quickstart includes Docker assets, follow the README for Docker or docker-compose instructions.
- Confirm any required ports or external resources before starting the example.

## Try it out!

Most quickstarts offer one or both run modes:
- A minimal FastAPI service that serves a tiny UI and HTTP endpoints.
- A CLI script that runs the solver on example data and outputs results.

To try a quick example:
1. Open the quickstart folder of interest (for example `legacy/meeting-scheduling-fast`).
2. Follow the run instructions in that folder's README. Common commands are:
   - `python -m <module>` or `uvicorn` for FastAPI-based examples.
   - `python run_demo.py` or similar CLI entrypoints described in the README.

Check these README files for concrete run commands:
- `legacy/vehicle-routing/README.MD`
- `legacy/vehicle-routing-fast/README.MD`
- `legacy/meeting-scheduling-fast/README.adoc`
- `legacy/employee-scheduling-fast/README.MD`

## Benchmarks & performance

Performance-focused work and benchmark artifacts live in the `benchmarks/` folder:
- `benchmarks/results_meeting-scheduling.md`
- `benchmarks/results_vehicle-routing.md`
- `benchmarks/report.md`

## Where to read more

- Start at the repository top-level README for an overview and the full use-case list.
- Read the individual quickstart READMEs for run instructions, configuration and design notes.
- Consult `benchmarks/` for performance comparisons and technical rationale.

## Legal note

This repository derives from prior quickstarts and carries permissive licensing details documented in the top-level README and LICENSE files. Refer to those files for full copyright and licensing information.
