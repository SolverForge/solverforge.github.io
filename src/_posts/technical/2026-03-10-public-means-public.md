---
title: "Public Means Public"
date: 2026-03-10
draft: false
tags: [rust]
description: >
  In SolverForge, visibility is a contract enforced by the compiler. What's public is public. What's internal is internal. This will never change.
---

Every `pub` in SolverForge is a promise.

Not a suggestion. Not a default that might get locked down in the next major version. Not a technicality of the language's visibility model that we'll retroactively paper over with a module system. A promise. Enforced at compile time, honored permanently.

## The Visibility Contract

Rust has two visibility markers that matter: `pub` and `pub(crate)`. `pub` means any downstream code can use it. `pub(crate)` means only code within the same crate can touch it. The compiler enforces both at compile time. There is no ambiguity, no runtime layer that reinterprets access, no policy document that overrides what the type system says.

This is the entire visibility model. There's nothing else to learn.

SolverForge is organized across six crates: `solverforge-core` for score types and domain traits, `solverforge-scoring` for the SERIO incremental engine and constraint streams, `solverforge-solver` for phases and move selectors, `solverforge-macros` for derive macros, `solverforge-config` for solver configuration, and the top-level `solverforge` crate that re-exports the public API.

Every item in this architecture has an explicit visibility decision. The `ConstraintFactory`, the `ScoreDirector`, the `Move` trait, every score type, every phase builder, every termination condition — all `pub`. Deliberately. Users build on these. Users extend these. Users depend on these.

The internal machinery — console formatting helpers, macro attribute parsers, stream struct fields that hold closures and phantom types — all `pub(crate)`. Not because we're hiding interesting things, but because these are implementation details that would create coupling without value. You don't need to know how the `EventVisitor` struct stores its fields to use the console output. You shouldn't have to care.

Across the entire codebase, there is exactly one `#[doc(hidden)]` module: `__internal`, which exists solely so that macro-generated code can reference internal types without polluting the user-facing API. That's it. One module, clearly named, serving a mechanical purpose.

## Why This Matters

If you're building custom moves, you import the `Move` trait. It's `pub`. You implement it for your type. The compiler checks your implementation against the trait definition. You ship it.

If you're writing a custom termination condition, you implement the `Termination` trait. It's `pub`. The generic parameters are documented. The associated types are clear.

If you're integrating the solver into a production system, you use `SolverManager`, `SolverFactory`, the phase builders. All `pub`. You configure construction heuristics, local search acceptors, k-opt moves. All `pub`. You read the scoring pipeline, trace how SERIO evaluates your constraints, understand exactly why a move was accepted or rejected. The code is there. No access layer between you and the implementation.

This transparency isn't incidental. A constraint solver is not a black box you feed problems into and trust the output. You need to understand scoring behavior to write effective constraints. You need to understand move evaluation to tune performance. You need to understand phase configuration to know why the solver converges fast on one problem structure and not another. Opacity in a solver is a liability.

## Zero-Cost Openness

A natural question: does exposing a large public API compromise performance?

In Rust, no. The entire SolverForge architecture is zero-erasure — fully monomorphized, no trait objects in hot paths, no dynamic dispatch during move evaluation. When you call a `pub` method on a generic type, the compiler generates specialized machine code for your exact type parameters. The public API boundary doesn't exist at runtime. It's a compile-time concept that the optimizer sees straight through.

Exposing `ChangeMove`, `SwapMove`, `KOptMove` as public types doesn't add indirection. Making `ScoreDirector` generic over your solution and score types doesn't add vtable lookups. The `pub` keyword tells the compiler "other crates can name this type." It says nothing about runtime cost, because there is none.

This is not true in every language. In some, making something accessible across module boundaries requires boxing, dynamic dispatch, or reflection. The API designer faces a real trade-off: clean public surface or fast internal execution. Rust eliminates this trade-off entirely. Monomorphization means the public API compiles to the same machine code as if everything were in a single module.

So we expose everything that's useful. There's no performance reason not to.

## The Permanent Commitment

Here is the commitment, stated plainly: SolverForge will never shrink its public API surface.

What is `pub` today will not become `pub(crate)` tomorrow. We will not introduce a module system, an access control layer, or a policy document that reinterprets existing visibility markers. We will not deprecate public types because users found creative ways to use them that we didn't anticipate. If you build on something that's public, it stays public.

This is enforced structurally, not by good intentions. Rust's visibility model doesn't have a mechanism for "public but actually don't use this." There is no annotation that says "this compiles today but might not next release." `pub` is `pub`. The compiler doesn't know about your product roadmap.

New public APIs will be added as the solver grows. Existing public APIs will be extended, never restricted. The surface area only expands.

Power users — the ones building custom heuristics, writing domain-specific moves, integrating solvers into production pipelines — need to know the ground won't shift. That what compiled today compiles tomorrow. That the types they depend on won't disappear behind an access control change justified by "architectural best practices."

The visibility contract is simple: read the type signature. If it says `pub`, it's yours. Forever.
