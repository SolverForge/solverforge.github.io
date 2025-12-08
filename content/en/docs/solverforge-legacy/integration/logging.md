---
title: "Logging"
linkTitle: "Logging"
weight: 30
description: >
  Configure logging for debugging and monitoring.
---

Configure Python logging to monitor solver behavior and debug issues.

## Basic Configuration

```python
import logging

# Configure root logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)

# Get logger for your app
logger = logging.getLogger("my_app")
```

## Solver Logging

The solver uses the `ai.timefold` logger hierarchy:

```python
# Enable solver debug logging
logging.getLogger("ai.timefold").setLevel(logging.DEBUG)

# Or just specific components
logging.getLogger("ai.timefold.solver").setLevel(logging.DEBUG)
```

## Log Levels

| Level | Use Case |
|-------|----------|
| DEBUG | Detailed solver internals |
| INFO | Progress updates, scores |
| WARNING | Potential issues |
| ERROR | Failures |

## Progress Logging

Log solver progress with event listeners:

```python
from solverforge_legacy.solver import BestSolutionChangedEvent

logger = logging.getLogger("solver")

def on_progress(event: BestSolutionChangedEvent):
    logger.info(
        f"Score: {event.new_best_score} | "
        f"Time: {event.time_spent} | "
        f"Initialized: {event.is_new_best_solution_initialized}"
    )

solver.add_event_listener(on_progress)
```

## File Logging

Write logs to a file:

```python
import logging

# Create file handler
file_handler = logging.FileHandler("solver.log")
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
))

# Add to logger
logging.getLogger().addHandler(file_handler)
```

## Structured Logging

For production, use structured logging:

```python
import json
import logging

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "score"):
            log_data["score"] = record.score
        if hasattr(record, "job_id"):
            log_data["job_id"] = record.job_id
        return json.dumps(log_data)


handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.getLogger().addHandler(handler)
```

### Logging with Context

```python
def log_with_context(logger, job_id, message, **kwargs):
    extra = {"job_id": job_id, **kwargs}
    logger.info(message, extra=extra)

# Usage
log_with_context(logger, "job-123", "Solving started", entities=100)
```

## FastAPI Logging

```python
from fastapi import FastAPI, Request
import logging
import time

logger = logging.getLogger("api")

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start

    logger.info(
        f"{request.method} {request.url.path} "
        f"- {response.status_code} - {duration:.3f}s"
    )
    return response
```

## Debugging Tips

### Enable Verbose Logging

```python
# Maximum verbosity
logging.getLogger().setLevel(logging.DEBUG)
logging.getLogger("ai.timefold").setLevel(logging.DEBUG)
```

### Log Constraint Matches

```python
def debug_constraints(solution):
    logger = logging.getLogger("constraints")
    analysis = solution_manager.analyze(solution)

    for constraint in analysis.constraint_analyses():
        logger.debug(
            f"{constraint.constraint_name}: "
            f"score={constraint.score}, matches={constraint.match_count}"
        )
        for match in constraint.matches():
            logger.debug(f"  - {match.justification}")
```

### Log Configuration

```python
def log_config(config: SolverConfig):
    logger = logging.getLogger("config")
    logger.info(f"Solution class: {config.solution_class}")
    logger.info(f"Entity classes: {config.entity_class_list}")
    logger.info(f"Termination: {config.termination_config}")
```

## Production Recommendations

### Log Aggregation

Send logs to a central system:

```python
# Example with Python logging to stdout (for container orchestration)
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s',  # JSON formatted
    stream=sys.stdout,
)
```

### Metrics

Track key metrics:

```python
from dataclasses import dataclass
from datetime import datetime

@dataclass
class SolveMetrics:
    job_id: str
    start_time: datetime
    end_time: datetime | None = None
    final_score: str | None = None
    is_feasible: bool | None = None

    def log(self):
        duration = (self.end_time - self.start_time).total_seconds() if self.end_time else 0
        logger.info(
            f"Job {self.job_id}: "
            f"duration={duration:.1f}s, "
            f"score={self.final_score}, "
            f"feasible={self.is_feasible}"
        )
```

### Alerting

Alert on issues:

```python
def check_solution_quality(solution, job_id):
    if not solution.score.is_feasible:
        logger.warning(f"Job {job_id} produced infeasible solution!")
        send_alert(f"Infeasible solution for job {job_id}")

    if solution.score.soft_score < -10000:
        logger.warning(f"Job {job_id} has poor soft score: {solution.score}")
```

## Next Steps

- [FastAPI](fastapi.md) - API integration
- [Benchmarking](../solver/benchmarking.md) - Performance tracking
