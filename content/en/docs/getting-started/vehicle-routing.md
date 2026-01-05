---
title: "Vehicle Routing"
linkTitle: "Vehicle Routing"
icon: fa-brands fa-python
date: 2025-12-09
weight: 30
description: "A comprehensive quickstart guide to understanding and building intelligent vehicle routing with SolverForge"
categories: [Quickstarts]
tags: [quickstart, python]
---

{{% pageinfo color="warning" %}}
**Legacy Implementation Guide**

This guide uses **solverforge-legacy**, a fork of Timefold 1.24 that bridges Python to Java via JPype. This legacy implementation is **already archived** and will no longer be maintained once SolverForge's native Python bindings are production-ready.

SolverForge has been **completely rewritten as a native constraint solver in Rust**. This guide is preserved for educational purposes and constraint modeling concepts.
{{% /pageinfo %}}

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [Understanding the Data Model](#understanding-the-data-model)
5. [How Route Optimization Works](#how-route-optimization-works)
6. [Writing Constraints: The Business Rules](#writing-constraints-the-business-rules)
7. [The Solver Engine](#the-solver-engine)
8. [Web Interface and API](#web-interface-and-api)
9. [Making Your First Customization](#making-your-first-customization)
10. [Advanced Constraint Patterns](#advanced-constraint-patterns)
11. [Testing and Validation](#testing-and-validation)
12. [Production Considerations](#production-considerations)
13. [Quick Reference](#quick-reference)

---

## Introduction

### What You'll Learn

This guide walks you through a complete vehicle routing application built with **SolverForge**, a constraint-based optimization framework. You'll learn:

- How to model real-world logistics problems as **optimization problems**
- How to construct efficient delivery routes with **time windows and capacity constraints**
- How optimization algorithms balance competing objectives automatically
- How to customize the system for your specific routing needs

**No optimization background required** — we'll explain concepts as we encounter them in the code.

{{% alert title="Performance Note" %}}
Vehicle routing is particularly sensitive to constraint evaluation performance, as the solver must recalculate distances and arrival times millions of times during optimization. This implementation uses the "fast" dataclass architecture—see [benchmark results](/blog/technical/python-constraint-solver-architecture/#results-vehicle-routing). Note: benchmarks were run on small test problems (25-77 customers); JPype bridge overhead may compound at larger scales.
{{% /alert %}}

### Prerequisites

- Basic Python knowledge (classes, functions, type annotations)
- Familiarity with REST APIs
- Comfort with command-line operations
- Understanding of basic geographic concepts (latitude/longitude)

### What is Vehicle Routing Optimization?

Traditional planning: Manually assign deliveries to drivers and plan routes using maps.

**Vehicle routing optimization**: You describe your vehicles, customers, and constraints — the solver automatically generates efficient routes that minimize travel time while satisfying all requirements.

Think of it like having an expert logistics planner who can evaluate millions of route combinations per second to find near-optimal solutions.

### SolverForge Enhancements

This implementation includes several enhancements over the standard Timefold quickstart:

| Feature | Benefit |
|---------|---------|
| **Adaptive time windows** | Time windows dynamically scale based on problem area and visit count, ensuring feasible solutions |
| **Haversine formula** | Fast great-circle distances without external API dependencies (default mode) |
| **Real Roads mode** | Optional OSMnx integration for actual road network routing with visual route display |
| **Real street addresses** | Demo data uses actual locations in Philadelphia, Hartford, and Florence for realistic routing |

These features give you more control over the performance/accuracy tradeoff during development and production.

---

## Getting Started

### Running the Application

1. **Navigate to the project directory:**
   ```bash
   cd solverforge-quickstarts/legacy/vehicle-routing-fast
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
   http://localhost:8082
   ```

You'll see a map interface with customer locations plotted. Click "Solve" and watch the solver automatically create delivery routes for multiple vehicles, respecting capacity limits and time windows.

### File Structure Overview

```
src/vehicle_routing/
├── domain.py              # Data classes (Vehicle, Visit, Location)
├── constraints.py         # Business rules (capacity, time windows, distance)
├── solver.py              # Solver configuration
├── demo_data.py           # Sample datasets (Philadelphia, Hartford, Florence)
├── rest_api.py            # HTTP API endpoints
├── routing.py             # Distance matrix and OSMnx routing
├── converters.py          # REST ↔ Domain model conversion
├── json_serialization.py  # JSON helpers
└── score_analysis.py      # Score breakdown DTOs

static/
├── index.html             # Web UI
└── app.js                 # UI logic and map visualization

tests/
├── test_constraints.py    # Unit tests for constraints
├── test_routing.py        # Unit tests for routing module
└── test_feasible.py       # Integration tests
```

**Key insight:** Most business customization happens in `constraints.py` alone. The domain model defines what can be routed, but constraints define what makes a good route.

---

## The Problem We're Solving

### The Vehicle Routing Challenge

You need to assign **customer visits** to **vehicles** and determine the **order** of visits for each vehicle while satisfying:

**Hard constraints** (must be satisfied):
- Vehicle capacity limits (total customer demand ≤ vehicle capacity)
- Time windows (arrive at customer before their deadline)

**Soft constraints** (objectives to minimize):
- Total driving time across all vehicles

This is known as the **Capacitated Vehicle Routing Problem with Time Windows (CVRPTW)** — a classic optimization problem in logistics.

### Why This is Hard

Even with just 10 customers and 3 vehicles, there are over **3.6 million possible route configurations**. With 50 customers and 6 vehicles, the possibilities become astronomical.

**The challenges:**
- **Combinatorial explosion**: Number of possibilities grows exponentially with problem size
- **Multiple objectives**: Minimize distance while respecting capacity and time constraints
- **Interdependencies**: Assigning one customer affects available capacity and time for others

**Route optimization algorithms** use sophisticated strategies to explore this space efficiently, finding high-quality solutions in seconds.

---

## Understanding the Data Model

Let's examine the core classes that model our routing problem. Open `src/vehicle_routing/domain.py`:

### The Location Class

```python
@dataclass
class Location:
    latitude: float
    longitude: float

    # Earth radius in meters
    _EARTH_RADIUS_M = 6371000
    _TWICE_EARTH_RADIUS_M = 2 * _EARTH_RADIUS_M
    # Average driving speed assumption: 50 km/h
    _AVERAGE_SPEED_KMPH = 50

    def driving_time_to(self, other: "Location") -> int:
        """
        Get driving time in seconds to another location using Haversine formula.
        """
        return self._calculate_driving_time_haversine(other)
```

**What it represents:** A geographic coordinate (latitude/longitude).

**Key method:**
- `driving_time_to()`: Calculates driving time using the Haversine formula

**Haversine formula details:**
- Accounts for Earth's curvature using great-circle distance
- Assumes 50 km/h average driving speed
- Example: Philadelphia to New York (~130 km) → ~9,400 seconds (~2.6 hours)

**Optimization concept:** The Haversine formula provides realistic geographic distances without external API dependencies. For production with real road networks, you can replace the distance calculation with a routing API (Google Maps, OSRM, etc.).

### The Visit Class (Planning Entity)

```python
@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    name: str                                          # Customer name
    location: Location                                # Where to visit
    demand: int                                       # Capacity units required
    min_start_time: datetime                          # Earliest service start
    max_end_time: datetime                            # Latest service end (deadline)
    service_duration: timedelta                       # How long service takes
    
    # Shadow variables (automatically updated by solver)
    vehicle: Annotated[
        Optional['Vehicle'],
        InverseRelationShadowVariable(source_variable_name="visits"),
    ] = None
    
    previous_visit: Annotated[
        Optional['Visit'], 
        PreviousElementShadowVariable(source_variable_name="visits")
    ] = None
    
    next_visit: Annotated[
        Optional['Visit'], 
        NextElementShadowVariable(source_variable_name="visits")
    ] = None
    
    arrival_time: Annotated[
        Optional[datetime],
        CascadingUpdateShadowVariable(target_method_name="update_arrival_time"),
    ] = None
```

**What it represents:** A customer location that needs a delivery/service visit.

**Key fields:**
- `demand`: How much vehicle capacity this visit consumes (e.g., number of packages, weight)
- `min_start_time`: Earliest acceptable arrival (customer opens at 8 AM)
- `max_end_time`: Latest acceptable service completion (customer closes at 6 PM)
- `service_duration`: Time spent at customer location (unloading, paperwork, etc.)

**Shadow variable annotations explained:**
- `InverseRelationShadowVariable(source_variable_name="visits")`: Automatically set to the Vehicle when this Visit is added to a vehicle's `visits` list
- `PreviousElementShadowVariable(source_variable_name="visits")`: Points to the previous visit in the route chain (or None if first)
- `NextElementShadowVariable(source_variable_name="visits")`: Points to the next visit in the route chain (or None if last)
- `CascadingUpdateShadowVariable(target_method_name="update_arrival_time")`: Triggers the `update_arrival_time()` method when dependencies change, cascading arrival time calculations through the route

**Shadow variables** (automatically maintained by solver):
- `vehicle`: Which vehicle is assigned to this visit (inverse relationship)
- `previous_visit`/`next_visit`: Links forming the route chain
- `arrival_time`: When vehicle arrives at this location (cascades through chain)

**Optimization concept:** Shadow variables implement **derived data** — values that depend on planning decisions but aren't directly decided by the solver. They update automatically when the solver modifies routes.

**Important methods:**

```python
def calculate_departure_time(self) -> datetime:
    """When vehicle leaves after service."""
    return max(self.arrival_time, self.min_start_time) + self.service_duration

def is_service_finished_after_max_end_time(self) -> bool:
    """Check if time window violated."""
    return self.calculate_departure_time() > self.max_end_time

def service_finished_delay_in_minutes(self) -> int:
    """How many minutes late (for penalty calculation)."""
    if not self.is_service_finished_after_max_end_time():
        return 0
    return int((self.calculate_departure_time() - self.max_end_time).total_seconds() / 60)
```

These methods support constraint evaluation without duplicating logic.

### The Vehicle Class (Planning Entity)

```python
@planning_entity
@dataclass
class Vehicle:
    id: Annotated[str, PlanningId]
    name: str                                          # Vehicle name (e.g., "Alpha", "Bravo")
    capacity: int                                      # Maximum demand it can handle
    home_location: Location                            # Depot location
    departure_time: datetime                           # When vehicle leaves depot
    visits: Annotated[list[Visit], PlanningListVariable] = field(default_factory=list)
```

**What it represents:** A delivery vehicle that starts from a depot, visits customers, and returns.

**Key fields:**
- `id`: Unique identifier for the vehicle
- `name`: Human-readable name (e.g., "Alpha", "Bravo" from phonetic alphabet)
- `capacity`: Total demand the vehicle can carry (e.g., 100 packages, 1000 kg)
- `home_location`: Depot where vehicle starts and ends its route
- `departure_time`: When vehicle begins its route
- **`visits`**: Ordered list of customer visits — this is what the solver optimizes!

**Annotations:**
- `@planning_entity`: Tells SolverForge this class contains decisions
- `PlanningListVariable`: Marks `visits` as a **list variable** — the solver assigns visits to vehicles AND determines their order

**Important properties:**

```python
@property
def arrival_time(self) -> datetime:
    """When vehicle returns to depot."""
    if not self.visits:
        return self.departure_time
    return self.visits[-1].calculate_departure_time() + timedelta(
        seconds=self.visits[-1].location.driving_time_to(self.home_location)
    )

@property
def total_demand(self) -> int:
    """Sum of all visit demands."""
    return sum(visit.demand for visit in self.visits)

@property
def total_driving_time_seconds(self) -> int:
    """Total travel time including return to depot."""
    # Includes depot → first visit, between visits, and last visit → depot
```

These properties enable constraints to easily evaluate route feasibility and quality.

**Optimization concept:** Using a **list variable** for the route means the solver simultaneously solves:
1. **Assignment**: Which vehicle serves which customers?
2. **Sequencing**: In what order should each vehicle visit its customers?

This is more powerful than separate assignment and routing phases.

### The VehicleRoutePlan Class (Planning Solution)

```python
@planning_solution
@dataclass
class VehicleRoutePlan:
    name: str
    south_west_corner: Location                        # Map bounds
    north_east_corner: Location                        # Map bounds
    vehicles: Annotated[list[Vehicle], PlanningEntityCollectionProperty]
    visits: Annotated[list[Visit], PlanningEntityCollectionProperty, ValueRangeProvider]
    score: Annotated[Optional[HardSoftScore], PlanningScore] = None
    solver_status: SolverStatus = SolverStatus.NOT_SOLVING
```

**What it represents:** The complete routing problem and its solution.

**Key fields:**
- `vehicles`: All available vehicles (planning entities)
- `visits`: All customer visits to be routed (planning entities + value range)
- `score`: Solution quality metric
- Map bounds: Used for visualization

**Annotations explained:**
- `@planning_solution`: Marks this as the top-level problem definition
- `PlanningEntityCollectionProperty`: Collections of entities being optimized
- `ValueRangeProvider`: The `visits` list provides possible values for vehicle assignments
- `PlanningScore`: Where the solver stores calculated quality

**Optimization concept:** Unlike employee scheduling where only shifts are entities, here **both vehicles and visits are planning entities**. Vehicles have list variables (routes), and visits have shadow variables tracking their position in routes.

---

## How Route Optimization Works

Before diving into constraints, let's understand route construction.

### The Route Chaining Mechanism

Routes are built using **shadow variable chaining**:

1. **Solver modifies**: `vehicle.visits = [visit_A, visit_B, visit_C]`

2. **Shadow variables automatically update:**
   - Each visit's `vehicle` points to the vehicle
   - Each visit's `previous_visit` and `next_visit` link the chain
   - Each visit's `arrival_time` cascades through the chain

3. **Arrival time cascade:**
   ```
   visit_A.arrival_time = vehicle.departure_time + travel(depot → A)
   visit_B.arrival_time = visit_A.departure_time + travel(A → B)
   visit_C.arrival_time = visit_B.departure_time + travel(B → C)
   ```

4. **Constraints evaluate**: Check capacity, time windows, and distance

**Optimization concept:** This is **incremental score calculation**. When the solver moves one visit, only affected arrival times recalculate — not the entire solution. This enables evaluating millions of route modifications per second.

**Why this matters for performance:** Shadow variables enable efficient incremental updates. With Pydantic models, validation overhead would occur on every update—compounding across millions of moves per second. The dataclass approach avoids this overhead entirely. See [benchmark analysis](/blog/technical/python-constraint-solver-architecture/#object-equality-in-hot-paths) for details on this architectural choice.

### The Search Process

1. **Initial solution**: Often all visits unassigned or randomly assigned
2. **Evaluate score**: Calculate capacity violations, time window violations, and total distance
3. **Make a move**: 
   - Assign visit to different vehicle
   - Change visit order in a route
   - Swap visits between routes
4. **Re-evaluate score** (incrementally)
5. **Accept if improvement** (with controlled randomness to escape local optima)
6. **Repeat millions of times**
7. **Return best solution found**

**Metaheuristics used:**
- **Variable Neighborhood Descent**: Tries different types of moves
- **Late Acceptance**: Accepts solutions close to recent best
- **Strategic Oscillation**: Temporarily allows infeasibility to explore more space

### The Score: Measuring Route Quality

Every solution gets a score with two parts:

```
0hard/-45657soft
```

- **Hard score**: Counts capacity overages and time window violations (must be 0)
- **Soft score**: Total driving time in seconds (lower magnitude is better)

**Examples:**
- `-120hard/-50000soft`: Infeasible (120 minutes late or 120 units over capacity)
- `0hard/-45657soft`: Feasible route with 45,657 seconds (12.7 hours) driving
- `0hard/-30000soft`: Better route with only 30,000 seconds (8.3 hours) driving

**Optimization concept:** The scoring system implements **constraint prioritization**. We absolutely require capacity and time window compliance before optimizing distance.

---

## Writing Constraints: The Business Rules

Now the heart of the system. Open `src/vehicle_routing/constraints.py`.

### The Constraint Provider Pattern

All constraints are registered in one function:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # Hard constraints (must satisfy)
        vehicle_capacity(constraint_factory),
        service_finished_after_max_end_time(constraint_factory),
        # Soft constraints (minimize)
        minimize_travel_time(constraint_factory),
    ]
```

Let's examine each constraint in detail.

### Hard Constraint: Vehicle Capacity

**Business rule:** "A vehicle's total customer demand cannot exceed its capacity."

```python
def vehicle_capacity(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Vehicle)
        .filter(lambda vehicle: vehicle.calculate_total_demand() > vehicle.capacity)
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda vehicle: vehicle.calculate_total_demand() - vehicle.capacity
        )
        .as_constraint("vehicleCapacity")
    )
```

**How to read this:**
1. `for_each(Vehicle)`: Consider every vehicle
2. `.filter(...)`: Keep only vehicles exceeding capacity
3. `.penalize(ONE_HARD, ...)`: Penalize by the amount of excess demand (overage)
4. `.as_constraint(...)`: Name it for debugging

**Why penalize by overage amount?**

Example scenarios:
- Vehicle capacity: 100 units
- Assigned demand: 80 units → No penalty (feasible)
- Assigned demand: 105 units → Penalty of 5 hard points (5 units over)
- Assigned demand: 120 units → Penalty of 20 hard points (20 units over)

**Optimization concept:** This creates **graded penalties** that guide the solver. Being slightly over capacity (penalty 5) is "less wrong" than being very over (penalty 20), helping the solver navigate toward feasibility incrementally.

**Implementation detail:** The `calculate_total_demand()` method in `domain.py`:

```python
def calculate_total_demand(self) -> int:
    return sum(visit.demand for visit in self.visits)
```

### Hard Constraint: Time Window Compliance

**Business rule:** "Service at each customer must finish before their deadline (max_end_time)."

```python
def service_finished_after_max_end_time(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Visit)
        .filter(lambda visit: visit.is_service_finished_after_max_end_time())
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda visit: visit.service_finished_delay_in_minutes()
        )
        .as_constraint("serviceFinishedAfterMaxEndTime")
    )
```

**How to read this:**
1. `for_each(Visit)`: Consider every customer visit
2. `.filter(...)`: Keep only visits finishing after their deadline
3. `.penalize(ONE_HARD, ...)`: Penalize by minutes late

**Example scenario:**

Customer has `max_end_time = 18:00` (6 PM deadline):
- Arrive at 17:00, 30-minute service → Finish at 17:30 → No penalty (on time)
- Arrive at 17:50, 30-minute service → Finish at 18:20 → Penalty of 20 minutes
- Arrive at 19:00, 30-minute service → Finish at 19:30 → Penalty of 90 minutes

**Wait time handling:**

If vehicle arrives before `min_start_time`, it waits:
```python
def calculate_departure_time(self) -> datetime:
    # If arrive at 7:00 but min_start_time is 8:00, wait until 8:00
    return max(self.arrival_time, self.min_start_time) + self.service_duration
```

**Optimization concept:** Time windows create **temporal dependencies** in routes. The order of visits affects whether deadlines can be met. The solver must balance early visits (to respect time windows) with short distances (to minimize travel).

**Helper methods in `domain.py`:**

```python
def is_service_finished_after_max_end_time(self) -> bool:
    """Check deadline violation."""
    if self.arrival_time is None:
        return False
    return self.calculate_departure_time() > self.max_end_time

def service_finished_delay_in_minutes(self) -> int:
    """Calculate penalty magnitude."""
    if not self.is_service_finished_after_max_end_time():
        return 0
    delay = self.calculate_departure_time() - self.max_end_time
    return int(delay.total_seconds() / 60)
```

### Soft Constraint: Minimize Total Distance

**Business rule:** "Minimize the total driving time across all vehicles."

```python
def minimize_travel_time(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Vehicle)
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda vehicle: vehicle.calculate_total_driving_time_seconds()
        )
        .as_constraint("minimizeTravelTime")
    )
```

**How to read this:**
1. `for_each(Vehicle)`: Consider every vehicle
2. `.penalize(ONE_SOFT, ...)`: Penalize by total driving seconds for that vehicle
3. No filter: Every vehicle contributes to the soft score

**Why penalize all vehicles?**

Each vehicle's driving time adds to the penalty:
- Vehicle 1: 10,000 seconds → -10,000 soft score
- Vehicle 2: 15,000 seconds → -15,000 soft score
- Vehicle 3: 8,000 seconds → -8,000 soft score
- **Total soft score: -33,000**

The solver tries different route configurations to reduce this total.

**Optimization concept:** This constraint implements the **routing objective function**. After ensuring feasibility (hard constraints), the solver focuses on minimizing this distance measure.

**Implementation detail in `domain.py`:**

```python
def calculate_total_driving_time_seconds(self) -> int:
    """Total travel time including depot → first → ... → last → depot."""
    if not self.visits:
        return 0
    
    total = 0
    
    # Depot to first visit
    total += self.home_location.driving_time_to(self.visits[0].location)
    
    # Between consecutive visits
    for i in range(len(self.visits) - 1):
        total += self.visits[i].location.driving_time_to(self.visits[i + 1].location)
    
    # Last visit back to depot
    total += self.visits[-1].location.driving_time_to(self.home_location)
    
    return total
```

**Why include depot return?** Real routes must return vehicles to the depot. Not including this would incentivize ending routes far from the depot.

---

## The Solver Engine

Now let's see how the solver is configured. Open `src/vehicle_routing/solver.py`:

```python
solver_config = SolverConfig(
    solution_class=VehicleRoutePlan,
    entity_class_list=[Vehicle, Visit],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(spent_limit=Duration(seconds=30)),
)

solver_manager = SolverManager.create(solver_config)
solution_manager = SolutionManager.create(solver_manager)
```

### Configuration Breakdown

**`solution_class`**: Your planning solution class (`VehicleRoutePlan`)

**`entity_class_list`**: **Both** `Vehicle` and `Visit` are planning entities
- `Vehicle` has a planning variable (`visits` list)
- `Visit` has shadow variables that depend on vehicle assignments

**`score_director_factory_config`**: Contains the constraint provider function
- This is where your business rules are registered

**`termination_config`**: When to stop solving
- `spent_limit=Duration(seconds=30)`: Stop after 30 seconds
- Could also use: `unimproved_spent_limit` (stop if no improvement for X seconds)

### SolverManager: Asynchronous Solving

Routing problems can take time to solve well. `SolverManager` handles solving in the background:

```python
# Start solving (non-blocking)
solver_manager.solve_and_listen(job_id, route_plan, callback_function)

# Check status
status = solver_manager.get_solver_status(job_id)

# Get current best solution (updates in real-time)
solution = solver_manager.get_final_best_solution(job_id)

# Stop early if satisfied
solver_manager.terminate_early(job_id)
```

**Optimization concept:** Vehicle routing uses **anytime algorithms** that continuously improve solutions. You get a valid answer quickly, then progressively better answers as solving continues. You can stop whenever the solution is "good enough."

### SolutionManager: Score Analysis

The `solution_manager` helps explain scores:

```python
solution_manager = SolutionManager.create(solver_manager)

# Analyze which constraints fired and why
analysis = solution_manager.analyze(route_plan)

# Shows breakdown like:
# - Vehicle capacity: -50 hard (Vehicle 1: 20 over, Vehicle 2: 30 over)
# - Time windows: -15 hard (Visit 42: 15 minutes late)
# - Total distance: -45657 soft
```

This is invaluable for debugging infeasible solutions or understanding score composition.

### Solving Timeline

**Small problems** (20-30 visits, 2-3 vehicles):
- Initial valid solution: < 1 second
- Good solution: 5-10 seconds  
- High-quality: 30 seconds

**Medium problems** (50-100 visits, 5-8 vehicles):
- Initial valid solution: 1-5 seconds
- Good solution: 30-60 seconds
- High-quality: 2-5 minutes

**Large problems** (200+ visits, 10+ vehicles):
- Initial valid solution: 5-30 seconds
- Good solution: 5-10 minutes
- High-quality: 30-60 minutes

**Factors affecting speed:**
- Number of visits (main factor)
- Number of vehicles (less impact than visits)
- How tight time windows are (tighter = harder)
- How tight capacity constraints are (fuller vehicles = less flexibility)

---

## Web Interface and API

### REST API Endpoints

Open `src/vehicle_routing/rest_api.py` to see the API. It runs on **port 8082** (different from employee scheduling's 8080).

#### GET /demo-data

Returns available demo datasets:

```json
["PHILADELPHIA", "HARTFORT", "FIRENZE"]
```

Each dataset uses real city coordinates with different problem sizes.

#### GET /demo-data/{demo_name}

Returns a specific demo dataset:

**Parameters:**
- `demo_name`: Name of the demo dataset (PHILADELPHIA, HARTFORT, FIRENZE)
- `routing` (query, optional): Routing mode - `haversine` (default) or `real_roads`

**Request:**
```
GET /demo-data/PHILADELPHIA?routing=haversine
```

**Response:**
```json
{
  "name": "demo",
  "southWestCorner": [39.7656, -76.8378],
  "northEastCorner": [40.7764, -74.9301],
  "vehicles": [
    {
      "id": "0",
      "name": "Alpha",
      "capacity": 25,
      "homeLocation": [40.5154, -75.3721],
      "departureTime": "2025-12-10T06:00:00",
      "visits": [],
      "totalDemand": 0,
      "totalDrivingTimeSeconds": 0
    }
  ],
  "visits": [
    {
      "id": "0",
      "name": "Amy Cole",
      "location": [40.7831, -74.9376],
      "demand": 1,
      "minStartTime": "2025-12-10T17:00:00",
      "maxEndTime": "2025-12-10T20:00:00",
      "serviceDuration": 420,
      "vehicle": null,
      "arrivalTime": null
    }
  ],
  "score": null,
  "solverStatus": null,
  "totalDrivingTimeSeconds": 0
}
```

**Field notes:**
- Coordinates are `[latitude, longitude]` arrays
- Times use ISO format strings
- `serviceDuration` is in seconds (420 = 7 minutes)
- Initially `vehicle` is null (unassigned) and `visits` lists are empty
- Vehicles have names from the phonetic alphabet (Alpha, Bravo, Charlie, etc.)
- Customer names are randomly generated from first/last name combinations

**Demo datasets:**
- **PHILADELPHIA**: 55 visits, 6 vehicles, moderate capacity (15-30)
- **HARTFORT**: 50 visits, 6 vehicles, tighter capacity (20-30)
- **FIRENZE**: 77 visits (largest), 6 vehicles, varied capacity (20-40)

#### GET /demo-data/{demo_name}/stream

Server-Sent Events (SSE) endpoint for loading demo data with progress updates. Use this when `routing=real_roads` to show download/computation progress.

**Parameters:**
- `demo_name`: Name of the demo dataset
- `routing` (query, optional): `haversine` (default) or `real_roads`

**Request:**
```
GET /demo-data/PHILADELPHIA/stream?routing=real_roads
```

**SSE Events:**

Progress event (during computation):
```json
{"event": "progress", "phase": "network", "message": "Downloading OpenStreetMap road network...", "percent": 10, "detail": "Area: 0.08° × 0.12°"}
```

Complete event (when ready):
```json
{"event": "complete", "solution": {...}, "geometries": {"0": ["encodedPolyline1", "encodedPolyline2"], "1": [...]}}
```

Error event (on failure):
```json
{"event": "error", "message": "Demo data not found: INVALID"}
```

**Geometry format:** Each vehicle's geometries are an array of encoded polylines (Google polyline format), one per route segment:
- First: depot → first visit
- Middle: visit → visit
- Last: last visit → depot

#### GET /route-plans/{problem_id}/geometry

Get route geometries for displaying actual road paths:

**Response:**
```json
{
  "geometries": {
    "0": ["_p~iF~ps|U_ulLnnqC_mqNvxq`@", "afvkFnps|U~hbE~reK"],
    "1": ["_izlFnps|U_ulLnnqC"]
  }
}
```

Decode polylines on the frontend to display actual road routes instead of straight lines.

#### POST /route-plans

Submit a routing problem to solve:

**Request body:** Same format as demo data response

**Response:** Job ID as plain text
```
"a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

**Implementation:**
```python
@app.post("/route-plans")
async def solve(problem: VehicleRoutePlanModel) -> str:
    job_id = str(uuid4())
    route_plan = model_to_plan(problem)
    data_sets[job_id] = route_plan
    
    solver_manager.solve_and_listen(
        job_id,
        route_plan,
        lambda solution: update_solution(job_id, solution)
    )
    
    return job_id
```

**Key detail:** Uses `solve_and_listen()` with a callback that updates the stored solution in real-time. This enables live progress tracking in the UI.

#### GET /route-plans/{problem_id}

Get current best solution:

**Request:**
```
GET /route-plans/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Response (while solving):**
```json
{
  "vehicles": [
    {
      "id": "vehicle_0",
      "visits": ["5", "12", "23", "7"],
      "totalDemand": 28,
      "totalDrivingTimeSeconds": 15420
    }
  ],
  "visits": [
    {
      "id": "5",
      "vehicle": "vehicle_0",
      "arrivalTime": "2025-11-27T08:15:30"
    }
  ],
  "score": "-15hard/-187594soft",
  "solverStatus": "SOLVING_ACTIVE"
}
```

**Response (finished):**
```json
{
  "score": "0hard/-45657soft",
  "solverStatus": "NOT_SOLVING"
}
```

**Important:** The response updates in real-time as solving progresses. Clients should poll this endpoint (e.g., every 2 seconds) to show live progress.

#### GET /route-plans

List all active job IDs:

**Response:**
```json
["a1b2c3d4-e5f6-7890-abcd-ef1234567890", "b2c3d4e5-f6a7-8901-bcde-f23456789012"]
```

#### GET /route-plans/{problem_id}/status

Lightweight status check (score and solver status only):

**Response:**
```json
{
  "name": "PHILADELPHIA",
  "score": "0hard/-45657soft",
  "solverStatus": "SOLVING_ACTIVE"
}
```

#### DELETE /route-plans/{problem_id}

Terminate solving early:

```python
@app.delete("/route-plans/{problem_id}")
async def stop_solving(problem_id: str) -> VehicleRoutePlanModel:
    solver_manager.terminate_early(problem_id)
    return plan_to_model(data_sets.get(problem_id))
```

Returns the best solution found so far. Useful if the user is satisfied with current quality and doesn't want to wait for the full 30 seconds.

#### POST /route-plans/recommendation

Request recommendations for assigning a new visit to vehicles:

**Request body:**
```json
{
  "solution": { /* complete route plan */ },
  "visitId": "new_visit_42"
}
```

**Response:**
```json
[
  {
    "proposition": {
      "vehicleId": "vehicle_2",
      "index": 3
    },
    "scoreDiff": "0hard/-1234soft"
  },
  {
    "proposition": {
      "vehicleId": "vehicle_0",
      "index": 5
    },
    "scoreDiff": "0hard/-2345soft"
  }
]
```

Returns up to 5 recommendations sorted by score impact. The first recommendation is the best option.

#### POST /route-plans/recommendation/apply

Apply a selected recommendation:

**Request body:**
```json
{
  "solution": { /* complete route plan */ },
  "visitId": "new_visit_42",
  "vehicleId": "vehicle_2",
  "index": 3
}
```

**Response:** Updated route plan with the visit inserted at the specified position.

#### PUT /route-plans/analyze

Analyze a solution's score breakdown:

**Request body:** Complete route plan (assigned solution)

**Response:**
```json
{
  "score": "-20hard/-45657soft",
  "constraints": [
    {
      "name": "Vehicle capacity",
      "score": "-20hard/0soft",
      "matches": [
        {
          "justification": "Vehicle vehicle_2 exceeds capacity by 20 units",
          "score": "-20hard/0soft"
        }
      ]
    },
    {
      "name": "Minimize travel time", 
      "score": "0hard/-45657soft",
      "matches": [
        {
          "justification": "Vehicle vehicle_0 drives 12345 seconds",
          "score": "0hard/-12345soft"
        }
      ]
    }
  ]
}
```

This is invaluable for understanding **why** a solution has a particular score and **which** constraints are violated.

### Web UI Flow

The `static/app.js` implements this workflow:

1. **User opens page** → Load demo data (`GET /demo-data/PHILADELPHIA`)
2. **Display map** with:
   - Depot marked as home icon
   - Customer locations as numbered markers
   - Sidebar showing visit details
3. **User clicks "Solve"** → `POST /route-plans` (get job ID)
4. **Poll** `GET /route-plans/{id}` every 2 seconds
5. **Update UI** with:
   - Routes drawn as colored lines connecting visits
   - Each vehicle's route in different color
   - Stats: total distance, capacity used, time windows status
6. **When** `solverStatus === "NOT_SOLVING"` → Stop polling
7. **Display** final score and route statistics

**Visual features:**
- Color-coded routes (one color per vehicle)
- Depot-to-depot complete routes visualized
- Visit details on hover (arrival time, demand, time window status)
- Stats panel showing capacity utilization and total distance per vehicle

---

## Making Your First Customization

Let's add a new constraint step-by-step.

### Scenario: Limit Maximum Route Duration

**New business rule:** "No vehicle can be out for more than 8 hours (from depot departure to depot return)."

This is a **hard constraint** (must be satisfied).

### Step 1: Open constraints.py

Navigate to `src/vehicle_routing/constraints.py`.

### Step 2: Write the Constraint Function

Add this function:

```python
def max_route_duration(constraint_factory: ConstraintFactory):
    """
    Hard constraint: Vehicle routes cannot exceed 8 hours total duration.
    """
    MAX_DURATION_SECONDS = 8 * 60 * 60  # 8 hours
    
    return (
        constraint_factory.for_each(Vehicle)
        .filter(lambda vehicle: len(vehicle.visits) > 0)  # Skip empty vehicles
        .filter(lambda vehicle: 
            (vehicle.arrival_time - vehicle.departure_time).total_seconds() 
            > MAX_DURATION_SECONDS
        )
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda vehicle: int(
                ((vehicle.arrival_time - vehicle.departure_time).total_seconds() 
                 - MAX_DURATION_SECONDS) / 60
            )
        )
        .as_constraint("Max route duration 8 hours")
    )
```

**How this works:**
1. Examine each vehicle with visits
2. Calculate total time: depot departure → visit customers → depot return
3. If exceeds 8 hours, penalize by excess minutes
4. Example: 9-hour route → 60-minute penalty

**Why penalize by excess?** A 8.5-hour route (penalty 30 minutes) is closer to feasible than a 12-hour route (penalty 240 minutes), guiding the solver incrementally.

### Step 3: Register the Constraint

Add it to the `define_constraints` function:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # Hard constraints
        vehicle_capacity(constraint_factory),
        service_finished_after_max_end_time(constraint_factory),
        max_route_duration(constraint_factory),  # ← Add this line
        # Soft constraints
        minimize_travel_time(constraint_factory),
    ]
```

### Step 4: Test It

1. **Restart the server:**
   ```bash
   run-app
   ```

2. **Load demo data and solve:**
   - Open http://localhost:8082
   - Load PHILADELPHIA dataset
   - Click "Solve"

3. **Verify constraint:**
   - Check vehicle stats in the UI
   - Each vehicle's total time should be ≤ 8 hours
   - If infeasible, some vehicles may still exceed (hard score < 0)

**Testing tip:** Temporarily lower the limit to 4 hours to see the constraint actively preventing long routes. You might get an infeasible solution (negative hard score) showing the constraint is working but can't be satisfied with current vehicles.

### Step 5: Make It Configurable

For production use, make the limit configurable per vehicle:

**Modify domain.py:**
```python
@dataclass
class Vehicle:
    id: Annotated[str, PlanningId]
    name: str
    capacity: int
    home_location: Location
    departure_time: datetime
    max_duration_seconds: int = 8 * 60 * 60  # New field with default
    visits: Annotated[list[Visit], PlanningListVariable] = field(default_factory=list)
```

**Update constraint:**
```python
def max_route_duration(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Vehicle)
        .filter(lambda vehicle: len(vehicle.visits) > 0)
        .filter(lambda vehicle: 
            (vehicle.arrival_time - vehicle.departure_time).total_seconds() 
            > vehicle.max_duration_seconds  # Use vehicle-specific limit
        )
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda vehicle: int(
                ((vehicle.arrival_time - vehicle.departure_time).total_seconds() 
                 - vehicle.max_duration_seconds) / 60
            )
        )
        .as_constraint("Max route duration")
    )
```

Now each vehicle can have a different maximum duration.

### Understanding What You Did

You just implemented a **temporal constraint** — limiting time-based aspects of routes. This pattern is common in routing:

- Driver shift limits (8-hour, 10-hour, etc.)
- Maximum distance per route
- Required breaks after X hours
- Service windows for depot operations

The pattern is always:
1. Calculate the temporal/distance measure
2. Compare to limit
3. Penalize by the excess amount (for graded guidance)

---

## Advanced Constraint Patterns

### Pattern 1: Priority Customers

**Scenario:** Some customers are high-priority and should be served earlier in their vehicle's route.

```python
def priority_customers_early(constraint_factory: ConstraintFactory):
    """
    Soft constraint: High-priority customers should be visited early in route.
    """
    HIGH_PRIORITY_CUSTOMERS = {"Customer A", "Customer B"}
    
    return (
        constraint_factory.for_each(Visit)
        .filter(lambda visit: visit.name in HIGH_PRIORITY_CUSTOMERS)
        .filter(lambda visit: visit.vehicle is not None)  # Assigned visits only
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda visit: visit.vehicle.visits.index(visit) * 100
        )
        .as_constraint("Priority customers early")
    )
```

**How it works:** Penalize by position in route × weight:
- 1st position: penalty 0
- 2nd position: penalty 100
- 5th position: penalty 400

This incentivizes placing priority customers earlier without making it a hard requirement.

**Optimization concept:** This implements **soft sequencing preferences**. Unlike hard sequencing (e.g., "A must come before B"), this just prefers certain orders.

### Pattern 2: Vehicle-Customer Compatibility

**Scenario:** Certain vehicles cannot serve certain customers (e.g., refrigerated trucks for frozen goods, size restrictions).

First, add compatibility data to domain:

```python
@dataclass
class Vehicle:
    # ... existing fields ...
    vehicle_type: str = "standard"  # e.g., "refrigerated", "large", "standard"

@dataclass
class Visit:
    # ... existing fields ...
    required_vehicle_type: Optional[str] = None  # None = any vehicle OK
```

Then the constraint:

```python
def vehicle_customer_compatibility(constraint_factory: ConstraintFactory):
    """
    Hard constraint: Only compatible vehicles can serve customers.
    """
    return (
        constraint_factory.for_each(Visit)
        .filter(lambda visit: visit.required_vehicle_type is not None)
        .filter(lambda visit: visit.vehicle is not None)
        .filter(lambda visit: visit.vehicle.vehicle_type != visit.required_vehicle_type)
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Vehicle customer compatibility")
    )
```

### Pattern 3: Balanced Workload Across Vehicles

**Scenario:** Distribute visits evenly across vehicles (avoid one vehicle doing everything).

```python
def balance_vehicle_workload(constraint_factory: ConstraintFactory):
    """
    Soft constraint: Balance number of visits across vehicles.
    """
    return (
        constraint_factory.for_each(Vehicle)
        .group_by(
            ConstraintCollectors.count_distinct(lambda vehicle: vehicle)
        )
        .complement(Vehicle, lambda v: 0)  # Include empty vehicles
        .group_by(
            ConstraintCollectors.load_balance(
                lambda vehicle: vehicle,
                lambda vehicle: len(vehicle.visits)
            )
        )
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda load_balance: int(load_balance.unfairness() * 100)
        )
        .as_constraint("Balance workload")
    )
```

**Optimization concept:** This uses the **load balancing collector** which calculates variance in workload distribution. It's more sophisticated than simple quadratic penalties.

### Pattern 4: Break Requirements

**Scenario:** Drivers must take a 30-minute break after 4 hours of driving.

This requires modeling breaks explicitly:

```python
@dataclass
class Break:
    """Represents a required break in a vehicle's route."""
    id: str
    duration: timedelta = timedelta(minutes=30)
    min_driving_before: timedelta = timedelta(hours=4)

@dataclass
class Vehicle:
    # ... existing fields ...
    required_breaks: list[Break] = field(default_factory=list)
```

Then a complex constraint checking cumulative driving time:

```python
def break_enforcement(constraint_factory: ConstraintFactory):
    """
    Hard constraint: Breaks must occur within required intervals.
    """
    # Implementation would track cumulative driving time and verify
    # breaks are inserted appropriately in the route
    # This is advanced and requires careful handling of route chains
    pass
```

**Note:** Break enforcement is complex and often requires custom move selectors to ensure breaks are positioned correctly. This is beyond basic constraint writing.

### Pattern 5: Distance Limits

**Scenario:** Each vehicle has a maximum total distance it can travel (fuel constraint).

```python
def max_vehicle_distance(constraint_factory: ConstraintFactory):
    """
    Hard constraint: Vehicle cannot exceed maximum distance.
    """
    return (
        constraint_factory.for_each(Vehicle)
        .filter(lambda vehicle: len(vehicle.visits) > 0)
        .filter(lambda vehicle: 
            vehicle.calculate_total_driving_time_seconds() 
            > vehicle.max_driving_seconds  # New field needed
        )
        .penalize(
            HardSoftScore.ONE_HARD,
            lambda vehicle: int(
                (vehicle.calculate_total_driving_time_seconds() 
                 - vehicle.max_driving_seconds) / 60
            )
        )
        .as_constraint("Max vehicle distance")
    )
```

You'd need to add `max_driving_seconds` to the `Vehicle` class in `domain.py`.

---

## Testing and Validation

### Unit Testing Constraints

Best practice: Test each constraint in isolation without running full solver.

Open `tests/test_constraints.py` to see examples:

```python
from vehicle_routing.domain import Vehicle, Visit, Location, VehicleRoutePlan
from vehicle_routing.constraints import define_constraints
from solverforge_legacy.solver.test import ConstraintVerifier

# Create verifier with your constraints
constraint_verifier = ConstraintVerifier.build(
    define_constraints,
    VehicleRoutePlan,
    Vehicle,
    Visit
)
```

**Example: Test Capacity Constraint**

```python
def test_vehicle_capacity_unpenalized():
    """Capacity within limit should not penalize."""
    vehicle = Vehicle(
        id="v1",
        name="Alpha",
        capacity=100,
        home_location=Location(0.0, 0.0),
        departure_time=datetime(2025, 11, 27, 8, 0)
    )

    visit = Visit(
        id="visit1",
        name="Customer A",
        location=Location(1.0, 1.0),
        demand=80,  # Within capacity
        min_start_time=datetime(2025, 11, 27, 9, 0),
        max_end_time=datetime(2025, 11, 27, 18, 0),
        service_duration=timedelta(minutes=30)
    )

    # Connect visit to vehicle (helper from tests)
    connect(vehicle, visit)

    # Verify no penalty
    constraint_verifier.verify_that(vehicle_capacity) \
        .given(vehicle, visit) \
        .penalizes_by(0)

def test_vehicle_capacity_penalized():
    """Exceeding capacity should penalize by overage amount."""
    vehicle = Vehicle(id="v1", name="Alpha", capacity=100, ...)

    visit1 = Visit(id="v1", demand=80, ...)
    visit2 = Visit(id="v2", demand=40, ...)  # Total 120 > 100

    connect(vehicle, visit1, visit2)

    # Should penalize by 20 (overage amount)
    constraint_verifier.verify_that(vehicle_capacity) \
        .given(vehicle, visit1, visit2) \
        .penalizes_by(20)
```

**Helper function for tests:**

```python
def connect(vehicle: Vehicle, *visits: Visit):
    """Helper to set up vehicle-visit relationships."""
    vehicle.visits = list(visits)
    
    for i, visit in enumerate(visits):
        visit.vehicle = vehicle
        visit.previous_visit = visits[i - 1] if i > 0 else None
        visit.next_visit = visits[i + 1] if i < len(visits) - 1 else None
        
        # Calculate arrival times
        if i == 0:
            travel_time = vehicle.home_location.driving_time_to(visit.location)
            visit.arrival_time = vehicle.departure_time + timedelta(seconds=travel_time)
        else:
            travel_time = visits[i-1].location.driving_time_to(visit.location)
            visit.arrival_time = visits[i-1].calculate_departure_time() + timedelta(seconds=travel_time)
```

**Example: Test Time Window Constraint**

```python
def test_time_window_violation():
    """Finishing after deadline should penalize by delay minutes."""
    vehicle = Vehicle(
        id="v1",
        name="Alpha",
        departure_time=datetime(2025, 11, 27, 7, 0),
        ...
    )

    visit = Visit(
        id="visit1",
        max_end_time=datetime(2025, 11, 27, 12, 0),  # Noon deadline
        service_duration=timedelta(minutes=30),
        ...
    )

    # Set arrival causing late finish
    visit.arrival_time = datetime(2025, 11, 27, 11, 45)  # Arrive 11:45
    # Service ends at 12:15 (30 min service) → 15 minutes late

    constraint_verifier.verify_that(service_finished_after_max_end_time) \
        .given(visit) \
        .penalizes_by(15)
```

**Run tests:**
```bash
pytest tests/test_constraints.py -v
```

### Integration Testing: Full Solve

Test the complete solving cycle in `tests/test_feasible.py`:

```python
import time
from vehicle_routing.demo_data import DemoData, generate_demo_data
from vehicle_routing.solver import solver_manager

def test_solve_philadelphia():
    """Test that solver finds feasible solution for Philadelphia dataset."""
    
    # Get demo problem
    route_plan = generate_demo_data(DemoData.PHILADELPHIA)
    
    # Verify initially unassigned
    assert all(visit.vehicle is None for visit in route_plan.visits)
    assert all(len(vehicle.visits) == 0 for vehicle in route_plan.vehicles)
    
    # Start solving
    job_id = "test-philadelphia"
    solver_manager.solve(job_id, route_plan)
    
    # Wait for completion (with timeout)
    max_wait = 120  # 2 minutes
    start = time.time()
    
    while solver_manager.get_solver_status(job_id) != "NOT_SOLVING":
        if time.time() - start > max_wait:
            solver_manager.terminate_early(job_id)
            break
        time.sleep(2)
    
    # Get solution
    solution = solver_manager.get_final_best_solution(job_id)
    
    # Verify all visits assigned
    unassigned = [v for v in solution.visits if v.vehicle is None]
    assert len(unassigned) == 0, f"{len(unassigned)} visits remain unassigned"
    
    # Verify feasible (hard score = 0)
    assert solution.score is not None
    assert solution.score.hard_score == 0, \
        f"Solution infeasible with hard score {solution.score.hard_score}"
    
    # Report quality
    print(f"Final score: {solution.score}")
    print(f"Total driving time: {solution.score.soft_score / -1} seconds")
    
    # Verify route integrity
    for vehicle in solution.vehicles:
        if vehicle.visits:
            # Check capacity
            total_demand = sum(v.demand for v in vehicle.visits)
            assert total_demand <= vehicle.capacity, \
                f"Vehicle {vehicle.id} over capacity: {total_demand}/{vehicle.capacity}"
            
            # Check time windows
            for visit in vehicle.visits:
                assert not visit.is_service_finished_after_max_end_time(), \
                    f"Visit {visit.id} finishes late"
```

**Run integration tests:**
```bash
pytest tests/test_feasible.py -v
```

### Manual Testing via UI

1. **Start the application:**
   ```bash
   run-app
   ```

2. **Open browser console** (F12) to see API calls and responses

3. **Load demo data:**
   - Select "PHILADELPHIA" from dropdown
   - Verify map shows 55 customer markers + 1 depot
   - Check visit list shows all customers unassigned

4. **Solve and observe:**
   - Click "Solve"
   - Watch score improve in real-time
   - See routes appear on map (colored lines)
   - Monitor stats panel for capacity and time info

5. **Verify solution quality:**
   - Final hard score should be 0 (feasible)
   - All visits should be assigned (no gray markers)
   - Routes should form complete loops (depot → customers → depot)
   - Check vehicle stats: demand ≤ capacity for each

6. **Test different datasets:**
   - Try HARTFORT (tighter capacity constraints)
   - Try FIRENZE (more visits, harder problem)
   - Compare solve times and final scores

7. **Test early termination:**
   - Start solving FIRENZE
   - Click "Stop" after 10 seconds
   - Verify you get a partial solution (may be infeasible)

8. **Test with different datasets:**
   - Try PHILADELPHIA (55 visits), HARTFORT (50 visits), and FIRENZE (77 visits)
   - Larger datasets take longer to solve but demonstrate scalability

---

## Production Considerations

### Performance: Constraint Evaluation Speed

Constraints are evaluated **millions of times per second** during solving. Performance is critical.

**❌ DON'T: Expensive operations in constraints**

```python
def bad_constraint(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Visit)
        .filter(lambda visit: 
            fetch_customer_credit_score(visit.name) < 500)  # API call!
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Bad")
    )
```

**✅ DO: Pre-compute before solving**

```python
# Before solving, once
blocked_customers = {
    name for name, score in fetch_all_credit_scores().items()
    if score < 500
}

def good_constraint(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Visit)
        .filter(lambda visit: visit.name in blocked_customers)  # Fast set lookup
        .penalize(HardSoftScore.ONE_HARD)
        .as_constraint("Good")
    )
```

**Performance tips:**
- **Pre-compute** expensive calculations (distances, lookup tables)
- **Cache** property calculations in domain objects if safe
- **Avoid** loops and complex logic in lambda functions
- **Use** efficient data structures (sets for membership, dicts for lookup)

### Distance Calculation: Two Modes

This quickstart supports two routing modes, selectable via the UI toggle or API parameter:

#### Haversine Mode (Default)

Fast great-circle distance calculation using the Haversine formula:
- No external dependencies or network calls
- Assumes 50 km/h average driving speed
- Routes display as straight lines on the map
- Best for: development, testing, and quick iterations

#### Real Roads Mode

Actual road network routing using OpenStreetMap data via OSMnx:
- Downloads and caches road network data locally
- Computes shortest paths using Dijkstra's algorithm
- Routes display as actual road paths on the map
- Progress streaming via Server-Sent Events (SSE)

**First-time use:** The initial load downloads ~5-15 MB of road network data for the demo area (cached for subsequent runs).

**How it works:**
1. Enable "Real Roads" toggle in the UI before loading demo data
2. The system downloads/loads the OSM road network for the bounding box
3. A distance matrix is precomputed for all location pairs
4. The solver uses real driving times; the UI displays actual road routes

```python
# The Location class automatically uses the distance matrix when set
Location.set_distance_matrix(matrix)

# Solver calls driving_time_to() which checks for matrix first
time = loc1.driving_time_to(loc2)  # Uses matrix if available, else haversine
```

### Custom Routing APIs

For production with proprietary routing (Google Maps, Mapbox, OSRM), pre-compute a distance matrix before solving:

```python
def build_real_distance_matrix(locations):
    """Fetch actual driving times from routing API (run once, before solving)."""
    matrix = {}
    for loc1 in locations:
        for loc2 in locations:
            if loc1 != loc2:
                # Call Google Maps / Mapbox / OSRM once per pair
                matrix[(loc1, loc2)] = call_routing_api(loc1, loc2)
    return matrix
```

**Never** call external APIs during solving — pre-compute everything.

### Scaling Strategies

**Problem size guidelines (30 second solve):**
- Up to 100 visits × 5 vehicles: Good solutions
- 100-200 visits: Increase solve time to 2-5 minutes
- 200-500 visits: Increase to 10-30 minutes
- 500+ visits: Consider decomposition strategies

**Decomposition approaches:**

**Geographic clustering:**
```python
# Split large problem into regions
north_region_visits = [v for v in visits if v.location.latitude > 40.5]
south_region_visits = [v for v in visits if v.location.latitude <= 40.5]

# Solve each region separately
north_solution = solve(north_vehicles, north_region_visits)
south_solution = solve(south_vehicles, south_region_visits)
```

**Time-based decomposition:**
```python
# Solve AM deliveries, then PM deliveries
am_visits = [v for v in visits if v.max_end_time.hour < 13]
pm_visits = [v for v in visits if v.min_start_time.hour >= 13]
```

**Multi-day routing:**
```python
# Route planning for weekly schedule
for day in ["Monday", "Tuesday", "Wednesday", ...]:
    day_visits = get_visits_for_day(day)
    solution = solve(vehicles, day_visits)
    save_solution(day, solution)
```

### Handling Infeasible Problems

Sometimes no feasible solution exists (e.g., time windows impossible to meet, insufficient vehicle capacity).

**Detect and report:**

```python
solution = solver_manager.get_final_best_solution(job_id)

if solution.score.hard_score < 0:
    # Analyze what's infeasible
    unassigned = [v for v in solution.visits if v.vehicle is None]
    over_capacity = [
        v for v in solution.vehicles 
        if v.calculate_total_demand() > v.capacity
    ]
    late_visits = [
        v for v in solution.visits 
        if v.is_service_finished_after_max_end_time()
    ]
    
    return {
        "status": "infeasible",
        "hard_score": solution.score.hard_score,
        "issues": {
            "unassigned_visits": len(unassigned),
            "capacity_violations": len(over_capacity),
            "time_window_violations": len(late_visits)
        },
        "suggestions": [
            "Add more vehicles" if unassigned else None,
            "Increase vehicle capacity" if over_capacity else None,
            "Relax time windows" if late_visits else None
        ]
    }
```

**Relaxation strategies:**

1. **Soft capacity violations:**
   ```python
   # Change capacity from hard to soft constraint
   .penalize(HardSoftScore.ONE_SOFT, lambda v: v.total_demand - v.capacity)
   ```

2. **Penalized unassigned visits:**
   ```python
   # Allow unassigned visits with large penalty
   factory.for_each(Visit)
       .filter(lambda v: v.vehicle is None)
       .penalize(HardSoftScore.of_soft(100000))
   ```

3. **Flexible time windows:**
   ```python
   # Allow late arrivals with graduated penalty
   .penalize(HardSoftScore.ONE_SOFT, lambda v: v.service_finished_delay_in_minutes())
   ```

### Real-Time Routing Adjustments

**Scenario:** Need to re-route due to:
- New urgent orders received
- Vehicle breakdown
- Traffic delays

**Dynamic re-routing:**

```python
def add_urgent_visit(current_solution: VehicleRoutePlan, new_visit: Visit):
    """Add urgent visit and re-optimize."""
    
    # Add to problem
    current_solution.visits.append(new_visit)
    
    # Use current solution as warm start
    job_id = f"urgent-{uuid4()}"
    solver_manager.solve_and_listen(
        job_id,
        current_solution,  # Starts from current routes
        callback,
        problem_change=ProblemChange.add_entity(new_visit)
    )
    
    return job_id

def handle_vehicle_breakdown(solution: VehicleRoutePlan, broken_vehicle_id: str):
    """Re-assign visits from broken vehicle."""
    
    broken_vehicle = next(v for v in solution.vehicles if v.id == broken_vehicle_id)
    
    # Unassign all visits from this vehicle
    for visit in broken_vehicle.visits:
        visit.vehicle = None
    broken_vehicle.visits = []
    
    # Mark vehicle unavailable
    broken_vehicle.capacity = 0
    
    # Re-solve
    solver_manager.solve_and_listen("emergency-replan", solution, callback)
```

**Optimization concept:** **Warm starting** from current solution makes re-routing much faster than solving from scratch. The solver starts with current routes and only modifies what's necessary.

### Monitoring and Logging

**Track key metrics:**

```python
import logging
import time

logger = logging.getLogger(__name__)

start_time = time.time()
solver_manager.solve_and_listen(job_id, route_plan, callback)

# ... wait for completion ...

solution = solver_manager.get_final_best_solution(job_id)
duration = time.time() - start_time

# Calculate metrics
total_visits = len(solution.visits)
total_vehicles = len(solution.vehicles)
assigned_visits = sum(1 for v in solution.visits if v.vehicle is not None)
total_distance = -solution.score.soft_score if solution.score else 0

logger.info(
    f"Solved route plan {job_id}: "
    f"duration={duration:.1f}s, "
    f"score={solution.score}, "
    f"visits={assigned_visits}/{total_visits}, "
    f"vehicles={total_vehicles}, "
    f"distance={total_distance}s"
)

# Alert if infeasible
if solution.score and solution.score.hard_score < 0:
    logger.warning(
        f"Infeasible solution for {job_id}: "
        f"hard_score={solution.score.hard_score}"
    )
```

**Production monitoring:**
- **Solve duration**: Alert if suddenly increases (data quality issue?)
- **Infeasibility rate**: Track percentage of infeasible solutions
- **Score trends**: Monitor if soft scores degrading over time
- **Capacity utilization**: Are vehicles underutilized? (might need fewer vehicles)
- **Time window tightness**: Frequent time violations? (might need more vehicles)

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Add/change business rule | `src/vehicle_routing/constraints.py` |
| Add field to Vehicle | `src/vehicle_routing/domain.py` + `converters.py` |
| Add field to Visit | `src/vehicle_routing/domain.py` + `converters.py` |
| Change solve time | `src/vehicle_routing/solver.py` |
| Change distance calculation | `src/vehicle_routing/routing.py` |
| Configure routing mode | `src/vehicle_routing/routing.py` |
| Add REST endpoint | `src/vehicle_routing/rest_api.py` |
| Change demo data | `src/vehicle_routing/demo_data.py` |
| Change UI/map | `static/index.html`, `static/app.js` |

### Common Constraint Patterns

**Unary constraint (single entity):**
```python
constraint_factory.for_each(Vehicle)
    .filter(lambda vehicle: # condition)
    .penalize(HardSoftScore.ONE_HARD)
```

**Filtering by route property:**
```python
constraint_factory.for_each(Vehicle)
    .filter(lambda vehicle: len(vehicle.visits) > 0)  # Has visits
    .filter(lambda vehicle: vehicle.calculate_total_demand() > vehicle.capacity)
    .penalize(...)
```

**Visit constraints:**
```python
constraint_factory.for_each(Visit)
    .filter(lambda visit: visit.vehicle is not None)  # Assigned only
    .filter(lambda visit: # condition)
    .penalize(...)
```

**Summing over vehicles:**
```python
constraint_factory.for_each(Vehicle)
    .penalize(
        HardSoftScore.ONE_SOFT,
        lambda vehicle: vehicle.calculate_total_driving_time_seconds()
    )
```

**Variable penalty amount:**
```python
.penalize(
    HardSoftScore.ONE_HARD,
    lambda entity: calculate_penalty_amount(entity)
)
```

### Common Domain Patterns

**Check if visit assigned:**
```python
if visit.vehicle is not None:
    # Visit is assigned to a vehicle
```

**Iterate through route:**
```python
for i, visit in enumerate(vehicle.visits):
    print(f"Stop {i+1}: {visit.name}")
```

**Calculate route metrics:**
```python
total_demand = sum(v.demand for v in vehicle.visits)
total_time = (vehicle.arrival_time - vehicle.departure_time).total_seconds()
avg_demand = total_demand / len(vehicle.visits) if vehicle.visits else 0
```

**Time calculations:**
```python
arrival = visit.arrival_time
service_start = max(arrival, visit.min_start_time)  # Wait if arrived early
service_end = service_start + visit.service_duration
is_late = service_end > visit.max_end_time
```

### Debugging Tips

**Enable verbose logging:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Analyze solution score:**
```python
from vehicle_routing.solver import solution_manager

analysis = solution_manager.analyze(route_plan)
print(analysis.summary())

# See detailed constraint breakdown
for constraint in analysis.constraint_analyses:
    print(f"{constraint.name}: {constraint.score}")
    for match in constraint.matches:
        print(f"  - {match.justification}")
```

**Test constraint in isolation:**
```python
from vehicle_routing.constraints import define_constraints
from solverforge_legacy.test import ConstraintVerifier

verifier = ConstraintVerifier.build(
    define_constraints,
    VehicleRoutePlan,
    Vehicle,
    Visit
)

# Test specific scenario
verifier.verify_that(vehicle_capacity) \
    .given(test_vehicle, test_visit) \
    .penalizes_by(expected_penalty)
```

**Visualize route in tests:**
```python
def print_route(vehicle: Vehicle):
    """Debug helper to print route."""
    print(f"Vehicle {vehicle.id}:")
    print(f"  Capacity: {vehicle.total_demand}/{vehicle.capacity}")
    print(f"  Route:")
    print(f"    Depot → {vehicle.departure_time}")
    for i, visit in enumerate(vehicle.visits):
        print(f"    {visit.name} → arrive {visit.arrival_time}, "
              f"depart {visit.calculate_departure_time()}")
    print(f"    Depot → {vehicle.arrival_time}")
```

### Common Gotchas

1. **Forgot to handle empty routes**
   - Check `len(vehicle.visits) > 0` before accessing route properties
   - Symptom: IndexError or None errors

2. **Shadow variables not updated**
   - Use the `connect()` helper in tests to properly link visits
   - In production, solver maintains these automatically
   - Symptom: arrival_time is None or incorrect

3. **Distance calculation too slow**
   - Pre-compute distance matrices before solving
   - Never call external APIs during constraint evaluation
   - Symptom: Solving extremely slow (< 100 evaluations/second)

4. **Forgot to register constraint**
   - Add to `define_constraints()` return list
   - Symptom: Constraint not enforced

5. **Time zone issues**
   - Use timezone-aware datetime objects consistently
   - Or use naive datetime (no timezone) consistently
   - Symptom: Time calculations off by hours

6. **Capacity violations not penalized**
   - Ensure `calculate_total_demand()` is used, not manual sum
   - Check filter logic: should penalize when demand > capacity
   - Symptom: Solutions with impossible loads

### Performance Benchmarks

**Typical evaluation speeds** (on modern hardware):

| Problem Size | Evaluations/Second | 30-Second Results |
|--------------|-------------------|-------------------|
| 20 visits, 2 vehicles | 10,000+ | Near-optimal |
| 50 visits, 5 vehicles | 5,000+ | High quality |
| 100 visits, 8 vehicles | 2,000+ | Good quality |
| 200 visits, 10 vehicles | 500-1000 | Decent quality |

If your speeds are significantly lower, review constraint complexity and pre-compute expensive operations.

---

## Conclusion

You now have a complete understanding of constraint-based vehicle routing:

✅ **Problem modeling** — How to represent routing problems with vehicles, visits, and locations  
✅ **Constraint logic** — How to express capacity, time windows, and distance minimization  
✅ **Route construction** — How list variables and shadow variables build efficient routes  
✅ **Customization patterns** — How to extend for your routing needs  
✅ **Production readiness** — Performance, scaling, and infeasibility handling

### Next Steps

1. **Run the application** and experiment with the three demo datasets
2. **Modify an existing constraint** — change capacity limits or time windows
3. **Add your own constraint** — implement a rule from your domain (max distance, breaks, priorities)
4. **Test thoroughly** — write unit tests for your constraints
5. **Customize the data model** — add vehicle types, visit priorities, or other business fields
6. **Deploy with real data** — integrate with your customer database and mapping service

### Key Takeaways

**List Variables for Routing:**
- `PlanningListVariable` on `vehicle.visits` handles both assignment and sequencing
- Shadow variables automatically maintain route chain integrity
- Arrival times cascade through the chain for efficient time calculations

**Hard vs Soft Constraints:**
- Hard: Capacity and time windows (must satisfy for valid routes)
- Soft: Total distance (optimize after ensuring validity)

**Graded Penalties:**
- Penalize by excess amount (not just binary yes/no)
- Helps solver navigate incrementally toward feasibility
- Example: 20 units over capacity is "less wrong" than 50 units over

**Metaheuristics for Routing:**
- Efficiently explore massive solution spaces (millions of possibilities)
- Anytime algorithms: improve continuously, stop when satisfied
- No guarantee of global optimum, but high-quality solutions in practical time

**The Power of Constraints:**
- Most business logic lives in one file (`constraints.py`)
- Easy to add new rules without changing core routing logic
- Declarative: describe what you want, solver figures out how

### Comparison to Other Quickstarts

**vs. Employee Scheduling:**
- Scheduling: Temporal (when to schedule shifts)
- Routing: Spatial + temporal (where to go and when to arrive)
- Scheduling: Simple planning variable (which employee)
- Routing: List variable (which visits, in what order)

**vs. Other Routing Variants:**
- **CVRP** (Capacitated Vehicle Routing): Just capacity, no time windows
- **VRPTW** (this quickstart): Capacity + time windows
- **VRPPD** (Pickup & Delivery): Precedence constraints between pickup/delivery pairs
- **MDVRP** (Multi-Depot): Multiple starting locations

This quickstart teaches core concepts applicable to all routing variants.

### Additional Resources

- [SolverForge Documentation](https://docs.solverforge.ai)
- [Vehicle Routing Problem (Wikipedia)](https://en.wikipedia.org/wiki/Vehicle_routing_problem)
- [GitHub Repository](https://github.com/solverforge/solverforge-quickstarts)
- [Time Windows in Routing](https://developers.google.com/optimization/routing/vrptw)

---

**Questions?** Start by solving the demo datasets and observing how the routes are constructed. Try modifying capacity or time windows to see how the solver adapts. The best way to learn routing optimization is to experiment and visualize the results.

Happy routing! 🚚📦
