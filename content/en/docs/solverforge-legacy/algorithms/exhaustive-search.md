---
title: "Exhaustive Search"
linkTitle: "Exhaustive Search"
weight: 30
description: >
  Find optimal solutions with exhaustive search (for small problems).
---

**Exhaustive search** algorithms explore all possible solutions to find the optimal one. They guarantee the best solution but are only practical for small problems.

## When to Use

Exhaustive search is only feasible when:

- Problem is very small (< 20 entities, few values)
- You need a guaranteed optimal solution
- You have time to wait for completion

For most problems, local search finds near-optimal solutions much faster.

## Branch and Bound

The main exhaustive search algorithm. It systematically explores the solution space while pruning branches that can't improve on the best solution found.

### How It Works

```
                    Root (no assignments)
                   /    |    \
            Entity1=A  Entity1=B  Entity1=C
              /  \        |          |
        E2=A  E2=B    E2=A         ...
        /  \    |      |
      E3=A ...  X    (pruned)
       |
    (Best?)
```

1. Build a tree of partial solutions
2. At each node, try assigning a value to the next entity
3. Calculate a score bound for the branch
4. If bound is worse than best known solution, prune the branch
5. Continue until all branches are explored or pruned

### Pruning

Pruning is key to performance:

```
Best so far: -5hard/0soft

Current partial: -3hard/?soft
→ Continue (might improve)

Current partial: -10hard/?soft
→ Prune (can't beat best)
```

## Brute Force

Tries every possible combination without pruning:

- Guarantees optimal solution
- Extremely slow (exponential time)
- Only for very small problems or validation

### Complexity

For N entities with M possible values each:
- Combinations: M^N
- Example: 10 entities × 10 values = 10^10 = 10 billion combinations

## Comparison

| Aspect | Branch and Bound | Brute Force |
|--------|------------------|-------------|
| Optimality | Guaranteed | Guaranteed |
| Speed | Better (pruning) | Very slow |
| Memory | Higher | Lower |
| Use case | Small problems | Tiny problems |

## Practical Limits

| Problem Size | Exhaustive Search Feasibility |
|--------------|-------------------------------|
| < 10 entities | Possible (seconds to minutes) |
| 10-20 entities | Challenging (minutes to hours) |
| > 20 entities | Usually impractical |

## When Local Search is Better

For most real problems, local search is the right choice:

| Problem | Entities | Exhaustive | Local Search |
|---------|----------|------------|--------------|
| Small demo | 10 | 1 second | 1 second |
| School timetabling | 200 | Years | 30 seconds |
| Vehicle routing | 100 | Years | 1 minute |

## Hybrid Approach

Use exhaustive search to validate local search:

```python
def validate_optimality(problem):
    """
    For small problems, verify local search finds optimal.
    For testing only!
    """
    # Run local search
    local_solution = run_local_search(problem)

    # Run exhaustive search (small problems only!)
    optimal_solution = run_exhaustive(problem)

    assert local_solution.score == optimal_solution.score
```

## Best Practices

### Do

- Use exhaustive search only for very small problems
- Use it to validate your constraint model on tiny examples
- Understand that it's for special cases, not general use

### Don't

- Expect exhaustive search to scale
- Use it in production for real-world problems
- Wait for results on large problems (it won't finish)

## Next Steps

- [Local Search](local-search.md) - For practical problem sizes
- [Benchmarking](../solver/benchmarking.md) - Compare approaches
