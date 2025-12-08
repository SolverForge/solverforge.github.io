---
title: "Problem Types"
linkTitle: "Problem Types"
weight: 20
description: >
  Common categories of planning and scheduling problems.
---

SolverForge can solve a wide variety of planning and scheduling problems. Here are some common categories:

## Scheduling Problems

Assign activities to time slots and resources.

### Employee Scheduling (Rostering)

Assign employees to shifts based on:
- Skills and qualifications
- Availability and preferences
- Labor regulations (max hours, rest periods)
- Fairness (balanced workload)

**Examples:** Hospital nurse scheduling, retail staff scheduling, call center scheduling

### School Timetabling

Assign lessons to timeslots and rooms:
- Teachers can only teach one class at a time
- Rooms have limited capacity
- Student groups shouldn't have conflicts
- Preference for consecutive lessons

**Examples:** University course scheduling, school class scheduling

### Meeting Scheduling

Find optimal times for meetings:
- Required attendees must be available
- Rooms must be available and large enough
- Minimize conflicts with other meetings
- Consider timezone differences

### Job Shop Scheduling

Schedule jobs on machines:
- Operations must follow a specific order
- Machines can only do one job at a time
- Minimize total completion time (makespan)

**Examples:** Manufacturing scheduling, print shop scheduling

## Routing Problems

Plan routes and sequences for vehicles or resources.

### Vehicle Routing Problem (VRP)

Plan delivery or service routes:
- Vehicle capacity constraints
- Time windows for deliveries
- Minimize total travel distance/time
- Multiple depots possible

**Variants:**
- CVRP - Capacitated VRP
- VRPTW - VRP with Time Windows
- PDPTW - Pickup and Delivery with Time Windows

**Examples:** Delivery route planning, field service scheduling, waste collection

### Traveling Salesman Problem (TSP)

Visit all locations exactly once with minimum travel:
- Single vehicle
- Return to starting point
- Minimize total distance

**Examples:** Sales territory planning, circuit board drilling

## Assignment Problems

Assign entities to resources or positions.

### Task Assignment

Assign tasks to workers or machines:
- Match skills/capabilities
- Balance workload
- Meet deadlines
- Minimize cost

**Examples:** Project team assignment, warehouse task allocation

### Bin Packing

Pack items into containers:
- Items have sizes/weights
- Containers have capacity limits
- Minimize number of containers used

**Examples:** Truck loading, cloud server allocation, cutting stock

### Resource Allocation

Allocate limited resources to competing demands:
- Budget allocation
- Equipment assignment
- Space allocation

## Complex Planning Problems

Real-world problems often combine multiple problem types:

### Field Service Scheduling

Combines:
- **Routing** - Travel between customer locations
- **Scheduling** - Time windows and appointment slots
- **Assignment** - Match technician skills to job requirements

### Project Planning

Combines:
- **Task scheduling** - Activities with durations and dependencies
- **Resource assignment** - Assign people/equipment to tasks
- **Constraint satisfaction** - Deadlines, budgets, availability

## Problem Characteristics

When modeling your problem, consider these characteristics:

| Characteristic | Description | Example |
|----------------|-------------|---------|
| **Hard constraints** | Must be satisfied | Legal requirements |
| **Soft constraints** | Should be optimized | Customer preferences |
| **Planning entities** | What gets assigned | Lessons, visits, shifts |
| **Planning variables** | The assignments | Timeslot, room, vehicle |
| **Problem facts** | Fixed data | Employees, rooms, skills |

## Choosing the Right Model

When modeling your problem:

1. **Identify entities** - What things need to be assigned or scheduled?
2. **Identify variables** - What values are you assigning?
3. **Identify constraints** - What rules must be followed?
4. **Define the score** - How do you measure solution quality?

The [Quickstarts](../quickstarts/) section provides complete examples for common problem types.
