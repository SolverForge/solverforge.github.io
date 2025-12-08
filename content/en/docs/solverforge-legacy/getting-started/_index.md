---
title: "Getting Started"
linkTitle: "Getting Started"
weight: 20
tags: [quickstart, python]
description: >
  Install SolverForge and solve your first planning problem.
---

Get up and running with SolverForge in minutes.

## Quick Start

1. **[Installation](installation.md)** - Set up Python, JDK, and install SolverForge
2. **[Hello World](hello-world.md)** - Build a simple school timetabling solver (CLI)
3. **[Hello World with FastAPI](hello-world-fastapi.md)** - Add a REST API to your solver

## What You'll Learn

In the Hello World tutorial, you'll build a school timetabling application that:

- Assigns lessons to timeslots and rooms
- Avoids scheduling conflicts (same teacher, room, or student group at the same time)
- Optimizes for teacher preferences (room stability, consecutive lessons)

This introduces the core concepts you'll use in any SolverForge application:

- **Planning entities** - The things being scheduled (lessons)
- **Planning variables** - The values being assigned (timeslot, room)
- **Constraints** - The rules that define a valid solution
- **Solver configuration** - How to run the optimization
