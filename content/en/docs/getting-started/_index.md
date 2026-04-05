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

## Quickstart

{{< cardpane >}} {{< card header="**Employee Scheduling**" >}} Build efficient
employee scheduling with SolverForge's native Rust constraint solver. Covers
domain modeling, constraint streams, `solver.toml`, and the current event-based
solve loop.

[Start Tutorial →](employee-scheduling-rust/) {{< /card >}} {{< /cardpane >}}

## Prerequisites

- **Rust toolchain**: Install via [rustup.rs](https://rustup.rs/) (stable
  channel)
- **Cargo**: Included with the Rust toolchain
- Familiarity with Rust basics (structs, traits, closures, derive macros)

## Fastest Path

```bash
cargo install solverforge-cli
solverforge new my-scheduler --standard
cd my-scheduler
solverforge server
```

The standalone CLI scaffolds the current `0.7.x` application shape, including a
runtime crate dependency, generated domain modules, and `solver.toml`.

Follow the [Employee Scheduling tutorial](employee-scheduling-rust/) for a
guided walkthrough of the runtime concepts behind that scaffold: planning
entities, constraint streams, and `SolverEvent`-based solving.

## Where to Read More

- [solverforge-cli repository](https://github.com/solverforge/solverforge-cli)
- [Quickstarts repository](https://github.com/solverforge/solverforge-quickstarts)
- [SolverForge API documentation](https://docs.rs/solverforge)
- [Core GitHub repository](https://github.com/solverforge/solverforge)
