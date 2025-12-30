---
title: "Why Java Interop is Difficult in SolverForge Core"
date: 2025-12-30
draft: false
tags: [python, rust, java]
description: >
  Reflections on the challenges of bridging Rust and Java in constraint solving, and the hard lessons learned along the way.
---

SolverForge Core is written in Rust. The constraint solving engine runs in Java (Timefold). Getting these two to talk to each other has been one of the more humbling engineering challenges we've faced.

This post is a retrospective on what we've tried, what worked, what didn't, and what we've learned about the fundamental tensions in cross-language constraint solving architectures.

## The Fundamental Tension

Constraint solving is computationally intensive. A typical solving run evaluates millions of moves, each triggering:

- **Constraint evaluation**: Checking if a candidate solution violates rules
- **Score calculation**: Computing solution quality
- **Shadow variable updates**: Cascading changes through dependent values
- **Move generation**: Creating new candidate solutions

The solver's inner loop is tight and fast. Any overhead in that loop compounds millions of times. This is where language boundaries become painful.

## JNI: The Road Not Taken

Java Native Interface (JNI) is the standard way to call Java from native code. We ruled it out early, but it's worth understanding why.

**Memory management complexity**: JNI requires explicit management of local and global references. Missing a `DeleteLocalRef` causes memory leaks. Keeping references across JNI calls requires `NewGlobalRef`. The garbage collector can move objects, invalidating pointers. Getting this wrong crashes the JVM—often silently, hours into a long solve.

**Type marshalling overhead**: Every call requires converting types between Rust and Java representations. Strings must be converted to/from modified UTF-8. Arrays require copying. Objects need reflection-based access. In a hot loop, this adds up.

**Thread safety constraints**: JNI has strict rules about which threads can call which methods. Attaching native threads to the JVM has overhead. Detaching must happen before thread termination. Get the threading wrong and you get deadlocks or segfaults with no stack trace.

**Error handling across boundaries**: Java exceptions don't automatically propagate through native code. Every JNI call must check for pending exceptions. When something goes wrong deep in constraint evaluation, the error context is often lost by the time it surfaces.

We looked at Rust libraries that wrap JNI (j4rs, jni-rs, robusta_jni). They reduce boilerplate but can't eliminate the fundamental overhead of crossing the boundary millions of times per solve.

## The JPype Lesson

Before SolverForge, we maintained Python bindings to Timefold using JPype. JPype bridges Python and Java by creating proxy objects—Python method calls translate to Java method calls transparently.

This transparency has a cost. Our [order picking quickstart](/blog/technical/order-picking-quickstart-jpype-performance/) made this viscerally clear: constraint evaluation calls cross the Python-Java boundary millions of times. Each crossing involves type conversion, reference management, and GIL coordination.

```python
@constraint_provider
def define_constraints(factory: ConstraintFactory):
    return [
        minimize_travel_distance(factory),  # Called for every move
        minimize_overloaded_trolleys(factory),
    ]
```

The constraint provider looks like Python. It runs as Java. Every evaluation triggers JPype conversions. Even with [dataclass optimizations](/blog/technical/python-constraint-solver-architecture/), we couldn't eliminate the FFI cost.

This experience shaped our thinking: FFI bridges that cross the language boundary in constraint hot paths will always have performance problems at scale. The only way to win is to keep the hot path on one side of the boundary.

## The HTTP/WASM Approach

Our current architecture tries to solve this by moving all solving to Java:

1. **Serialize the problem** to JSON in Rust
2. **Send via HTTP** to an embedded Java service
3. **Execute constraints as WASM** inside the JVM (via Chicory)
4. **Return the solution** as JSON

The idea is clean: boundary crossing happens exactly twice (problem in, solution out). The hot path runs entirely in the JVM. No FFI overhead during solving.

In practice, it's more complicated.

## The WASM Complexity Tax

Compiling constraint predicates to WebAssembly sounds elegant. In practice, it introduces its own category of problems.

**Memory layout alignment**: WASM memory layout must exactly match what the Rust code expects. We compute field offsets using Rust's `LayoutCalculator` approach, and the Java-side dynamic class generation must produce compatible layouts. When this drifts—and it has—values read from wrong offsets, data corrupts silently, and constraints evaluate incorrectly.

**Limited expressiveness**: WASM predicates can only use a defined set of host functions. Complex logic that would be trivial in native code requires creative workarounds. We've added host functions for string comparison, list membership, and various list operations. Each new host function is a maintenance burden and a potential source of bugs.

**Debugging opacity**: When a WASM predicate behaves unexpectedly, debugging is painful. You're looking at compiled WebAssembly, not your original constraint logic. Stack traces don't map cleanly to source. Print debugging requires host function calls.

**Dynamic class generation**: The Java service generates domain classes at runtime from JSON specifications. This is powerful but fragile. Schema mismatches between Rust and Java manifest as runtime errors, often in ways that are hard to trace back to the root cause.

## Score Corruption: The Silent Killer

The most insidious problems we've encountered involve score corruption. Timefold's incremental score calculation is highly optimized—it doesn't recalculate everything from scratch on each move. Instead, it tracks deltas and applies corrections.

This works beautifully when the constraint implementation is correct. When there's a bug in the WASM layer, the memory layout, or the host function implementation, scores drift. The solver thinks it's improving the solution when it's actually making it worse. Or it rejects good moves because corrupted scores make them look bad.

Score corruption is hard to detect because the solver still runs. It still produces solutions. The solutions are just subtly wrong. We've added `FULL_ASSERT` environment mode for testing, which recalculates scores from scratch and compares them to incremental results. But you can't run production workloads in full assert mode—the performance hit is too severe.

We've caught and fixed several score corruption bugs. Each time, we've wondered how many edge cases remain.

## The Serialization Boundary

Moving problems and solutions across HTTP as JSON has its own costs.

**Large problem overhead**: Serializing a problem with thousands of entities and millions of constraint-relevant relationships is non-trivial. We've optimized our serializers, but there's a floor to how fast JSON can go.

**No intermediate visibility**: Once the problem is sent, Rust is blind until the solution comes back. You can't inspect intermediate solutions. You can't adjust parameters mid-solve based on progress. Everything must be pre-computed before serialization.

**State synchronization**: The Rust and Java representations of the problem must stay synchronized. Domain model changes require updating both sides. This is a source of bugs we've learned to test carefully.

## Service Lifecycle Complexity

The Java service must be started, monitored, and stopped. We handle this in `solverforge-service` with automatic JAR downloading, JVM process management, and port allocation.

This works, but it adds operational complexity:

- JVM startup time adds latency to first solve
- JAR caching and versioning requires careful management
- Port conflicts require detection and retry logic
- Process health monitoring adds code and failure modes
- Java 24+ requirement narrows deployment options

For users who just want to solve a constraint problem, requiring a JVM feels like a lot of machinery.

## What We've Learned

Building this architecture has taught us a lot about what makes cross-language constraint solving hard:

1. **The hot path must be pure**: Any boundary crossing in the inner loop is fatal to performance
2. **Memory layout bugs are silent**: They don't crash, they corrupt
3. **Incremental score calculation amplifies bugs**: Small errors compound into wrong solutions
4. **Operational complexity compounds**: Each moving part adds failure modes

These lessons have shaped how we think about constraint solver architecture. The HTTP/WASM approach was a reasonable bet — it solves the FFI overhead problem by eliminating FFI from the hot path. But the complexity tax is real: the WASM layer introduces subtle bugs, score corruption remains an ever-present concern, and the operational overhead of managing an embedded JVM service is non-trivial.

We've spent the past months wrestling with these challenges, and it's given us a deep appreciation for what a constraint solver actually needs to be reliable and fast.

## Looking Ahead

We're on track for our January release. The work we've done understanding these interop challenges, debugging score corruption edge cases, and learning the internals of constraint solving has been invaluable — even when frustrating.

Stay tuned. We think you'll like what we've been building.

---

**Further reading:**
- [JPype Performance in Order Picking](/blog/technical/order-picking-quickstart-jpype-performance/)
- [Dataclasses vs Pydantic Architecture](/blog/technical/python-constraint-solver-architecture/)
- [SolverForge Documentation](https://solverforge.org/docs/)
- [SolverForge on GitHub](https://github.com/SolverForge/solverforge)
