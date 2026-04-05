---
title: Getting Started
linkTitle: 'Getting Started'
description:
  Quickstart guides for building constraint solving applications with
  SolverForge.
categories: [Quickstarts]
tags: [quickstart]
weight: 2
---

## Official starting point

Start with the Employee Scheduling tutorial for the most stable, fully
explained introduction to SolverForge.

{{< cardpane >}} {{< card header="**Employee Scheduling**" >}} Build efficient
employee scheduling with SolverForge's native Rust constraint solver. Covers
domain modeling, constraint streams, `solver.toml`, and the current event-based
solve loop.

[Start Tutorial →](employee-scheduling-rust/) {{< /card >}} {{< /cardpane >}}

The archived quickstarts repository remains the standard reference surface for
worked examples while the standalone CLI rollout is still in progress.

## Preview: `solverforge-cli`

If you want to explore the newer scaffolding workflow, `solverforge-cli` is
available in public preview.

```bash
cargo install solverforge-cli
solverforge new my-scheduler --standard
cd my-scheduler
solverforge server
```

`solverforge-cli` reflects the direction of SolverForge onboarding, but it is
still evolving and has not yet had its formal standalone release announcement.

## Prerequisites

- **Rust toolchain**: Install via [rustup.rs](https://rustup.rs/) (stable
  channel)
- **Cargo**: Included with the Rust toolchain
- Familiarity with Rust basics (structs, traits, closures, derive macros)

## Where to Read More

- [Employee Scheduling tutorial](employee-scheduling-rust/)
- [Quickstarts repository](https://github.com/solverforge/solverforge-quickstarts)
- [solverforge-cli repository](https://github.com/solverforge/solverforge-cli)
- [SolverForge API documentation](https://docs.rs/solverforge)
- [Core GitHub repository](https://github.com/solverforge/solverforge)
