---
title: "SolverForge"
linkTitle: "Rust Solver"
icon: fa-brands fa-rust
weight: 3
tags: [rust]
description: "Rust-based constraint solver library using WASM modules and HTTP communication"
---

SolverForge is a Rust library for solving constraint satisfaction and optimization problems. It bridges language bindings to the Timefold solver engine via WebAssembly and HTTP, eliminating JNI complexity.

{{% pageinfo color="warning" %}}
**🚧 Language Bindings In Progress**

User-facing APIs (Python, JavaScript, etc.) are under active development. The documentation below covers the **core Rust library**, which is intended for developers creating new language bindings — not for end users.

If you want to experiment with SolverForge today, you can use the core library directly from Rust. This is **not recommended for production use** and the API may change without notice.
{{% /pageinfo %}}

## Key Features

- **Language-agnostic core**: Pure Rust library with planned bindings for Python, JavaScript, etc.
- **WASM-based constraints**: Constraint predicates compile to WebAssembly for portable execution
- **HTTP interface**: Clean JSON/HTTP communication with the Timefold solver service
- **Full constraint streams**: forEach, filter, join, groupBy, penalize, reward, and more

## Getting Started

- [Installation](installation/) - Add SolverForge to your Rust project
- [Rust Quickstart](/docs/getting-started/rust-quickstart/) - Build your first constraint solver (in Getting Started section)

## Documentation

- [SolverForge Core](solverforge-core/) - Complete library reference (for binding developers)
