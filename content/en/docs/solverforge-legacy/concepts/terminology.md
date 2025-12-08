---
title: "Terminology"
linkTitle: "Terminology"
weight: 30
tags: [concepts, python]
description: >
  Glossary of terms used in SolverForge documentation.
---

## Core Concepts

### Planning Problem
The input to the solver: a set of planning entities with uninitialized planning variables, plus all problem facts and constraints.

### Planning Solution
The container class that holds all problem data (entities and facts) and the resulting score. Decorated with `@planning_solution`.

### Planning Entity
A class whose instances are modified during solving. Planning entities contain planning variables. Decorated with `@planning_entity`.

### Planning Variable
A property of a planning entity that the solver changes during optimization. Annotated with `PlanningVariable`.

### Problem Fact
Immutable data that defines the problem but is not changed by the solver (e.g., rooms, timeslots, employees). Annotated with `ProblemFactCollectionProperty` or `ProblemFactProperty`.

### Value Range
The set of possible values for a planning variable. Provided via `ValueRangeProvider`.

## Scoring

### Score
A measure of solution quality. Higher scores are better. Common types: `SimpleScore`, `HardSoftScore`, `HardMediumSoftScore`.

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
The fluent API for defining constraints. Starts with `ConstraintFactory.for_each()`.

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
A shadow variable that maintains a reverse reference (e.g., a visit knowing which vehicle it belongs to).

### Previous/Next Element Shadow Variable
Shadow variables that track the previous or next element in a list variable.

### Cascading Update Shadow Variable
A shadow variable that triggers recalculation when upstream variables change.

### List Variable
A planning variable that holds an ordered list of values (used for routing problems). Annotated with `PlanningListVariable`.

### Pinning
Locking certain assignments so the solver cannot change them. Useful for preserving manual decisions or already-executed plans.

### Problem Change
A modification to the problem while the solver is running (real-time planning).

## Solver Components

### Solver
The main component that performs optimization. Created via `SolverFactory`.

### SolverFactory
Factory for creating Solver instances from configuration.

### SolverConfig
Configuration object specifying solution class, entities, constraints, and termination.

### SolverManager
Manages multiple concurrent solving jobs. Useful for web applications.

### SolutionManager
Analyzes solutions: explains scores, identifies constraint violations.

### ScoreDirector
Internal component that calculates scores efficiently. Used in problem changes.

### Constraint Provider
A function decorated with `@constraint_provider` that returns a list of constraints.

## Constraint Stream Operations

### for_each / forEach
Start a constraint stream by iterating over all instances of a class.

### for_each_unique_pair
Iterate over all unique pairs of instances (A,B where A != B, without duplicates like (B,A)).

### filter
Remove items that don't match a predicate.

### join
Combine two streams by matching on joiners.

### Joiner
A condition for matching items in joins (e.g., `Joiners.equal()`, `Joiners.overlapping()`).

### group_by
Aggregate items by key with collectors.

### Collector
Aggregation function (count, sum, min, max, toList, etc.).

### penalize / reward
Apply score impact for matching items.

### as_constraint
Finalize the constraint with a name.

## Score Analysis

### Score Explanation
Breakdown of which constraints contributed to the score.

### Constraint Match
A single instance of a constraint being triggered.

### Indictment
List of constraint violations associated with a specific entity.

### Justification
Explanation of why a constraint was triggered.
