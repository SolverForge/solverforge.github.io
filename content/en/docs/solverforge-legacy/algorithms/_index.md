---
title: "Optimization Algorithms"
linkTitle: "Algorithms"
weight: 60
description: >
  Understand the algorithms that power SolverForge's optimization.
---

SolverForge uses a combination of algorithms to find high-quality solutions efficiently. Understanding these algorithms helps you tune solver performance.

## Topics

- **[Construction Heuristics](construction-heuristics.md)** - Build an initial solution quickly
- **[Local Search](local-search.md)** - Improve the solution iteratively
- **[Exhaustive Search](exhaustive-search.md)** - Find optimal solutions (for small problems)
- **[Move Selectors](move-selectors.md)** - Reference for available move types

## Algorithm Phases

SolverForge typically runs algorithms in phases:

```
1. Construction Heuristic
   └── Builds initial solution (fast, may be suboptimal)

2. Local Search
   └── Iteratively improves solution (most time spent here)

3. (Optional) Exhaustive Search
   └── Proves optimality (only feasible for small problems)
```

## Construction Heuristics

Build an initial feasible solution quickly:

| Algorithm | Description |
|-----------|-------------|
| First Fit | Assign first available value |
| First Fit Decreasing | Assign largest/most constrained entities first |
| Cheapest Insertion | Insert at lowest cost position |
| Allocate from Pool | Allocate entities from a pool |

## Local Search Algorithms

Iteratively improve the solution:

| Algorithm | Description |
|-----------|-------------|
| Hill Climbing | Accept only improving moves |
| Tabu Search | Track recent moves to avoid cycles |
| Simulated Annealing | Accept worse moves with decreasing probability |
| Late Acceptance | Accept if better than solution from N steps ago |
| Great Deluge | Accept if within rising threshold |

## Default Behavior

By default, SolverForge uses:
1. **First Fit Decreasing** construction heuristic
2. **Late Acceptance** local search

This works well for most problems. Advanced users can customize the algorithm configuration for specific use cases.
