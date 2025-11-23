---
title: "Employee Scheduling"
date: 2025-11-21
description: "A comprehensive quickstart guide to understanding and building intelligent employee scheduling with SolverForge"
categories: [Examples]
tags: [scheduling, optimization, tutorial]
---

{{% pageinfo %}}
A comprehensive quickstart guide to understanding and building intelligent employee scheduling with SolverForge. Learn optimization concepts while exploring a working codebase.
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
12. [Production Considerations](#production-considerations)
13. [Quick Reference](#quick-reference)

---

## Introduction

### What You'll Learn

This guide walks you through a complete employee scheduling application built with **SolverForge**, a constraint-based optimization framework. You'll learn:

- How to model real-world scheduling problems as **optimization problems**
- How to express business rules as **constraints** that guide the solution
- How optimization algorithms find high-quality solutions automatically
- How to customize the system for your specific needs

**No optimization background required** — we'll explain concepts as we encounter them in the code.

### Prerequisites

- Basic Python knowledge (classes, functions, type annotations)
- Familiarity with REST APIs
- Comfort with command-line operations

### What is Constraint-Based Optimization?

Traditional programming: You write explicit logic that says "do this, then that."

**Constraint-based optimization**: You describe what a good solution looks like and the solver figures out how to achieve it.

Think of it like describing what puzzle pieces you have and what rules they must follow — then having a computer try millions of arrangements per second to find the best fit.

---

## Getting Started

### Running the Application

1. **Navigate to the project directory:**
   ```bash
   cd /srv/lab/dev/solverforge/solverforge-quickstarts/fast/employee-scheduling-fast
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Start the server:**
   ```bash
   python -m employee_scheduling.rest_api
   ```

4. **Open your browser:**
   ```
   http://localhost:8080
   ```

You'll see a scheduling interface with employees, shifts and a "Solve" button. Click it and watch the solver automatically assign employees to shifts while respecting business rules.

### File Structure Overview

```
src/employee_scheduling/
├── domain.py              # Data classes (Employee, Shift, Schedule)
├── constraints.py         # Business rules (90% of customization happens here)
├── solver.py              # Solver configuration
├── demo_data.py           # Sample data generation
├── rest_api.py            # HTTP API endpoints
├── converters.py          # REST ↔ Domain model conversion
└── json_serialization.py  # JSON helpers

static/
├── index.html             # Web UI
└── app.js                 # UI logic and visualization

tests/
├── test_constraints.py    # Unit tests for constraints
└── test_feasible.py       # Integration tests
```

**Key insight:** Most business customization happens in `constraints.py` alone. You rarely need to modify other files.

---

## The Problem We're Solving

### The Scheduling Challenge

You need to assign **employees** to **shifts** while satisfying rules like:

**Hard constraints** (must be satisfied):
- Employee must have the required skill for the shift
- Employee can't work overlapping shifts
- Employee needs 10 hours rest between shifts
- Employee can't work more than one shift per day
- Employee can't work on days they're unavailable

**Soft constraints** (preferences to optimize):
- Avoid scheduling on days the employee marked as "undesired"
- Prefer scheduling on days the employee marked as "desired"
- Balance workload fairly across all employees

### Why This is Hard

For even 20 shifts and 10 employees, there are **10^20 possible assignments** (100 quintillion). A human can't evaluate them all. Even a computer trying random assignments would take years.

**Optimization algorithms** use smart strategies to explore this space efficiently, finding high-quality solutions in seconds.

---

## Understanding the Data Model

Let's examine the three core classes that model our problem. Open `src/employee_scheduling/domain.py`:

### The Employee Class

```python
@dataclass
class Employee:
    name: Annotated[str, PlanningId]
    skills: set[str] = field(default_factory=set)
    unavailable_dates: set[date] = field(default_factory=set)
    undesired_dates: set[date] = field(default_factory=set)
    desired_dates: set[date] = field(default_factory=set)
```

**What it represents:** A person who can be assigned to shifts.

**Key fields:**
- `name`: Unique identifier (the `PlanningId` annotation tells SolverForge this is the primary key)
- `skills`: What skills this employee possesses (e.g., `{"Doctor", "Cardiology"}`)
- `unavailable_dates`: Days the employee absolutely cannot work (hard constraint)
- `undesired_dates`: Days the employee prefers not to work (soft constraint)
- `desired_dates`: Days the employee wants to work (soft constraint)

**Optimization concept:** These availability fields demonstrate **hard vs soft constraints**. Unavailable is non-negotiable; undesired is a preference the solver will try to honor but may violate if necessary.

### The Shift Class (Planning Entity)

```python
@planning_entity
@dataclass
class Shift:
    id: Annotated[str, PlanningId]
    start: datetime
    end: datetime
    location: str
    required_skill: str
    employee: Annotated[Employee | None, PlanningVariable] = None
```

**What it represents:** A time slot that needs an employee assignment.

**Key fields:**
- `id`: Unique identifier
- `start`/`end`: When the shift occurs
- `location`: Where the work happens
- `required_skill`: What skill is needed (must match employee's skills)
- **`employee`**: The assignment decision — this is what the solver optimizes!

**Important annotations:**
- `@planning_entity`: Tells SolverForge this class contains decisions to make
- `PlanningVariable`: Marks `employee` as the decision variable

**Optimization concept:** This is a **planning variable** — the value the solver assigns. Each shift starts with `employee=None` (unassigned). The solver tries different employee assignments, evaluating each according to your constraints.

### The EmployeeSchedule Class (Planning Solution)

```python
@planning_solution
@dataclass
class EmployeeSchedule:
    employees: Annotated[list[Employee], ProblemFactCollectionProperty, ValueRangeProvider]
    shifts: Annotated[list[Shift], PlanningEntityCollectionProperty]
    score: Annotated[HardSoftDecimalScore | None, PlanningScore] = None
    solver_status: SolverStatus = SolverStatus.NOT_SOLVING
```

**What it represents:** The complete problem and its solution.

**Key fields:**
- `employees`: All available employees (these are the possible values for assignments)
- `shifts`: All shifts that need assignment (the planning entities)
- `score`: Solution quality metric (calculated by constraints)
- `solver_status`: Whether solving is active

**Annotations explained:**
- `@planning_solution`: Marks this as the top-level problem definition
- `ProblemFactCollectionProperty`: Immutable data (doesn't change during solving)
- `PlanningEntityCollectionProperty`: The entities being optimized
- `ValueRangeProvider`: Tells the solver which employees can be assigned to shifts
- `PlanningScore`: Where the solver stores the calculated score

**Optimization concept:** This demonstrates the **declarative modeling approach**. You describe the problem structure (what can be assigned to what) and the solver handles the search process.

---

## How Optimization Works

Before diving into constraints, let's understand how the solver finds solutions.

### The Search Process (Simplified)

1. **Start with an initial solution** (often random or all unassigned)
2. **Evaluate the score** using your constraint functions
3. **Make a small change** (assign a different employee to one shift)
4. **Evaluate the new score**
5. **Keep the change if it improves the score** (with some controlled randomness)
6. **Repeat millions of times** in seconds
7. **Return the best solution found**

### Why This Works: Metaheuristics

SolverForge uses sophisticated **metaheuristic algorithms** like:

- **Tabu Search**: Remembers recent moves to avoid cycling
- **Simulated Annealing**: Occasionally accepts worse solutions to escape local optima
- **Late Acceptance**: Compares current solution to recent history, not just the immediate previous

These techniques efficiently explore the massive solution space without getting stuck.

### The Score: How "Good" is a Solution?

Every solution gets a score with two parts:

```
0hard/-45soft
```

- **Hard score**: Counts hard constraint violations (must be 0 for a valid solution)
- **Soft score**: Counts soft constraint violations/rewards (higher is better)

**Scoring rules:**
- Hard score must be 0 or positive (negative = invalid/infeasible)
- Among valid solutions (hard score = 0), highest soft score wins
- Hard score always takes priority over soft score

**Optimization concept:** This is **multi-objective optimization** with a **lexicographic ordering**. We absolutely prioritize hard constraints, then optimize soft ones.

---

## Writing Constraints: The Business Rules

Now the heart of the system. Open `src/employee_scheduling/constraints.py`.

### The Constraint Provider Pattern

All constraints are registered in one function:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # Hard constraints
        required_skill(constraint_factory),
        no_overlapping_shifts(constraint_factory),
        at_least_10_hours_between_two_shifts(constraint_factory),
        one_shift_per_day(constraint_factory),
        unavailable_employee(constraint_factory),
        # Soft constraints
        undesired_day_for_employee(constraint_factory),
        desired_day_for_employee(constraint_factory),
        balance_employee_shift_assignments(constraint_factory),
    ]
```

Each constraint is a function returning a `Constraint` object. Let's examine them from simple to complex.

### Hard Constraint: Required Skill

**Business rule:** "An employee assigned to a shift must have the required skill."

```python
def required_skill(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .filter(lambda shift: shift.required_skill not in shift.employee.skills)
        .penalize(HardSoftDecimalScore.ONE_HARD)
        .as_constraint("Missing required skill")
    )
```

**How to read this:**
1. `for_each(Shift)`: Consider every shift in the schedule
2. `.filter(...)`: Keep only shifts where the employee lacks the required skill
3. `.penalize(ONE_HARD)`: Each violation subtracts 1 from the hard score
4. `.as_constraint(...)`: Give it a name for debugging

**Optimization concept:** This is a **unary constraint** — it examines one entity at a time. The filter identifies violations and the penalty quantifies the impact.

**Note:** There's no null check for `shift.employee` because constraints are only evaluated on complete assignments during the scoring phase.

### Hard Constraint: No Overlapping Shifts

**Business rule:** "An employee can't work two shifts that overlap in time."

```python
def no_overlapping_shifts(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each_unique_pair(
            Shift,
            Joiners.equal(lambda shift: shift.employee.name),
            Joiners.overlapping(lambda shift: shift.start, lambda shift: shift.end),
        )
        .penalize(HardSoftDecimalScore.ONE_HARD, get_minute_overlap)
        .as_constraint("Overlapping shift")
    )
```

**How to read this:**
1. `for_each_unique_pair(Shift, ...)`: Create pairs of shifts
2. `Joiners.equal(lambda shift: shift.employee.name)`: Only pair shifts assigned to the same employee
3. `Joiners.overlapping(...)`: Only pair shifts that overlap in time
4. `.penalize(ONE_HARD, get_minute_overlap)`: Penalize by the number of overlapping minutes

**Optimization concept:** This is a **binary constraint** — it examines pairs of entities. The `for_each_unique_pair` ensures we don't count each violation twice (e.g., comparing shift A to B and B to A).

**Helper function:**
```python
def get_minute_overlap(shift1: Shift, shift2: Shift) -> int:
    return (
        min(shift1.end, shift2.end) - max(shift1.start, shift2.start)
    ).total_seconds() // 60
```

**Why penalize by minutes?** This creates a **graded penalty**. A 5-minute overlap is less bad than a 5-hour overlap, giving the solver better guidance.

### Hard Constraint: Rest Between Shifts

**Business rule:** "Employees need at least 10 hours rest between shifts."

```python
def at_least_10_hours_between_two_shifts(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .join(
            Shift,
            Joiners.equal(lambda shift: shift.employee.name),
            Joiners.less_than_or_equal(
                lambda shift: shift.end, lambda shift: shift.start
            ),
        )
        .filter(
            lambda first_shift, second_shift: (
                second_shift.start - first_shift.end
            ).total_seconds() // (60 * 60) < 10
        )
        .penalize(
            HardSoftDecimalScore.ONE_HARD,
            lambda first_shift, second_shift: 600 - (
                (second_shift.start - first_shift.end).total_seconds() // 60
            ),
        )
        .as_constraint("At least 10 hours between 2 shifts")
    )
```

**How to read this:**
1. `for_each(Shift)`: Start with all shifts
2. `.join(Shift, ...)`: Pair with other shifts
3. `Joiners.equal(...)`: Same employee
4. `Joiners.less_than_or_equal(...)`: First shift ends before or when second starts (ensures ordering)
5. `.filter(...)`: Keep only pairs with less than 10 hours gap
6. `.penalize(...)`: Penalize by `600 - actual_minutes` (the deficit from required 10 hours)

**Optimization concept:** The penalty function `600 - actual_minutes` creates **incremental guidance**. 9 hours rest (penalty 60) is better than 5 hours rest (penalty 300), helping the solver navigate toward feasibility.

### Hard Constraint: One Shift Per Day

**Business rule:** "Employees can work at most one shift per calendar day."

```python
def one_shift_per_day(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each_unique_pair(
            Shift,
            Joiners.equal(lambda shift: shift.employee.name),
            Joiners.equal(lambda shift: shift.start.date()),
        )
        .penalize(HardSoftDecimalScore.ONE_HARD)
        .as_constraint("Max one shift per day")
    )
```

**How to read this:**
1. `for_each_unique_pair(Shift, ...)`: Create pairs of shifts
2. First joiner: Same employee
3. Second joiner: Same date (`shift.start.date()` extracts calendar day)
4. Each pair found is a violation

### Hard Constraint: Unavailable Dates

**Business rule:** "Employees cannot work on days they marked as unavailable."

```python
def unavailable_employee(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .join(
            Employee,
            Joiners.equal(lambda shift: shift.employee, lambda employee: employee),
        )
        .flatten_last(lambda employee: employee.unavailable_dates)
        .filter(
            lambda shift, unavailable_date: is_overlapping_with_date(
                shift, unavailable_date
            )
        )
        .penalize(
            HardSoftDecimalScore.ONE_HARD,
            lambda shift, unavailable_date: get_shift_overlapping_duration_in_minutes(
                shift, unavailable_date
            ),
        )
        .as_constraint("Unavailable employee")
    )
```

**How to read this:**
1. `for_each(Shift)`: All shifts
2. `.join(Employee, ...)`: Join with the assigned employee
3. `.flatten_last(lambda employee: employee.unavailable_dates)`: Expand each employee's unavailable_dates set
4. `.filter(...)`: Keep only when shift overlaps the unavailable date
5. `.penalize(...)`: Penalize by overlapping duration in minutes

**Optimization concept:** The `flatten_last` operation demonstrates **constraint streaming with collections**. We iterate over each date in the employee's unavailable set, creating (shift, date) pairs to check.

**Helper functions:**
```python
def is_overlapping_with_date(shift: Shift, dt: date) -> bool:
    return shift.start.date() == dt or shift.end.date() == dt

def get_shift_overlapping_duration_in_minutes(shift: Shift, dt: date) -> int:
    start_date_time = datetime.combine(dt, datetime.min.time())
    end_date_time = datetime.combine(dt, datetime.max.time())
    return overlapping_in_minutes(start_date_time, end_date_time, shift.start, shift.end)
```

### Soft Constraint: Undesired Days

**Business rule:** "Prefer not to schedule employees on days they marked as undesired."

```python
def undesired_day_for_employee(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .join(
            Employee,
            Joiners.equal(lambda shift: shift.employee, lambda employee: employee),
        )
        .flatten_last(lambda employee: employee.undesired_dates)
        .filter(
            lambda shift, undesired_date: is_overlapping_with_date(
                shift, undesired_date
            )
        )
        .penalize(
            HardSoftDecimalScore.ONE_SOFT,
            lambda shift, undesired_date: get_shift_overlapping_duration_in_minutes(
                shift, undesired_date
            ),
        )
        .as_constraint("Undesired day for employee")
    )
```

**Key difference from hard constraints:** Uses `ONE_SOFT` instead of `ONE_HARD`.

**Optimization concept:** The solver will try to avoid undesired days but may violate this if necessary to satisfy hard constraints or achieve better overall soft score.

### Soft Constraint: Desired Days (Reward)

**Business rule:** "Prefer to schedule employees on days they marked as desired."

```python
def desired_day_for_employee(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .join(
            Employee,
            Joiners.equal(lambda shift: shift.employee, lambda employee: employee),
        )
        .flatten_last(lambda employee: employee.desired_dates)
        .filter(
            lambda shift, desired_date: is_overlapping_with_date(shift, desired_date)
        )
        .reward(
            HardSoftDecimalScore.ONE_SOFT,
            lambda shift, desired_date: get_shift_overlapping_duration_in_minutes(
                shift, desired_date
            ),
        )
        .as_constraint("Desired day for employee")
    )
```

**Key difference:** Uses `.reward()` instead of `.penalize()`.

**Optimization concept:** Rewards **increase** the score instead of decreasing it. This constraint actively pulls the solution toward desired assignments.

### Soft Constraint: Load Balancing

**Business rule:** "Distribute shifts fairly across employees."

```python
def balance_employee_shift_assignments(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .group_by(lambda shift: shift.employee, ConstraintCollectors.count())
        .complement(Employee, lambda e: 0)
        .group_by(
            ConstraintCollectors.load_balance(
                lambda employee, shift_count: employee,
                lambda employee, shift_count: shift_count,
            )
        )
        .penalize_decimal(
            HardSoftDecimalScore.ONE_SOFT,
            lambda load_balance: load_balance.unfairness(),
        )
        .as_constraint("Balance employee shift assignments")
    )
```

**How to read this:**
1. `for_each(Shift)`: All shifts
2. `.group_by(..., ConstraintCollectors.count())`: Count shifts per employee
3. `.complement(Employee, lambda e: 0)`: Include employees with 0 shifts
4. `.group_by(ConstraintCollectors.load_balance(...))`: Calculate fairness metric
5. `.penalize_decimal(..., unfairness())`: Penalize by the unfairness amount

**Optimization concept:** This uses a sophisticated **load balancing collector** that calculates variance/unfairness in workload distribution. It's more nuanced than simple quadratic penalties — it measures how far the distribution is from perfectly balanced.

**Why complement?** Without it, employees with zero shifts wouldn't appear in the grouping, skewing the fairness calculation.

---

## The Solver Engine

Now let's see how the solver is configured. Open `src/employee_scheduling/solver.py`:

```python
solver_config = SolverConfig(
    solution_class=EmployeeSchedule,
    entity_class_list=[Shift],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(spent_limit=Duration(seconds=30)),
)

solver_manager = SolverManager.create(SolverFactory.create(solver_config))
solution_manager = SolutionManager.create(solver_manager)
```

### Configuration Breakdown

**`solution_class`**: Your planning solution class (`EmployeeSchedule`)

**`entity_class_list`**: Planning entities to optimize (`[Shift]`)

**`score_director_factory_config`**: Contains the constraint provider function
- **Note:** This is nested inside `ScoreDirectorFactoryConfig`, not directly in `SolverConfig`

**`termination_config`**: When to stop solving
- `spent_limit=Duration(seconds=30)`: Stop after 30 seconds

### SolverManager: Asynchronous Solving

`SolverManager` handles solving in the background without blocking your API:

```python
# Start solving (non-blocking)
solver_manager.solve_and_listen(job_id, schedule, callback_function)

# Check status
status = solver_manager.get_status(job_id)

# Get current best solution
solution = solver_manager.get_solution(job_id)

# Stop early
solver_manager.terminate_early(job_id)
```

**Optimization concept:** Real-world problems may take minutes to hours. **Anytime algorithms** like metaheuristics continuously improve solutions over time, so you can stop whenever you're satisfied with the quality.

### Solving Timeline

**Small problems** (10-20 shifts, 5-10 employees):
- Initial valid solution: < 1 second
- Good solution: 5-10 seconds
- High-quality: 30 seconds

**Medium problems** (50-100 shifts, 20-30 employees):
- Initial valid solution: 1-5 seconds
- Good solution: 30-60 seconds
- High-quality: 5-10 minutes

**Factors affecting speed:**
- Number of employees × shifts (search space size)
- Constraint complexity
- How "tight" constraints are (fewer valid solutions = harder)

---

## Web Interface and API

### REST API Endpoints

Open `src/employee_scheduling/rest_api.py` to see the API:

#### GET /demo-data

Returns available demo datasets:

```json
["SMALL", "LARGE"]
```

#### GET /demo-data/{dataset_id}

Generates and returns sample data:

```json
{
  "employees": [
    {
      "name": "Amy Cole",
      "skills": ["Doctor", "Cardiology"],
      "unavailableDates": ["2025-11-25"],
      "undesiredDates": ["2025-11-26"],
      "desiredDates": ["2025-11-27"]
    }
  ],
  "shifts": [
    {
      "id": "0",
      "start": "2025-11-25T06:00:00",
      "end": "2025-11-25T14:00:00",
      "location": "Ambulatory care",
      "requiredSkill": "Doctor",
      "employee": null
    }
  ]
}
```

**Note:** Field names use camelCase in JSON (REST API convention) but snake_case in Python (domain model). The `converters.py` handles this translation.

#### POST /schedules

Submit a schedule to solve:

**Request body:** Same format as demo-data response

**Response:** Job ID as plain text
```
"a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

**Implementation:**
```python
@app.post("/schedules")
async def solve_timetable(schedule_model: EmployeeScheduleModel) -> str:
    job_id = str(uuid4())
    schedule = model_to_schedule(schedule_model)
    data_sets[job_id] = schedule
    solver_manager.solve_and_listen(
        job_id, 
        schedule,
        lambda solution: update_schedule(job_id, solution)
    )
    return job_id
```

**Key detail:** Uses `solve_and_listen()` with a callback that updates the stored solution in real-time as solving progresses.

#### GET /schedules/{problem_id}

Check solving status and get current solution:

**Response (while solving):**
```json
{
  "employees": [...],
  "shifts": [...],
  "score": "0hard/-45soft",
  "solverStatus": "SOLVING_ACTIVE"
}
```

**Response (finished):**
```json
{
  "employees": [...],
  "shifts": [...],
  "score": "0hard/-12soft",
  "solverStatus": "NOT_SOLVING"
}
```

#### DELETE /schedules/{problem_id}

Stop solving early and return best solution found so far:

```python
@app.delete("/schedules/{problem_id}")
async def stop_solving(problem_id: str) -> None:
    solver_manager.terminate_early(problem_id)
```

### Web UI Flow

The `static/app.js` implements this polling workflow:

1. **User opens page** → Load demo data (`GET /demo-data/SMALL`)
2. **Display** employees and shifts in timeline visualization
3. **User clicks "Solve"** → `POST /schedules` (get job ID back)
4. **Poll** `GET /schedules/{id}` every 2 seconds
5. **Update UI** with latest assignments in real-time
6. **When** `solverStatus === "NOT_SOLVING"` → Stop polling
7. **Display** final score and solution

**Visual feedback:** The UI uses vis-timeline library to show:
- Shifts color-coded by availability (red=unavailable, orange=undesired, green=desired, blue=normal)
- Skills color-coded (red=missing skill, green=has skill)
- Two views: by employee and by location

---

## Making Your First Customization

Let's add a new constraint step-by-step.

### Scenario: Limit Maximum Shifts Per Employee

**New business rule:** "No employee can work more than 5 shifts in the schedule period."

This is a **hard constraint** (must be satisfied).

### Step 1: Open constraints.py

Navigate to `src/employee_scheduling/constraints.py`.

### Step 2: Write the Constraint Function

Add this function:

```python
def max_shifts_per_employee(constraint_factory: ConstraintFactory):
    """
    Hard constraint: No employee can have more than 5 shifts.
    """
    return (
        constraint_factory.for_each(Shift)
        .group_by(
            lambda shift: shift.employee,
            ConstraintCollectors.count()
        )
        .filter(lambda employee, shift_count: shift_count > 5)
        .penalize(
            HardSoftDecimalScore.ONE_HARD,
            lambda employee, shift_count: shift_count - 5
        )
        .as_constraint("Max 5 shifts per employee")
    )
```

**How this works:**
1. Group shifts by employee and count them
2. Filter to employees with more than 5 shifts
3. Penalize by the excess amount (6 shifts = penalty 1, 7 shifts = penalty 2, etc.)

### Step 3: Register the Constraint

Add it to the `define_constraints` function:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # Hard constraints
        required_skill(constraint_factory),
        no_overlapping_shifts(constraint_factory),
        at_least_10_hours_between_two_shifts(constraint_factory),
        one_shift_per_day(constraint_factory),
        unavailable_employee(constraint_factory),
        max_shifts_per_employee(constraint_factory),  # ← Add this line
        # Soft constraints
        undesired_day_for_employee(constraint_factory),
        desired_day_for_employee(constraint_factory),
        balance_employee_shift_assignments(constraint_factory),
    ]
```

### Step 4: Test It

1. Restart the server
2. Load demo data
3. Click "Solve"
4. Verify no employee has more than 5 shifts

**Testing tip:** Temporarily change the limit to 2 to see the constraint in action more obviously.

### Understanding What You Did

You just implemented a **cardinality constraint** — limiting the count of something. This pattern is extremely common in scheduling:

- Maximum hours per week
- Minimum shifts per employee
- Exact number of nurses per shift

The pattern is always:
1. Group by what you're counting
2. Collect the count
3. Filter by your limit
4. Penalize/reward appropriately

---

## Advanced Constraint Patterns

### Pattern 1: Weighted Penalties

**Scenario:** Some skills are harder to staff — penalize their absence more heavily.

```python
def preferred_skill_coverage(constraint_factory: ConstraintFactory):
    """
    Soft constraint: Prefer specialized skills when available.
    """
    SPECIALTY_SKILLS = {"Cardiology", "Anaesthetics", "Radiology"}
    
    return (
        constraint_factory.for_each(Shift)
        .filter(lambda shift: shift.required_skill in SPECIALTY_SKILLS)
        .filter(lambda shift: shift.required_skill in shift.employee.skills)
        .reward(
            HardSoftDecimalScore.of_soft(10),  # 10x normal reward
        )
        .as_constraint("Preferred specialty coverage")
    )
```

**Optimization concept:** **Weighted constraints** let you express relative importance. This rewards specialty matches 10 times more than standard matches.

### Pattern 2: Conditional Constraints

**Scenario:** Night shifts (after 6 PM) require two employees at the same location.

```python
def night_shift_minimum_staff(constraint_factory: ConstraintFactory):
    """
    Hard constraint: Night shifts need at least 2 employees per location.
    """
    def is_night_shift(shift: Shift) -> bool:
        return shift.start.hour >= 18  # 6 PM or later
    
    return (
        constraint_factory.for_each(Shift)
        .filter(is_night_shift)
        .group_by(
            lambda shift: (shift.start, shift.location),
            ConstraintCollectors.count()
        )
        .filter(lambda timeslot_location, count: count < 2)
        .penalize(
            HardSoftDecimalScore.ONE_HARD,
            lambda timeslot_location, count: 2 - count
        )
        .as_constraint("Night shift minimum 2 staff")
    )
```

### Pattern 3: Employee Pairing (Incompatibility)

**Scenario:** Certain employees shouldn't work the same shift.

First, add the field to `domain.py`:

```python
@dataclass
class Employee:
    name: Annotated[str, PlanningId]
    skills: set[str] = field(default_factory=set)
    # ... existing fields ...
    incompatible_with: set[str] = field(default_factory=set)  # employee names
```

Then the constraint:

```python
def avoid_incompatible_pairs(constraint_factory: ConstraintFactory):
    """
    Hard constraint: Incompatible employees can't work overlapping shifts.
    """
    return (
        constraint_factory.for_each(Shift)
        .join(
            Shift,
            Joiners.equal(lambda shift: shift.location),
            Joiners.overlapping(lambda shift: shift.start, lambda shift: shift.end),
        )
        .filter(
            lambda shift1, shift2: 
                shift2.employee.name in shift1.employee.incompatible_with
        )
        .penalize(HardSoftDecimalScore.ONE_HARD)
        .as_constraint("Avoid incompatible pairs")
    )
```

### Pattern 4: Time-Based Accumulation

**Scenario:** Limit total hours worked per week.

```python
def max_hours_per_week(constraint_factory: ConstraintFactory):
    """
    Hard constraint: Maximum 40 hours per employee per week.
    """
    def get_shift_hours(shift: Shift) -> float:
        return (shift.end - shift.start).total_seconds() / 3600
    
    def get_week(shift: Shift) -> int:
        return shift.start.isocalendar()[1]  # ISO week number
    
    return (
        constraint_factory.for_each(Shift)
        .group_by(
            lambda shift: (shift.employee, get_week(shift)),
            ConstraintCollectors.sum(get_shift_hours)
        )
        .filter(lambda employee_week, total_hours: total_hours > 40)
        .penalize(
            HardSoftDecimalScore.ONE_HARD,
            lambda employee_week, total_hours: int(total_hours - 40)
        )
        .as_constraint("Max 40 hours per week")
    )
```

**Optimization concept:** This uses **temporal aggregation** — grouping by time periods (weeks) and summing durations. Common in workforce scheduling.

---

## Testing and Validation

### Unit Testing Constraints

Best practice: Test each constraint in isolation.

Create `tests/test_my_constraints.py`:

```python
from datetime import datetime, date
from employee_scheduling.domain import Employee, Shift, EmployeeSchedule
from employee_scheduling.solver import solver_config
from solverforge_legacy.solver import SolverFactory

def test_max_shifts_constraint_violation():
    """Test that exceeding 5 shifts creates a hard constraint violation."""
    
    employee = Employee(
        name="Test Employee",
        skills={"Doctor"}
    )
    
    # Create 6 shifts assigned to same employee
    shifts = []
    for i in range(6):
        shifts.append(Shift(
            id=str(i),
            start=datetime(2025, 11, 25 + i, 9, 0),
            end=datetime(2025, 11, 25 + i, 17, 0),
            location="Test Location",
            required_skill="Doctor",
            employee=employee
        ))
    
    schedule = EmployeeSchedule(
        employees=[employee],
        shifts=shifts
    )
    
    # Score the solution
    solver_factory = SolverFactory.create(solver_config)
    score_director = solver_factory.get_score_director_factory().build_score_director()
    score_director.set_working_solution(schedule)
    score = score_director.calculate_score()
    
    # Verify hard constraint violation
    assert score.hard_score == -1, f"Expected -1 hard score, got {score.hard_score}"
    
def test_max_shifts_constraint_satisfied():
    """Test that 5 or fewer shifts doesn't violate constraint."""
    
    employee = Employee(
        name="Test Employee",
        skills={"Doctor"}
    )
    
    # Create only 5 shifts
    shifts = []
    for i in range(5):
        shifts.append(Shift(
            id=str(i),
            start=datetime(2025, 11, 25 + i, 9, 0),
            end=datetime(2025, 11, 25 + i, 17, 0),
            location="Test Location",
            required_skill="Doctor",
            employee=employee
        ))
    
    schedule = EmployeeSchedule(
        employees=[employee],
        shifts=shifts
    )
    
    solver_factory = SolverFactory.create(solver_config)
    score_director = solver_factory.get_score_director_factory().build_score_director()
    score_director.set_working_solution(schedule)
    score = score_director.calculate_score()
    
    # No violation from this constraint (may have soft penalties from balancing, etc.)
    assert score.hard_score >= -0, f"Expected non-negative hard score, got {score.hard_score}"
```

Run with:
```bash
pytest tests/test_my_constraints.py -v
```

### Integration Testing: Full Solve

Test the complete solving cycle in `tests/test_feasible.py`:

```python
import time
from employee_scheduling.demo_data import DemoData, generate_demo_data
from employee_scheduling.solver import solver_manager
from solverforge_legacy.solver import SolverStatus

def test_solve_small_dataset():
    """Test that solver finds a feasible solution for small dataset."""
    
    # Generate problem
    schedule = generate_demo_data(DemoData.SMALL)
    
    # Verify initially unassigned
    assert all(shift.employee is None for shift in schedule.shifts)
    
    # Solve
    job_id = "test-job"
    solver_manager.solve(job_id, schedule)
    
    # Wait for completion (with timeout)
    timeout_seconds = 60
    start_time = time.time()
    while solver_manager.get_solver_status(job_id) != SolverStatus.NOT_SOLVING:
        if time.time() - start_time > timeout_seconds:
            solver_manager.terminate_early(job_id)
            break
        time.sleep(1)
    
    # Get solution
    solution = solver_manager.get_solution(job_id)
    
    # Verify all shifts assigned
    assert all(shift.employee is not None for shift in solution.shifts), \
        "Not all shifts were assigned"
    
    # Verify feasible (hard score = 0)
    assert solution.score.hard_score == 0, \
        f"Solution is infeasible with hard score {solution.score.hard_score}"
    
    print(f"Final score: {solution.score}")
```

### Manual Testing via UI

1. Start the application: `python -m employee_scheduling.rest_api`
2. Open browser console (F12) to see API calls
3. Load "SMALL" demo data
4. Verify data displays correctly (employees with skills, shifts unassigned)
5. Click "Solve" and watch:
   - Score improving in real-time
   - Shifts getting assigned (colored by availability)
   - Final hard score reaches 0
6. Manually verify constraint satisfaction:
   - Check that assigned employees have required skills (green badges)
   - Verify no overlapping shifts (timeline shouldn't show overlaps)
   - Confirm unavailable days are respected (no shifts on red-highlighted dates)

---

## Production Considerations

### Performance: Constraint Evaluation Speed

Constraints are evaluated **millions of times** during solving. Performance matters.

**❌ DON'T: Database calls or expensive operations in constraints**

```python
def bad_constraint(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .filter(lambda shift: 
            check_external_api(shift.employee.name))  # SLOW!
        .penalize(HardSoftDecimalScore.ONE_HARD)
        .as_constraint("Bad constraint")
    )
```

**✅ DO: Pre-compute before solving**

```python
# Before solving
blacklisted_employees = fetch_from_api()  # Do this ONCE

def good_constraint(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .filter(lambda shift: 
            shift.employee.name in blacklisted_employees)  # Fast set lookup
        .penalize(HardSoftDecimalScore.ONE_HARD)
        .as_constraint("Good constraint")
    )
```

### Scaling Strategies

**Problem size limits (30 second solve):**
- Up to ~200 shifts × 50 employees = feasible
- Beyond that:
  - Increase solve time (minutes instead of seconds)
  - Use **decomposition** (solve week-by-week)
  - Use **warm starts** (start from previous solution)

**Warm start example:**

```python
# Use last week's solution as starting point
previous_solution = load_from_database("week-2025-11-18")

# Adapt for new week (update dates, add/remove shifts)
new_problem = adapt_for_new_week(previous_solution)

# Solve (starts from previous assignments, converges faster)
solver_manager.solve("week-2025-11-25", new_problem)
```

**Optimization concept:** Warm starts leverage **solution similarity**. If this week is similar to last week, starting from last week's assignments reaches a good solution faster than starting from scratch.

### Data Quality and Validation

**Critical validations:**

1. **Skill normalization:**
```python
# Canonicalize to avoid mismatches
employee.skills = {skill.strip().lower() for skill in raw_skills}
shift.required_skill = shift.required_skill.strip().lower()
```

2. **Unique IDs:**
```python
assert len(set(e.name for e in employees)) == len(employees), "Duplicate employee names"
assert len(set(s.id for s in shifts)) == len(shifts), "Duplicate shift IDs"
```

3. **Feasibility pre-check:**
```python
# Verify at least one employee has each required skill
required_skills = {shift.required_skill for shift in shifts}
available_skills = set().union(*(e.skills for e in employees))
missing_skills = required_skills - available_skills
if missing_skills:
    raise ValueError(f"No employee has skills: {missing_skills}")
```

### Handling Infeasible Problems

Sometimes no solution exists (e.g., not enough skilled employees).

**Detect and report:**

```python
solution = solver_manager.get_solution(job_id)

if solution.score.hard_score < 0:
    # Problem is infeasible
    unassigned_shifts = [s for s in solution.shifts if s.employee is None]
    
    return {
        "error": "No feasible solution exists",
        "hard_score": solution.score.hard_score,
        "unassigned_count": len(unassigned_shifts),
        "suggestion": "Try relaxing constraints or adding more employees"
    }
```

### Monitoring and Logging

**Track key metrics:**

```python
import logging
import time

logger = logging.getLogger(__name__)

start_time = time.time()
solver_manager.solve(job_id, schedule)

# ... wait for completion ...

solution = solver_manager.get_solution(job_id)
solve_duration = time.time() - start_time

logger.info(
    f"Solved schedule {job_id}: "
    f"duration={solve_duration:.1f}s, "
    f"score={solution.score}, "
    f"problem_size={len(solution.shifts)}×{len(solution.employees)}"
)
```

**What to monitor in production:**
- Solve duration (alert if suddenly increases)
- Infeasible solutions (indicates data quality issues)
- Score trends (degrading scores may indicate changing data patterns)

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Add/change business rule | `src/employee_scheduling/constraints.py` |
| Add field to Employee | `src/employee_scheduling/domain.py` + `converters.py` |
| Add field to Shift | `src/employee_scheduling/domain.py` + `converters.py` |
| Change solve time | `src/employee_scheduling/solver.py` |
| Add REST endpoint | `src/employee_scheduling/rest_api.py` |
| Change demo data | `src/employee_scheduling/demo_data.py` |
| Change UI | `static/index.html`, `static/app.js` |

### Common Constraint Patterns

**Unary constraint (examine one entity):**
```python
constraint_factory.for_each(Shift)
    .filter(lambda shift: # condition)
    .penalize(HardSoftDecimalScore.ONE_HARD)
```

**Binary constraint (examine pairs):**
```python
constraint_factory.for_each_unique_pair(
    Shift,
    Joiners.equal(lambda shift: shift.employee.name)
)
    .penalize(HardSoftDecimalScore.ONE_HARD)
```

**Grouping and counting:**
```python
constraint_factory.for_each(Shift)
    .group_by(
        lambda shift: shift.employee,
        ConstraintCollectors.count()
    )
    .filter(lambda employee, count: count > MAX)
    .penalize(...)
```

**Reward instead of penalize:**
```python
.reward(HardSoftDecimalScore.ONE_SOFT)
```

**Variable penalty:**
```python
.penalize(
    HardSoftDecimalScore.ONE_HARD,
    lambda shift: calculate_penalty_amount(shift)
)
```

**Working with collections (flatten):**
```python
constraint_factory.for_each(Shift)
    .join(Employee, Joiners.equal(...))
    .flatten_last(lambda employee: employee.unavailable_dates)
    .filter(...)
```

### Common Joiners

| Joiner | Purpose |
|--------|---------|
| `Joiners.equal(lambda x: x.field)` | Match entities with same field value |
| `Joiners.less_than(lambda x: x.field)` | First entity's field < second's (ensures ordering) |
| `Joiners.overlapping(start, end)` | Time intervals overlap |

### Debugging Tips

**Enable verbose logging:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Test constraint in isolation:**
```python
# Create minimal test case with just the constraint you're debugging
schedule = EmployeeSchedule(
    employees=[test_employee],
    shifts=[test_shift]
)

solver_factory = SolverFactory.create(solver_config)
score_director = solver_factory.get_score_director_factory().build_score_director()
score_director.set_working_solution(schedule)
score = score_director.calculate_score()

print(f"Score: {score}")
```

**Check constraint matches:**
Add print statements (remove in production):
```python
.filter(lambda shift: (
    print(f"Checking shift {shift.id}") or  # Debug print
    shift.required_skill not in shift.employee.skills
))
```

### Common Gotchas

1. **Forgot to register constraint** in `define_constraints()` return list
   - Symptom: Constraint not enforced

2. **Using wrong Joiner**
   - `Joiners.equal` when you need `Joiners.less_than`
   - Symptom: Pairs counted twice or constraint not working

3. **Expensive operations in constraint functions**
   - Database/API calls in filters
   - Symptom: Solving extremely slow

4. **Score sign confusion**
   - Higher soft score is better (not worse!)
   - Hard score must be ≥ 0 for feasible solution

5. **Field name mismatch**
   - Guide said `skill_set`, actual is `skills`
   - Guide said `employee_list`, actual is `employees`

---

## Conclusion

You now have a complete understanding of constraint-based employee scheduling:

✅ **Problem modeling** — How to represent scheduling problems declaratively  
✅ **Constraint logic** — How to express business rules that guide the solver  
✅ **Optimization concepts** — How metaheuristics find high-quality solutions efficiently  
✅ **Customization patterns** — How to extend the system for your needs  
✅ **Production readiness** — Performance, testing and scaling considerations

### Next Steps

1. **Run the application** and experiment with the demo data
2. **Modify an existing constraint** — change a limit and observe the impact
3. **Add your own constraint** — implement a rule from your domain
4. **Test thoroughly** — write unit tests for your constraints
5. **Customize the data model** — add fields relevant to your business
6. **Deploy** — integrate with your real data sources

### Key Takeaways

**Declarative vs Imperative:**
- Traditional: "Assign employee A to shift 1, B to shift 2..."
- Constraint-based: "Here are the rules; find the best assignment"

**Hard vs Soft Constraints:**
- Hard: Must be satisfied (non-negotiable rules)
- Soft: Preferences to optimize (business goals)

**Metaheuristics:**
- Efficiently explore massive solution spaces
- Anytime algorithms: improve continuously, stop when satisfied
- No guarantee of global optimum, but high-quality solutions in practical time

**The Power of Constraints:**
- Most business logic lives in one file (`constraints.py`)
- Adding rules is often easier than removing them
- Start with fewer constraints, add complexity as needed

### Additional Resources

- [SolverForge Documentation](https://docs.solverforge.ai)
- [GitHub Repository](https://github.com/solverforge/solverforge-quickstarts)
- [Constraint Optimization Primer](https://en.wikipedia.org/wiki/Constraint_satisfaction_problem)

---

**Questions?** Start by modifying the demo constraints and observing how solutions change. The best way to learn optimization is to experiment with constraints and see the solver's behavior.

Happy optimizing! 🚀
