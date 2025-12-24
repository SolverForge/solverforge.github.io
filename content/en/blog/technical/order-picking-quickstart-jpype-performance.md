---
title: "Order Picking Quickstart: When Good Architecture Reveals Infrastructure Limits"
date: 2025-12-24
tags: [quickstarts, python, performance]
description: >
  Introducing the Order Picking quickstart with real-time 3D visualization—and an honest look at JPype performance bottlenecks.
---

We just shipped the final quickstart in our first iteration: [Order Picking](https://github.com/SolverForge/solverforge-quickstarts/tree/main/fast/order-picking-fast). It solves warehouse optimization with real-time isometric visualization showing trolleys dynamically routing through shelves to pick orders.

It works well. It's also slower than we'd like. That tension—between what works architecturally and what performs optimally—is worth examining.

## The Problem

Order picking is the warehouse operation where workers (or trolleys) collect items from shelves to fulfill customer orders. The optimization challenge combines:

- **Capacity constraints**: trolleys have buckets with volume limits, products have different sizes
- **Routing constraints**: minimize travel distance, efficient sequencing
- **Assignment constraints**: each item picked exactly once, balance load across trolleys

This maps to vehicle routing with bin packing characteristics.

## Real-Time Visualization

The UI renders an isometric warehouse with five trolleys navigating between shelving units. Routes update live as the solver reassigns items, color-coded to show which trolley picks which items. The visualization polls solver state every 250ms and renders at 60fps using HTML5 Canvas.

Getting real-time updates working required solving a JPype-specific challenge. The solver runs in a Java thread and modifies domain objects that Python needs to read. We cache solutions in callbacks (`with_first_initialized_solution_consumer`, `with_best_solution_consumer`) so the API can serve them without crossing the Python-Java boundary on every poll:

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

The frontend detects when paths change and smoothly transitions between routes:

```javascript
function updateWarehouseAnimation(solution) {
    if (!userRequestedSolving) return;

    for (const trolley of solution.trolleys || []) {
        const stepIds = (trolley.steps || []).map(ref =>
            typeof ref === 'string' ? ref : ref.id
        );
        const newSignature = stepIds.join(',');

        if (existingAnim && oldSignature !== newSignature) {
            existingAnim.path = buildTrolleyPath(trolley, steps).path;
            existingAnim.stepSignature = newSignature;
            existingAnim.startTime = Date.now();
        }
    }

    renderWarehouse(solution);
}
```

## Performance Numbers

Here's where we need to be honest: this is noticeably slower than Java.

Running on the default problem (5 trolleys, 8 orders, ~40 steps):

| Implementation | 30-second solve iterations | Score achieved |
|----------------|---------------------------|----------------|
| Java (Timefold) | ~500-600 | 0hard/-8000soft |
| Python (dataclass) | ~200-250 | 0hard/-12000soft |

Python completes roughly 40% of the iterations Java manages in the same timeframe, and reaches a less optimal score.

The solver spends time in constraint evaluation, move generation, and score calculation. For order picking specifically, there's overhead from list variable manipulation (`PlanningListVariable`), shadow variable updates (cascading capacity calculations), and equality checks during move validation.

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

Every constraint evaluation triggers JPype conversions. Even with dataclass optimization (avoiding Pydantic overhead in hot paths), we can't eliminate the FFI cost.

Some operations are more affected:

- **List operations**: `PlanningListVariable` for trolley steps requires frequent list manipulation, each crossing to Java
- **Shadow variables**: capacity calculations cascade through step lists, triggering Java calls
- **Equality checks**: object comparison during move validation crosses the boundary

What actually helps: callback-based caching (storing serialized solutions), thread pool for analysis (running `solution_manager.analyze()` in ThreadPoolExecutor), and minimizing domain model complexity (fewer fields, fewer conversions).

## Why This Validates Rust

This quickstart doesn't just expose a performance problem—it validates our architectural direction.

We're building a constraint solver framework in Rust with WASM + HTTP architecture:

- Solver compiles to WebAssembly
- Runs natively in browser or server
- No FFI boundary—just function calls
- Zero serialization overhead for in-memory solving
- No JPype conversions, no GIL contention, direct memory access

With Rust/WASM, the order picking implementation would eliminate all JPype overhead and run constraint evaluation at native speed while keeping the same domain model structure. The architecture stays the same. The performance gap disappears.

## Try It

**Live demo:** [Hugging Face Spaces](https://huggingface.co/spaces/solverforge/order-picking)

**Run locally:**
```bash
git clone https://github.com/SolverForge/solverforge-quickstarts.git
cd solverforge-quickstarts/fast/order-picking-fast
python -m venv .venv
source .venv/bin/activate
pip install -e .
run-app
```

**Source:** All quickstarts follow the architectural pattern documented in [dataclasses vs Pydantic](/blog/technical/python-constraint-solver-architecture/).

## What's Next

Completed first iteration:
- Employee Scheduling
- Meeting Scheduling
- Vehicle Routing
- Order Picking

Next iteration adds maintenance scheduling, school timetabling, task assignment, and resource allocation.

The Rust framework is in active development:
- Q1 2025: Alpha release with basic constraint types
- Q2 2025: Feature parity with Python quickstarts
- Q3 2025: Production-ready 1.0 with WASM compilation

Follow progress at [github.com/SolverForge](https://github.com/SolverForge)

---

**Further reading:**
- [Dataclasses vs Pydantic in Constraint Solvers](/blog/technical/python-constraint-solver-architecture/)
- [Vehicle Routing Quickstart](/docs/getting-started/vehicle-routing/)
- [Order Picking README](https://github.com/SolverForge/solverforge-quickstarts/tree/main/fast/order-picking-fast)
- [SolverForge Docs](https://www.solverforge.org/docs/)
