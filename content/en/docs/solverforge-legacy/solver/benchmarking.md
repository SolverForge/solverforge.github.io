---
title: "Benchmarking"
linkTitle: "Benchmarking"
weight: 50
description: >
  Compare solver configurations and tune performance.
---

Benchmarking helps you compare different solver configurations and find the best settings for your problem.

## Why Benchmark

- **Compare algorithms:** Find the best algorithm combination
- **Tune parameters:** Optimize termination times, moves, etc.
- **Validate changes:** Ensure improvements don't regress
- **Understand scaling:** See how performance changes with problem size

## Basic Benchmarking

Create a simple benchmark by running the solver multiple times:

```python
import time
from statistics import mean, stdev

def benchmark_config(config: SolverConfig, problems: list, runs: int = 3):
    """Benchmark a solver configuration."""
    results = []

    for problem in problems:
        problem_results = []
        for run in range(runs):
            factory = SolverFactory.create(config)
            solver = factory.build_solver()

            start = time.time()
            solution = solver.solve(problem)
            elapsed = time.time() - start

            problem_results.append({
                "score": solution.score,
                "time": elapsed,
                "feasible": solution.score.is_feasible,
            })

        results.append({
            "problem": problem.id,
            "avg_score": mean(r["score"].soft_score for r in problem_results),
            "avg_time": mean(r["time"] for r in problem_results),
            "feasibility_rate": sum(r["feasible"] for r in problem_results) / runs,
        })

    return results
```

## Comparing Configurations

```python
def compare_termination_times():
    """Compare different termination durations."""
    base_config = SolverConfig(
        solution_class=Timetable,
        entity_class_list=[Lesson],
        score_director_factory_config=ScoreDirectorFactoryConfig(
            constraint_provider_function=define_constraints
        ),
    )

    durations = [10, 30, 60, 120, 300]  # seconds
    problems = load_benchmark_problems()

    results = {}
    for duration in durations:
        config = SolverConfig(
            **vars(base_config),
            termination_config=TerminationConfig(
                spent_limit=Duration(seconds=duration)
            ),
        )
        results[duration] = benchmark_config(config, problems)

    return results
```

## Benchmark Report

Generate a readable report:

```python
def generate_report(results: dict):
    """Generate benchmark report."""
    print("=" * 60)
    print("BENCHMARK REPORT")
    print("=" * 60)

    for config_name, config_results in results.items():
        print(f"\n{config_name}:")
        print("-" * 40)

        total_score = 0
        total_time = 0
        feasible_count = 0

        for r in config_results:
            print(f"  {r['problem']}: score={r['avg_score']:.1f}, "
                  f"time={r['avg_time']:.1f}s, "
                  f"feasible={r['feasibility_rate']*100:.0f}%")
            total_score += r["avg_score"]
            total_time += r["avg_time"]
            feasible_count += r["feasibility_rate"]

        n = len(config_results)
        print(f"\n  Average: score={total_score/n:.1f}, "
              f"time={total_time/n:.1f}s, "
              f"feasible={feasible_count/n*100:.0f}%")

    print("\n" + "=" * 60)
```

## Problem Datasets

Create consistent benchmark datasets:

```python
class BenchmarkDataset:
    """Collection of benchmark problems."""

    @staticmethod
    def small():
        """Small problems for quick testing."""
        return [
            generate_problem(lessons=20, rooms=3, timeslots=10),
            generate_problem(lessons=30, rooms=4, timeslots=10),
        ]

    @staticmethod
    def medium():
        """Medium problems for standard benchmarks."""
        return [
            generate_problem(lessons=100, rooms=10, timeslots=25),
            generate_problem(lessons=150, rooms=12, timeslots=25),
        ]

    @staticmethod
    def large():
        """Large problems for stress testing."""
        return [
            generate_problem(lessons=500, rooms=20, timeslots=50),
            generate_problem(lessons=1000, rooms=30, timeslots=50),
        ]
```

## Reproducible Benchmarks

For consistent results:

```python
def reproducible_benchmark(config: SolverConfig, problem, seed: int = 42):
    """Run benchmark with fixed seed."""
    config = SolverConfig(
        **vars(config),
        environment_mode=EnvironmentMode.REPRODUCIBLE,
        random_seed=seed,
    )

    factory = SolverFactory.create(config)
    solver = factory.build_solver()

    return solver.solve(problem)
```

## Metrics to Track

### Primary Metrics

| Metric | Description |
|--------|-------------|
| **Best Score** | Final solution quality |
| **Time to Best** | When best score was found |
| **Feasibility Rate** | % of runs finding feasible solution |

### Secondary Metrics

| Metric | Description |
|--------|-------------|
| **Score Over Time** | Score improvement curve |
| **Steps per Second** | Algorithm throughput |
| **Memory Usage** | Peak memory consumption |

## Score Over Time

Track how score improves:

```python
def benchmark_with_history(config: SolverConfig, problem):
    """Benchmark with score history."""
    history = []

    def on_progress(event):
        history.append({
            "time": event.time_spent.total_seconds(),
            "score": event.new_best_score,
        })

    factory = SolverFactory.create(config)
    solver = factory.build_solver()
    solver.add_event_listener(on_progress)

    solution = solver.solve(problem)

    return {
        "final_score": solution.score,
        "history": history,
    }
```

## Visualization

Plot results with matplotlib:

```python
import matplotlib.pyplot as plt

def plot_score_over_time(results: dict):
    """Plot score improvement over time."""
    plt.figure(figsize=(10, 6))

    for config_name, result in results.items():
        times = [h["time"] for h in result["history"]]
        scores = [h["score"].soft_score for h in result["history"]]
        plt.plot(times, scores, label=config_name)

    plt.xlabel("Time (seconds)")
    plt.ylabel("Soft Score")
    plt.title("Score Improvement Over Time")
    plt.legend()
    plt.grid(True)
    plt.savefig("benchmark_results.png")
```

## CI/CD Integration

Add benchmarks to your pipeline:

```python
# test_benchmark.py
import pytest

def test_minimum_score():
    """Ensure solver achieves minimum score."""
    config = load_production_config()
    problem = BenchmarkDataset.small()[0]

    factory = SolverFactory.create(config)
    solver = factory.build_solver()
    solution = solver.solve(problem)

    assert solution.score.is_feasible, "Solution should be feasible"
    assert solution.score.soft_score >= -100, "Score should be >= -100"


def test_performance_regression():
    """Check for performance regression."""
    config = load_production_config()
    problem = BenchmarkDataset.medium()[0]

    start = time.time()
    factory = SolverFactory.create(config)
    solver = factory.build_solver()
    solution = solver.solve(problem)
    elapsed = time.time() - start

    assert solution.score.is_feasible
    assert elapsed < 120, "Should complete within 2 minutes"
```

## Best Practices

### Do

- Use consistent problem datasets
- Run multiple times (3-5) for statistical significance
- Track both score and time
- Use reproducible mode for comparisons

### Don't

- Compare results from different machines
- Use production data for benchmarks (privacy)
- Optimize for benchmark problems only
- Ignore feasibility rate

## Next Steps

- [Algorithms](../algorithms/) - Understand optimization algorithms
- [Performance](../constraints/performance.md) - Optimize constraints
