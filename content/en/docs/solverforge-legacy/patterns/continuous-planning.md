---
title: "Continuous Planning"
linkTitle: "Continuous Planning"
weight: 20
tags: [concepts, python]
description: >
  Rolling horizon and replanning strategies.
---

**Continuous planning** handles problems that span long time periods by using a rolling planning window. Instead of planning everything at once, you plan a window and move it forward as time passes.

## The Challenge

Planning a full year of shifts at once:
- Huge problem size
- Far-future plans become irrelevant
- Real-world changes invalidate long-term plans

## Rolling Horizon

Plan only a window of time, then slide it forward:

```
Time ──────────────────────────────────────────►

Window 1: [====Plan====]
Window 2:    [====Plan====]
Window 3:       [====Plan====]
```

### Implementation

```python
from datetime import datetime, timedelta

def plan_window(start_date: date, window_days: int, problem: Schedule) -> Schedule:
    """Plan a time window."""
    end_date = start_date + timedelta(days=window_days)

    # Filter entities to window
    window_shifts = [
        s for s in problem.shifts
        if start_date <= s.date < end_date
    ]

    window_problem = Schedule(
        employees=problem.employees,
        shifts=window_shifts,
    )

    solver = create_solver()
    return solver.solve(window_problem)


def continuous_plan(problem: Schedule, window_days: int = 14):
    """Run continuous planning with rolling windows."""
    current_date = date.today()
    end_date = max(s.date for s in problem.shifts)

    while current_date < end_date:
        solution = plan_window(current_date, window_days, problem)
        save_solution(solution)

        # Move window forward
        current_date += timedelta(days=7)  # Overlap
```

## Published vs Draft

Divide the window into published (locked) and draft (changeable):

```
Time ──────────────────────────────────────────►

      [Published][====Draft====]
      (Locked)   (Can change)
```

### Implementation with Pinning

```python
def prepare_window(problem: Schedule, publish_deadline: datetime):
    """Pin published shifts, leave draft unpinned."""
    for shift in problem.shifts:
        if shift.start_time < publish_deadline:
            shift.pinned = True
        else:
            shift.pinned = False

    return problem
```

## Replanning Triggers

Replan when:

1. **Time-based:** Every hour, day, or week
2. **Event-based:** New orders, cancellations, resource changes
3. **Threshold-based:** When score degrades below threshold

### Event-Based Replanning

```python
def on_new_order(order: Order, active_job_id: str):
    """Trigger replanning when new order arrives."""
    solver_manager.terminate_early(active_job_id)

    updated_problem = load_current_state()
    updated_problem.orders.append(order)

    new_job_id = start_solving(updated_problem)
    return new_job_id
```

## Warm Starting

Start from the previous solution to preserve good assignments:

```python
def warm_start_plan(previous: Schedule, new_shifts: list[Shift]) -> Schedule:
    """Start from previous solution, add new shifts."""
    # Keep previous assignments (pinned or as starting point)
    for shift in previous.shifts:
        if shift.employee is not None:
            shift.pinned = True  # Or just leave assigned

    # Add new unassigned shifts
    for shift in new_shifts:
        shift.employee = None
        shift.pinned = False
        previous.shifts.append(shift)

    return solve(previous)
```

## Time Windows

### Sliding Window

```
Week 1: Plan days 1-14
Week 2: Plan days 8-21 (7-day overlap)
Week 3: Plan days 15-28
```

The overlap allows replanning of near-future assignments.

### Growing Window

For finite problems, grow the window:

```
Day 1: Plan days 1-7
Day 2: Plan days 1-14
Day 3: Plan days 1-21
...until complete
```

## Handling Conflicts

When replanning conflicts with executed work:

```python
def merge_with_reality(planned: Schedule, actual: Schedule) -> Schedule:
    """Merge planned schedule with actual execution."""
    for planned_shift in planned.shifts:
        actual_shift = find_actual(actual, planned_shift.id)

        if actual_shift and actual_shift.is_started:
            # Can't change started shifts
            planned_shift.employee = actual_shift.employee
            planned_shift.pinned = True

    return planned
```

## Best Practices

### Do

- Use overlapping windows for smoother transitions
- Pin executed/committed work
- Warm start from previous solutions
- Handle edge cases (window boundaries)

### Don't

- Plan too far ahead (changes will invalidate)
- Forget to merge with reality
- Ignore the transition between windows

## Example: Weekly Scheduling

```python
class WeeklyScheduler:
    def __init__(self):
        self.solver_manager = create_solver_manager()

    def plan_next_week(self):
        """Run weekly planning cycle."""
        # Load current state
        current = load_current_schedule()

        # Determine window
        today = date.today()
        window_start = today + timedelta(days=(7 - today.weekday()))  # Next Monday
        window_end = window_start + timedelta(days=14)

        # Pin this week (being executed)
        for shift in current.shifts:
            if shift.date < window_start:
                shift.pinned = True
            elif shift.date < window_end:
                shift.pinned = False  # Can replan
            else:
                continue  # Outside window

        # Solve
        solution = self.solve(current)

        # Publish next week
        publish_week(solution, window_start, window_start + timedelta(days=7))

        return solution
```

## Next Steps

- [Real-Time Planning](real-time-planning.md) - Handle immediate changes
- [Pinning](../modeling/pinning.md) - Lock assignments
