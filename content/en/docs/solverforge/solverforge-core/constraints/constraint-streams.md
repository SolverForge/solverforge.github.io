---
title: "Constraint Streams"
linkTitle: "Streams"
weight: 10
description: "Build constraints with forEach, filter, join, groupBy, and more"
---

# Constraint Streams

Constraint streams are pipelines of operations that select, filter, and score entities.

## Stream Operations

### Source Operations

#### for_each

Select all instances of a class:

```rust
StreamComponent::for_each("Shift")
```

#### for_each_including_unassigned

Include entities with unassigned planning variables:

```rust
StreamComponent::for_each_including_unassigned("Shift")
```

#### for_each_unique_pair

Select unique pairs of the same class (avoiding duplicates and self-pairs):

```rust
StreamComponent::for_each_unique_pair("Shift")

// With joiners for efficient matching
StreamComponent::for_each_unique_pair_with_joiners(
    "Shift",
    vec![Joiner::equal(WasmFunction::new("get_Shift_employee"))]
)
```

### Filter Operations

#### filter

Keep only elements matching a predicate:

```rust
StreamComponent::filter(WasmFunction::new("skillMismatch"))
```

The predicate is a WASM function that returns true to include the element.

### Join Operations

#### join

Join with another class:

```rust
StreamComponent::join("Employee")

// With joiners
StreamComponent::join_with_joiners(
    "Shift",
    vec![Joiner::equal(WasmFunction::new("get_Shift_employee"))]
)
```

#### if_exists

Keep elements where a matching element exists in another class:

```rust
StreamComponent::if_exists("Conflict")

StreamComponent::if_exists_with_joiners(
    "Conflict",
    vec![Joiner::equal(WasmFunction::new("get_id"))]
)
```

#### if_not_exists

Keep elements where no matching element exists:

```rust
StreamComponent::if_not_exists("Conflict")

StreamComponent::if_not_exists_with_joiners(
    "Conflict",
    vec![Joiner::filtering(WasmFunction::new("is_conflict"))]
)
```

### Aggregation Operations

#### group_by

Group elements by keys and aggregate with collectors:

```rust
// Group by employee, count shifts
StreamComponent::group_by(
    vec![WasmFunction::new("get_Shift_employee")],
    vec![Collector::count()]
)

// Group by key only (no aggregation)
StreamComponent::group_by_key(WasmFunction::new("get_employee"))

// Aggregate only (no grouping)
StreamComponent::group_by_collector(Collector::count())
```

### Transformation Operations

#### map

Transform elements:

```rust
StreamComponent::map(vec![
    WasmFunction::new("get_employee"),
    WasmFunction::new("get_shift_count")
])

StreamComponent::map_single(WasmFunction::new("get_value"))
```

#### flatten_last

Flatten a collection in the last position of a tuple:

```rust
StreamComponent::flatten_last()

StreamComponent::flatten_last_with_map(WasmFunction::new("get_dates"))
```

#### expand

Expand elements by adding computed values:

```rust
StreamComponent::expand(vec![WasmFunction::new("compute_extra")])
```

#### complement

Add elements from a class that are missing from the current stream:

```rust
// After grouping by employee, add employees with zero count
StreamComponent::complement("Employee")
```

### Scoring Operations

#### penalize

Apply a penalty to matching elements:

```rust
// Fixed penalty
StreamComponent::penalize("1hard/0soft")

// Dynamic penalty based on weigher function
StreamComponent::penalize_with_weigher(
    "1hard/0soft",
    WasmFunction::new("getOverlapMinutes")
)
```

#### reward

Apply a reward (negative penalty) to matching elements:

```rust
StreamComponent::reward("1soft")

StreamComponent::reward_with_weigher(
    "1soft",
    WasmFunction::new("getBonus")
)
```

## Complete Examples

### Skill Requirement Constraint

```rust
// Employee must have the skill required by the shift
constraints.insert(
    "requiredSkill".to_string(),
    vec![
        StreamComponent::for_each("Shift"),
        StreamComponent::filter(WasmFunction::new("skillMismatch")),
        StreamComponent::penalize("1hard/0soft"),
    ],
);
```

### No Overlapping Shifts

```rust
// Same employee cannot work overlapping shifts
constraints.insert(
    "noOverlappingShifts".to_string(),
    vec![
        StreamComponent::for_each("Shift"),
        StreamComponent::join_with_joiners(
            "Shift",
            vec![Joiner::equal(WasmFunction::new("get_Shift_employee"))]
        ),
        StreamComponent::filter(WasmFunction::new("shiftsOverlap")),
        StreamComponent::penalize_with_weigher(
            "1hard/0soft",
            WasmFunction::new("getMinuteOverlap")
        ),
    ],
);
```

### Balance Shift Assignments

```rust
// Distribute shifts fairly across employees
constraints.insert(
    "balanceEmployeeShiftAssignments".to_string(),
    vec![
        StreamComponent::for_each("Shift"),
        StreamComponent::group_by(
            vec![WasmFunction::new("get_Shift_employee")],
            vec![Collector::count()]
        ),
        StreamComponent::complement("Employee"),
        StreamComponent::group_by(
            vec![],
            vec![Collector::load_balance_with_load(
                WasmFunction::new("pick1"),
                WasmFunction::new("pick2")
            )]
        ),
        StreamComponent::penalize_with_weigher(
            "0hard/1soft",
            WasmFunction::new("scaleByFloat")
        ),
    ],
);
```

## API Reference

| Method | Description |
|--------|-------------|
| `for_each(class)` | Select all instances |
| `for_each_including_unassigned(class)` | Include unassigned entities |
| `for_each_unique_pair(class)` | Select unique pairs |
| `for_each_unique_pair_with_joiners(class, joiners)` | Pairs with joiners |
| `filter(predicate)` | Filter by predicate |
| `join(class)` | Join with class |
| `join_with_joiners(class, joiners)` | Join with joiners |
| `if_exists(class)` | Keep if match exists |
| `if_exists_with_joiners(class, joiners)` | Conditional with joiners |
| `if_not_exists(class)` | Keep if no match |
| `if_not_exists_with_joiners(class, joiners)` | Negated conditional |
| `group_by(keys, aggregators)` | Group and aggregate |
| `group_by_key(key)` | Group by single key |
| `group_by_collector(collector)` | Aggregate without grouping |
| `map(mappers)` | Transform elements |
| `map_single(mapper)` | Single transformation |
| `flatten_last()` | Flatten collection |
| `flatten_last_with_map(map)` | Flatten with mapping |
| `expand(mappers)` | Add computed values |
| `complement(class)` | Add missing elements |
| `penalize(weight)` | Fixed penalty |
| `penalize_with_weigher(weight, weigher)` | Dynamic penalty |
| `reward(weight)` | Fixed reward |
| `reward_with_weigher(weight, weigher)` | Dynamic reward |
