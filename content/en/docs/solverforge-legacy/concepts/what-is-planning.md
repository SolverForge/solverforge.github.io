---
title: "What is Planning Optimization?"
linkTitle: "What is Planning?"
weight: 10
description: >
  Introduction to planning optimization and constraint satisfaction.
---

## Planning

The need to create plans generally arises from a desire to achieve a **goal**:

- Build a house
- Correctly staff a hospital shift
- Complete work at all customer locations
- Deliver packages efficiently

Achieving those goals involves organizing the available **resources**. To correctly staff a hospital you need enough qualified personnel in a variety of fields and specializations to cover the opening hours of the hospital.

Any plan to deploy resources, whether to staff a hospital shift or to assemble the building materials for a new house, is done under **constraints**.

Constraints could be:
- **Physical laws** - People can't work two shifts in two separate locations at the same time, and you can't mount a roof on a house that doesn't exist
- **Regulations** - Employees need a certain number of hours between shifts or are only allowed to work a maximum number of hours per week
- **Preferences** - Certain employees prefer to work specific shift patterns

## Feasible Plans

Any plan needs to consider all three elements—goals, resources, and constraints—in balance to be a **feasible plan**. A plan that fails to account for all the elements of the problem is an **infeasible plan**.

For instance, if a hospital staff roster covers all shifts, but assigns employees back-to-back shifts with no breaks for sleep or life outside work, it is not a valid plan.

## Why Planning Problems are Hard

Planning problems become harder to solve as the number of resources and constraints increase. Creating an employee shift schedule for a small team of four employees is fairly straightforward. However, if each employee performs a specific function within the business and those functions need to be performed in a specific order, changes that affect one employee quickly cascade and affect everybody on the team.

As more employees and different work specializations are added, things become much more complicated.

**Example:** For a trivial field service routing problem with 4 vehicles and 8 visits, the number of possibilities that a brute force algorithm considers is **19,958,418**.

What would take a team of planners many hours to schedule can be automatically scheduled by SolverForge in a fraction of the time.

## Operations Research

Operations Research (OR) is a field of research focused on finding optimal (or near optimal) solutions to problems with techniques that improve decision-making.

**Constraint satisfaction programming** is part of Operations Research that aims to satisfy all the constraints of a problem.

## Planning AI

Planning AI is a type of artificial intelligence designed specifically to handle complex planning and scheduling tasks, and to satisfy the constraints of planning problems. Instead of just automating simple, repetitive tasks, it helps you make better decisions by sorting through countless possibilities to find the best solutions—saving you time, reducing costs, and improving efficiency.

### Why Planning AI is Different

Traditional methods of planning often involve manually sifting through options or relying on basic tools that can't keep up with the complexity of real-world problems. Planning AI, on the other hand, uses advanced strategies to quickly focus on the most promising solutions, even when the situation is extremely complicated.

Planning AI also makes it possible to understand the final solution with a breakdown of:
- Which constraints have been violated
- Scores for individual constraints
- An overall score

This makes Planning AI incredibly valuable in industries where getting the right plan is crucial—whether that's scheduling workers, routing deliveries, or managing resources in a factory.

## Constraints and Scoring

Constraints can be considered **hard**, **medium**, or **soft**.

### Hard Constraints

Hard constraints represent rules and limitations of the real world that any planning solution has to respect. For instance, there are only 24 hours in a day and people can only be in one place at a time. Hard constraints also include rules that must be adhered to, such as employee contracts and the order in which dependent tasks are completed.

**Breaking hard constraints results in infeasible plans.**

### Medium Constraints

Medium constraints help manage plans when resources are limited (for instance, when there aren't enough technicians to complete all the customer visits or there aren't enough employees to work all the available shifts). Medium constraints incentivize SolverForge to assign as many entities (visits or shifts) as possible.

### Soft Constraints

Soft constraints help optimize plans based on the business goals, for instance:
- Minimize travel time between customer visits
- Assign employees to their preferred shifts
- Keep teachers in the same room for consecutive lessons

## Understanding Scores

To help determine the quality of the solution, plans are assigned a score with values for hard, medium, and soft constraints.

```
0hard/-257medium/-6119520soft
```

From this example score we can see:
- Zero hard constraints were broken (feasible!)
- Medium and soft scores have negative values (room for optimization)

> **Note:** The scores do not show how many constraints were broken, but weighted values associated with those constraints.

### Score Comparison

Because breaking hard constraints would result in an infeasible solution, **a solution that breaks zero hard constraints and has a soft constraint score of -1,000,000 is better than a solution that breaks one hard constraint and has a soft constraint score of 0**.

The weight of constraints can be tweaked to adjust their impact on the solution.
