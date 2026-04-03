---
title: Getting Started
linkTitle: 'Getting Started'
description: >
  Quickstart guides for building constraint solving applications with
  SolverForge.
categories: [Quickstarts]
tags: [quickstart]
weight: 2
---

{{% pageinfo color="primary" %}}
The default onboarding path is now **`solverforge-cli`**. Start with a generated project, then use the longer tutorials when you want a domain-specific walkthrough.
{{% /pageinfo %}}

## Start Here

{{< cardpane >}}
{{< card header="**CLI Quickstart**" >}}
Install `solverforge-cli`, scaffold a new project, run the server, and grow the app incrementally.

[Start with solverforge-cli →](../solverforge-cli/getting-started/)
{{< /card >}}
{{< card header="**Employee Scheduling Tutorial**" >}}
Follow a longer Rust walkthrough that explains domain modeling, constraints, and the web application in more detail.

[Open tutorial →](employee-scheduling-rust/)
{{< /card >}}
{{< /cardpane >}}

## Prerequisites

- **Rust toolchain**: Install via [rustup.rs](https://rustup.rs/) (stable channel)
- **Cargo**: Included with the Rust toolchain
- Familiarity with Rust basics (structs, traits, closures, derive macros)

## Fastest Path to a Running App

```bash
cargo install solverforge-cli
solverforge new my-scheduler --standard
cd my-scheduler
solverforge server
```

Open `http://localhost:7860` to see the generated app.

Use `--list` instead of `--standard` when your model is sequence-based rather than assignment-based:

```bash
solverforge new my-router --list
```

## Where to Read More

- [CLI onboarding guide](../solverforge-cli/getting-started/)
- [Employee Scheduling tutorial](employee-scheduling-rust/)
- [SolverForge API documentation](https://docs.rs/solverforge)
- [Core GitHub repository](https://github.com/solverforge/solverforge)
