---
title: Getting Started
linkTitle: "Getting Started"
description: Quickstart Guides — repository layout, prerequisites, and how to run examples locally.
categories: [Quickstarts]
tags: [quickstart, python]
weight: 2
---

{{% pageinfo color="warning" %}}
**🚧 Work in Progress**

SolverForge is under active development. User-facing language bindings (Python, JavaScript, etc.) are not yet available.

If you want to try SolverForge today, you'll need to write your own language bindings against the [SolverForge Core](../solverforge/) library. **This is not recommended for production use** — or even casual experimentation unless you're comfortable with low-level integration work.

We're working hard to deliver proper bindings. Stay tuned!
{{% /pageinfo %}}

The quickstart guides below demonstrate constraint-solver patterns using the legacy Python implementation. They serve as reference material for understanding SolverForge concepts while the new bindings are being developed.

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

- `legacy/` — Original quickstarts that use unified Pydantic models. Great for learning and understanding the domain modelling approach.
- `fast/` — Refactored quickstarts that minimize runtime overhead by constraining Pydantic to the API boundary and using lighter-weight models during solver moves.
- `benchmarks/` — Benchmarks, results and a short performance report comparing implementations and use cases.

Common fast quickstarts available now:
- `fast/meeting-scheduling-fast`
- `fast/vehicle-routing-fast`
- `fast/employee-scheduling-fast`
- `fast/portfolio-optimization-fast`
- `fast/vm-placement-fast`

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
1. Open the quickstart folder of interest (for example `fast/meeting-scheduling-fast`).
2. Follow the run instructions in that folder's README. Common commands are:
   - `python -m <module>` or `uvicorn` for FastAPI-based examples.
   - `python run_demo.py` or similar CLI entrypoints described in the README.

Check these README files for concrete run commands:
- `legacy/vehicle-routing/README.MD`
- `fast/vehicle-routing-fast/README.MD`
- `fast/meeting-scheduling-fast/README.adoc`
- `fast/employee-scheduling-fast/README.MD`

## Benchmarks & performance

Performance-focused work and benchmark artifacts live in the `benchmarks/` folder:
- `benchmarks/results_meeting-scheduling.md`
- `benchmarks/results_vehicle-routing.md`
- `benchmarks/report.md`

The `fast/` refactors prioritise reducing runtime overhead (limiting Pydantic to the API boundary, using compact domain models, etc.) to close the performance gap with Java/Kotlin implementations.

## Where to read more

- Start at the repository top-level README for an overview and the full use-case list.
- Read the individual quickstart READMEs for run instructions, configuration and design notes.
- Consult `benchmarks/` for performance comparisons and technical rationale.

## Legal note

This repository derives from prior quickstarts and carries permissive licensing details documented in the top-level README and LICENSE files. Refer to those files for full copyright and licensing information.
