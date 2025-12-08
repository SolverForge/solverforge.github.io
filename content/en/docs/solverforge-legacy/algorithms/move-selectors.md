---
title: "Move Selectors"
linkTitle: "Move Selectors"
weight: 40
description: >
  Reference for move types available in local search.
---

**Move selectors** generate the moves that local search evaluates. Different move types are effective for different problems.

## Move Types

### Change Move

Changes one planning variable to a different value:

```
Before: lesson.room = Room A
After:  lesson.room = Room B
```

Best for: Assignment problems, scheduling

### Swap Move

Swaps values between two entities:

```
Before: lesson1.room = Room A, lesson2.room = Room B
After:  lesson1.room = Room B, lesson2.room = Room A
```

Best for: When both changes are needed for improvement

### Pillar Change Move

Changes multiple entities with the same value simultaneously:

```
Before: [lesson1, lesson2, lesson3].room = Room A
After:  [lesson1, lesson2, lesson3].room = Room B
```

Best for: Grouped entities that should move together

### Pillar Swap Move

Swaps values between two groups of entities:

```
Before: [l1, l2].room = A, [l3, l4].room = B
After:  [l1, l2].room = B, [l3, l4].room = A
```

Best for: Problems with entity groups

### List Change Move (for List Variables)

Changes an element's position in a list:

```
Before: vehicle.visits = [A, B, C, D]
Move: Move C from position 2 to position 0
After:  vehicle.visits = [C, A, B, D]
```

Best for: Routing, sequencing

### List Swap Move

Swaps two elements within or between lists:

```
Before: vehicle1.visits = [A, B], vehicle2.visits = [C, D]
Move: Swap B and C
After:  vehicle1.visits = [A, C], vehicle2.visits = [B, D]
```

Best for: Rebalancing routes

### 2-Opt Move

Reverses a segment of a list:

```
Before: vehicle.visits = [A, B, C, D, E]
Move: Reverse [B, C, D]
After:  vehicle.visits = [A, D, C, B, E]
```

Best for: Routing (reduces "crossing" paths)

### Sublist Change Move

Moves a subsequence to a different position:

```
Before: vehicle.visits = [A, B, C, D, E]
Move: Move [B, C] to end
After:  vehicle.visits = [A, D, E, B, C]
```

Best for: Batch relocations

### Sublist Swap Move

Swaps two subsequences:

```
Before: vehicle1.visits = [A, B, C], vehicle2.visits = [X, Y, Z]
Move: Swap [B, C] and [Y, Z]
After:  vehicle1.visits = [A, Y, Z], vehicle2.visits = [X, B, C]
```

Best for: Inter-route optimization

## Default Move Selectors

SolverForge automatically selects appropriate moves based on your variable types:

| Variable Type | Default Moves |
|---------------|---------------|
| `PlanningVariable` | Change, Swap |
| `PlanningListVariable` | List Change, List Swap, 2-Opt |

## Move Selection Process

```
1. Selector generates candidate moves
2. Each move is evaluated (score calculated)
3. Acceptance criteria decides to apply or not
4. Repeat
```

## Move Efficiency

### Incremental Scoring

Moves are scored incrementally—only recalculating affected constraints:

```
Change lesson.room = A → B
Only recalculate:
├── Room conflict (for A and B)
├── Teacher room stability
└── (Other constraints unaffected)
```

This makes move evaluation fast.

### Move Speed

Typical moves evaluated per second:

| Scenario | Moves/Second |
|----------|--------------|
| Simple constraints | 10,000+ |
| Complex constraints | 1,000-10,000 |
| Very complex | 100-1,000 |

More moves = more exploration = better solutions (usually).

## Filtering Moves

The solver automatically filters invalid moves:

- Moves that don't change anything (same value)
- Moves that violate pinning
- Moves on uninitialized variables

## Move Caching

To avoid regenerating the same moves:

- Construction moves are cached
- Local search moves are regenerated (solution changes)

## Performance Impact

Move selection affects:

1. **Diversity:** Different move types explore different parts of the search space
2. **Speed:** Some moves are faster to evaluate
3. **Effectiveness:** Some moves are more likely to find improvements

## Problem-Specific Guidance

### Scheduling (Timetabling, Shifts)

- Change moves: Reassign timeslot, room, employee
- Swap moves: Exchange assignments
- Default selection works well

### Routing (VRP)

- List moves: Reorder visits
- 2-Opt: Eliminate crossing paths
- Sublist moves: Move segments between vehicles

### Assignment (Task Assignment, Bin Packing)

- Change moves: Reassign to different resource
- Swap moves: Exchange assignments
- Pillar moves: Move groups together

## Troubleshooting

### Slow Moves

If moves are slow:
1. Check constraint complexity
2. Optimize filtering (use joiners)
3. Reduce problem size

### Poor Improvement

If solutions don't improve:
1. Run longer
2. Ensure moves can reach better solutions
3. Check if stuck in local optimum

## Next Steps

- [Local Search](local-search.md) - How moves are used
- [Performance](../constraints/performance.md) - Speed up constraint evaluation
