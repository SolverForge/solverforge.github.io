---
title: Overview
description: Roadmap, goals and how to get involved.
weight: 1
---

{{% pageinfo %}}

This page presents the SolverForge project overview and official development roadmap. It explains our objectives, the core engineering challenge, the staged plan to deliver a high-performance solver for Python and Rust, and how you can help.

{{% /pageinfo %}}

# Project Overview & Roadmap

SolverForge is a high-performance, 100% Timefold-compatible constraint solver focused on delivering a first-class developer experience for Python and Rust.

## Core objective

- Provide the Python and Rust ecosystems with a first-class, high-performance Constraint Programming and Optimization toolset
- Deliver a seamless developer experience and enable new workflows in ML, data science, and operations research

## Core challenge: the Python–Java bridge

Most JVM-backed Python tooling is limited by the interoperability layer between Python and Java. Our strategy is a ground-up rewrite of that layer in native Rust using `PyO3` and `JNI` so we can eliminate the bridge bottleneck and achieve near-native performance.

## Roadmap

We’re executing a three-phase plan to preserve continuity for current users while delivering a production-ready native solution.

### Phase 1 — Stabilize the legacy bridge (Present → Q4 2025)
Objective: Maintain continuity for existing Timefold users with a supported, debranded continuation of the old Python API.

Key deliverables:
- `solverforge-legacy` (released): a maintained fork of Timefold 1.24.0. Installable via `pip install solverforge-legacy`. Serves as a stable baseline for production users.
- `solverforge-quickstarts`: central repository of quickstarts and reproducible benchmarks.
Status: Complete — provides continuity for existing projects.

### Phase 2 — Alpha: native Rust solver (Q4 2025 → Q1 2026)
Objective: Ship an alpha release with a native Rust backend that removes the Python→Java bridge overhead.

Key deliverables:
- `solverforge-solver`: a ground-up rewrite in Rust using `PyO3` and direct `JNI` integration with the Timefold JVM core.
- Full API compatibility with the discontinued Timefold Python API (API surface parity).
- Lambda support:
  - Simple lambdas: translated to Java bytecode for native performance.
  - Complex lambdas: efficient proxy fallbacks to preserve Python semantics and feature parity.
- Performance target: within ~0.5% overhead of pure Java.
Status: Active development — core infrastructure implemented and functional.

### Phase 3 — Production release & ecosystem expansion (H1 2026 → Q3 2026)
Objective: Harden the Rust solver for production, publish stable packages, deepen documentation, and expand integrations into the ML ecosystem.

Key deliverables:
- Production PyPI package: `blackops` (expected `pip install blackops`).
- Full documentation: installation, migration notes from Timefold, and advanced usage patterns.
- Advanced quickstarts: predictive and ML-integrated scheduling examples (e.g., simple regressors to forecast demand).
- Native Rust API: a first-class Rust client for pure Rust applications.
- Near-zero-overhead `PyO3` Python API.
- HuggingFace engagement: Dockerized quickstarts and example models to attract ML practitioners.

## How you can contribute

This project thrives on community involvement. You can help in several ways:

- Test & benchmark: try `solverforge-legacy` and run examples from `solverforge-quickstarts`. Report issues, share performance numbers, and attach reproducible benchmarks.
- Join the discussion: tell us which features, integrations, or APIs matter most for your workflows.
- Contribute code: PRs, bug fixes, and documentation improvements are welcome.
- Spread the word: star the repositories and share the project with colleagues in scheduling, optimization, and ML.

## Where to go next

- Quickstart guides: see the project’s quickstart guides in the docs.
- Examples & quickstarts: explore `solverforge-quickstarts` for reproducible examples and benchmarks.
