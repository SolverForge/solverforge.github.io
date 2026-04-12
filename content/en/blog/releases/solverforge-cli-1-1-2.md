---
title: 'solverforge-cli 1.1.2: Stabilized Scaffolding for the Converged Runtime'
date: 2026-04-12
draft: false
description: >
  solverforge-cli 1.1.2 polishes the CLI/runtime integration introduced in
  SolverForge 0.8.x, with aligned scaffold targets and improved test reliability
  for the retained lifecycle workflow.
---

**solverforge-cli 1.1.2** is now available. This is a stabilization release
following the CLI/runtime convergence work in SolverForge 0.8.x.

## Why this release matters

SolverForge 0.8.2 established a single coherent pipeline from scaffolding through
to the retained runtime. The CLI was always the entry point; the runtime was
always the destination. What changed in 0.8.x was that they now speak the same
vocabulary—jobs, snapshots, checkpoints—using the same configuration format and
type system all the way through.

CLI 1.1.2 ensures that the scaffolds you generate today target that converged
runtime correctly:

- Scaffolded projects now depend on **SolverForge 0.8.4**, **solverforge-ui
  0.4.3**, and **solverforge-maps 2.1.3**
- Generated code uses the retained `SolverManager` lifecycle introduced in 0.8.0
- The same `solver.toml` configuration drives both scaffolded servers and custom
  extensions

## What changed in 1.1.2

### Aligned scaffold targets

The 1.1.2 release fixes target alignment in the scaffold templates and adds
proper tag publishing to the release workflow. When you run:

```bash
cargo install solverforge-cli
solverforge new my-scheduler
```

The generated `Cargo.toml` now correctly pins the 0.8.4 runtime line, ensuring
that new projects start from the converged API surface rather than intermediate
versions.

### Reliable test executable resolution

Integration tests now resolve generated-app executables from `cargo metadata`
rather than assuming hardcoded paths. This makes the test suite more resilient
to workspace layout variations and cross-platform differences.

## The broader context: from convergence to stability

The 0.8.x releases were about bringing the pieces together:

- **0.7.0** introduced CLI-first onboarding with `solverforge new`
- **0.8.0** through **0.8.2** solidified the retained runtime with exact pause
  semantics, snapshot-bound analysis, and the job/snapshot/checkpoint vocabulary

CLI 1.1.x has been tracking that stabilization:

- **1.1.0** aligned scaffolds with the retained lifecycle
- **1.1.1** hardened the scaffold templates and added demo data generation
- **1.1.2** (this release) polishes target alignment and test reliability

The result is that scaffolding now produces code that fits naturally into the
converged runtime. The generated `SolverManager` setup, the event stream
handling, and the configuration overlay pattern all match what the 0.8.4 runtime
expects.

## Upgrade notes

- **New installs**: `cargo install solverforge-cli` gets you 1.1.2
- **Existing installs**: `cargo install solverforge-cli --force`
- **Verify targets**: Run `solverforge --version` to see scaffold targets

Projects scaffolded with earlier CLI versions continue to work. The runtime
APIs are stable within the 0.8.x line. New projects benefit from the corrected
target versions and the refined template structure.

## What's next

The CLI is now a reliable entry point for the converged SolverForge toolchain.
Planned work includes:

- Expanded generator commands for common constraint patterns
- Deeper integration with the score analysis APIs introduced in 0.8.2
- Refined scaffold extension workflows for custom phases and selectors

---

**solverforge-cli 1.1.2** is available on [crates.io](https://crates.io/crates/solverforge-cli).
