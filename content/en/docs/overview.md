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

## Core Objective

To provide the Rust, Python and broader language ecosystems with a first-class, high-performance Constraint Programming and Optimization solver, offering a seamless experience and unlocking new possibilities for the ML, data science, and systems programming communities.

## Core Innovation: WASM + HTTP Bridge Architecture

Unlike traditional approaches that rely on complex JNI bridges or interpreter overhead, SolverForge eliminates these bottlenecks entirely through a novel architecture:

1. **WebAssembly-compiled constraints** - Constraint predicates are compiled to WASM and executed directly in the JVM via the Chicory WASM runtime
2. **HTTP/JSON communication** - Clean separation between language bindings and the solver service
3. **Native Rust core** - Language-agnostic core library with zero-cost abstractions
4. **No JNI complexity** - Pure HTTP interface eliminates the need for platform-specific native bindings

This architecture provides near-native performance while maintaining complete language independence.

## What We've Achieved

### ✅ Core Architecture (Completed - Q4 2025)

**Repository**: [solverforge/solverforge](https://github.com/solverforge/solverforge) (v0.1.56)

- **Complete Rust core library** (`solverforge-core`) - Language-agnostic foundation
  - Domain model definition with planning annotations (@PlanningEntity, @PlanningVariable, etc.)
  - Comprehensive constraint streams API (forEach, filter, join, groupBy, complement, flattenLast)
  - Advanced collectors (count, countDistinct, loadBalance)
  - Full score type system (Simple, HardSoft, HardMediumSoft, Bendable, BigDecimal variants)
  - Score analysis with constraint breakdown and indictments

- **WASM module generation** with proper memory alignment
  - Domain object layout with 32-bit and 64-bit type alignment
  - Field accessors (getters/setters)
  - Constraint predicates with complex logic (conditionals, arithmetic, range checking)
  - Primitive list operations (LocalDate[], LocalDateTime[], etc.)

- **Java service integration** (`timefold-wasm-service` submodule)
  - Chicory WASM runtime integration
  - Dynamic bytecode generation for domain classes and constraint providers
  - Host function provider for WASM-Java interop
  - HTTP endpoints for solving and score analysis

- **End-to-end integration tests**
  - Employee scheduling with 5 complex constraints
  - Temporal types (LocalDate, LocalDateTime) with proper alignment
  - Weighted penalties and custom weighers
  - Load balancing with fair distribution

## Roadmap Phases

### Phase 1: Foundation & Proof of Concept ✅ (Complete)

**Status**: Complete as of Q4 2025

**Achievements**:
- ✅ Core Rust library with language-agnostic types
- ✅ Complete constraint streams API
- ✅ WASM generation pipeline
- ✅ HTTP communication layer
- ✅ Java service integration
- ✅ Memory alignment correctness
- ✅ End-to-end solving with real constraint problems

### Phase 2: Performance Optimization & Python Bindings (Q1 2026 - Q2 2026)

**Objective**: Achieve production-grade performance and deliver Python bindings via PyO3

**Key Deliverables**:
- **Performance optimization**:
  - WASM module caching optimization for repeated solves
  - Export function lookup optimization
  - Incremental scoring with delta calculations
  - Join indexing for O(1) lookups 

- **Python bindings** (`solverforge-python`):
  - PyO3-based native extension module
  - Pythonic API matching Timefold Python conventions
  - Type hints and comprehensive documentation
  - PyPI package: `pip install solverforge`

- **Enhanced testing**:
  - Complete benchmark suite supporting all official Timefold quickstarts
  - Performance regression tests
  - Cross-language validation tests

### Phase 3: Production Readiness & Ecosystem Expansion (H2 2026)

**Objective**: Deliver production-ready solver with comprehensive ecosystem support

**Key Deliverables**:
- **Production release**: Stable v1.0.0 release
  - Comprehensive API documentation
  - Seamless migration from solverforge-legacy or Timefold Python
  - Performance tuning guide
  - Production deployment patterns

- **Language bindings expansion**:
  - 1:1 Timefold-compatible bindings in Python
  - Native Rust API for pure Rust applications

- **Advanced features**:
  - Custom move selectors
  - Real-time solving with event streaming
  - Multi-stage solving
  - Constraint configuration at runtime

- **ML/AI integration examples (?)**:
  - Predictive scheduling using ML forecasts
  - HuggingFace integration demos
  - Dockerized quickstarts for easy experimentation
  - Integration with popular Python data stack (pandas, numpy, polars)

## Technical Architecture
```
┌───────────────────────────────────────────────────────────────┐
│                       Language Bindings                       │
│                (Python, JavaScript, Rust, Go)                 │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│                   solverforge-core (Rust)                     │
│                                                               │
│  ┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐                │
│  │Domain │   │Constr-│   │ WASM  │   │ HTTP  │                │
│  │Model  │   │ aint  │   │Builder│   │Client │                │
│  │       │   │Stream │   │       │   │       │                │
│  └───────┘   └───────┘   └───────┘   └───────┘                │
└───────────────────────────────────────────────────────────────┘
                              │
                        HTTP/JSON + WASM
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│               timefold-wasm-service (Java)                    │
│                                                               │
│  ┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐                │
│  │Chicory│   │Dynamic│   │Timefld│   │  Host │                │
│  │ WASM  │   │Bytcde │   │Solver │   │  Func │                │
│  │Runtime│   │  Gen  │   │Engine │   │  tions│                │
│  └───────┘   └───────┘   └───────┘   └───────┘                │
└───────────────────────────────────────────────────────────────┘
```

## How You Can Contribute

This project thrives on community input. Here's how you can help:

1. **Test the core library**: Clone the repository and run the integration tests
   ```bash
   git clone https://github.com/solverforge/solverforge
   cd solverforge
   cargo test --workspace
   ```

2. **Benchmark your use cases**: We're collecting real-world constraint problems to ensure SolverForge works well for diverse scenarios

3. **Contribute to Python bindings**: We're starting work on PyO3 bindings - contributions welcome!

4. **Join the discussion**: Share your thoughts on this roadmap! What features are most critical for your use case?

5. **Spread the word**: Star the GitHub repository and share this project with anyone interested in constraint optimization

## Why SolverForge?

- **Language independence**: Write constraints in Python, Rust, JavaScript, or any language
- **No JNI complexity**: Clean HTTP/JSON interface eliminates platform-specific native code
- **Near-native performance**: WASM-compiled constraints with minimal overhead
- **Modern architecture**: Built for cloud-native deployment and microservices
- **Open source**: Apache 2.0 license, community-driven development
