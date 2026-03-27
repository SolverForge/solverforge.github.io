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
domain modeling, constraint streams, and a complete web application.

[Start Tutorial →](employee-scheduling-rust/) {{< /card >}} {{< /cardpane >}}

## Prerequisites

- **Rust toolchain**: Install via [rustup.rs](https://rustup.rs/) (stable
  channel)
- **Cargo**: Included with the Rust toolchain
- Familiarity with Rust basics (structs, traits, closures, derive macros)

## Getting the Code

```bash
git clone https://github.com/SolverForge/solverforge-quickstarts
cd solverforge-quickstarts/rust/employee-scheduling
cargo build --release
cargo run --release
```

This is the current runnable onboarding path while the scaffolded app workflow
is still evolving. Follow the
[Employee Scheduling tutorial](employee-scheduling-rust/) to understand the
domain model, constraints, and web UI implementation.

## Where to Read More

- [Quickstarts repository](https://github.com/solverforge/solverforge-quickstarts)
- [SolverForge API documentation](https://docs.rs/solverforge)
- [Core GitHub repository](https://github.com/solverforge/solverforge)
