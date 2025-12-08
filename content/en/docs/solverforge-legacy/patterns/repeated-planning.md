---
title: "Repeated Planning"
linkTitle: "Repeated Planning"
weight: 30
description: >
  Batch optimization and periodic replanning.
---

**Repeated planning** runs the solver on a regular schedule, optimizing batches of work. Unlike continuous planning, each run is independent.

## Use Cases

- Daily route optimization
- Weekly shift scheduling
- Periodic resource allocation
- Batch order assignment

## Basic Pattern

```python
from datetime import datetime
import schedule
import time

def daily_optimization():
    """Run optimization every day at 2 AM."""
    # Load today's problem
    problem = load_todays_problem()

    # Solve
    solver = create_solver()
    solution = solver.solve(problem)

    # Save results
    save_solution(solution)
    notify_stakeholders(solution)

# Schedule daily run
schedule.every().day.at("02:00").do(daily_optimization)

while True:
    schedule.run_pending()
    time.sleep(60)
```

## Batch Processing

Process multiple independent problems:

```python
def optimize_all_regions():
    """Optimize each region independently."""
    regions = load_regions()
    results = {}

    for region in regions:
        problem = load_region_problem(region)
        solution = solve(problem)
        results[region] = solution
        save_solution(region, solution)

    return results
```

### Parallel Batch Processing

```python
from concurrent.futures import ThreadPoolExecutor

def optimize_regions_parallel():
    """Optimize regions in parallel."""
    regions = load_regions()

    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {
            executor.submit(solve_region, region): region
            for region in regions
        }

        results = {}
        for future in futures:
            region = futures[future]
            results[region] = future.result()

    return results
```

## Time-Based Replanning

### Fixed Schedule

```python
# Every hour
schedule.every().hour.do(replan)

# Every day at specific time
schedule.every().day.at("06:00").do(replan)

# Every Monday
schedule.every().monday.at("00:00").do(weekly_plan)
```

### Cron-Based

```python
from apscheduler.schedulers.background import BackgroundScheduler

scheduler = BackgroundScheduler()

# Run at 2 AM every day
scheduler.add_job(daily_optimization, 'cron', hour=2)

# Run every 30 minutes
scheduler.add_job(frequent_replan, 'cron', minute='*/30')

scheduler.start()
```

## Handling Failures

```python
def robust_optimization():
    """Optimization with retry and fallback."""
    max_retries = 3

    for attempt in range(max_retries):
        try:
            problem = load_problem()
            solution = solve(problem)
            save_solution(solution)
            return solution

        except Exception as e:
            logger.error(f"Attempt {attempt + 1} failed: {e}")
            if attempt < max_retries - 1:
                time.sleep(60)  # Wait before retry
            else:
                # Use previous solution as fallback
                return load_previous_solution()
```

## Comparing Solutions

Track solution quality over time:

```python
def track_solution_quality(solution: Schedule):
    """Log solution metrics for analysis."""
    metrics = {
        "timestamp": datetime.now().isoformat(),
        "score": str(solution.score),
        "feasible": solution.score.is_feasible,
        "entity_count": len(solution.shifts),
        "assigned_count": sum(1 for s in solution.shifts if s.employee),
    }

    log_metrics(metrics)

    # Alert if quality degrades
    if not solution.score.is_feasible:
        send_alert("Infeasible solution generated!")
```

## Incremental vs Fresh

### Fresh Start

Each run starts from scratch:

```python
def fresh_optimization():
    problem = load_problem()
    # All entities unassigned
    for entity in problem.entities:
        entity.planning_variable = None
    return solve(problem)
```

### Incremental (Warm Start)

Start from previous solution:

```python
def incremental_optimization():
    previous = load_previous_solution()

    # Keep good assignments, clear bad ones
    for entity in previous.entities:
        if should_keep(entity):
            entity.pinned = True
        else:
            entity.planning_variable = None
            entity.pinned = False

    return solve(previous)
```

## Monitoring

```python
class OptimizationMonitor:
    def __init__(self):
        self.runs = []

    def record_run(self, solution, duration):
        self.runs.append({
            "time": datetime.now(),
            "score": solution.score,
            "duration": duration,
            "feasible": solution.score.is_feasible,
        })

    def get_statistics(self):
        if not self.runs:
            return None

        feasible_rate = sum(r["feasible"] for r in self.runs) / len(self.runs)
        avg_duration = sum(r["duration"] for r in self.runs) / len(self.runs)

        return {
            "total_runs": len(self.runs),
            "feasibility_rate": feasible_rate,
            "avg_duration_seconds": avg_duration,
        }
```

## Best Practices

### Do

- Log all runs for analysis
- Implement retry logic
- Monitor solution quality trends
- Use appropriate scheduling library

### Don't

- Run optimization during peak hours
- Ignore failures silently
- Forget to save results
- Overload with too frequent replanning

## Next Steps

- [Continuous Planning](continuous-planning.md) - For dynamic problems
- [Benchmarking](../solver/benchmarking.md) - Track performance
