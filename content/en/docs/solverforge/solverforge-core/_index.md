---
title: "SolverForge Core"
linkTitle: "Core Library"
weight: 10
tags: [rust]
description: "Complete reference documentation for the solverforge-core Rust library"
---

# SolverForge

SolverForge is a Rust library for solving constraint satisfaction and optimization problems. It bridges language bindings to the Timefold solver engine via WebAssembly and HTTP, eliminating JNI complexity.

## Key Features

- **Language-agnostic core**: Pure Rust library with planned bindings for Python, JavaScript, etc.
- **WASM-based constraints**: Constraint predicates compile to WebAssembly for portable execution
- **HTTP interface**: Clean JSON/HTTP communication with the Timefold solver service
- **Full constraint streams**: forEach, filter, join, groupBy, penalize, reward, and more

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Language Bindings                             │
│                 (Python, JavaScript, etc.)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   solverforge-core (Rust)                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐│
│  │  Domain    │  │ Constraint │  │   WASM     │  │   HTTP     ││
│  │  Model     │  │  Streams   │  │  Builder   │  │  Client    ││
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                         HTTP/JSON
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                timefold-wasm-service (Java)                      │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐│
│  │  Chicory   │  │  Dynamic   │  │  Timefold  │  │   Host     ││
│  │WASM Runtime│  │ Class Gen  │  │   Solver   │  │ Functions  ││
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Getting Started

For user-facing quickstarts, see the [Getting Started guides](/docs/getting-started/), including the [Rust Quickstart](/docs/getting-started/rust-quickstart/) which demonstrates using the core library directly.

## Documentation Sections

| Section | Description |
|---------|-------------|
| [Concepts](concepts/) | Architecture and core concepts |
| [Modeling](modeling/) | Define planning domains |
| [Constraints](constraints/) | Build constraint streams |
| [Solver](solver/) | Configure and run the solver |
| [WASM](wasm/) | Generate WASM predicates |
| [Reference](reference/) | API reference and error handling |

## Requirements

- **Rust**: 1.70+
- **Java**: 24+ (for the solver service)
- **Maven**: 3.9+ (for building the Java service)

## Current Status

SolverForge is in active development. The MVP supports:

- Domain model definition with planning annotations
- Constraint streams: forEach, filter, join, groupBy, complement, flattenLast, penalize, reward
- Score types: Simple, HardSoft, HardMediumSoft, Bendable (with Decimal variants)
- WASM module generation with proper memory alignment
- End-to-end solving via HTTP
