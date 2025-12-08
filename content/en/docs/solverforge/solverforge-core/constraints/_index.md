---
title: "Constraints"
linkTitle: "Constraints"
weight: 40
tags: [reference, rust]
description: "Define hard and soft constraints using the constraint streams API"
---

This section covers the constraint streams API for defining constraints.

## In This Section

- [Constraint Streams](constraint-streams/) - Build constraints with forEach, filter, join, groupBy, and more
- [Joiners](joiners/) - Efficiently match entities with equal, lessThan, overlapping, and filtering joiners
- [Collectors](collectors/) - Aggregate values with count, sum, average, min, max, toList, toSet, and loadBalance

## Overview

Constraints are defined as pipelines of stream operations:

```rust
use solverforge_core::{Collector, StreamComponent, WasmFunction};
use indexmap::IndexMap;

let mut constraints = IndexMap::new();

constraints.insert(
    "requiredSkill".to_string(),
    vec![
        StreamComponent::for_each("Shift"),
        StreamComponent::filter(WasmFunction::new("skillMismatch")),
        StreamComponent::penalize("1hard/0soft"),
    ],
);
```

## Constraint Pipeline Pattern

Every constraint follows this pattern:

```
Source → [Filter/Join/Group] → Scoring
```

1. **Source**: Select entities (`for_each`, `for_each_unique_pair`)
2. **Transform**: Filter, join, group, or map the stream
3. **Score**: Apply penalty or reward

## Weight Format

Penalties and rewards use score format strings:

| Format | Score Type | Example |
|--------|------------|---------|
| `"1hard"` | Hard constraint | `"1hard/0soft"` |
| `"1soft"` | Soft constraint | `"0hard/1soft"` |
| `"1hard/5soft"` | Combined | Hard and soft |
| `"1"` | Simple | Single dimension |

## Common Constraint Patterns

### Simple Filter

```rust
// Penalize unassigned shifts
StreamComponent::for_each("Shift"),
StreamComponent::filter(WasmFunction::new("hasNoEmployee")),
StreamComponent::penalize("1hard/0soft"),
```

### Pairwise Comparison

```rust
// Penalize overlapping shifts for same employee
StreamComponent::for_each("Shift"),
StreamComponent::join_with_joiners("Shift", vec![
    Joiner::equal(WasmFunction::new("get_Shift_employee"))
]),
StreamComponent::filter(WasmFunction::new("shiftsOverlap")),
StreamComponent::penalize("1hard/0soft"),
```

### Load Balancing

```rust
// Balance shift assignments across employees
StreamComponent::for_each("Shift"),
StreamComponent::group_by(
    vec![WasmFunction::new("get_Shift_employee")],
    vec![Collector::count()]
),
StreamComponent::complement("Employee"),
StreamComponent::group_by(
    vec![],
    vec![Collector::load_balance_with_load(
        WasmFunction::new("pick1"),
        WasmFunction::new("pick2")
    )]
),
StreamComponent::penalize_with_weigher("0hard/1soft", WasmFunction::new("scaleByFloat")),
```
