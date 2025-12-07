---
title: "Meeting Scheduling"
date: 2225-11-26
description: "A comprehensive quickstart guide to understanding and building intelligent meeting scheduling with SolverForge"
categories: [Examples]
tags: [scheduling, optimization, meetings, calendar, tutorial]
---

{{% pageinfo %}}
A comprehensive quickstart guide to understanding and building intelligent meeting scheduling with SolverForge. Learn optimization concepts while exploring a working codebase.
{{% /pageinfo %}}

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [The Problem We're Solving](#the-problem-were-solving)
4. [Understanding the Data Model](#understanding-the-data-model)
5. [How Scheduling Optimization Works](#how-scheduling-optimization-works)
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

This guide walks you through a complete meeting scheduling application built with **SolverForge**, a constraint-based optimization framework. You'll learn:

- How to model complex scheduling problems with **multiple resource types** (time slots, rooms, people)
- How to handle **hierarchical constraints** with different priority levels
- How to balance competing objectives (minimize conflicts, pack meetings early, encourage breaks)
- How to customize the system for your organization's meeting policies

**No optimization background required** — we'll explain concepts as we encounter them in the code.

> **Architecture Note:** This implementation uses dataclass domain models for optimal solver performance. See [benchmark results](/blog/news/python-constraint-solver-architecture/#results-meeting-scheduling) showing this approach completes 60/60 optimization iterations while Pydantic-based alternatives complete only 46-58. Note: benchmarks were run on small test problems; JPype bridge overhead may increase at larger scales.

### Prerequisites

- Basic Python knowledge (classes, functions, type annotations)
- Familiarity with REST APIs
- Comfort with command-line operations
- Understanding of calendar/scheduling concepts

### What is Meeting Scheduling Optimization?

Traditional approach: Manually coordinate calendars, send emails back and forth, book rooms one by one.

**Meeting scheduling optimization**: You describe your meetings, attendees, available rooms, and constraints — the solver automatically finds a schedule that satisfies requirements while minimizing conflicts.

Think of it like having an executive assistant who can evaluate millions of scheduling combinations per second to find arrangements that work for everyone.

---

## Getting Started

### Running the Application

1. **Navigate to the project directory:**
   ```bash
   cd /srv/lab/dev/solverforge/solverforge-quickstarts/fast/meeting-scheduling-fast
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

You'll see a calendar interface with meetings, rooms, and people. Click "Solve" and watch the solver automatically schedule meetings into time slots and rooms while avoiding conflicts.

### File Structure Overview

```
src/meeting_scheduling/
├── domain.py              # Data classes (Meeting, Person, Room, TimeGrain)
├── constraints.py         # Business rules (conflicts, capacity, timing)
├── solver.py              # Solver configuration
├── demo_data.py           # Sample data generation
├── rest_api.py            # HTTP API endpoints
├── converters.py          # REST ↔ Domain model conversion
├── json_serialization.py  # JSON serialization helpers
└── score_analysis.py      # Score breakdown DTOs

static/
├── index.html             # Web UI
└── app.js                 # UI logic and visualization

tests/
├── test_constraints.py    # Unit tests for constraints
└── test_feasible.py       # Integration tests
```

**Key insight:** Most business customization happens in `constraints.py`. The domain model defines what can be scheduled, but constraints define what makes a good schedule.

---

## The Problem We're Solving

### The Meeting Scheduling Challenge

You need to assign **meetings** to **time slots** and **rooms** while satisfying rules like:

**Hard constraints** (must be satisfied):
- Rooms cannot be double-booked (no overlapping meetings in same room)
- Required attendees cannot be double-booked
- Meetings must fit within available time slots (no overtime)
- Rooms must have sufficient capacity for all attendees
- Meetings cannot span multiple days (must start and end same day)

**Medium constraints** (strong preferences):
- Avoid conflicts where a person is required at one meeting and preferred at another
- Avoid conflicts for preferred attendees

**Soft constraints** (optimization goals):
- Schedule meetings as early as possible
- Encourage breaks between consecutive meetings
- Minimize general overlapping meetings
- Use larger rooms first (efficient room utilization)
- Minimize room switches for attendees

### Why This is Hard

For even 10 meetings, 5 rooms, and 20 time slots per day, there are over **10 trillion possible schedules**. With 24 meetings like in the demo, the possibilities become astronomical.

**The challenges:**
- **Resource coordination**: Must simultaneously allocate time, rooms, and people
- **Conflict resolution**: One assignment affects availability of all resources
- **Priority balancing**: Hard constraints must hold while optimizing preferences
- **Temporal dependencies**: Meeting times affect break patterns and room switch distances

**Scheduling optimization algorithms** use sophisticated strategies to explore this space efficiently, finding high-quality schedules in seconds.

---

## Understanding the Data Model

Let's examine the core classes that model our scheduling problem. Open `src/meeting_scheduling/domain.py`:

### The Person Class

```python
@dataclass
class Person:
    id: Annotated[str, PlanningId]
    full_name: str
```

**What it represents:** An attendee who can be required or preferred at meetings.

**Key fields:**
- `id`: Unique identifier (the `PlanningId` annotation tells SolverForge this is the primary key)
- `full_name`: Display name (e.g., "Amy Cole")

**Optimization concept:** People are **resources** that can be allocated to meetings. Unlike employee scheduling where employees are assigned to shifts, here people's attendance at meetings creates constraints but isn't directly optimized.

### The TimeGrain Class

```python
# Time slot granularity (configurable)
GRAIN_LENGTH_IN_MINUTES = 15

@dataclass
class TimeGrain:
    grain_index: Annotated[int, PlanningId]
    day_of_year: int
    starting_minute_of_day: int
    
    @property
    def ending_minute_of_day(self) -> int:
        return self.starting_minute_of_day + GRAIN_LENGTH_IN_MINUTES
```

**What it represents:** A discrete time slot (default: 15 minutes).

**Time grain granularity:** The `GRAIN_LENGTH_IN_MINUTES` constant (defined at the top of `domain.py`) controls the scheduling precision. The default 15-minute grain balances precision with search space size. Smaller grains (5 minutes) offer more flexibility but slower solving. Larger grains (30 minutes) solve faster but with less scheduling flexibility.

**Key fields:**
- `grain_index`: Sequential index across all days (0, 1, 2, ... for the entire planning horizon)
- `day_of_year`: Which day (1-365)
- `starting_minute_of_day`: Time within the day (e.g., 480 = 8:00 AM, 540 = 9:00 AM)

**Why discrete time slots?**

Instead of continuous time, meetings snap to 15-minute intervals. This:
- Simplifies conflict detection (integer comparisons)
- Matches real-world calendar behavior
- Reduces search space (finite number of start times)

**Optimization concept:** This is **time discretization** — converting continuous time into discrete slots. It's a common technique in scheduling to make problems tractable.

**Example time grains:**
```
grain_index=0  → Day 1, 8:00-8:15 AM  (starting_minute_of_day=480)
grain_index=1  → Day 1, 8:15-8:30 AM  (starting_minute_of_day=495)
grain_index=39 → Day 1, 5:45-6:00 PM  (starting_minute_of_day=1065)
grain_index=40 → Day 2, 8:00-8:15 AM  (starting_minute_of_day=480)
```

### The Room Class

```python
@dataclass
class Room:
    id: Annotated[str, PlanningId]
    name: str
    capacity: int
```

**What it represents:** A physical meeting room.

**Key fields:**
- `name`: Display name (e.g., "Room A", "Conference Room")
- `capacity`: Maximum number of people it can hold

**Optimization concept:** Rooms are **constrained resources**. Each room can host at most one meeting at a time, and must be large enough for attendees.

### The Meeting Class

```python
@dataclass
class Meeting:
    id: Annotated[str, PlanningId]
    topic: str
    duration_in_grains: int
    required_attendances: list[RequiredAttendance]
    preferred_attendances: list[PreferredAttendance]
    speakers: list[Person]
    entire_group_meeting: bool
```

**What it represents:** A meeting that needs to be scheduled.

**Key fields:**
- `topic`: Meeting subject (e.g., "Sprint Planning", "Budget Review")
- `duration_in_grains`: Length in 15-minute slots (e.g., 8 = 2 hours)
- `required_attendances`: People who must attend (hard constraint)
- `preferred_attendances`: People who should attend if possible (soft constraint)
- `speakers`: Optional presenter list
- `entire_group_meeting`: Flag for all-hands meetings

**Attendance types:**

**Required attendance** (hard constraint):
```python
@dataclass
class RequiredAttendance:
    id: Annotated[str, PlanningId]
    person: Person
    meeting: Meeting
```
The person **must** be available at the meeting time. Conflicts are hard constraint violations.

**Preferred attendance** (soft constraint):
```python
@dataclass
class PreferredAttendance:
    id: Annotated[str, PlanningId]
    person: Person
    meeting: Meeting
```
The person **should** attend if possible, but conflicts are only soft penalties.

**Optimization concept:** This is **hierarchical attendance** — distinguishing must-have from nice-to-have attendees. It allows flexible scheduling when not everyone can attend.

### The MeetingAssignment Class (Planning Entity)

```python
@planning_entity
@dataclass
class MeetingAssignment:
    id: Annotated[str, PlanningId]
    meeting: Meeting
    starting_time_grain: Annotated[TimeGrain | None, PlanningVariable] = None
    room: Annotated[Room | None, PlanningVariable] = None
    pinned: bool = False
```

**What it represents:** A decision about when and where to hold a meeting.

**Key fields:**
- `meeting`: Reference to the Meeting object (immutable)
- **`starting_time_grain`**: When the meeting starts — **this is a planning variable!**
- **`room`**: Where the meeting is held — **this is also a planning variable!**
- `pinned`: If `True`, this assignment is fixed and won't be changed by the solver

**Annotations:**
- `@planning_entity`: Tells SolverForge this class contains decisions to make
- `PlanningVariable`: Marks fields as decision variables

**Optimization concept:** Unlike employee scheduling (one variable: which employee) or vehicle routing (one list variable: which visits), this problem has **two independent planning variables** per entity. The solver must simultaneously decide both time and room.

**Why multiple planning variables matter:** Having two planning variables (time and room) per entity creates a larger search space but more flexibility. The dataclass-based domain model enables efficient evaluation of variable combinations. For architectural details on why dataclasses outperform Pydantic in constraint evaluation, see [Dataclasses vs Pydantic in Constraint Solvers](/blog/news/python-constraint-solver-architecture/).

**Important methods:**

```python
def get_last_time_grain_index(self) -> int:
    """Calculate when meeting ends."""
    return self.starting_time_grain.grain_index + self.meeting.duration_in_grains - 1

def calculate_overlap(self, other: 'MeetingAssignment') -> int:
    """Calculate overlap in time grains with another meeting."""
    if self.starting_time_grain is None or other.starting_time_grain is None:
        return 0
    
    start1 = self.starting_time_grain.grain_index
    end1 = self.get_last_time_grain_index()
    start2 = other.starting_time_grain.grain_index
    end2 = other.get_last_time_grain_index()
    
    # Interval intersection
    overlap_start = max(start1, start2)
    overlap_end = min(end1, end2)
    
    return max(0, overlap_end - overlap_start + 1)
```

This helper enables efficient overlap detection in constraints.

### The MeetingSchedule Class (Planning Solution)

```python
@planning_solution
@dataclass
class MeetingSchedule:
    day_list: Annotated[list[int], ProblemFactCollectionProperty, ValueRangeProvider]
    time_grain_list: Annotated[list[TimeGrain], ProblemFactCollectionProperty, ValueRangeProvider]
    room_list: Annotated[list[Room], ProblemFactCollectionProperty, ValueRangeProvider]
    person_list: Annotated[list[Person], ProblemFactCollectionProperty]
    meeting_list: Annotated[list[Meeting], ProblemFactCollectionProperty]
    meeting_assignment_list: Annotated[list[MeetingAssignment], PlanningEntityCollectionProperty]
    score: Annotated[HardMediumSoftScore | None, PlanningScore] = None
    solver_status: SolverStatus = SolverStatus.NOT_SOLVING
```

**What it represents:** The complete scheduling problem and its solution.

**Key fields:**
- `time_grain_list`: All available time slots (value range for `starting_time_grain`)
- `room_list`: All available rooms (value range for `room`)
- `person_list`: All people who might attend meetings
- `meeting_list`: All meetings that need scheduling
- `meeting_assignment_list`: The planning entities (what the solver optimizes)
- `score`: Solution quality metric
- `solver_status`: Whether solving is active

**Annotations explained:**
- `@planning_solution`: Marks this as the top-level problem definition
- `ProblemFactCollectionProperty`: Immutable input data
- `ValueRangeProvider`: Collections that provide possible values for planning variables
- `PlanningEntityCollectionProperty`: The entities being optimized
- `PlanningScore`: Where the solver stores calculated quality

**Optimization concept:** The `ValueRangeProvider` annotations tell the solver: "When assigning `starting_time_grain`, choose from `time_grain_list`; when assigning `room`, choose from `room_list`."

---

## How Scheduling Optimization Works

Before diving into constraints, let's understand the scheduling process.

### The Three-Tier Scoring System

Unlike employee scheduling (Hard/Soft) or vehicle routing (Hard/Soft), meeting scheduling uses **three levels**:

```
Score format: "0hard/0medium/-1234soft"
```

**Hard constraints** (priority 1):
- Room conflicts
- Required attendee conflicts
- Room capacity
- Meetings within available time
- Same-day constraints

**Medium constraints** (priority 2):
- Required vs preferred attendee conflicts
- Preferred attendee conflicts

**Soft constraints** (priority 3):
- Schedule meetings early
- Breaks between meetings
- Minimize overlaps
- Room utilization
- Room stability

**Why three tiers?**

This creates a hierarchy: hard > medium > soft. A solution with `0hard/-100medium/-5000soft` is better than `0hard/-50medium/-1000soft` even though soft score is worse, because medium takes priority.

**Optimization concept:** This is **lexicographic scoring** with three levels instead of two. It's useful when you have multiple categories of preferences with clear priority relationships.

### The Search Process

1. **Initial solution**: Often all meetings unassigned or randomly assigned
2. **Evaluate score**: Calculate all constraint penalties across three tiers
3. **Make a move**:
   - Change a meeting's time slot
   - Change a meeting's room
   - Swap two meetings' times or rooms
4. **Re-evaluate score** (incrementally)
5. **Accept if improvement** (considering all three score levels)
6. **Repeat millions of times**
7. **Return best solution found**

**Move types specific to meeting scheduling:**
- **Change time**: Move meeting to different time slot
- **Change room**: Move meeting to different room
- **Change both**: Simultaneously change time and room
- **Swap times**: Exchange times of two meetings
- **Swap rooms**: Exchange rooms of two meetings

### Why Multiple Planning Variables Matter

Having two planning variables (time and room) per entity creates interesting dynamics:

**Independent optimization**: The solver can change time without changing room, or vice versa.

**Coordinated moves**: Sometimes changing both together is better than changing separately.

**Search space**: With T time slots and R rooms, each meeting has T × R possible assignments (much larger than T or R alone).

---

## Writing Constraints: The Business Rules

Now the heart of the system. Open `src/meeting_scheduling/constraints.py`.

### The Constraint Provider Pattern

All constraints are registered in one function:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # Hard constraints
        room_conflict(constraint_factory),
        avoid_overtime(constraint_factory),
        required_attendance_conflict(constraint_factory),
        required_room_capacity(constraint_factory),
        start_and_end_on_same_day(constraint_factory),
        
        # Medium constraints
        required_and_preferred_attendance_conflict(constraint_factory),
        preferred_attendance_conflict(constraint_factory),
        
        # Soft constraints
        do_meetings_as_soon_as_possible(constraint_factory),
        one_break_between_consecutive_meetings(constraint_factory),
        overlapping_meetings(constraint_factory),
        assign_larger_rooms_first(constraint_factory),
        room_stability(constraint_factory),
    ]
```

Let's examine each constraint category.

---

## Hard Constraints

### Hard Constraint: Room Conflict

**Business rule:** "No two meetings can use the same room at overlapping times."

```python
def room_conflict(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each_unique_pair(
            MeetingAssignment,
            Joiners.equal(lambda meeting_assignment: meeting_assignment.room),
        )
        .filter(lambda meeting1, meeting2: meeting1.calculate_overlap(meeting2) > 0)
        .penalize(
            HardMediumSoftScore.ONE_HARD,
            lambda meeting1, meeting2: meeting1.calculate_overlap(meeting2)
        )
        .as_constraint("Room conflict")
    )
```

**How to read this:**
1. `for_each_unique_pair(MeetingAssignment, ...)`: Create pairs of meeting assignments
2. `Joiners.equal(...)`: Only pair meetings assigned to the same room
3. `.filter(...)`: Keep only pairs that overlap in time
4. `.penalize(ONE_HARD, ...)`: Penalize by number of overlapping time grains

**Example scenario:**

Room A, Time grains 0-11 (8:00 AM - 11:00 AM):
- Meeting 1: Time grains 0-7 (8:00-10:00 AM, 2 hours)
- Meeting 2: Time grains 4-11 (9:00-11:00 AM, 2 hours)
- **Overlap**: Time grains 4-7 (9:00-10:00 AM) = 4 grains → **Penalty: 4 hard points**

**Optimization concept:** This is a **resource conflict constraint**. The resource (room) has limited capacity (one meeting at a time), and the penalty is proportional to the conflict severity (overlap duration).

### Hard Constraint: Avoid Overtime

**Business rule:** "Meetings cannot extend beyond available time slots."

```python
def avoid_overtime(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .filter(lambda meeting_assignment: 
            meeting_assignment.get_last_time_grain_index() >= len(time_grain_list))
        .penalize(
            HardMediumSoftScore.ONE_HARD,
            lambda meeting_assignment: 
                meeting_assignment.get_last_time_grain_index() - len(time_grain_list) + 1
        )
        .as_constraint("Don't go in overtime")
    )
```

**How to read this:**
1. `for_each(MeetingAssignment)`: Consider every meeting
2. `.filter(...)`: Keep meetings that end beyond the last available time grain
3. `.penalize(...)`: Penalize by how far past the boundary

**Example scenario:**

Time grains available: 0-155 (156 total grains = 4 days × 39 grains/day)
- Meeting starts at grain 150, duration 8 grains
- Ends at grain 157 (150 + 8 - 1 = 157)
- Overtime: 157 - 155 = 2 grains → **Penalty: 2 hard points**

**Note:** This constraint assumes `time_grain_list` is available in the scope. In practice, it's passed via closure or accessed from the solution object.

### Hard Constraint: Required Attendance Conflict

**Business rule:** "Required attendees cannot be double-booked."

```python
def required_attendance_conflict(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(RequiredAttendance)
        .join(
            RequiredAttendance,
            Joiners.equal(lambda attendance: attendance.person),
            Joiners.less_than(lambda attendance: attendance.id)
        )
        .filter(
            lambda attendance1, attendance2:
                attendance1.meeting.meeting_assignment.calculate_overlap(
                    attendance2.meeting.meeting_assignment
                ) > 0
        )
        .penalize(
            HardMediumSoftScore.ONE_HARD,
            lambda attendance1, attendance2:
                attendance1.meeting.meeting_assignment.calculate_overlap(
                    attendance2.meeting.meeting_assignment
                )
        )
        .as_constraint("Required attendance conflict")
    )
```

**How to read this:**
1. `for_each(RequiredAttendance)`: Consider every required attendance
2. `.join(RequiredAttendance, ...)`: Pair with other required attendances
3. `Joiners.equal(...)`: Only pair attendances for the same person
4. `Joiners.less_than(...)`: Ensure each pair counted once (ordering by ID)
5. `.filter(...)`: Keep pairs where meetings overlap in time
6. `.penalize(...)`: Penalize by overlap duration

**Example scenario:**

Person "Amy Cole" is required at:
- Meeting A: Time grains 0-7 (8:00-10:00 AM)
- Meeting B: Time grains 6-13 (8:30-10:30 AM)
- **Overlap**: Time grains 6-7 (9:30-10:00 AM) = 2 grains → **Penalty: 2 hard points**

**Optimization concept:** This is a **person-centric conflict constraint**. Unlike room conflicts (resource conflict), this is about a person's availability (capacity of 1 meeting at a time).

**Why join on RequiredAttendance instead of MeetingAssignment?**

By joining on attendance records, we automatically filter to only the meetings each person is required at. This is more efficient than checking all meeting pairs and then filtering by attendees.

### Hard Constraint: Required Room Capacity

**Business rule:** "Rooms must have enough capacity for all attendees (required + preferred)."

```python
def required_room_capacity(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .filter(
            lambda meeting_assignment:
                len(meeting_assignment.meeting.required_attendances) +
                len(meeting_assignment.meeting.preferred_attendances) >
                meeting_assignment.room.capacity
        )
        .penalize(
            HardMediumSoftScore.ONE_HARD,
            lambda meeting_assignment:
                len(meeting_assignment.meeting.required_attendances) +
                len(meeting_assignment.meeting.preferred_attendances) -
                meeting_assignment.room.capacity
        )
        .as_constraint("Required room capacity")
    )
```

**How to read this:**
1. `for_each(MeetingAssignment)`: Consider every assigned meeting
2. `.filter(...)`: Keep meetings where attendee count exceeds room capacity
3. `.penalize(...)`: Penalize by the capacity shortage

**Example scenario:**

Meeting has:
- Required attendees: 8 people
- Preferred attendees: 4 people
- Total: 12 people

Assigned to Room B (capacity 10):
- Shortage: 12 - 10 = 2 people → **Penalty: 2 hard points**

**Design choice:** Count both required and preferred attendees. You could alternatively only count required attendees (and make preferred overflow a soft constraint).

### Hard Constraint: Start and End on Same Day

**Business rule:** "Meetings cannot span multiple days."

```python
def start_and_end_on_same_day(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .join(
            TimeGrain,
            Joiners.equal(
                lambda meeting_assignment: meeting_assignment.get_last_time_grain_index(),
                lambda time_grain: time_grain.grain_index
            )
        )
        .filter(
            lambda meeting_assignment, last_time_grain:
                meeting_assignment.starting_time_grain.day_of_year != 
                last_time_grain.day_of_year
        )
        .penalize(HardMediumSoftScore.ONE_HARD)
        .as_constraint("Start and end on same day")
    )
```

**How to read this:**
1. `for_each(MeetingAssignment)`: All meetings
2. `.join(TimeGrain, ...)`: Join with the time grain where meeting ends
3. `.filter(...)`: Keep meetings where start day ≠ end day
4. `.penalize(ONE_HARD)`: Simple binary penalty

**Example scenario:**

Meeting starts at:
- Time grain 35 (day 1, 5:15 PM, `starting_minute_of_day = 1035`)
- Duration: 8 grains (2 hours)
- Ends at grain 42 (day 2, 8:00 AM)
- Start day (1) ≠ End day (2) → **Penalty: 1 hard point**

**Optimization concept:** This enforces a **temporal boundary constraint**. Meetings respect day boundaries, which is realistic for most organizations.

---

## Medium Constraints

Medium constraints sit between hard (must satisfy) and soft (nice to have). They represent strong preferences that should rarely be violated.

### Medium Constraint: Required and Preferred Attendance Conflict

**Business rule:** "Strongly discourage conflicts where a person is required at one meeting and preferred at another."

```python
def required_and_preferred_attendance_conflict(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(RequiredAttendance)
        .join(
            PreferredAttendance,
            Joiners.equal(
                lambda required: required.person,
                lambda preferred: preferred.person
            )
        )
        .filter(
            lambda required, preferred:
                required.meeting.meeting_assignment.calculate_overlap(
                    preferred.meeting.meeting_assignment
                ) > 0
        )
        .penalize(
            HardMediumSoftScore.ONE_MEDIUM,
            lambda required, preferred:
                required.meeting.meeting_assignment.calculate_overlap(
                    preferred.meeting.meeting_assignment
                )
        )
        .as_constraint("Required and preferred attendance conflict")
    )
```

**How to read this:**
1. `for_each(RequiredAttendance)`: All required attendances
2. `.join(PreferredAttendance, ...)`: Pair with preferred attendances for same person
3. `.filter(...)`: Keep pairs where meetings overlap
4. `.penalize(ONE_MEDIUM, ...)`: Medium-level penalty by overlap

**Example scenario:**

Person "Bob Smith":
- Required at Meeting A: Time grains 0-7
- Preferred at Meeting B: Time grains 4-11
- Overlap: 4 grains → **Penalty: 4 medium points**

**Why medium instead of hard?**

This is a **degraded service scenario**. The person can't attend the preferred meeting (unfortunate) but can fulfill their required attendance (essential). It's not ideal but acceptable.

### Medium Constraint: Preferred Attendance Conflict

**Business rule:** "Discourage conflicts between two preferred attendances for the same person."

```python
def preferred_attendance_conflict(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(PreferredAttendance)
        .join(
            PreferredAttendance,
            Joiners.equal(lambda attendance: attendance.person),
            Joiners.less_than(lambda attendance: attendance.id)
        )
        .filter(
            lambda attendance1, attendance2:
                attendance1.meeting.meeting_assignment.calculate_overlap(
                    attendance2.meeting.meeting_assignment
                ) > 0
        )
        .penalize(
            HardMediumSoftScore.ONE_MEDIUM,
            lambda attendance1, attendance2:
                attendance1.meeting.meeting_assignment.calculate_overlap(
                    attendance2.meeting.meeting_assignment
                )
        )
        .as_constraint("Preferred attendance conflict")
    )
```

**Similar to required attendance conflict** but for preferred attendees.

**Why medium instead of soft?**

Preferred attendees are still important — just not critical. Medium priority expresses "try hard to avoid this" without making it a hard requirement.

---

## Soft Constraints

Soft constraints represent optimization goals and nice-to-have preferences.

### Soft Constraint: Schedule Meetings Early

**Business rule:** "Prefer scheduling meetings earlier in the day/week rather than later."

```python
def do_meetings_as_soon_as_possible(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .penalize(
            HardMediumSoftScore.ONE_SOFT,
            lambda meeting_assignment: meeting_assignment.get_last_time_grain_index()
        )
        .as_constraint("Do all meetings as soon as possible")
    )
```

**How to read this:**
1. `for_each(MeetingAssignment)`: All meetings
2. `.penalize(ONE_SOFT, ...)`: Penalize by the ending time grain index

**Why penalize by end time?**

The later a meeting ends, the higher the penalty. This naturally pushes meetings toward earlier time slots.

**Example scenarios:**
- Meeting ends at grain 10 → Penalty: 10 soft points
- Meeting ends at grain 50 → Penalty: 50 soft points
- Meeting ends at grain 100 → Penalty: 100 soft points

The solver will prefer the first meeting's timing.

**Alternative formulation:**

You could penalize by start time instead:
```python
.penalize(ONE_SOFT, lambda ma: ma.starting_time_grain.grain_index)
```

Penalizing by end time accounts for both start time and duration, which can be more balanced.

### Soft Constraint: Breaks Between Meetings

**Business rule:** "Encourage at least one 15-minute break between consecutive meetings."

```python
def one_break_between_consecutive_meetings(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .join(
            MeetingAssignment,
            Joiners.less_than(
                lambda meeting: meeting.get_last_time_grain_index(),
                lambda meeting: meeting.starting_time_grain.grain_index
            )
        )
        .filter(
            lambda meeting1, meeting2:
                meeting1.get_last_time_grain_index() + 1 ==
                meeting2.starting_time_grain.grain_index
        )
        .penalize(HardMediumSoftScore.of_soft(100))
        .as_constraint("One time grain break between two consecutive meetings")
    )
```

**How to read this:**
1. `for_each(MeetingAssignment)`: All meetings
2. `.join(MeetingAssignment, ...)`: Pair with meetings that start after this one ends
3. `.filter(...)`: Keep pairs that are back-to-back (no gap)
4. `.penalize(100 soft)`: Fixed penalty for consecutive meetings

**Example scenario:**

- Meeting A: Time grains 0-7 (ends at grain 7)
- Meeting B: Time grains 8-15 (starts at grain 8)
- Back-to-back: `7 + 1 == 8` → **Penalty: 100 soft points**

**Why not check for shared attendees?**

This constraint applies globally — any consecutive meetings are discouraged. You could enhance it to only penalize when attendees overlap:

```python
.filter(lambda m1, m2: has_shared_attendees(m1, m2))
```

### Soft Constraint: Minimize Overlapping Meetings

**Business rule:** "Generally discourage overlapping meetings, even in different rooms."

```python
def overlapping_meetings(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each_unique_pair(
            MeetingAssignment,
            Joiners.less_than(lambda meeting: meeting.id)
        )
        .filter(lambda meeting1, meeting2: meeting1.calculate_overlap(meeting2) > 0)
        .penalize(
            HardMediumSoftScore.of_soft(10),
            lambda meeting1, meeting2: meeting1.calculate_overlap(meeting2)
        )
        .as_constraint("Overlapping meetings")
    )
```

**How to read this:**
1. `for_each_unique_pair(MeetingAssignment, ...)`: All pairs of meetings
2. `.filter(...)`: Keep overlapping pairs
3. `.penalize(10 soft, ...)`: Penalize by overlap × 10

**Why discourage overlaps in different rooms?**

This creates a **temporal spread** of meetings. Benefits:
- Reduces hallway congestion
- Easier to find substitute attendees
- Better utilization of time slots

**Weight tuning:** The penalty weight (10) can be adjusted based on preference. Higher values more strongly discourage overlaps.

### Soft Constraint: Assign Larger Rooms First

**Business rule:** "Prefer using larger rooms over smaller rooms."

```python
def assign_larger_rooms_first(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .join(
            Room,
            Joiners.greater_than(
                lambda meeting_assignment: meeting_assignment.room.capacity,
                lambda room: room.capacity
            )
        )
        .penalize(
            HardMediumSoftScore.ONE_SOFT,
            lambda meeting_assignment, room:
                room.capacity - meeting_assignment.room.capacity
        )
        .as_constraint("Assign larger rooms first")
    )
```

**How to read this:**
1. `for_each(MeetingAssignment)`: All meetings
2. `.join(Room, ...)`: Join with rooms larger than the assigned room
3. `.penalize(ONE_SOFT, ...)`: Penalize by capacity difference

**Example scenario:**

Available rooms: 30, 20, 16 capacity

Meeting assigned to Room B (capacity 20):
- Room A (capacity 30) exists and is larger
- Penalty: 30 - 20 = 10 soft points

If all larger rooms are used, no penalty.

**Why prefer larger rooms?**

This implements **conservative resource allocation** — use larger rooms by default, save smaller rooms for when larger ones are occupied. This maximizes flexibility.

**Alternative approach:** You could prefer smaller rooms that fit (minimize waste):
```python
# Prefer smallest room that fits
.filter(lambda ma: ma.room.capacity >= required_capacity)
.reward(ONE_SOFT, lambda ma: ma.room.capacity)
```

The choice depends on your organization's room utilization patterns.

### Soft Constraint: Room Stability

**Business rule:** "Encourage attendees to stay in the same room for nearby meetings."

```python
def room_stability(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .join(
            RequiredAttendance,
            Joiners.equal(
                lambda meeting_assignment: meeting_assignment.meeting,
                lambda attendance: attendance.meeting
            )
        )
        .join(
            RequiredAttendance,
            Joiners.equal(
                lambda attendance, attendance2: attendance.person,
                lambda attendance2: attendance2.person
            ),
            Joiners.less_than(
                lambda meeting_assignment, attendance: meeting_assignment.id,
                lambda attendance: attendance.meeting.meeting_assignment.id
            )
        )
        .filter(
            lambda meeting1, attendance1, attendance2:
                meeting1.room != attendance2.meeting.meeting_assignment.room and
                abs(meeting1.starting_time_grain.grain_index - 
                    attendance2.meeting.meeting_assignment.starting_time_grain.grain_index)
                <= 2  # Within 2 time grains (30 minutes)
        )
        .penalize(HardMediumSoftScore.ONE_SOFT)
        .as_constraint("Room stability")
    )
```

**How to read this:**
1. `for_each(MeetingAssignment)`: All meetings
2. `.join(RequiredAttendance, ...)`: Get required attendances for this meeting
3. `.join(RequiredAttendance, ...)`: Get other meetings the same person attends
4. `.filter(...)`: Keep pairs in different rooms and close in time
5. `.penalize(ONE_SOFT)`: Simple penalty for room switches

**Example scenario:**

Person "Carol Johnson":
- Meeting A at 9:00 AM in Room A
- Meeting B at 9:30 AM in Room B (different room, 30 minutes apart)
- **Penalty: 1 soft point** (room switch)

If Meeting B were also in Room A, no penalty.

**Optimization concept:** This is a **locality constraint** — encouraging spatial proximity for temporally close activities. It reduces attendee movement.

**Time threshold:** The `<= 2` filter means within 30 minutes (2 × 15-minute grains). Adjust this based on building size and walking times.

---

## The Solver Engine

Now let's see how the solver is configured. Open `src/meeting_scheduling/solver.py`:

```python
solver_config = SolverConfig(
    solution_class=MeetingSchedule,
    entity_class_list=[MeetingAssignment],
    score_director_factory_config=ScoreDirectorFactoryConfig(
        constraint_provider_function=define_constraints
    ),
    termination_config=TerminationConfig(spent_limit=Duration(seconds=30)),
)

solver_manager = SolverManager.create(solver_config)
solution_manager = SolutionManager.create(solver_manager)
```

### Configuration Breakdown

**`solution_class`**: `MeetingSchedule` (the top-level planning solution)

**`entity_class_list`**: `[MeetingAssignment]` (the planning entities with variables)

**`score_director_factory_config`**: Links to `define_constraints` function

**`termination_config`**: Stops after 30 seconds

### Multiple Planning Variables

Unlike simpler problems with one variable per entity, `MeetingAssignment` has **two planning variables**:
- `starting_time_grain` (when)
- `room` (where)

The solver must optimize both simultaneously. This creates:

**More complex search space**: T × R possible combinations per meeting

**More move types**: Can change time, change room, or change both

**Better flexibility**: Can optimize time and room independently

**Optimization concept:** This is **multi-variable planning**. The solver uses specialized move selectors that understand how to efficiently explore both variables.

### SolverManager: Asynchronous Solving

Meeting scheduling can take time for large problems. `SolverManager` enables non-blocking solving:

```python
# Start solving (returns immediately)
solver_manager.solve_and_listen(job_id, schedule, callback_function)

# Check status
status = solver_manager.get_solver_status(job_id)

# Get current best solution (updates live)
solution = solver_manager.get_final_best_solution(job_id)

# Stop early
solver_manager.terminate_early(job_id)
```

### SolutionManager: Score Analysis

The `solution_manager` provides detailed score breakdowns:

```python
# Analyze solution
analysis = solution_manager.analyze(schedule)

# See which constraints fired
for constraint_analysis in analysis.constraint_analyses:
    print(f"{constraint_analysis.name}: {constraint_analysis.score}")
    for match in constraint_analysis.matches:
        print(f"  {match.justification}")
```

This shows exactly which constraints are violated and by how much — invaluable for debugging.

### Solving Timeline

**Small problems** (10-15 meetings, 2-3 rooms, 2 days):
- Initial feasible solution: < 1 second
- Good solution: 5-10 seconds
- High-quality: 30 seconds

**Medium problems** (20-30 meetings, 3-5 rooms, 4 days):
- Initial feasible solution: 1-5 seconds
- Good solution: 30-60 seconds
- High-quality: 2-5 minutes

**Large problems** (50+ meetings, 5+ rooms, 5+ days):
- Initial feasible solution: 5-30 seconds
- Good solution: 5-10 minutes
- High-quality: 15-30 minutes

**Factors affecting speed:**
- Number of meetings (primary factor)
- Number of attendees per meeting (affects conflict constraints)
- Time grain granularity (finer = more options = slower)
- Constraint complexity

---

## Web Interface and API

### REST API Endpoints

Open `src/meeting_scheduling/rest_api.py` to see the API. It runs on **port 8080**.

#### GET /demo-data

Returns generated demo data:

**Response:**
```json
{
  "dayList": [1, 2, 3, 4],
  "timeGrainList": [
    {"grainIndex": 0, "dayOfYear": 1, "startingMinuteOfDay": 480},
    {"grainIndex": 1, "dayOfYear": 1, "startingMinuteOfDay": 495},
    ...
  ],
  "roomList": [
    {"id": "room_0", "name": "Room 0", "capacity": 30},
    {"id": "room_1", "name": "Room 1", "capacity": 20},
    {"id": "room_2", "name": "Room 2", "capacity": 16}
  ],
  "personList": [
    {"id": "person_0", "fullName": "Amy Cole"},
    ...
  ],
  "meetingList": [
    {
      "id": "meeting_0",
      "topic": "Strategize B2B",
      "durationInGrains": 8,
      "requiredAttendances": [...],
      "preferredAttendances": [...],
      "entireGroupMeeting": false
    },
    ...
  ],
  "meetingAssignmentList": [
    {
      "id": "assignment_0",
      "meeting": "meeting_0",
      "startingTimeGrain": null,
      "room": null,
      "pinned": false
    },
    ...
  ]
}
```

**Demo data specs:**
- 4 days
- 156 time grains (39 per day, 8 AM - 6 PM)
- 3 rooms (capacities 30, 20, 16)
- 20 people
- 24 meetings

#### POST /schedules

Submit a schedule for solving:

**Request body:** Same format as demo data

**Response:** Job ID
```
"a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

**Implementation:**
```python
@app.post("/schedules")
async def solve(schedule: MeetingScheduleModel) -> str:
    job_id = str(uuid4())
    meeting_schedule = model_to_schedule(schedule)
    data_sets[job_id] = meeting_schedule
    
    solver_manager.solve_and_listen(
        job_id,
        meeting_schedule,
        lambda solution: update_solution(job_id, solution)
    )
    
    return job_id
```

The solver runs in the background, continuously updating the best solution.

#### GET /schedules/{schedule_id}

Get current solution:

**Response (while solving):**
```json
{
  "meetingAssignmentList": [
    {
      "id": "assignment_0",
      "meeting": "meeting_0",
      "startingTimeGrain": {"grainIndex": 5, ...},
      "room": {"id": "room_1", ...}
    },
    ...
  ],
  "score": "0hard/-150medium/-8945soft",
  "solverStatus": "SOLVING_ACTIVE"
}
```

**Response (finished):**
```json
{
  "score": "0hard/0medium/-6234soft",
  "solverStatus": "NOT_SOLVING"
}
```

#### GET /schedules/{problem_id}/status

Lightweight status check (doesn't return full solution):

**Response:**
```json
{
  "score": "0hard/0medium/-6234soft",
  "solverStatus": "NOT_SOLVING"
}
```

#### DELETE /schedules/{problem_id}

Stop solving early:

```python
@app.delete("/schedules/{problem_id}")
async def stop_solving(problem_id: str) -> None:
    solver_manager.terminate_early(problem_id)
```

Returns best solution found so far.

#### PUT /schedules/analyze

Analyze a solution's score:

**Request body:** Complete schedule with assignments

**Response:**
```json
{
  "score": "-2hard/-50medium/-8945soft",
  "constraints": [
    {
      "name": "Room conflict",
      "score": "-2hard/0medium/0soft",
      "matches": [
        {
          "justification": "Room room_1: Meeting A (grains 5-12) overlaps Meeting B (grains 10-17) by 2 grains",
          "indictedObjects": ["assignment_5", "assignment_12"]
        }
      ]
    },
    {
      "name": "Required attendance conflict",
      "score": "0hard/-50medium/0soft",
      "matches": [...]
    }
  ]
}
```

This endpoint is extremely useful for understanding why a solution has a particular score.

### Web UI Flow

The `static/app.js` implements this workflow:

1. **Load demo data** → `GET /demo-data`
2. **Display** unscheduled meetings and available resources
3. **User clicks "Solve"** → `POST /schedules` (get job ID)
4. **Poll** `GET /schedules/{id}/status` every 2 seconds
5. **Update visualization** with current assignments
6. **When** `solverStatus === "NOT_SOLVING"` → Stop polling
7. **Display** final schedule in timeline view

**Visualization features:**
- Timeline view by room or by person
- Color-coded meetings (by topic or priority)
- Hover details (attendees, time, room)
- Unassigned meetings highlighted
- Score breakdown panel
- Constraint analysis tab

---

## Making Your First Customization

Let's add a new constraint step-by-step.

### Scenario: Limit Meetings Per Day

**New business rule:** "No more than 5 meetings should be scheduled on any single day."

This is a **soft constraint** (preference, not requirement).

### Step 1: Open constraints.py

Navigate to `src/meeting_scheduling/constraints.py`.

### Step 2: Write the Constraint Function

Add this function:

```python
def max_meetings_per_day(constraint_factory: ConstraintFactory):
    """
    Soft constraint: Discourage having more than 5 meetings on the same day.
    """
    MAX_MEETINGS_PER_DAY = 5
    
    return (
        constraint_factory.for_each(MeetingAssignment)
        .group_by(
            lambda meeting: meeting.starting_time_grain.day_of_year,
            ConstraintCollectors.count()
        )
        .filter(lambda day, count: count > MAX_MEETINGS_PER_DAY)
        .penalize(
            HardMediumSoftScore.ONE_SOFT,
            lambda day, count: (count - MAX_MEETINGS_PER_DAY) * 100
        )
        .as_constraint("Max meetings per day")
    )
```

**How this works:**
1. Group meetings by day
2. Count meetings per day
3. Filter to days exceeding 5 meetings
4. Penalize by excess × 100

**Example:**
- Day 1: 7 meetings → Excess: 2 → Penalty: 200 soft points
- Day 2: 4 meetings → No penalty
- Day 3: 6 meetings → Excess: 1 → Penalty: 100 soft points

### Step 3: Register the Constraint

Add to `define_constraints`:

```python
@constraint_provider
def define_constraints(constraint_factory: ConstraintFactory):
    return [
        # ... existing constraints ...
        # Soft constraints
        do_meetings_as_soon_as_possible(constraint_factory),
        one_break_between_consecutive_meetings(constraint_factory),
        overlapping_meetings(constraint_factory),
        assign_larger_rooms_first(constraint_factory),
        room_stability(constraint_factory),
        max_meetings_per_day(constraint_factory),  # ← Add here
    ]
```

### Step 4: Test It

1. **Restart the server:**
   ```bash
   run-app
   ```

2. **Load demo data and solve:**
   - Open http://localhost:8080
   - Click "Solve"
   - Check meeting distribution across days

3. **Verify** meetings are more evenly spread across days

**Testing tip:** To see the effect more clearly, increase the penalty weight (e.g., `× 1000` instead of `× 100`) or lower the threshold to 3 meetings per day.

### Step 5: Add Unit Test

Create a test in `tests/test_constraints.py`:

```python
def test_max_meetings_per_day():
    """Test that exceeding 5 meetings per day creates penalty."""
    from meeting_scheduling.constraints import max_meetings_per_day
    
    # Create 6 meetings on the same day
    time_grain_day1 = TimeGrain(grain_index=0, day_of_year=1, starting_minute_of_day=480)
    
    meetings = []
    for i in range(6):
        meeting = Meeting(
            id=f"meeting_{i}",
            topic=f"Meeting {i}",
            duration_in_grains=4,
            required_attendances=[],
            preferred_attendances=[],
            speakers=[],
            entire_group_meeting=False
        )
        assignment = MeetingAssignment(
            id=f"assignment_{i}",
            meeting=meeting,
            starting_time_grain=time_grain_day1,
            room=test_room
        )
        meetings.append(assignment)
    
    # Should penalize by (6 - 5) × 100 = 100
    constraint_verifier.verify_that(max_meetings_per_day) \
        .given(*meetings) \
        .penalizes_by(100)
```

Run with:
```bash
pytest tests/test_constraints.py::test_max_meetings_per_day -v
```

---

## Advanced Constraint Patterns

### Pattern 1: Minimum Meeting Spacing

**Scenario:** Require at least 30 minutes between any two meetings (not just consecutive ones).

```python
def minimum_meeting_spacing(constraint_factory: ConstraintFactory):
    """
    Soft constraint: Encourage 30-minute spacing between all meetings.
    """
    MIN_SPACING_GRAINS = 2  # 30 minutes
    
    return (
        constraint_factory.for_each_unique_pair(
            MeetingAssignment,
            Joiners.less_than(lambda m: m.id)
        )
        .filter(lambda m1, m2: 
            abs(m1.starting_time_grain.grain_index - 
                m2.starting_time_grain.grain_index) < MIN_SPACING_GRAINS and
            m1.calculate_overlap(m2) == 0  # Not overlapping
        )
        .penalize(
            HardMediumSoftScore.ONE_SOFT,
            lambda m1, m2: MIN_SPACING_GRAINS - 
                abs(m1.starting_time_grain.grain_index - 
                    m2.starting_time_grain.grain_index)
        )
        .as_constraint("Minimum meeting spacing")
    )
```

### Pattern 2: Preferred Time Slots

**Scenario:** Some meetings should preferably be in the morning (before noon).

First, add a field to `Meeting`:

```python
@dataclass
class Meeting:
    # ... existing fields ...
    preferred_time: str = "anytime"  # "morning", "afternoon", "anytime"
```

Then the constraint:

```python
def preferred_time_slot(constraint_factory: ConstraintFactory):
    """
    Soft constraint: Honor preferred time slots.
    """
    NOON_MINUTE = 12 * 60  # 720 minutes
    
    return (
        constraint_factory.for_each(MeetingAssignment)
        .filter(lambda ma: ma.meeting.preferred_time == "morning")
        .filter(lambda ma: 
            ma.starting_time_grain.starting_minute_of_day >= NOON_MINUTE)
        .penalize(
            HardMediumSoftScore.of_soft(500),
            lambda ma: 
                ma.starting_time_grain.starting_minute_of_day - NOON_MINUTE
        )
        .as_constraint("Preferred time slot")
    )
```

Penalty increases with how far past noon the meeting is scheduled.

### Pattern 3: VIP Attendee Priority

**Scenario:** Meetings with executives should get preferred time slots and rooms.

Add a field to `Person`:

```python
@dataclass
class Person:
    id: str
    full_name: str
    is_vip: bool = False
```

Then prioritize their meetings:

```python
def vip_meeting_priority(constraint_factory: ConstraintFactory):
    """
    Soft constraint: VIP meetings scheduled early with best rooms.
    """
    return (
        constraint_factory.for_each(MeetingAssignment)
        .join(
            RequiredAttendance,
            Joiners.equal(
                lambda ma: ma.meeting,
                lambda att: att.meeting
            )
        )
        .filter(lambda ma, att: att.person.is_vip)
        .penalize(
            HardMediumSoftScore.of_soft(10),
            lambda ma, att: ma.starting_time_grain.grain_index
        )
        .as_constraint("VIP meeting priority")
    )
```

This penalizes later times more for VIP meetings, pushing them earlier.

### Pattern 4: Recurring Meeting Consistency

**Scenario:** Recurring meetings should be at the same time each day.

Add a field to identify recurring meetings:

```python
@dataclass
class Meeting:
    # ... existing fields ...
    recurrence_group: Optional[str] = None  # "weekly-standup", "daily-sync", etc.
```

Then enforce consistency:

```python
def recurring_meeting_consistency(constraint_factory: ConstraintFactory):
    """
    Soft constraint: Recurring meetings at same time each occurrence.
    """
    return (
        constraint_factory.for_each(MeetingAssignment)
        .filter(lambda ma: ma.meeting.recurrence_group is not None)
        .join(
            MeetingAssignment,
            Joiners.equal(
                lambda ma1: ma1.meeting.recurrence_group,
                lambda ma2: ma2.meeting.recurrence_group
            ),
            Joiners.less_than(lambda ma: ma.id)
        )
        .filter(lambda ma1, ma2:
            ma1.starting_time_grain.starting_minute_of_day !=
            ma2.starting_time_grain.starting_minute_of_day
        )
        .penalize(
            HardMediumSoftScore.ONE_SOFT,
            lambda ma1, ma2:
                abs(ma1.starting_time_grain.starting_minute_of_day -
                    ma2.starting_time_grain.starting_minute_of_day)
        )
        .as_constraint("Recurring meeting consistency")
    )
```

### Pattern 5: Department Room Preference

**Scenario:** Departments prefer certain rooms (closer to their area).

Add department info:

```python
@dataclass
class Person:
    # ... existing fields ...
    department: str = "General"

@dataclass
class Room:
    # ... existing fields ...
    preferred_department: Optional[str] = None
```

Then reward matches:

```python
def department_room_preference(constraint_factory: ConstraintFactory):
    """
    Soft constraint: Assign rooms preferred by attendees' departments.
    """
    return (
        constraint_factory.for_each(MeetingAssignment)
        .join(
            RequiredAttendance,
            Joiners.equal(
                lambda ma: ma.meeting,
                lambda att: att.meeting
            )
        )
        .filter(lambda ma, att:
            ma.room.preferred_department is not None and
            ma.room.preferred_department == att.person.department
        )
        .reward(HardMediumSoftScore.of_soft(50))
        .as_constraint("Department room preference")
    )
```

Each department match adds 50 soft points (reward).

---

## Testing and Validation

### Unit Testing Constraints

Best practice: Test constraints in isolation.

Open `tests/test_constraints.py` to see examples:

```python
from meeting_scheduling.domain import *
from meeting_scheduling.constraints import define_constraints
from solverforge_legacy.test import ConstraintVerifier

# Create verifier
constraint_verifier = ConstraintVerifier.build(
    define_constraints,
    MeetingSchedule,
    MeetingAssignment
)
```

**Example: Test Room Conflict**

```python
def test_room_conflict_penalized():
    """Two meetings in same room at overlapping times should penalize."""
    
    room = Room(id="room1", name="Room 1", capacity=20)
    
    # Meeting 1: Grains 0-7 (2 hours)
    meeting1 = create_test_meeting(id="m1", duration=8)
    assignment1 = MeetingAssignment(
        id="a1",
        meeting=meeting1,
        starting_time_grain=TimeGrain(0, 1, 480),
        room=room
    )
    
    # Meeting 2: Grains 5-12 (overlaps grains 5-7 = 3 grains)
    meeting2 = create_test_meeting(id="m2", duration=8)
    assignment2 = MeetingAssignment(
        id="a2",
        meeting=meeting2,
        starting_time_grain=TimeGrain(5, 1, 555),
        room=room
    )
    
    # Verify penalty of 3 hard points (overlap duration)
    constraint_verifier.verify_that(room_conflict) \
        .given(assignment1, assignment2) \
        .penalizes_by(3)
```

**Example: Test No Conflict**

```python
def test_room_conflict_not_penalized():
    """Meetings in same room without overlap should not penalize."""
    
    room = Room(id="room1", name="Room 1", capacity=20)
    
    # Meeting 1: Grains 0-7
    assignment1 = MeetingAssignment(
        id="a1",
        meeting=create_test_meeting(id="m1", duration=8),
        starting_time_grain=TimeGrain(0, 1, 480),
        room=room
    )
    
    # Meeting 2: Grains 10-17 (no overlap)
    assignment2 = MeetingAssignment(
        id="a2",
        meeting=create_test_meeting(id="m2", duration=8),
        starting_time_grain=TimeGrain(10, 1, 630),
        room=room
    )
    
    # No penalty
    constraint_verifier.verify_that(room_conflict) \
        .given(assignment1, assignment2) \
        .penalizes_by(0)
```

**Helper function:**

```python
def create_test_meeting(id: str, duration: int) -> Meeting:
    """Create a minimal meeting for testing."""
    return Meeting(
        id=id,
        topic=f"Test Meeting {id}",
        duration_in_grains=duration,
        required_attendances=[],
        preferred_attendances=[],
        speakers=[],
        entire_group_meeting=False
    )
```

**Run tests:**
```bash
pytest tests/test_constraints.py -v
```

### Integration Testing: Full Solve

Test the complete solving cycle in `tests/test_feasible.py`:

```python
def test_feasible():
    """Test that solver finds feasible solution for demo data."""
    
    # Get demo problem
    schedule = generate_demo_data()
    
    # Verify initially unassigned
    assert all(ma.starting_time_grain is None for ma in schedule.meeting_assignment_list)
    assert all(ma.room is None for ma in schedule.meeting_assignment_list)
    
    # Solve
    job_id = "test-feasible"
    solver_manager.solve(job_id, schedule)
    
    # Wait for completion
    timeout = 120  # 2 minutes
    start = time.time()
    
    while solver_manager.get_solver_status(job_id) == "SOLVING_ACTIVE":
        if time.time() - start > timeout:
            solver_manager.terminate_early(job_id)
            break
        time.sleep(2)
    
    # Get solution
    solution = solver_manager.get_final_best_solution(job_id)
    
    # Verify all assigned
    unassigned = [ma for ma in solution.meeting_assignment_list 
                  if ma.starting_time_grain is None or ma.room is None]
    assert len(unassigned) == 0, f"{len(unassigned)} meetings unassigned"
    
    # Verify feasible
    assert solution.score is not None
    assert solution.score.hard_score == 0, \
        f"Solution infeasible: {solution.score}"
    
    print(f"Final score: {solution.score}")
```

### Manual Testing via UI

1. **Start application:**
   ```bash
   run-app
   ```

2. **Open browser console** (F12) to monitor API calls

3. **Load and inspect data:**
   - Verify 24 meetings, 20 people, 3 rooms displayed
   - Check time grains span 4 days

4. **Solve and observe:**
   - Click "Solve"
   - Watch score improve in real-time
   - See meetings get assigned to rooms and times
   - Monitor constraint violations decrease

5. **Verify solution quality:**
   - Hard score should be 0 (feasible)
   - All meetings assigned (no unassigned list)
   - Room capacity respected (check stats)
   - No double-bookings (visual timeline check)

6. **Test constraint analysis:**
   - Click "Analyze" tab
   - Review constraint breakdown
   - Verify matches make sense

7. **Test early termination:**
   - Start solving
   - Click "Stop solving" after 5 seconds
   - Verify partial solution returned

---

## Production Considerations

### Performance: Constraint Evaluation Speed

Constraints are evaluated **millions of times** during solving. Performance matters.

**❌ DON'T: Complex calculations in constraints**

```python
def bad_constraint(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .filter(lambda ma: 
            expensive_api_call(ma.meeting.topic))  # SLOW!
        .penalize(HardMediumSoftScore.ONE_SOFT)
        .as_constraint("Bad")
    )
```

**✅ DO: Pre-compute before solving**

```python
# Before solving, once
blocked_topics = fetch_blocked_topics_from_api()

def good_constraint(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(MeetingAssignment)
        .filter(lambda ma: ma.meeting.topic in blocked_topics)  # Fast set lookup
        .penalize(HardMediumSoftScore.ONE_SOFT)
        .as_constraint("Good")
    )
```

### Time Grain Granularity

The default is 15-minute grains. Consider trade-offs:

**Finer granularity (5 minutes):**
- ✅ More scheduling flexibility
- ✅ Better fits meeting durations
- ❌ 3× more time slots → larger search space → slower

**Coarser granularity (30 minutes):**
- ✅ Fewer time slots → faster solving
- ❌ Less flexibility (all meetings snap to 30-min intervals)

**Recommendation:** 15 minutes is a good balance for most organizations.

### Scaling Strategies

**Problem size guidelines (30 second solve):**
- Up to 30 meetings, 5 rooms, 5 days: Good solutions
- 30-50 meetings: Increase solve time to 2-5 minutes
- 50-100 meetings: Consider decomposition

**Decomposition approaches:**

**By time period:**
```python
# Schedule week 1, then week 2
week1_meetings = [m for m in meetings if m.week == 1]
week2_meetings = [m for m in meetings if m.week == 2]

solution_week1 = solve(week1_meetings, rooms)
solution_week2 = solve(week2_meetings, rooms)
```

**By department:**
```python
# Schedule each department separately
for dept in ["Engineering", "Sales", "Marketing"]:
    dept_meetings = [m for m in meetings if m.department == dept]
    dept_solution = solve(dept_meetings, dept_rooms)
```

**By priority:**
```python
# Schedule high-priority meetings first, then fill in rest
high_pri = [m for m in meetings if m.priority == "high"]
solution_high = solve(high_pri, rooms)

# Pin high-priority assignments
for assignment in solution_high.meeting_assignment_list:
    assignment.pinned = True

# Add low-priority meetings and re-solve
all_meetings = high_pri + low_priority_meetings
final_solution = solve(all_meetings, rooms)
```

The `pinned` field prevents the solver from changing certain assignments.

### Handling Infeasible Problems

Sometimes no feasible solution exists (e.g., too many meetings, insufficient rooms).

**Detect and diagnose:**

```python
solution = solver_manager.get_final_best_solution(job_id)

if solution.score.hard_score < 0:
    # Analyze what's infeasible
    analysis = solution_manager.analyze(solution)
    
    violations = {}
    for constraint in analysis.constraint_analyses:
        if constraint.score.hard_score < 0:
            violations[constraint.name] = {
                "score": constraint.score.hard_score,
                "count": len(constraint.matches)
            }
    
    return {
        "status": "infeasible",
        "hard_score": solution.score.hard_score,
        "violations": violations,
        "suggestions": generate_suggestions(violations)
    }

def generate_suggestions(violations):
    suggestions = []
    if "Room conflict" in violations:
        suggestions.append("Add more rooms or reduce meeting durations")
    if "Required attendance conflict" in violations:
        suggestions.append("Mark some attendees as 'preferred' instead of 'required'")
    if "Required room capacity" in violations:
        suggestions.append("Use larger rooms or reduce attendee counts")
    return suggestions
```

### Real-Time Rescheduling

**Scenario:** Need to reschedule due to:
- Meeting canceled
- Room unavailable
- Attendee conflict added

**Incremental re-solving:**

```python
def cancel_meeting(schedule: MeetingSchedule, meeting_id: str):
    """Remove a meeting and re-optimize."""
    
    # Find and remove the assignment
    schedule.meeting_assignment_list = [
        ma for ma in schedule.meeting_assignment_list
        if ma.meeting.id != meeting_id
    ]
    
    # Re-solve (starting from current solution)
    job_id = f"replan-{uuid4()}"
    solver_manager.solve_and_listen(job_id, schedule, callback)
    
    return job_id

def add_urgent_meeting(schedule: MeetingSchedule, new_meeting: Meeting):
    """Add urgent meeting and re-optimize."""
    
    # Add meeting to schedule
    schedule.meeting_list.append(new_meeting)
    
    # Create assignment (initially unassigned)
    new_assignment = MeetingAssignment(
        id=f"assignment_{new_meeting.id}",
        meeting=new_meeting,
        starting_time_grain=None,
        room=None
    )
    schedule.meeting_assignment_list.append(new_assignment)
    
    # Re-solve
    solver_manager.solve_and_listen(f"urgent-{uuid4()}", schedule, callback)
```

**Optimization concept:** **Warm starting** from the current solution makes re-scheduling fast — the solver only adjusts what's necessary.

### Monitoring and Logging

**Track key metrics:**

```python
import logging

logger = logging.getLogger(__name__)

start_time = time.time()
solver_manager.solve_and_listen(job_id, schedule, callback)

# ... wait for completion ...

solution = solver_manager.get_final_best_solution(job_id)
duration = time.time() - start_time

# Metrics
total_meetings = len(solution.meeting_assignment_list)
assigned = sum(1 for ma in solution.meeting_assignment_list 
               if ma.starting_time_grain and ma.room)

logger.info(
    f"Solved schedule {job_id}: "
    f"duration={duration:.1f}s, "
    f"score={solution.score}, "
    f"assigned={assigned}/{total_meetings}, "
    f"feasible={solution.score.hard_score == 0}"
)

# Alert if infeasible
if solution.score.hard_score < 0:
    logger.warning(
        f"Infeasible schedule {job_id}: "
        f"hard_score={solution.score.hard_score}"
    )
```

---

## Quick Reference

### File Locations

| Need to... | Edit this file |
|------------|----------------|
| Add/change business rule | `src/meeting_scheduling/constraints.py` |
| Add field to Meeting | `src/meeting_scheduling/domain.py` + `converters.py` |
| Add field to Person/Room | `src/meeting_scheduling/domain.py` + `converters.py` |
| Change solve time | `src/meeting_scheduling/solver.py` |
| Change time grain size | `src/meeting_scheduling/domain.py` (GRAIN_LENGTH_IN_MINUTES) |
| Add REST endpoint | `src/meeting_scheduling/rest_api.py` |
| Change demo data | `src/meeting_scheduling/demo_data.py` |
| Change UI | `static/index.html`, `static/app.js` |

### Common Constraint Patterns

**Unary constraint (single meeting):**
```python
constraint_factory.for_each(MeetingAssignment)
    .filter(lambda ma: # condition)
    .penalize(HardMediumSoftScore.ONE_HARD)
```

**Binary constraint (pairs of meetings):**
```python
constraint_factory.for_each_unique_pair(
    MeetingAssignment,
    Joiners.equal(lambda ma: ma.room)  # Same room
)
    .filter(lambda ma1, ma2: ma1.calculate_overlap(ma2) > 0)
    .penalize(HardMediumSoftScore.ONE_HARD, 
              lambda ma1, ma2: ma1.calculate_overlap(ma2))
```

**Attendance-based constraint:**
```python
constraint_factory.for_each(RequiredAttendance)
    .join(RequiredAttendance,
          Joiners.equal(lambda att: att.person))
    .filter(lambda att1, att2: # overlapping meetings)
    .penalize(...)
```

**Grouping and counting:**
```python
constraint_factory.for_each(MeetingAssignment)
    .group_by(
        lambda ma: ma.starting_time_grain.day_of_year,
        ConstraintCollectors.count()
    )
    .filter(lambda day, count: count > MAX)
    .penalize(...)
```

**Reward instead of penalize:**
```python
.reward(HardMediumSoftScore.ONE_SOFT)
```

### Common Domain Patterns

**Check if meeting assigned:**
```python
if ma.starting_time_grain is not None and ma.room is not None:
    # Meeting is fully assigned
```

**Calculate meeting end time:**
```python
end_grain_index = ma.get_last_time_grain_index()
# or
end_grain_index = ma.starting_time_grain.grain_index + ma.meeting.duration_in_grains - 1
```

**Check overlap:**
```python
overlap_grains = meeting1.calculate_overlap(meeting2)
if overlap_grains > 0:
    # Meetings overlap
```

**Get attendee count:**
```python
total_attendees = (
    len(meeting.required_attendances) + 
    len(meeting.preferred_attendances)
)
```

**Time grain conversions:**
```python
# Grain index to time
hour = time_grain.starting_minute_of_day // 60
minute = time_grain.starting_minute_of_day % 60

# Check if morning
is_morning = time_grain.starting_minute_of_day < 12 * 60
```

### Debugging Tips

**Enable verbose logging:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Analyze solution score:**
```python
from meeting_scheduling.solver import solution_manager

analysis = solution_manager.analyze(schedule)

for constraint in analysis.constraint_analyses:
    print(f"{constraint.name}: {constraint.score}")
    for match in constraint.matches[:5]:  # First 5 matches
        print(f"  {match.justification}")
```

**Test constraint in isolation:**
```python
from solverforge_legacy.test import ConstraintVerifier

verifier = ConstraintVerifier.build(
    define_constraints,
    MeetingSchedule,
    MeetingAssignment
)

verifier.verify_that(room_conflict) \
    .given(assignment1, assignment2) \
    .penalizes_by(expected_penalty)
```

**Print meeting details:**
```python
def print_schedule(schedule: MeetingSchedule):
    """Debug helper."""
    for ma in schedule.meeting_assignment_list:
        if ma.starting_time_grain and ma.room:
            start_min = ma.starting_time_grain.starting_minute_of_day
            hour = start_min // 60
            minute = start_min % 60
            print(f"{ma.meeting.topic}: Day {ma.starting_time_grain.day_of_year}, "
                  f"{hour:02d}:{minute:02d} in {ma.room.name}")
        else:
            print(f"{ma.meeting.topic}: UNASSIGNED")
```

### Common Gotchas

1. **Forgot to handle None values**
   - Check `ma.starting_time_grain is not None` before accessing properties
   - Symptom: AttributeError: 'NoneType' object has no attribute 'grain_index'

2. **Time grain list not in scope**
   - The `avoid_overtime` constraint needs access to `time_grain_list`
   - Solution: Pass via closure or access from solution object
   - Symptom: NameError: name 'time_grain_list' is not defined

3. **Overlapping vs touching meetings**
   - Meeting ends at grain 7, next starts at grain 8: **not overlapping**
   - Use `calculate_overlap() > 0` to check
   - Symptom: False positives in conflict detection

4. **Forgot to register constraint**
   - Add to `define_constraints()` return list
   - Symptom: Constraint not enforced

5. **Score level confusion**
   - Hard: `HardMediumSoftScore.ONE_HARD`
   - Medium: `HardMediumSoftScore.ONE_MEDIUM`
   - Soft: `HardMediumSoftScore.ONE_SOFT`
   - Or: `HardMediumSoftScore.of_soft(100)`
   - Symptom: Constraint at wrong priority level

6. **Attendance navigation**
   - `RequiredAttendance` has `.person` and `.meeting`
   - Meeting has `.meeting_assignment`
   - Person doesn't directly link to meetings
   - Symptom: Can't navigate relationship

### Performance Benchmarks

**Typical evaluation speeds** (on modern hardware):

| Problem Size | Evaluations/Second | 30-Second Results |
|--------------|-------------------|-------------------|
| 10 meetings, 3 rooms, 2 days | 5,000+ | Near-optimal |
| 24 meetings, 3 rooms, 4 days | 2,000+ | High quality |
| 50 meetings, 5 rooms, 5 days | 500-1000 | Good quality |
| 100 meetings, 8 rooms, 10 days | 200-500 | Decent quality |

If significantly slower, review constraint complexity and look for expensive operations.

---

## Conclusion

You now have a complete understanding of constraint-based meeting scheduling:

✅ **Multi-resource modeling** — Coordinating time slots, rooms, and people simultaneously  
✅ **Hierarchical scoring** — Three-tier constraints (hard/medium/soft) with clear priorities  
✅ **Multiple planning variables** — Optimizing both time and room for each meeting  
✅ **Conflict resolution** — Handling required vs preferred attendance gracefully  
✅ **Customization patterns** — Extending for your organization's policies

### Next Steps

1. **Run the application** and experiment with the demo data
2. **Modify an existing constraint** — change capacity limits or time preferences
3. **Add your own constraint** — implement a rule from your organization
4. **Test thoroughly** — write unit tests for your constraints
5. **Customize the data model** — add departments, priorities, or other business fields
6. **Deploy with real data** — integrate with your calendar system

### Key Takeaways

**Three-Tier Scoring:**
- Hard: Non-negotiable requirements
- Medium: Strong preferences (degraded service acceptable)
- Soft: Optimization goals and nice-to-haves

**Multiple Planning Variables:**
- Each `MeetingAssignment` has two independent variables: time and room
- Solver optimizes both simultaneously
- Creates richer search space and better solutions

**Discrete Time Grains:**
- Convert continuous time into 15-minute slots
- Simplifies overlap detection and constraint evaluation
- Matches real-world calendar behavior

**Attendance Hierarchy:**
- Required attendance: Hard constraint (must attend)
- Preferred attendance: Soft constraint (should attend if possible)
- Enables flexible scheduling when conflicts arise

**The Power of Constraints:**
- Most business logic in one file (`constraints.py`)
- Easy to add new scheduling policies
- Declarative: describe what you want, solver finds how

### Comparison to Other Quickstarts

**vs. Employee Scheduling:**
- Employee: Single resource (employees assigned to shifts)
- Meeting: Three resources (time + room + people)
- Employee: Two-tier scoring (hard/soft)
- Meeting: Three-tier scoring (hard/medium/soft)

**vs. Vehicle Routing:**
- Routing: Spatial optimization (minimize distance)
- Meeting: Temporal optimization (minimize conflicts, pack early)
- Routing: List variables (route sequences)
- Meeting: Multiple simple variables per entity (time + room)

Each quickstart teaches complementary optimization techniques.

### Additional Resources

- [SolverForge Documentation](https://docs.solverforge.ai)
- [Meeting Scheduling Problem Overview](https://en.wikipedia.org/wiki/Meeting_scheduling_problem)
- [GitHub Repository](https://github.com/solverforge/solverforge-quickstarts)
- [Calendar Scheduling Algorithms](https://www.cs.cmu.edu/~awm/papers/scheduling.pdf)

---

**Questions?** Start by solving the demo data and observing how meetings get assigned. Try modifying constraints to see how the schedule changes. The best way to learn scheduling optimization is to experiment and visualize the results.

Happy scheduling! 📅🗓️
