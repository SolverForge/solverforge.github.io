---
title: "Installation"
linkTitle: "Installation"
weight: 10
tags: [quickstart, rust]
description: "Add SolverForge to your Rust project and set up the solver service"
---

## Add Dependencies

Add SolverForge to your `Cargo.toml`:

```toml
[dependencies]
solverforge-core = { path = "../solverforge-core" }
solverforge-service = { path = "../solverforge-service" }

# Required dependencies
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
indexmap = { version = "2.0", features = ["serde"] }
base64 = "0.22"
```

## Build the Workspace

```bash
# Clone the repository
git clone https://github.com/solverforge/solverforge.git
cd solverforge

# Initialize submodules (required for the Java solver service)
git submodule update --init --recursive

# Build all crates
cargo build --workspace
```

## Solver Service

SolverForge requires a running Java solver service (`timefold-wasm-service`) to execute the actual solving. The service is included as a Git submodule.

### Using EmbeddedService (Recommended)

The `EmbeddedService` automatically starts and manages the Java service:

```rust
use solverforge_service::{EmbeddedService, ServiceConfig};
use std::path::PathBuf;
use std::time::Duration;

let config = ServiceConfig::new()
    .with_startup_timeout(Duration::from_secs(120))
    .with_java_home(PathBuf::from("/usr/lib64/jvm/java-24-openjdk-24"))
    .with_submodule_dir(PathBuf::from("./timefold-wasm-service"));

let service = EmbeddedService::start(config)?;
println!("Service running at {}", service.url());
```

### Building the Service Manually

If you prefer to run the service separately:

```bash
cd timefold-wasm-service

# Set Java 24
export JAVA_HOME=/usr/lib64/jvm/java-24-openjdk-24
export PATH=$JAVA_HOME/bin:$PATH

# Build and run
mvn quarkus:dev
```

The service starts on `http://localhost:8080` by default.

## Verify Installation

Run the tests to verify everything is working:

```bash
# Run all tests (requires Java 24)
JAVA_HOME=/usr/lib64/jvm/java-24-openjdk-24 cargo test --workspace

# Run a specific integration test
JAVA_HOME=/usr/lib64/jvm/java-24-openjdk-24 \
  cargo test -p solverforge-service test_employee_scheduling_solve
```

## Project Structure

After setup, your workspace should look like:

```
your-project/
├── Cargo.toml
├── src/
│   └── main.rs
└── solverforge/              # Cloned repository
    ├── solverforge-core/     # Core library
    ├── solverforge-service/  # Service management
    └── timefold-wasm-service/  # Java solver (submodule)
```
