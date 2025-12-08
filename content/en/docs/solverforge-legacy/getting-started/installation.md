---
title: "Installation"
linkTitle: "Installation"
weight: 10
tags: [quickstart, python]
description: >
  Set up Python, JDK, and install SolverForge.
---

## Prerequisites

SolverForge requires:

- **Python 3.10 or higher** (3.11 or 3.12 recommended)
- **JDK 17 or higher** (for the optimization engine backend)

### Check Python Version

```bash
python --version
# Python 3.11.0 or higher
```

If you need to install Python, visit [python.org](https://www.python.org/downloads/) or use your system's package manager.

### Check JDK Version

```bash
java -version
# openjdk version "17.0.x" or higher
```

If you need to install a JDK:

- **macOS:** `brew install openjdk@17`
- **Ubuntu/Debian:** `sudo apt install openjdk-17-jdk`
- **Fedora:** `sudo dnf install java-17-openjdk`
- **Windows:** Download from [Adoptium](https://adoptium.net/) or [Oracle](https://www.oracle.com/java/technologies/downloads/)

Make sure `JAVA_HOME` is set:

```bash
echo $JAVA_HOME
# Should output path to JDK installation
```

## Install SolverForge

### Using pip (Recommended)

```bash
pip install solverforge-legacy
```

### In a Virtual Environment

```bash
# Create virtual environment
python -m venv .venv

# Activate it
source .venv/bin/activate  # Linux/macOS
# or
.venv\Scripts\activate     # Windows

# Install SolverForge
pip install solverforge-legacy
```

### Verify Installation

```python
python -c "from solverforge_legacy.solver import SolverFactory; print('SolverForge installed successfully!')"
```

## Project Setup

For a new project, create a `pyproject.toml`:

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "my-solver-project"
version = "1.0.0"
requires-python = ">=3.10"
dependencies = [
    "solverforge-legacy == 1.24.1",
    "pytest == 8.2.2",  # For testing
]
```

Then install your project in development mode:

```bash
pip install -e .
```

## IDE Setup

### VS Code

Install the Python extension and configure your interpreter to use the virtual environment.

### PyCharm

1. Open your project
2. Go to Settings > Project > Python Interpreter
3. Select the virtual environment interpreter

## Troubleshooting

### JVM Not Found

If you see errors about JVM not found:

1. Verify Java is installed: `java -version`
2. Set `JAVA_HOME` environment variable
3. Ensure `JAVA_HOME/bin` is in your `PATH`

### Import Errors

If imports fail:

1. Verify you're in the correct virtual environment
2. Re-install: `pip install --force-reinstall solverforge-legacy`

### Memory Issues

For large problems, you may need to increase JVM memory. This is configured automatically, but you can adjust if needed.

## Next Steps

Now that SolverForge is installed, follow the [Hello World Tutorial](hello-world.md) to build your first solver.
