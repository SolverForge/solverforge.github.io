---
title: "VM Placement"
linkTitle: "VM Placement"
icon: fa-brands fa-python
date: 2025-12-11
weight: 16
description: "A comprehensive quickstart guide to understanding and building intelligent virtual machine placement optimization with SolverForge"
categories: [Quickstarts]
tags: [quickstart, python]
---

{{% pageinfo %}}
A comprehensive quickstart guide to understanding and building intelligent virtual machine placement optimization with SolverForge. Learn optimization concepts while exploring a working codebase that demonstrates real-world datacenter resource management.
{{% /pageinfo %}}

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [Understanding the Data Model](#understanding-the-data-model)
5. [How Optimization Works](#how-optimization-works)
6. [Writing Constraints: The Business Rules](#writing-constraints-the-business-rules)
7. [The Solver Engine](#the-solver-engine)
8. [Web Interface and API](#web-interface-and-api)
9. [Making Your First Customization](#making-your-first-customization)
10. [Advanced Constraint Patterns](#advanced-constraint-patterns)
11. [Testing and Validation](#testing-and-validation)
12. [Quick Reference](#quick-reference)

---

## Introduction

### What You'll Learn

This guide walks you through a complete virtual machine placement application built with **SolverForge**, a constraint-based optimization framework. You'll learn:

- How to model **resource allocation decisions** as optimization problems
- How to express **capacity limits and placement rules** as constraints
- How optimization algorithms find efficient placements automatically
- How to customize the system for your specific infrastructure requirements

**No optimization or cloud infrastructure background required** — we'll explain both optimization and datacenter concepts as we encounter them in the code.

> **Architecture Note:** This guide uses the "fast" implementation pattern with dataclass domain models and Pydantic only at API boundaries. For the architectural reasoning behind this design, see [Dataclasses vs Pydantic in Constraint Solvers](/blog/technical/python-constraint-solver-architecture/).

### Prerequisites

- Basic Python knowledge (classes, functions, type annotations)
- Familiarity with REST APIs
- Comfort with command-line operations

### What is VM Placement Optimization?

Traditional VM placement: You write explicit rules like "sort VMs by size and pack them onto servers using first-fit decreasing."

**Constraint-based VM placement**: You describe what a valid placement looks like (capacity respected, replicas separated, load balanced) and the solver figures out which VM goes where.

Think of it like describing the ideal datacenter state and having a computer try millions of placement combinations per second to find the best fit.

### Datacenter Concepts (Quick Primer)

| Term | Definition | Example |
|------|------------|---------|
| **Server** | Physical machine with CPU, memory, and storage | 32 cores, 128 GB RAM, 2 TB storage |
| **VM** | Virtual machine requiring resources from a server | 4 cores, 16 GB RAM, 100 GB storage |
| **Rack** | Physical grouping of servers in a datacenter | Rack A contains 8 servers |
| **Affinity** | VMs that should run on the same server | Web app and its cache |
| **Anti-Affinity** | VMs that must run on different servers | Database primary and replica |
| **Consolidation** | Using fewer servers to reduce power/cooling costs | Pack VMs tightly |

---

## Getting Started

### Running the Application

1. **Download and navigate to the project directory:**
   ```bash
   git clone https://github.com/SolverForge/solverforge-quickstarts
   cd ./solverforge-quickstarts/fast/vm-placement-fast
   ```

2. **Create and activate virtual environment:**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

3. **Install the package:**
   ```bash
   pip install -e .
   ```

4. **Start the server:**
   ```bash
   run-app
   ```

5. **Open your browser:**
   ```
   http://localhost:8080
   ```

You'll see a VM placement interface with server racks, VMs, and a "Solve" button. Click it and watch the solver automatically assign VMs to servers while respecting capacity limits and placement rules.

### File Structure Overview

```
fast/vm-placement-fast/
├── src/vm_placement/
│   ├── domain.py              # Data classes (Server, VM, VMPlacementPlan)
│   ├── constraints.py         # Business rules (90% of customization happens here)
│   ├── solver.py              # Solver configuration
│   ├── demo_data.py           # Sample infrastructure and VMs
│   ├── rest_api.py            # HTTP API endpoints
│   ├── converters.py          # REST ↔ Domain model conversion
│   └── json_serialization.py  # JSON helpers
├── static/
│   ├── index.html             # Web UI with rack visualization
│   ├── app.js                 # UI logic and visualization
│   └── config.js              # Advanced settings sliders
└── tests/
    └── test_constraints.py    # Unit tests for constraints
```

**Key insight:** Most business customization happens in `constraints.py` alone. You rarely need to modify other files.

---

## The Problem We're Solving

### The Infrastructure Challenge

You manage a datacenter with **physical servers organized in racks**, and must place **virtual machines** onto those servers. Each server has limited CPU cores, memory, and storage capacity.

**Hard constraints** (must be satisfied):
- Never exceed a server's CPU, memory, or storage capacity
- Keep database replicas on different servers (anti-affinity)

**Soft constraints** (preferences to optimize):
- Place related services together when possible (affinity)
- Minimize the number of active servers (consolidation)
- Balance load across active servers
- Place higher-priority VMs first

### Why Use a Constraint Solver?

For simple bin-packing (fit VMs into servers by size), a well-implemented first-fit-decreasing algorithm works. So why use a constraint solver?

**1. Declarative vs Imperative:** With constraints, you describe *what* you want, not *how* to achieve it. Adding a new rule is one function, not a rewrite of your algorithm.

**2. Constraint Interactions:** As constraints multiply, greedy logic becomes brittle. Consider adding:
- Anti-affinity for database replicas
- Affinity for microservice tiers
- GPU requirements for ML workloads
- Rack-aware fault tolerance

Each new constraint in greedy code means more `if/else` branches and edge cases. In a constraint solver, you just add another constraint function.

**3. Real-World Complexity:** Production datacenters have migration costs, maintenance windows, SLA requirements, and live traffic patterns. These create solution spaces where greedy approaches fail.

---

## Understanding the Data Model

Let's examine the core classes that model our problem. Open `src/vm_placement/domain.py`:

### Domain Model Architecture

This quickstart separates domain models (dataclasses) from API models (Pydantic):

- **Domain layer** (`domain.py` lines 26-156): Pure `@dataclass` models for solver operations
- **API layer** (`domain.py` lines 159-207): Pydantic `BaseModel` classes for REST endpoints
- **Converters** (`converters.py`): Translate between the two layers

### The Server Class (Problem Fact)

```python
@dataclass
class Server:
    id: Annotated[str, PlanningId]
    name: str
    cpu_cores: int
    memory_gb: int
    storage_gb: int
    rack: Optional[str] = None
```

**What it represents:** A physical server that can host virtual machines.

**Key fields:**
- `id`: Unique identifier for the server
- `name`: Human-readable server name
- `cpu_cores`: Available CPU cores
- `memory_gb`: Available memory in gigabytes
- `storage_gb`: Available storage in gigabytes
- `rack`: Which physical rack contains this server

**Optimization concept:** This is a **problem fact** — immutable data that doesn't change during solving. Servers are the *targets* for VM placement, not the decisions themselves.

### The VM Class (Planning Entity)

```python
@planning_entity
@dataclass
class VM:
    id: Annotated[str, PlanningId]
    name: str
    cpu_cores: int
    memory_gb: int
    storage_gb: int
    priority: int = 1
    affinity_group: Optional[str] = None
    anti_affinity_group: Optional[str] = None
    server: Annotated[Optional[Server], PlanningVariable] = None
```

**What it represents:** A virtual machine that needs to be placed on a server.

**Key fields:**
- `id`: Unique identifier (VM ID)
- `name`: Human-readable VM name
- `cpu_cores`, `memory_gb`, `storage_gb`: Resource requirements
- `priority`: Importance level (1-5, higher = more important)
- `affinity_group`: Group name for VMs that should be together
- `anti_affinity_group`: Group name for VMs that must be separated
- **`server`**: The assignment decision — which server hosts this VM?

**Important annotations:**
- `@planning_entity`: Tells SolverForge this class contains decisions to make
- `PlanningVariable`: Marks `server` as the decision variable

**Optimization concept:** This is a **planning variable** — the value the solver assigns. Each VM starts with `server=None` (unassigned). The solver tries different server assignments, evaluating according to your constraints.

### The Assignment Pattern

Unlike portfolio optimization where the planning variable is a Boolean (SELECTED/NOT_SELECTED), VM placement uses a **reference assignment pattern**:

```python
server: Annotated[Optional[Server], PlanningVariable] = None
```

**Why a reference?** Each VM can be assigned to any server from the value range. The solver picks from the list of available servers, or leaves the VM unassigned (`None`).

### The VMPlacementPlan Class (Planning Solution)

```python
@planning_solution
@dataclass
class VMPlacementPlan:
    name: str
    servers: Annotated[list[Server], ProblemFactCollectionProperty, ValueRangeProvider]
    vms: Annotated[list[VM], PlanningEntityCollectionProperty]
    score: Annotated[Optional[HardSoftScore], PlanningScore] = None
    solver_status: SolverStatus = SolverStatus.NOT_SOLVING
```

**What it represents:** The complete problem and its solution.

**Key fields:**
- `name`: Problem instance name (e.g., "Datacenter Alpha")
- `servers`: All physical servers (problem facts + value range)
- `vms`: All VMs to place (planning entities)
- `score`: Solution quality metric (calculated by constraints)
- `solver_status`: Whether solving is active

**Annotations explained:**
- `@planning_solution`: Marks this as the top-level problem definition
- `ProblemFactCollectionProperty`: Immutable problem data
- `ValueRangeProvider`: Servers are valid values for VM.server
- `PlanningEntityCollectionProperty`: The entities being optimized
- `PlanningScore`: Where the solver stores the calculated score

### Helper Methods for Business Metrics

The `VMPlacementPlan` class includes useful analytics:

```python
def get_vms_on_server(self, server: Server) -> list:
    """Get all VMs assigned to a specific server."""
    return [vm for vm in self.vms if vm.server == server]

def get_server_used_cpu(self, server: Server) -> int:
    """Get total CPU cores used on a server."""
    return sum(vm.cpu_cores for vm in self.vms if vm.server == server)

@property
def active_servers(self) -> int:
    """Count servers that have at least one VM assigned."""
    active_server_ids = set(vm.server.id for vm in self.vms if vm.server is not None)
    return len(active_server_ids)

@property
def unassigned_vms(self) -> int:
    """Count VMs without a server assignment."""
    return sum(1 for vm in self.vms if vm.server is None)
```

---

## How Optimization Works

Before diving into constraints, let's understand how the solver finds solutions.

### The Search Process (Simplified)

1. **Start with an initial solution** (often all VMs unassigned)
2. **Evaluate the score** using your constraint functions
3. **Make a small change** (assign one VM to a server, or move it)
4. **Evaluate the new score**
5. **Keep the change if it improves the score** (with some controlled randomness)
6. **Repeat millions of times** in seconds
7. **Return the best solution found**

### The Search Space

For a placement problem with 12 servers and 30 VMs, each VM can go on any of 12 servers (or stay unassigned). That's 13^30 possible combinations — far too many to enumerate. The solver explores this space using smart heuristics, not brute force.

### The Score: How "Good" is a Placement?

Every solution gets a score with two parts:

```
0hard/-2500soft
```

- **Hard score**: Counts hard constraint violations (must be 0 for a valid placement)
- **Soft score**: Reflects optimization quality (higher/less negative is better)

**Scoring rules:**
- Hard score must be 0 or positive (negative = invalid placement)
- Among valid placements (hard score = 0), highest soft score wins
- Hard score always takes priority over soft score

**Placement example:**
```
-4hard/-1200soft  → Invalid: 4 capacity violations
0hard/-3000soft   → Valid but many servers active
0hard/-1500soft   → Valid with better consolidation
```

---

## Writing Constraints: The Business Rules

Now the heart of the system. Open `src/vm_placement/constraints.py`.

### The Constraint Provider Pattern

All constraints are registered in one function:

```python
@constraint_provider
def define_constraints(factory: ConstraintFactory):
    return [
        # Hard constraints
        cpu_capacity(factory),
        memory_capacity(factory),
        storage_capacity(factory),
        anti_affinity(factory),
        # Soft constraints
        affinity(factory),
        minimize_servers_used(factory),
        balance_utilization(factory),
        prioritize_placement(factory),
    ]
```

Each constraint is a function returning a `Constraint` object. Let's examine them.

### Hard Constraint: CPU Capacity

**Business rule:** "Server CPU capacity cannot be exceeded"

```python
def cpu_capacity(factory: ConstraintFactory):
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .group_by(lambda vm: vm.server, ConstraintCollectors.sum(lambda vm: vm.cpu_cores))
        .filter(lambda server, total_cpu: total_cpu > server.cpu_cores)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda server, total_cpu: total_cpu - server.cpu_cores,
        )
        .as_constraint("cpuCapacity")
    )
```

**How to read this:**
1. `for_each(VM)`: Consider every VM
2. `.filter(...)`: Keep only assigned VMs (server is not None)
3. `.group_by(server, sum(cpu_cores))`: Sum CPU cores per server
4. `.filter(...)`: Keep only overloaded servers
5. `.penalize(ONE_HARD, excess)`: Each excess core adds 1 hard penalty

**Example:** Server with 16 cores hosting VMs totaling 20 cores = penalty of 4

### Hard Constraint: Memory Capacity

**Business rule:** "Server memory capacity cannot be exceeded"

```python
def memory_capacity(factory: ConstraintFactory):
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .group_by(lambda vm: vm.server, ConstraintCollectors.sum(lambda vm: vm.memory_gb))
        .filter(lambda server, total_memory: total_memory > server.memory_gb)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda server, total_memory: total_memory - server.memory_gb,
        )
        .as_constraint("memoryCapacity")
    )
```

Same pattern as CPU capacity, applied to memory.

### Hard Constraint: Storage Capacity

**Business rule:** "Server storage capacity cannot be exceeded"

```python
def storage_capacity(factory: ConstraintFactory):
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .group_by(lambda vm: vm.server, ConstraintCollectors.sum(lambda vm: vm.storage_gb))
        .filter(lambda server, total_storage: total_storage > server.storage_gb)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda server, total_storage: total_storage - server.storage_gb,
        )
        .as_constraint("storageCapacity")
    )
```

Same pattern as CPU capacity, applied to storage.

### Hard Constraint: Anti-Affinity

**Business rule:** "VMs in the same anti-affinity group must be on different servers"

```python
def anti_affinity(factory: ConstraintFactory):
    return (
        factory.for_each_unique_pair(
            VM,
            Joiners.equal(lambda vm: vm.anti_affinity_group),
            Joiners.equal(lambda vm: vm.server),
        )
        .filter(lambda vm1, vm2: vm1.anti_affinity_group is not None)
        .filter(lambda vm1, vm2: vm1.server is not None)
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("antiAffinity")
    )
```

**How to read this:**
1. `for_each_unique_pair(VM, ...)`: Find pairs of VMs
2. `Joiners.equal(anti_affinity_group)`: Same anti-affinity group
3. `Joiners.equal(server)`: On the same server
4. `.filter(...)`: Group must be set (not None)
5. `.filter(...)`: Both must be assigned
6. `.penalize(ONE_HARD)`: Each violating pair adds 1 hard penalty

**Use case:** Database replicas should never be on the same physical server. If one server fails, the other replica survives.

### Soft Constraint: Affinity

**Business rule:** "VMs in the same affinity group should be on the same server"

```python
def affinity(factory: ConstraintFactory):
    return (
        factory.for_each_unique_pair(
            VM,
            Joiners.equal(lambda vm: vm.affinity_group),
        )
        .filter(lambda vm1, vm2: vm1.affinity_group is not None)
        .filter(lambda vm1, vm2: vm1.server is not None and vm2.server is not None)
        .filter(lambda vm1, vm2: vm1.server != vm2.server)
        .penalize(HardSoftScore.ONE_SOFT, lambda vm1, vm2: 100)
        .as_constraint("affinity")
    )
```

**How to read this:**
1. Find pairs of VMs in the same affinity group
2. Both must be assigned
3. Penalize if they're on *different* servers
4. Each separated pair costs 100 soft points

**Use case:** Web servers and their cache should be together for low latency.

### Soft Constraint: Minimize Servers Used

**Business rule:** "Use fewer servers to reduce power and cooling costs"

```python
def minimize_servers_used(factory: ConstraintFactory):
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .group_by(lambda vm: vm.server, ConstraintCollectors.count())
        .penalize(HardSoftScore.ONE_SOFT, lambda server, count: 100)
        .as_constraint("minimizeServersUsed")
    )
```

**How to read this:**
1. Find all assigned VMs
2. Group by server and count VMs
3. Each active server (with at least 1 VM) costs 100 soft points

**Business concept:** Server consolidation. An idle server still consumes power for cooling, lighting, and baseline operations. Packing VMs onto fewer servers reduces operational costs.

### Soft Constraint: Balance Utilization

**Business rule:** "Distribute load evenly across active servers"

```python
def balance_utilization(factory: ConstraintFactory):
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .group_by(lambda vm: vm.server, ConstraintCollectors.sum(lambda vm: vm.cpu_cores))
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda server, total_cpu: int((total_cpu / server.cpu_cores) ** 2 * 10) if server.cpu_cores > 0 else 0,
        )
        .as_constraint("balanceUtilization")
    )
```

**How to read this:**
1. Sum CPU usage per server
2. Calculate utilization ratio (used/capacity)
3. Apply squared penalty — heavily loaded servers cost more

**Why squared?** A server at 90% utilization is riskier than two servers at 45%. Squaring creates a "fairness" preference that spreads load.

**Example:**
| Scenario | Server A | Server B | Total Penalty |
|----------|----------|----------|---------------|
| Imbalanced | 90% = 8.1 | 10% = 0.1 | 8.2 |
| Balanced | 50% = 2.5 | 50% = 2.5 | 5.0 |

### Soft Constraint: Prioritize Placement

**Business rule:** "Higher-priority VMs should be placed first"

```python
def prioritize_placement(factory: ConstraintFactory):
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is None)
        .penalize(HardSoftScore.ONE_SOFT, lambda vm: 10000 + vm.priority * 1000)
        .as_constraint("prioritizePlacement")
    )
```

**How to read this:**
1. Find unassigned VMs
2. Penalize each based on priority
3. Higher priority = larger penalty when unassigned

**Why these weights?** The base penalty (10000) ensures VMs get placed before other soft constraints are optimized. The priority multiplier (1000) makes high-priority VMs more "expensive" to leave unassigned.

**Example penalties:**
| Priority | Unassigned Penalty |
|----------|-------------------|
| 1 (low) | 11000 |
| 3 (medium) | 13000 |
| 5 (critical) | 15000 |

---

## The Solver Engine

Now let's see how the solver is configured. Open `src/vm_placement/solver.py`:

```python
from solverforge_legacy.solver import (
    SolverManager,
    SolverConfig,
    SolverFactory,
    SolutionManager,
)
from solverforge_legacy.solver.config import (
    ScoreDirectorFactoryConfig,
    TerminationConfig,
    Duration,
)
from .constraints import define_constraints
from .domain import VMPlacementPlan, VM

solver_config = SolverConfig(
    solution_class=VMPlacementPlan,
    entity_class_list=[VM],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(
        spent_limit=Duration(seconds=30)
    ),
)

solver_manager = SolverManager.create(SolverFactory.create(solver_config))
solution_manager = SolutionManager.create(solver_manager)
```

### Configuration Breakdown

**`solution_class`**: Your planning solution class (`VMPlacementPlan`)

**`entity_class_list`**: Planning entities to optimize (`[VM]`)
- Note: Only `VM` is listed, not `Server` — servers are problem facts

**`score_director_factory_config`**: Contains the constraint provider function

**`termination_config`**: When to stop solving
- `spent_limit=Duration(seconds=30)`: Stop after 30 seconds

### SolverManager: Asynchronous Solving

`SolverManager` handles solving in the background without blocking your API:

```python
# Start solving (non-blocking)
solver_manager.solve_and_listen(job_id, placement, callback_function)

# Check status
status = solver_manager.get_solver_status(job_id)

# Stop early
solver_manager.terminate_early(job_id)
```

### Solving Timeline

**Small problems** (12 servers, 30 VMs):
- Initial valid placement: < 1 second
- Good placement: 5-10 seconds
- Near-optimal: 30 seconds

**Large problems** (50+ servers, 200 VMs):
- Initial valid placement: 2-5 seconds
- Good placement: 30-60 seconds
- High-quality: 2-5 minutes

**Factors affecting speed:**
- Number of servers and VMs (search space size)
- Constraint tightness (capacity headroom)
- Anti-affinity groups (placement restrictions)

---

## Web Interface and API

### REST API Endpoints

Open `src/vm_placement/rest_api.py` to see the API:

#### GET /demo-data

Returns available demo datasets:

```json
["SMALL", "MEDIUM", "LARGE"]
```

#### GET /demo-data/{dataset_id}

Generates and returns sample infrastructure data:

```json
{
  "name": "Small Datacenter",
  "servers": [
    {
      "id": "server-1",
      "name": "Rack-A-Server-1",
      "cpuCores": 32,
      "memoryGb": 128,
      "storageGb": 2000,
      "rack": "Rack-A"
    }
  ],
  "vms": [
    {
      "id": "vm-1",
      "name": "DB-Primary",
      "cpuCores": 8,
      "memoryGb": 32,
      "storageGb": 500,
      "priority": 5,
      "antiAffinityGroup": "db-replicas",
      "server": null
    }
  ]
}
```

#### POST /demo-data/generate

Generate custom infrastructure with configurable parameters:

**Request body:**
```json
{
  "rack_count": 3,
  "servers_per_rack": 4,
  "vm_count": 30
}
```

**Response:** Same format as demo-data response

#### POST /placements

Submit a placement problem for optimization:

**Request body:** Same format as demo-data response

**Response:** Job ID as plain text
```
"a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

#### GET /placements/{problem_id}

Get current solution:

```json
{
  "name": "Small Datacenter",
  "servers": [...],
  "vms": [...],
  "score": "0hard/-2500soft",
  "solverStatus": "SOLVING_ACTIVE",
  "totalServers": 12,
  "activeServers": 6,
  "unassignedVms": 0
}
```

#### GET /placements/{problem_id}/status

Lightweight status check with metrics:

```json
{
  "name": "Small Datacenter",
  "score": "0hard/-2500soft",
  "solverStatus": "SOLVING_ACTIVE",
  "activeServers": 6,
  "unassignedVms": 0
}
```

#### DELETE /placements/{problem_id}

Stop solving early and return best solution found.

#### PUT /placements/analyze

Analyze a placement's constraint violations in detail:

```json
{
  "constraints": [
    {
      "name": "cpuCapacity",
      "weight": "1hard",
      "score": "-2hard",
      "matches": [
        {
          "name": "cpuCapacity",
          "score": "-2hard",
          "justification": "Server-1: 34 cores used, 32 available"
        }
      ]
    }
  ]
}
```

### Web UI Flow

The `static/app.js` implements this polling workflow:

1. **User opens page** → Load demo data (`GET /demo-data/SMALL`)
2. **Display** servers organized by rack with utilization bars
3. **User clicks "Solve"** → `POST /placements` (get job ID back)
4. **Poll** `GET /placements/{id}` every 2 seconds
5. **Update UI** with latest assignments and score in real-time
6. **When** `solverStatus === "NOT_SOLVING"` → Stop polling
7. **Display** final score, server utilization, and VM assignments

### Advanced Settings

The web UI includes configurable sliders (in `static/config.js`):

- **Racks**: Number of server racks (1-8)
- **Servers per Rack**: Servers in each rack (2-10)
- **VMs**: Number of VMs to place (5-200)
- **Solver Time**: How long to optimize (5s-2min)

Click "Generate New Data" to create custom scenarios.

---

## Making Your First Customization

Let's add a new constraint that demonstrates a common datacenter pattern: rack-aware fault tolerance.

### The Rack Diversity Constraint

**Business rule:** "VMs in the same anti-affinity group should be spread across different racks, not just different servers"

### Why This Matters

If two database replicas are on different servers but the same rack, a rack-level failure (power, networking, cooling) takes out both. True high availability requires rack diversity.

### Implementation

Add this to `src/vm_placement/constraints.py`:

```python
def rack_diversity(factory: ConstraintFactory):
    """
    Soft constraint: Anti-affinity VMs should be on different racks.

    Provides rack-level fault tolerance beyond just server separation.
    """
    return (
        factory.for_each_unique_pair(
            VM,
            Joiners.equal(lambda vm: vm.anti_affinity_group),
        )
        .filter(lambda vm1, vm2: vm1.anti_affinity_group is not None)
        .filter(lambda vm1, vm2: vm1.server is not None and vm2.server is not None)
        .filter(lambda vm1, vm2: vm1.server.rack == vm2.server.rack)
        .penalize(HardSoftScore.ONE_SOFT, lambda vm1, vm2: 50)
        .as_constraint("rackDiversity")
    )
```

**How to read this:**
1. Find pairs of VMs in the same anti-affinity group
2. Both must be assigned
3. Penalize if they're on the same rack (even if different servers)
4. Each same-rack pair costs 50 soft points

### Registering the Constraint

Add it to `define_constraints()`:

```python
@constraint_provider
def define_constraints(factory: ConstraintFactory):
    return [
        # Hard constraints
        cpu_capacity(factory),
        memory_capacity(factory),
        storage_capacity(factory),
        anti_affinity(factory),
        # Soft constraints
        affinity(factory),
        minimize_servers_used(factory),
        balance_utilization(factory),
        prioritize_placement(factory),
        rack_diversity(factory),  # ADD THIS LINE
    ]
```

### Adding Tests

Add to `tests/test_constraints.py`:

```python
from vm_placement.constraints import rack_diversity

def test_rack_diversity_same_rack():
    """Anti-affinity VMs on same rack should be penalized."""
    server1 = Server(id="s1", name="Server1", cpu_cores=32, memory_gb=128, storage_gb=2000, rack="Rack-A")
    server2 = Server(id="s2", name="Server2", cpu_cores=32, memory_gb=128, storage_gb=2000, rack="Rack-A")
    vm1 = VM(id="vm1", name="DB-Primary", cpu_cores=8, memory_gb=32, storage_gb=500, anti_affinity_group="db-replicas")
    vm2 = VM(id="vm2", name="DB-Replica", cpu_cores=8, memory_gb=32, storage_gb=500, anti_affinity_group="db-replicas")
    assign(server1, vm1)
    assign(server2, vm2)

    (
        constraint_verifier.verify_that(rack_diversity)
        .given(server1, server2, vm1, vm2)
        .penalizes_by(50)
    )


def test_rack_diversity_different_racks():
    """Anti-affinity VMs on different racks should not be penalized."""
    server1 = Server(id="s1", name="Server1", cpu_cores=32, memory_gb=128, storage_gb=2000, rack="Rack-A")
    server2 = Server(id="s2", name="Server2", cpu_cores=32, memory_gb=128, storage_gb=2000, rack="Rack-B")
    vm1 = VM(id="vm1", name="DB-Primary", cpu_cores=8, memory_gb=32, storage_gb=500, anti_affinity_group="db-replicas")
    vm2 = VM(id="vm2", name="DB-Replica", cpu_cores=8, memory_gb=32, storage_gb=500, anti_affinity_group="db-replicas")
    assign(server1, vm1)
    assign(server2, vm2)

    (
        constraint_verifier.verify_that(rack_diversity)
        .given(server1, server2, vm1, vm2)
        .penalizes_by(0)
    )
```

Run with:
```bash
pytest tests/test_constraints.py -v -k "rack_diversity"
```

---

## Advanced Constraint Patterns

### Pattern 1: GPU Requirement

**Scenario:** Some VMs need GPU-equipped servers.

First, add a `has_gpu` field to Server and `requires_gpu` to VM in `domain.py`:

```python
@dataclass
class Server:
    # ... existing fields ...
    has_gpu: bool = False

@planning_entity
@dataclass
class VM:
    # ... existing fields ...
    requires_gpu: bool = False
```

Then add the constraint:

```python
def gpu_requirement(factory: ConstraintFactory):
    """
    Hard constraint: GPU VMs must be placed on GPU servers.
    """
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .filter(lambda vm: vm.requires_gpu)
        .filter(lambda vm: not vm.server.has_gpu)
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("gpuRequirement")
    )
```

### Pattern 2: Maintenance Window Avoidance

**Scenario:** Some servers are scheduled for maintenance and shouldn't receive new VMs.

```python
@dataclass
class Server:
    # ... existing fields ...
    in_maintenance: bool = False

def avoid_maintenance_servers(factory: ConstraintFactory):
    """
    Soft constraint: Prefer servers not in maintenance window.

    VMs can still be placed there if necessary, but it's discouraged.
    """
    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .filter(lambda vm: vm.server.in_maintenance)
        .penalize(HardSoftScore.ONE_SOFT, lambda vm: 500)
        .as_constraint("avoidMaintenanceServers")
    )
```

### Pattern 3: Memory Overcommit Limit

**Scenario:** Allow memory overcommit up to 120%, but heavily penalize beyond that.

```python
def memory_overcommit_limit(factory: ConstraintFactory):
    """
    Soft constraint: Penalize memory overcommit beyond 120%.

    Many hypervisors support memory overcommit, but excessive overcommit
    causes performance degradation.
    """
    OVERCOMMIT_RATIO = 1.2

    return (
        factory.for_each(VM)
        .filter(lambda vm: vm.server is not None)
        .group_by(lambda vm: vm.server, ConstraintCollectors.sum(lambda vm: vm.memory_gb))
        .filter(lambda server, total_mem: total_mem > server.memory_gb * OVERCOMMIT_RATIO)
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda server, total_mem: int((total_mem - server.memory_gb * OVERCOMMIT_RATIO) * 100)
        )
        .as_constraint("memoryOvercommitLimit")
    )
```

### Pattern 4: Prefer Same Rack for Affinity

**Scenario:** When VMs can't be on the same server, prefer the same rack.

```python
def affinity_same_rack_preference(factory: ConstraintFactory):
    """
    Soft constraint: Affinity VMs on different servers should prefer same rack.

    Provides lower latency than cross-rack communication.
    """
    return (
        factory.for_each_unique_pair(
            VM,
            Joiners.equal(lambda vm: vm.affinity_group),
        )
        .filter(lambda vm1, vm2: vm1.affinity_group is not None)
        .filter(lambda vm1, vm2: vm1.server is not None and vm2.server is not None)
        .filter(lambda vm1, vm2: vm1.server != vm2.server)
        .filter(lambda vm1, vm2: vm1.server.rack != vm2.server.rack)
        .penalize(HardSoftScore.ONE_SOFT, lambda vm1, vm2: 25)
        .as_constraint("affinitySameRackPreference")
    )
```

---

## Testing and Validation

### Unit Testing Constraints

The quickstart uses `ConstraintVerifier` for isolated constraint testing. See `tests/test_constraints.py`:

```python
from solverforge_legacy.solver.test import ConstraintVerifier

from vm_placement.domain import Server, VM, VMPlacementPlan
from vm_placement.constraints import define_constraints

# VM is the only planning entity (Server is a problem fact)
constraint_verifier = ConstraintVerifier.build(
    define_constraints, VMPlacementPlan, VM
)

def assign(server: Server, *vms: VM):
    """Helper to assign VMs to a server."""
    for vm in vms:
        vm.server = server
```

**Test patterns:**

**Verify no penalty:**
```python
def test_cpu_capacity_not_exceeded():
    server = Server(id="s1", name="Server1", cpu_cores=16, memory_gb=64, storage_gb=500)
    vm1 = VM(id="vm1", name="VM1", cpu_cores=4, memory_gb=8, storage_gb=50)
    vm2 = VM(id="vm2", name="VM2", cpu_cores=8, memory_gb=16, storage_gb=100)
    assign(server, vm1, vm2)

    (
        constraint_verifier.verify_that(cpu_capacity)
        .given(server, vm1, vm2)
        .penalizes_by(0)
    )
```

**Verify exact penalty amount:**
```python
def test_cpu_capacity_exceeded():
    server = Server(id="s1", name="Server1", cpu_cores=16, memory_gb=64, storage_gb=500)
    vm1 = VM(id="vm1", name="VM1", cpu_cores=12, memory_gb=8, storage_gb=50)
    vm2 = VM(id="vm2", name="VM2", cpu_cores=8, memory_gb=16, storage_gb=100)
    assign(server, vm1, vm2)

    # 12 + 8 = 20 cores, capacity = 16, excess = 4
    (
        constraint_verifier.verify_that(cpu_capacity)
        .given(server, vm1, vm2)
        .penalizes_by(4)
    )
```

**Verify anti-affinity violation:**
```python
def test_anti_affinity_violated():
    server = Server(id="s1", name="Server1", cpu_cores=16, memory_gb=64, storage_gb=500)
    vm1 = VM(id="vm1", name="DB-Primary", cpu_cores=4, memory_gb=8, storage_gb=50, anti_affinity_group="db-replicas")
    vm2 = VM(id="vm2", name="DB-Replica", cpu_cores=4, memory_gb=8, storage_gb=50, anti_affinity_group="db-replicas")
    assign(server, vm1, vm2)

    # Both VMs on same server with same anti-affinity group = 1 violation
    (
        constraint_verifier.verify_that(anti_affinity)
        .given(server, vm1, vm2)
        .penalizes_by(1)
    )
```

### Running Tests

```bash
# All tests
pytest

# Verbose output
pytest -v

# Specific test file
pytest tests/test_constraints.py

# Specific test function
pytest tests/test_constraints.py::test_cpu_capacity_exceeded

# With coverage
pytest --cov=vm_placement
```

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Add/change business rule | `src/vm_placement/constraints.py` |
| Add field to VM or Server | `src/vm_placement/domain.py` + `converters.py` |
| Change solve time | `src/vm_placement/solver.py` |
| Add REST endpoint | `src/vm_placement/rest_api.py` |
| Change demo data | `src/vm_placement/demo_data.py` |
| Change UI | `static/index.html`, `static/app.js` |

### Common Constraint Patterns

**Sum resource usage per server:**
```python
constraint_factory.for_each(VM)
    .filter(lambda vm: vm.server is not None)
    .group_by(lambda vm: vm.server, ConstraintCollectors.sum(lambda vm: vm.cpu_cores))
    .filter(lambda server, total: total > server.cpu_cores)
    .penalize(...)
```

**Find pairs with same group:**
```python
constraint_factory.for_each_unique_pair(
    VM,
    Joiners.equal(lambda vm: vm.some_group),
    Joiners.equal(lambda vm: vm.server),  # On same server
)
.filter(lambda vm1, vm2: vm1.some_group is not None)
.penalize(...)
```

**Count active servers:**
```python
constraint_factory.for_each(VM)
    .filter(lambda vm: vm.server is not None)
    .group_by(lambda vm: vm.server, ConstraintCollectors.count())
    .penalize(...)  # Each active server incurs cost
```

**Penalize unassigned entities:**
```python
constraint_factory.for_each(VM)
    .filter(lambda vm: vm.server is None)
    .penalize(HardSoftScore.ONE_SOFT, lambda vm: 10000 + vm.priority * 1000)
```

### Common Gotchas

1. **Forgot to register constraint** in `define_constraints()` return list
   - Symptom: Constraint not enforced

2. **Using wrong score type**
   - `HardSoftScore.ONE_HARD` for must-satisfy rules
   - `HardSoftScore.ONE_SOFT` for preferences

3. **Server is a problem fact, not an entity**
   - Don't add Server to `entity_class_list`
   - Don't add Server to `ConstraintVerifier.build()`

4. **Forgetting to check for None**
   - Always filter `vm.server is not None` before accessing server properties

5. **Score sign confusion**
   - Higher soft score is better (less negative)
   - Use `.reward()` to add points, `.penalize()` to subtract

6. **Forgetting to include problem facts in tests**
   - `constraint_verifier.verify_that(...).given(server, vm1, vm2)` — servers must be included

### Debugging Tips

**Enable verbose logging:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Use the /analyze endpoint:**
```bash
curl -X PUT http://localhost:8080/placements/analyze \
  -H "Content-Type: application/json" \
  -d @my_placement.json
```

**Print in constraints (temporary debugging):**
```python
.filter(lambda vm: (
    print(f"Checking {vm.name}: server={vm.server}") or
    vm.server is not None
))
```

---

## Additional Resources

- [GitHub Repository](https://github.com/SolverForge/solverforge-quickstarts)
- [Portfolio Optimization Quickstart](/docs/getting-started/portfolio-optimization) — Different problem domain, same patterns
- [Employee Scheduling Quickstart](/docs/getting-started/employee-scheduling) — Resource assignment patterns
