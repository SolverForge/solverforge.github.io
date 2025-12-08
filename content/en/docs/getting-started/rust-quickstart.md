---
title: "Rust Quickstart"
linkTitle: "Rust Quickstart"
icon: fa-brands fa-rust
date: 2025-12-08
weight: 100
description: "Build your first constraint solver with the SolverForge Rust core library"
categories: [Quickstarts]
tags: [quickstart, rust]
---

{{% pageinfo color="warning" %}}
**🚧 Experimental — For Adventurous Developers**

This quickstart uses the **SolverForge core Rust library** directly. This is the foundation layer intended for building language bindings, not for end-user applications.

**Why try it anyway?**
- You want to understand how SolverForge works under the hood
- You're interested in contributing to language bindings
- You enjoy working with cutting-edge, experimental software

**What to expect:**
- The API may change without notice
- Documentation is sparse in places
- You'll be working at a lower abstraction level than the Python guides

**Not recommended for:** Production use, casual experimentation, or if you prefer stable APIs.
{{% /pageinfo %}}

---

## Table of Contents

1. [Introduction](#introduction)
2. [What We've Built So Far](#what-weve-built-so-far)
3. [Prerequisites](#prerequisites)
4. [Getting Started](#getting-started)
5. [The Problem We're Solving](#the-problem-were-solving)
6. [Step 1: Define the Domain Model](#step-1-define-the-domain-model)
7. [Step 2: Create Constraints](#step-2-create-constraints)
8. [Step 3: Build WASM Predicates](#step-3-build-wasm-predicates)
9. [Step 4: Run the Solver](#step-4-run-the-solver)
10. [Understanding the Architecture](#understanding-the-architecture)
11. [What's Next](#whats-next)

---

## Introduction

### What You'll Learn

This guide walks you through building a complete employee scheduling solver using the **SolverForge Rust core library**. You'll learn:

- How SolverForge's WASM-based architecture works
- How to define domain models programmatically in Rust
- How to express constraints using the constraint streams API
- How to compile constraint predicates to WebAssembly
- How the solver service executes your constraints

**Rust experience required** — this guide assumes familiarity with Rust, Cargo, and systems programming concepts.

### How This Differs from Python Guides

The Python quickstarts use decorators and type annotations for a clean, declarative experience:

```python
@planning_entity
@dataclass
class Shift:
    employee: Annotated[Employee | None, PlanningVariable] = None
```

In Rust, you build the same structures programmatically:

```rust
DomainClass::new("Shift")
    .with_annotation(PlanningAnnotation::PlanningEntity)
    .with_field(
        FieldDescriptor::new("employee", FieldType::object("Employee"))
            .with_planning_annotation(PlanningAnnotation::planning_variable(...))
    )
```

This is more verbose but gives you complete control — and it's exactly how language bindings will generate these structures under the hood.

---

## What We've Built So Far

Before diving in, here's what the SolverForge project has accomplished:

### ✅ Complete Core Library (v0.1.56)

- **Domain model definition** with all planning annotations
- **Constraint streams API**: forEach, filter, join, groupBy, complement, flattenLast
- **Advanced collectors**: count, countDistinct, loadBalance
- **Score types**: Simple, HardSoft, HardMediumSoft, Bendable (with BigDecimal variants)
- **WASM module generation** with proper memory alignment

### ✅ Java Solver Service

- **Chicory WASM runtime** integration for executing constraint predicates
- **Dynamic bytecode generation** for domain classes
- **HTTP/JSON interface** for language-agnostic communication
- **Host functions** for WASM-Java interop

### ✅ End-to-End Integration

- Employee scheduling with 5+ complex constraints
- Temporal types (LocalDate, LocalDateTime)
- Load balancing with fair distribution
- Comprehensive test suite

**What's missing:** User-friendly language bindings. That's what Phase 2 (Q1-Q2 2026) will deliver.

---

## Prerequisites

### Required Software

- **Rust** 1.70+ (`rustc --version`)
- **Java** 24+ (`java -version`)
- **Maven** 3.9+ (`mvn -version`)
- **Git** for cloning the repository

### Clone the Repository

```bash
git clone https://github.com/SolverForge/solverforge
cd solverforge
```

### Build Everything

```bash
# Build the Rust library
cargo build --workspace

# Build the Java solver service (this may take a few minutes)
cd reference/timefold-wasm-service
mvn package -DskipTests
cd ../..
```

### Verify the Setup

```bash
# Run the integration tests
cargo test --workspace
```

If tests pass, you're ready to go!

---

## The Problem We're Solving

We'll build the same employee scheduling problem as the Python guides:

**Assign employees to shifts while satisfying:**

**Hard constraints** (must be satisfied):
- Employee must have the required skill for the shift

**Soft constraints** (preferences to optimize):
- Balance shift assignments fairly across employees

This is a simplified version — the full test suite includes more constraints like rest periods, availability, and overlapping shift prevention.

---

## Step 1: Define the Domain Model

The domain model describes the structure of your optimization problem. In SolverForge, you build it programmatically:

```rust
use solverforge_core::domain::{
    DomainClass, DomainModel, FieldDescriptor, FieldType,
    PlanningAnnotation, PrimitiveType, ScoreType,
};

let model = DomainModel::builder()
    // Employee: a problem fact (input data, not modified by solver)
    .add_class(
        DomainClass::new("Employee")
            .with_field(
                FieldDescriptor::new("name", FieldType::Primitive(PrimitiveType::String))
                    .with_planning_annotation(PlanningAnnotation::PlanningId),
            )
            .with_field(FieldDescriptor::new(
                "skills",
                FieldType::list(FieldType::Primitive(PrimitiveType::String)),
            )),
    )
    // Shift: the planning entity (employee assignment is the decision)
    .add_class(
        DomainClass::new("Shift")
            .with_annotation(PlanningAnnotation::PlanningEntity)
            .with_field(
                FieldDescriptor::new("id", FieldType::Primitive(PrimitiveType::String))
                    .with_planning_annotation(PlanningAnnotation::PlanningId),
            )
            .with_field(
                FieldDescriptor::new("employee", FieldType::object("Employee"))
                    .with_planning_annotation(
                        PlanningAnnotation::planning_variable(vec!["employees".to_string()])
                    ),
            )
            .with_field(FieldDescriptor::new(
                "requiredSkill",
                FieldType::Primitive(PrimitiveType::String),
            )),
    )
    // Schedule: the planning solution (container for everything)
    .add_class(
        DomainClass::new("Schedule")
            .with_annotation(PlanningAnnotation::PlanningSolution)
            .with_field(
                FieldDescriptor::new("employees", FieldType::list(FieldType::object("Employee")))
                    .with_planning_annotation(PlanningAnnotation::ProblemFactCollectionProperty)
                    .with_planning_annotation(PlanningAnnotation::value_range_provider("employees")),
            )
            .with_field(
                FieldDescriptor::new("shifts", FieldType::list(FieldType::object("Shift")))
                    .with_planning_annotation(PlanningAnnotation::PlanningEntityCollectionProperty),
            )
            .with_field(
                FieldDescriptor::new("score", FieldType::Score(ScoreType::HardSoft))
                    .with_planning_annotation(PlanningAnnotation::planning_score()),
            ),
    )
    .build();
```

### Key Concepts

**Planning Entity** (`Shift`): Contains the decision variable (`employee`) that the solver assigns.

**Problem Fact** (`Employee`): Input data that doesn't change during solving.

**Planning Solution** (`Schedule`): The top-level container with:
- `ProblemFactCollectionProperty`: The available employees
- `PlanningEntityCollectionProperty`: The shifts to assign
- `ValueRangeProvider`: Tells the solver which employees can be assigned

---

## Step 2: Create Constraints

Constraints define your business rules using a fluent streaming API:

```rust
use solverforge_core::{Collector, StreamComponent, WasmFunction};
use indexmap::IndexMap;

let mut constraints = IndexMap::new();

// Hard constraint: Employee must have the required skill
constraints.insert(
    "requiredSkill".to_string(),
    vec![
        StreamComponent::for_each("Shift"),
        StreamComponent::filter(WasmFunction::new("skillMismatch")),
        StreamComponent::penalize("1hard/0soft"),
    ],
);

// Soft constraint: Balance assignments across employees
constraints.insert(
    "balanceAssignments".to_string(),
    vec![
        StreamComponent::for_each("Shift"),
        StreamComponent::group_by(
            vec![WasmFunction::new("get_Shift_employee")],
            vec![Collector::count()],
        ),
        StreamComponent::complement("Employee"),
        StreamComponent::group_by(
            vec![],
            vec![Collector::load_balance_with_load(
                WasmFunction::new("pick1"),
                WasmFunction::new("pick2"),
            )],
        ),
        StreamComponent::penalize_with_weigher("0hard/1soft", WasmFunction::new("scaleByFloat")),
    ],
);
```

### Understanding Constraint Streams

**`for_each("Shift")`**: Iterate over all shifts.

**`filter(WasmFunction::new("skillMismatch"))`**: Keep only shifts where the predicate returns true (WASM function we'll define next).

**`penalize("1hard/0soft")`**: Each match subtracts from the score.

**`group_by`**: Aggregate data (count shifts per employee).

**`complement("Employee")`**: Include employees with zero shifts.

**`load_balance`**: Calculate fairness metric.

---

## Step 3: Build WASM Predicates

The constraint predicates compile to WebAssembly for execution in the JVM:

```rust
use solverforge_core::wasm::{
    Expr, FieldAccessExt, HostFunctionRegistry, PredicateDefinition, WasmModuleBuilder,
};

// skillMismatch: returns true if employee doesn't have required skill
let skill_mismatch = {
    let shift = Expr::param(0);
    let employee = shift.clone().get("Shift", "employee");
    Expr::and(
        Expr::is_not_null(employee.clone()),
        Expr::not(Expr::list_contains(
            employee.get("Employee", "skills"),
            shift.get("Shift", "requiredSkill"),
        )),
    )
};

// Build the WASM module
let wasm_bytes = WasmModuleBuilder::new()
    .with_domain_model(model.clone())
    .with_host_functions(HostFunctionRegistry::with_standard_functions())
    .with_initial_memory(16)
    .with_max_memory(Some(256))
    .add_predicate(PredicateDefinition::from_expression("skillMismatch", 1, skill_mismatch))
    // Add field accessors and other predicates...
    .build()
    .expect("Failed to build WASM");

let wasm_base64 = base64::engine::general_purpose::STANDARD.encode(&wasm_bytes);
```

### How WASM Predicates Work

1. **Expression trees** describe the predicate logic
2. **WasmModuleBuilder** compiles them to WebAssembly bytecode
3. The WASM module is sent to the Java service as base64
4. **Chicory runtime** executes predicates during constraint evaluation
5. **Host functions** handle complex operations (string comparison, list access)

This architecture means constraint logic runs at near-native speed inside the JVM, with no interpreter overhead.

---

## Step 4: Run the Solver

Start the solver service and send your problem:

```rust
use solverforge_core::{ListAccessorDto, SolveRequest, SolveResponse, TerminationConfig};

// Problem data as JSON
let problem_json = r#"{
    "employees": [
        {"name": "Alice", "skills": ["NURSE"]},
        {"name": "Bob", "skills": ["DOCTOR"]}
    ],
    "shifts": [
        {"id": "SHIFT1", "requiredSkill": "NURSE"},
        {"id": "SHIFT2", "requiredSkill": "DOCTOR"}
    ]
}"#;

// Build the solve request
let request = SolveRequest::new(
    model.to_dto(),
    constraints,
    wasm_base64,
    "alloc".to_string(),
    "dealloc".to_string(),
    ListAccessorDto::new("newList", "getItem", "setItem", "size", "append", "insert", "remove", "dealloc"),
    problem_json.to_string(),
)
.with_termination(TerminationConfig::new().with_move_count_limit(1000));

// Send to solver service
let client = reqwest::blocking::Client::new();
let response: SolveResponse = client
    .post("http://localhost:8080/solve")
    .json(&request)
    .send()?
    .json()?;

println!("Score: {}", response.score);
println!("Solution: {}", response.solution);
```

### Expected Output

```
Score: 0hard/0soft
Solution: {"employees":[...], "shifts":[
  {"id":"SHIFT1","employee":{"name":"Alice","skills":["NURSE"]},"requiredSkill":"NURSE"},
  {"id":"SHIFT2","employee":{"name":"Bob","skills":["DOCTOR"]},"requiredSkill":"DOCTOR"}
]}
```

A score of `0hard/0soft` means all hard constraints are satisfied — Alice (with NURSE skill) gets the nursing shift, Bob (with DOCTOR skill) gets the doctor shift.

---

## Understanding the Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                     Your Rust Code                            │
│         (Domain model, constraints, WASM predicates)          │
└───────────────────────────────────────────────────────────────┘
                              │
                         HTTP/JSON
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│               timefold-wasm-service (Java)                    │
│                                                               │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐  │
│  │  Chicory  │  │  Dynamic  │  │  Timefold │  │   Host    │  │
│  │   WASM    │  │  Bytecode │  │   Solver  │  │ Functions │  │
│  │  Runtime  │  │    Gen    │  │   Engine  │  │           │  │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘  │
└───────────────────────────────────────────────────────────────┘
```

**Why this architecture?**

1. **No JNI complexity**: Pure HTTP eliminates platform-specific native bindings
2. **Language agnostic**: Any language that speaks HTTP/JSON can use the solver
3. **WASM portability**: Constraint predicates run anywhere with a WASM runtime
4. **Timefold power**: Leverage battle-tested metaheuristic algorithms

---

## What's Next

### Explore the Codebase

- **Integration tests**: `solverforge-core/tests/` — See complete working examples
- **WASM builder**: `solverforge-core/src/wasm/` — How predicates compile
- **HTTP client**: `solverforge-core/src/http/` — Communication layer

### Run the Full Test Suite

```bash
# With logging to see what's happening
RUST_LOG=info cargo test --workspace -- --nocapture
```

### Dive Deeper

- [Core Library Reference](/docs/solverforge/solverforge-core/) — Complete API documentation
- [Constraint Streams](/docs/solverforge/solverforge-core/constraints/) — Full streaming API
- [WASM Module Builder](/docs/solverforge/solverforge-core/wasm/) — Expression language reference

### Contribute

We're actively working on Phase 2 (Python bindings via PyO3). If you're interested in contributing:

1. Check the [GitHub repository](https://github.com/SolverForge/solverforge)
2. Read the [Project Overview](/docs/overview/) for roadmap details
3. Open an issue or PR — we welcome contributions!

---

## Quick Reference

### Key Types

| Type | Purpose |
|------|---------|
| `DomainModel` | Container for all domain classes |
| `DomainClass` | Entity or fact definition |
| `FieldDescriptor` | Field with type and annotations |
| `StreamComponent` | Constraint stream operation |
| `Expr` | WASM predicate expression |
| `WasmModuleBuilder` | Compiles predicates to WASM |

### Common Annotations

| Annotation | Purpose |
|------------|---------|
| `PlanningEntity` | Marks a class as containing planning variables |
| `PlanningVariable` | The field the solver assigns |
| `PlanningSolution` | Top-level problem container |
| `ProblemFactCollectionProperty` | Immutable input data |
| `ValueRangeProvider` | Possible values for planning variables |

### Stream Operations

| Operation | Purpose |
|-----------|---------|
| `for_each(class)` | Iterate over entities |
| `filter(predicate)` | Keep matching entities |
| `join(class, joiners)` | Pair with other entities |
| `group_by(keys, collectors)` | Aggregate data |
| `penalize(score)` | Subtract from score |
| `reward(score)` | Add to score |
