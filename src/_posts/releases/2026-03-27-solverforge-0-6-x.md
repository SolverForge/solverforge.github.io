---
title: 'SolverForge 0.6.x: Scaffolding and Codegen'
date: 2026-03-27
draft: false
description: >
  SolverForge 0.6.x is now available with first-class project scaffolding and
  generated domain accessors for cleaner constraint code.
---

We're excited to announce **SolverForge 0.6.x**, the release line that
introduced first-class scaffolding and code generation.

Patch releases are folded into the matching line note instead of published as
separate release-note pages.

This release focuses on onboarding and developer ergonomics:

- **CLI scaffolding + code generation** for new projects
- **Generated collection accessors** (for example, `factory.shifts()`) to reduce
  extractor boilerplate
- **Constraint naming standardization** with `.named(...)`

## Why this release matters

SolverForge 0.6.0 makes it easier to go from a blank project to a working solver
model while keeping constraint code concise and type-safe.

## Upgrade notes

- Prefer generated accessors such as `factory.shifts()` over manual extractors.
- Use `.named("...")` for finalizing constraints.

## What's next

We're continuing to improve project setup and docs so new users can get started
faster with fewer moving parts.
