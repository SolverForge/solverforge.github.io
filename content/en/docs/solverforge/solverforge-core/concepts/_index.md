---
title: "Concepts"
linkTitle: "Concepts"
weight: 20
tags: [concepts, rust]
description: "Understand the core concepts behind SolverForge"
---

This section covers the foundational concepts you need to understand when working with SolverForge.

## In This Section

- [Architecture](architecture/) - How SolverForge uses WASM and HTTP to solve constraints
- [Constraint Satisfaction](constraint-satisfaction/) - Core concepts of constraint satisfaction and optimization

## Overview

SolverForge solves **constraint satisfaction and optimization problems** (CSPs). Given:

- A set of **planning entities** with **planning variables** to assign
- A set of **constraints** that define valid and preferred solutions
- An **objective function** (score) to optimize

The solver searches for an assignment of values to planning variables that:

1. Satisfies all **hard constraints** (feasibility)
2. Optimizes **soft constraints** (quality)

## Example: Employee Scheduling

| Concept | Example |
|---------|---------|
| Planning Entity | `Shift` |
| Planning Variable | `Shift.employee` |
| Problem Fact | `Employee`, `Skill` |
| Hard Constraint | Employee must have required skill |
| Soft Constraint | Balance assignments fairly |
| Score | `HardSoftScore` (e.g., `0hard/-5soft`) |

The solver tries different employee assignments for each shift, evaluating constraints until it finds a feasible, high-quality solution.
