---
title: "Architecture"
linkTitle: "Architecture"
weight: 10
description: "How SolverForge uses WASM and HTTP to solve constraints"
---

# Architecture

SolverForge uses a layered architecture that separates constraint definition (Rust) from solving execution (Java/Timefold).

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Your Application (Rust)                       │
│  • Define domain model                                          │
│  • Build constraints                                            │
│  • Generate WASM predicates                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                         HTTP/JSON
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               timefold-wasm-service (Java)                       │
│  • Execute WASM predicates via Chicory runtime                  │
│  • Run Timefold solver algorithms                               │
│  • Return optimized solution                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Why This Architecture?

### WASM for Portability

Constraint predicates are compiled to WebAssembly, which:

- Runs safely in a sandboxed environment
- Executes at near-native speed
- Works across different language runtimes

### HTTP for Simplicity

Using HTTP/JSON instead of JNI provides:

- Clean separation between Rust and Java
- Easy debugging (inspect JSON requests/responses)
- Language-agnostic interface for future bindings

## Components

### solverforge-core (Rust)

The core library provides:

| Module | Purpose |
|--------|---------|
| `domain` | Define planning entities and fields |
| `constraints` | Build constraint streams |
| `wasm` | Generate WASM modules |
| `solver` | Configure solver and send requests |
| `score` | Score types (HardSoft, Bendable, etc.) |

### timefold-wasm-service (Java)

The solver service handles:

| Component | Purpose |
|-----------|---------|
| Chicory WASM Runtime | Execute constraint predicates |
| Dynamic Class Generation | Create Java classes from domain DTOs |
| Timefold Solver | Run optimization algorithms |
| Host Functions | Bridge WASM calls to Java operations |

## Request Flow

```
1. Build Domain Model      → DomainModel with annotations
2. Create Constraints      → Constraint streams (forEach, filter, penalize)
3. Generate WASM           → Predicates compiled to WebAssembly
4. Build SolveRequest      → JSON payload with domain + constraints + WASM + problem
5. Send HTTP POST          → /solve endpoint
6. Solver Executes         → Timefold evaluates constraints via WASM
7. Return Solution         → JSON response with score and assignments
```

## WASM Memory Layout

Domain objects are stored in WASM linear memory with proper alignment:

| Type | Alignment | Size |
|------|-----------|------|
| int, float, pointer | 4 bytes | 4 bytes |
| long, double, DateTime | 8 bytes | 8 bytes |

Example `Shift` layout:

```
Field            Offset  Size  Type
───────────────────────────────────
id               0       4     String (pointer)
employee         4       4     Employee (pointer)
location         8       4     String (pointer)
[padding]        12      4     (align for DateTime)
start            16      8     LocalDateTime
end              24      8     LocalDateTime
requiredSkill    32      4     String (pointer)
───────────────────────────────────
Total: 40 bytes
```

Both Rust (WASM generation) and Java (runtime) use identical alignment rules.

## Host Functions

WASM predicates can call host functions for operations that require Java:

| Function | Purpose |
|----------|---------|
| `string_equals` | Compare two strings |
| `list_contains` | Check if list contains element |
| `ranges_overlap` | Check if time ranges overlap |
| `hround` | Round float to integer |

These are injected into the WASM module via `HostFunctionRegistry`.
