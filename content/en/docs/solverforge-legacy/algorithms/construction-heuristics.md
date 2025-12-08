---
title: "Construction Heuristics"
linkTitle: "Construction Heuristics"
weight: 10
description: >
  Build an initial solution quickly with construction heuristics.
---

A **construction heuristic** builds an initial solution by assigning values to all planning variables. It runs fast but may not find an optimal solution—that's the job of local search.

## Why Construction Heuristics?

- **Fast initialization:** Quickly assigns all variables
- **Warm start:** Gives local search a good starting point
- **Automatic termination:** Stops when all variables are assigned

## First Fit

### Algorithm

First Fit cycles through planning entities in default order, assigning each to the best available value:

1. Take the first unassigned entity
2. Try each possible value
3. Assign the value with the best score
4. Repeat until all entities are assigned

### Behavior

```
Entity 1 → Best value found → Assigned (never changed)
Entity 2 → Best value found → Assigned (never changed)
Entity 3 → Best value found → Assigned (never changed)
...
```

### Limitations

- Order matters: Early assignments may block better solutions
- No backtracking: Once assigned, values don't change
- May not find feasible solution if early choices are poor

## First Fit Decreasing

### Algorithm

Like First Fit, but sorts entities by difficulty first:

1. Sort entities by difficulty (hardest first)
2. Assign difficult entities first
3. Easy entities fit in remaining slots

### Why It Helps

Difficult entities (those with fewer valid options) are assigned first while there are more options available. Easy entities can usually fit anywhere.

### Example

For school timetabling:
- Teachers with many constraints → assigned first
- Teachers with few constraints → assigned last

## Default Behavior

SolverForge uses **First Fit Decreasing** by default. This works well for most problems without configuration.

## How It Works Internally

```
Phase: Construction Heuristic
├── Sort entities by difficulty
├── For each unassigned entity:
│   ├── Try each value from value range
│   ├── Calculate score impact
│   └── Assign best value
└── Done when all entities assigned
```

## Construction vs Local Search

| Aspect | Construction | Local Search |
|--------|--------------|--------------|
| Purpose | Build initial solution | Improve existing solution |
| Speed | Very fast | Runs until termination |
| Quality | Decent | Optimal/near-optimal |
| Changes | Assigns unassigned only | Modifies assigned values |

## When Construction Fails

If construction can't find a feasible solution:

1. **Overconstrained problem:** Not enough resources for all entities
2. **Tight constraints:** Early assignments block later ones
3. **Poor entity ordering:** Important entities assigned last

### Solutions

- Use medium constraints for "assign as many as possible"
- Add nullable planning variables
- Let local search fix infeasibilities

## Monitoring Construction

```python
from solverforge_legacy.solver import BestSolutionChangedEvent

def on_progress(event: BestSolutionChangedEvent):
    if not event.is_new_best_solution_initialized:
        print("Construction phase...")
    else:
        print("Local search phase...")

solver.add_event_listener(on_progress)
```

## Performance Tips

### Entity Ordering

Entities are processed in declaration order by default. For better results:

- Define difficult entities first in your entity list
- Or implement difficulty comparison

### Value Ordering

Values are tried in order. Better default values lead to faster construction.

## Next Steps

- [Local Search](local-search.md) - Improve the initial solution
- [Move Selectors](move-selectors.md) - Customize optimization moves
