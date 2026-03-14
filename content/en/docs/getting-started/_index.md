---
title: Getting Started
linkTitle: "Getting Started"
description: Quickstart guides for building constraint solving applications with SolverForge.
categories: [Quickstarts]
tags: [quickstart]
weight: 2
---

## Quickstart

{{< cardpane >}}
{{< card header="**Employee Scheduling**" >}}
Build efficient employee scheduling with SolverForge's native Rust constraint solver. Covers domain modeling, constraint streams, and a complete web application.

[Start Tutorial →](employee-scheduling-rust/)
{{< /card >}}
{{< /cardpane >}}

## Prerequisites

- **Rust toolchain**: Install via [rustup.rs](https://rustup.rs/) (stable channel)
- **Cargo**: Included with the Rust toolchain
- Familiarity with Rust basics (structs, traits, closures, derive macros)

## Getting the Code

```bash
git clone https://github.com/SolverForge/solverforge-quickstarts
cd solverforge-quickstarts/rust/employee-scheduling
cargo build --release
cargo run --release
```

Open `http://localhost:7860` in your browser to see the scheduling UI.

## Where to Read More

- [SolverForge API documentation](https://docs.rs/solverforge)
- [GitHub repository](https://github.com/solverforge/solverforge)
