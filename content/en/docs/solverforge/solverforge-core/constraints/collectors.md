---
title: "Collectors"
linkTitle: "Collectors"
weight: 30
tags: [reference, rust]
description: "Aggregate values with count, sum, average, min, max, toList, toSet, and loadBalance"
---

Collectors aggregate values during `group_by` operations.

## Collector Types

### count

Count elements:

```rust
// Count all
Collector::count()

// Count distinct
Collector::count_distinct()

// Count with mapping (count unique mapped values)
Collector::count_with_map(WasmFunction::new("get_id"))
```

### sum

Sum numeric values:

```rust
Collector::sum(WasmFunction::new("get_duration"))
```

### average

Calculate average:

```rust
Collector::average(WasmFunction::new("get_score"))
```

### min / max

Find minimum or maximum with comparator:

```rust
Collector::min(
    WasmFunction::new("get_time"),
    WasmFunction::new("compare_time")
)

Collector::max(
    WasmFunction::new("get_priority"),
    WasmFunction::new("compare_priority")
)
```

### to_list / to_set

Collect into a collection:

```rust
// Collect elements as-is
Collector::to_list()
Collector::to_set()

// Collect mapped values
Collector::to_list_with_map(WasmFunction::new("get_name"))
Collector::to_set_with_map(WasmFunction::new("get_id"))
```

### load_balance

Calculate unfairness metric for balancing:

```rust
// Simple load balance (count per entity)
Collector::load_balance(WasmFunction::new("get_employee"))

// Load balance with custom load function
Collector::load_balance_with_load(
    WasmFunction::new("pick1"),   // Extract entity
    WasmFunction::new("pick2")    // Extract load value
)
```

The unfairness value represents how imbalanced the distribution is (0 = perfectly balanced).

### compose

Combine multiple collectors:

```rust
Collector::compose(
    vec![
        Collector::count(),
        Collector::sum(WasmFunction::new("get_duration"))
    ],
    WasmFunction::new("combine_count_and_sum")
)
```

### conditionally

Apply collector only when predicate matches:

```rust
Collector::conditionally(
    WasmFunction::new("is_premium"),
    Collector::count()
)
```

### collect_and_then

Transform collected result:

```rust
Collector::collect_and_then(
    Collector::count(),
    WasmFunction::new("to_penalty_weight")
)
```

## Usage Examples

### Count Shifts per Employee

```rust
StreamComponent::group_by(
    vec![WasmFunction::new("get_Shift_employee")],
    vec![Collector::count()]
)
```

Output: Stream of `(Employee, count)` tuples.

### Total Duration per Room

```rust
StreamComponent::group_by(
    vec![WasmFunction::new("get_room")],
    vec![Collector::sum(WasmFunction::new("get_duration"))]
)
```

### Load Balancing

```rust
// Group shifts by employee with count
StreamComponent::group_by(
    vec![WasmFunction::new("get_Shift_employee")],
    vec![Collector::count()]
),
// Add employees with 0 shifts
StreamComponent::complement("Employee"),
// Calculate unfairness
StreamComponent::group_by(
    vec![],
    vec![Collector::load_balance_with_load(
        WasmFunction::new("pick1"),   // Get employee from tuple
        WasmFunction::new("pick2")    // Get count from tuple
    )]
),
// Penalize by unfairness
StreamComponent::penalize_with_weigher(
    "0hard/1soft",
    WasmFunction::new("scaleByFloat")
)
```

### Multiple Aggregations

```rust
StreamComponent::group_by(
    vec![WasmFunction::new("get_department")],
    vec![
        Collector::count(),
        Collector::sum(WasmFunction::new("get_salary")),
        Collector::average(WasmFunction::new("get_years"))
    ]
)
```

### Conditional Counting

```rust
StreamComponent::group_by(
    vec![WasmFunction::new("get_region")],
    vec![
        Collector::conditionally(
            WasmFunction::new("is_active"),
            Collector::count()
        )
    ]
)
```

## API Reference

| Method | Description |
|--------|-------------|
| `count()` | Count elements |
| `count_distinct()` | Count unique elements |
| `count_with_map(map)` | Count unique mapped values |
| `sum(map)` | Sum mapped values |
| `average(map)` | Average of mapped values |
| `min(map, cmp)` | Minimum with comparator |
| `max(map, cmp)` | Maximum with comparator |
| `to_list()` | Collect to list |
| `to_list_with_map(map)` | Collect mapped values to list |
| `to_set()` | Collect to set |
| `to_set_with_map(map)` | Collect mapped values to set |
| `load_balance(map)` | Calculate unfairness |
| `load_balance_with_load(map, load)` | Unfairness with load function |
| `compose(collectors, combiner)` | Combine collectors |
| `conditionally(predicate, collector)` | Conditional collection |
| `collect_and_then(collector, mapper)` | Transform result |
