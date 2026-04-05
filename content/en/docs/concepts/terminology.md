---
title: "Terminology"
linkTitle: "Terminology"
weight: 30
tags: [concepts]
description: >
  Glossary of terms used in SolverForge documentation.
---

## Core Concepts

### Planning Problem
The input to the solver: a set of planning entities with uninitialized planning variables, plus all problem facts and constraints.

### Planning Solution
The root Rust struct that holds all problem facts, planning entities, and the current score. Annotated with `#[planning_solution]`.

### Planning Entity
A Rust struct whose instances are modified during solving. Planning entities contain genuine planning variables or list variables. Annotated with `#[planning_entity]`.

### Planning Variable
A field on a planning entity that the solver changes during optimization. Annotated with `#[planning_variable(...)]`.

### Problem Fact
Immutable input data that constraints reference but the solver does not modify. Annotated with `#[problem_fact]` and stored in a `#[problem_fact_collection]`.

### Planning ID
A stable identifier for an entity or fact. Annotated with `#[planning_id]`. Most user-facing examples use one so joins, telemetry, and analysis stay easy to read.

### Value Range
The set of possible values for a planning variable. In the common stock runtime, the planning variable names its provider with `value_range = "solution_field"`.

## Scoring

### Score
A measure of solution quality. Higher scores are better. Common types: `SoftScore`, `HardSoftScore`, and `HardMediumSoftScore`.

### Hard Constraint
A constraint that must be satisfied for a solution to be feasible. Broken hard constraints make a solution invalid.

### Soft Constraint
A constraint that should be optimized but isn't required. Used for preferences and optimization goals.

### Medium Constraint
A constraint between hard and soft, typically used for "assign as many as possible" scenarios.

### Feasible Solution
A solution with no broken hard constraints (hard score of 0 or positive).

### Optimal Solution
A feasible solution with the best possible soft score. May be impractical to find for large problems.

### Constraint Stream
The fluent API for defining constraints. Streams start from `ConstraintFactory::<Solution, Score>::new()`, then either `for_each(...)` or a generated collection accessor such as `.shifts()`.

## Algorithms

### Construction Heuristic
An algorithm that builds an initial solution quickly by assigning values to all planning variables.

### Local Search
An algorithm that improves an existing solution by making incremental changes (moves).

### Move
A change to the solution, such as swapping two assignments or changing a single variable.

### Step
One iteration of the optimization algorithm, consisting of selecting and applying a move.

### Termination
The condition that stops the solver (time limit, score target, no improvement, etc.).

## Advanced Concepts

### Shadow Variable
A planning variable whose value is calculated from other variables, not directly assigned by the solver. Used for derived values like arrival times.

### Inverse Shadow Variable
A shadow variable that maintains a reverse reference to the owner or assignment created by a genuine variable.

### Previous/Next Element Shadow Variable
Shadow variables that track the previous or next element in a list variable.

### Cascading Update Shadow Variable
A shadow variable that triggers recalculation when upstream variables change.

### List Variable
A planning variable that holds an ordered list of element indices. Used for routing and sequencing problems. Annotated with `#[planning_list_variable(...)]`.

### Nearby Selection
Distance-pruned move generation for large neighborhoods. In the config-driven runtime, this is expressed by choosing nearby move-selector variants such as `nearby_list_change_move_selector`.

### Pinning
Locking certain assignments so the solver cannot change them. Useful for preserving manual decisions or already-executed plans.

### Problem Change
A modification to the problem while the solver is running (real-time planning).

## Solver Components

### Solver
The search engine that applies phases, selectors, acceptors, and incremental scoring to improve a solution.

### SolverConfig
Configuration object for runtime behavior such as termination, random seed, phases, and move-thread count.

### SolverManager
Manages concurrent solve jobs and streams `SolverEvent` values through channels. Useful for services and web applications.

### Analyzable
Trait generated for `#[planning_solution]` types that specify a constraints path. It enables score analysis for a concrete solution instance.

### ScoreDirector
Internal component that calculates scores efficiently and powers score analysis.

### ConstraintSet
The trait implemented for tuples of finalized constraints returned by your constraint function.

## Constraint Stream Operations

### for_each
Start a constraint stream by iterating over items produced by an extractor closure.

### Generated Collection Accessor
A method like `.shifts()` or `.employees()` generated by `#[planning_solution]` for use on `ConstraintFactory`.

### unassigned
A generated helper on streams of entities with a single `Option<_>` planning variable. It filters to entities whose planning variable is currently `None`.

### filter
Remove items that don't match a predicate.

### join
Combine two streams by matching on joiners. The current API uses one unified `.join(target)` entry point for self-joins, cross-joins, and predicate joins.

### Joiner
A condition for matching items in joins, such as `equal`, `equal_bi`, or `overlapping`.

### group_by
Aggregate items by key with collectors.

### flatten_last
Flatten the final element of a tuple stream into a child collection, then continue matching on the flattened values.

### balance
Compute load imbalance directly from a uni-stream without manually writing `group_by` aggregation code.

### if_exists_filtered / if_not_exists_filtered
Keep or reject items based on whether matching items exist in another collection.

### Collector
Aggregation function (count, sum, min, max, toList, etc.).

### penalize / reward
Apply score impact for matching items.

### named
Finalize the constraint with a human-readable name.

## Score Analysis

### Score Explanation
Breakdown of which constraints contributed to the score.

### Constraint Match
A single instance of a constraint being triggered.

### Indictment
List of constraint violations associated with a specific entity.

### Justification
Explanation of why a constraint was triggered.
