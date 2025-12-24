---
title: "Order Picking Quickstart: JPype Bridge Overhead in Constraint Solving"
date: 2025-12-24
draft: false
tags: [quickstart, python]
description: >
  Building an order picking quickstart with real-time 3D visualization deepened our understanding of JPype's performance characteristics in constraint-heavy workloads.
---

Our current constraint solving quickstarts in Python are based on our stable, legacy fork of [Timefold](https://www.timefold.ai) for Python, which uses JPype to bridge to Timefold's Java solver engine. The latest example is [Order Picking](https://github.com/SolverForge/solverforge-quickstarts/tree/main/fast/order-picking-fast)—a warehouse optimization problem with real-time isometric visualization showing trolleys routing through shelves to pick orders.

The implementation works and demonstrates the architectural patterns we've developed. It also exposes the inherent overhead of FFI (Foreign Function Interface) bridges in constraint-heavy workloads.

## The Problem Domain

Order picking is the warehouse operation where workers (or trolleys) collect items from shelves to fulfill customer orders. The optimization challenge combines:

- **Capacity constraints**: trolleys have buckets with volume limits, products have different sizes
- **Routing constraints**: minimize travel distance, efficient sequencing
- **Assignment constraints**: each item picked exactly once, balance load across trolleys

This maps to vehicle routing with bin packing characteristics—a constraint-intensive problem domain.

## Real-Time Visualization

The UI renders an isometric warehouse with trolleys navigating between shelving units. Routes update live as the solver reassigns items, color-coded to show which trolley picks which items.

Not only solving itself, but merely getting real-time updates working required tackling JPype-specific challenges. The solver runs in a Java thread and modifies domain objects that Python needs to read. To avoid crossing the Python-Java boundary on every poll, solutions are cached in solver callbacks:

```python
@app.get("/schedules/{problem_id}")
async def get_solution(problem_id: str) -> Dict[str, Any]:
    solver_status = solver_manager.get_solver_status(problem_id)

    with cache_lock:
        cached = cached_solutions.get(problem_id)

    if not cached:
        raise HTTPException(status_code=404)

    result = dict(cached)
    result["solverStatus"] = solver_status.name
    return result
```

This pattern—caching solver state in callbacks, serving from cache—avoids *some* JPype overhead in the hot path of UI polling.

## Performance Characteristics

In spite of the above hack, the JPype bridge still introduces major overhead that becomes very significant in constraint-heavy problems like order picking. The overhead is expacted to grow exponentially with scale.

The solver's work happens primarily in:
- **Constraint evaluation**: Checking capacity limits, routing constraints, assignment rules
- **Move generation**: Creating candidate solutions (reassigning items, reordering routes)
- **Score calculation**: Computing solution quality after each move
- **Shadow variable updates**: Cascading capacity calculations through trolley routes

For order picking specifically, the overhead compounds from:
- **List variable manipulation** (`PlanningListVariable`): Frequent reordering of trolley pick lists
- **Shadow variable cascading**: Capacity changes ripple through entire routes
- **Equality checks**: Object comparison during move validation

Each of these operations crosses the Python-Java boundary through JPype, and these crossings happen millions of times during solving.

## Why JPype Specifically

JPype bridges Python and Java by converting Python objects to Java proxies, calling Java methods, and converting results back. Each crossing has overhead. In constraint solving, we cross this boundary millions of times:

```python
@constraint_provider
def define_constraints(factory: ConstraintFactory):
    return [
        minimize_travel_distance(factory),  # Called for every move
        minimize_overloaded_trolleys(factory),
    ]
```

Every constraint evaluation triggers JPype conversions. Even with [dataclass optimization]((/blog/technical/python-constraint-solver-architecture/))(avoiding Pydantic overhead in hot paths), we can't eliminate the FFI cost.

The operations most affected by bridge overhead:

- **List operations**: `PlanningListVariable` for trolley steps requires frequent list manipulation
- **Shadow variables**: capacity calculations cascade through step lists
- **Equality checks**: object comparison during move validation

Mitigation strategies that help:
- **Callback-based caching**: Store serialized solutions to avoid repeated boundary crossings
- **Simplified domain models**: Fewer fields means fewer conversions
- **Dataclass over Pydantic**: Skip validation overhead in solver hot paths (see [architecture comparison](/blog/technical/python-constraint-solver-architecture/))

## Why This Validates Rust

This quickstart doesn't just expose a performance problem—it validates our architectural direction.

We're building a constraint solver framework in Rust with WASM + HTTP architecture:

- Solver compiles to WebAssembly
- Runs natively in browser or server
- No FFI boundary—just function calls
- Zero serialization overhead for in-memory solving
- No JPype conversions, no GIL contention, direct memory access

With Rust/WASM, the order picking implementation would eliminate all JPype overhead and run constraint evaluation at native speed while keeping the same domain model structure. The architecture stays the same. The performance gap disappears.

## Source Code

**Repository:** [SolverForge Quickstarts](https://github.com/SolverForge/solverforge-quickstarts/tree/main/fast/order-picking-fast)

**Run locally:**
```bash
git clone https://github.com/SolverForge/solverforge-quickstarts.git
cd solverforge-quickstarts/fast/order-picking-fast
python -m venv .venv
source .venv/bin/activate
pip install -e .
run-app
```

**Architecture:** All quickstarts follow the pattern documented in [dataclasses vs Pydantic](/blog/technical/python-constraint-solver-architecture/).

**Rust framework development:**

The Rust/WASM framework is in early development. Follow progress at [github.com/SolverForge](https://github.com/SolverForge).

---

**Further reading:**
- [Dataclasses vs Pydantic in Constraint Solvers](/blog/technical/python-constraint-solver-architecture/)
- [Vehicle Routing Quickstart](/docs/getting-started/vehicle-routing/)
- [Order Picking README](https://github.com/SolverForge/solverforge-quickstarts/tree/main/fast/order-picking-fast)
- [SolverForge Docs](https://www.solverforge.org/docs/)
