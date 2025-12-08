---
title: "Joiners"
linkTitle: "Joiners"
weight: 20
description: "Efficiently match entities with equal, lessThan, overlapping, and filtering joiners"
---

# Joiners

Joiners define how entities are matched in join operations. They enable indexed lookups instead of O(n*m) scans.

## Joiner Types

### equal

Match entities where a mapped value is equal:

```rust
// Same mapping for both sides
Joiner::equal(WasmFunction::new("get_employee"))

// Different mappings for left and right
Joiner::equal_with_mappings(
    WasmFunction::new("get_left_timeslot"),
    WasmFunction::new("get_right_timeslot")
)

// Custom equality and hash functions
Joiner::equal_with_custom_equals(
    WasmFunction::new("get_id"),
    WasmFunction::new("ids_equal"),
    WasmFunction::new("id_hash")
)
```

### less_than

Match where left < right:

```rust
Joiner::less_than(
    WasmFunction::new("get_start_time"),
    WasmFunction::new("compare_time")
)

Joiner::less_than_with_mappings(
    WasmFunction::new("get_left_time"),
    WasmFunction::new("get_right_time"),
    WasmFunction::new("compare_time")
)
```

### less_than_or_equal

Match where left <= right:

```rust
Joiner::less_than_or_equal(
    WasmFunction::new("get_priority"),
    WasmFunction::new("compare_priority")
)
```

### greater_than

Match where left > right:

```rust
Joiner::greater_than(
    WasmFunction::new("get_value"),
    WasmFunction::new("compare_values")
)
```

### greater_than_or_equal

Match where left >= right:

```rust
Joiner::greater_than_or_equal(
    WasmFunction::new("get_score"),
    WasmFunction::new("compare_scores")
)
```

### overlapping

Match entities with overlapping time ranges:

```rust
// Same start/end mapping for both sides
Joiner::overlapping(
    WasmFunction::new("get_start"),
    WasmFunction::new("get_end")
)

// Different mappings for left and right
Joiner::overlapping_with_mappings(
    WasmFunction::new("left_start"),
    WasmFunction::new("left_end"),
    WasmFunction::new("right_start"),
    WasmFunction::new("right_end")
)

// With custom comparator
Joiner::overlapping_with_comparator(
    WasmFunction::new("get_start"),
    WasmFunction::new("get_end"),
    WasmFunction::new("compare_time")
)
```

### filtering

Custom filter predicate (least efficient, use as last resort):

```rust
Joiner::filtering(WasmFunction::new("is_compatible"))
```

## Usage Examples

### Join Shifts by Employee

```rust
StreamComponent::join_with_joiners(
    "Shift",
    vec![Joiner::equal(WasmFunction::new("get_Shift_employee"))]
)
```

### Find Overlapping Time Slots

```rust
StreamComponent::for_each_unique_pair_with_joiners(
    "Meeting",
    vec![
        Joiner::equal(WasmFunction::new("get_room")),
        Joiner::overlapping(
            WasmFunction::new("get_start"),
            WasmFunction::new("get_end")
        )
    ]
)
```

### Conditional Existence Check

```rust
StreamComponent::if_exists_with_joiners(
    "Constraint",
    vec![
        Joiner::equal(WasmFunction::new("get_entity_id")),
        Joiner::filtering(WasmFunction::new("is_active"))
    ]
)
```

## Multiple Joiners

Combine joiners for more specific matching (AND logic):

```rust
vec![
    Joiner::equal(WasmFunction::new("get_employee")),      // Same employee
    Joiner::less_than(                                      // Earlier shift first
        WasmFunction::new("get_start"),
        WasmFunction::new("compare_time")
    )
]
```

## Performance Tips

1. **Use `equal` when possible** - enables hash-based indexing
2. **Avoid `filtering` alone** - no optimization, O(n*m) scan
3. **Combine with `equal` first** - `equal` + `filtering` is faster than `filtering` alone
4. **Use specific joiners** - `overlapping` is optimized for interval queries

## API Reference

| Method | Description |
|--------|-------------|
| `equal(map)` | Match on equal mapped values |
| `equal_with_mappings(left, right)` | Different mappings per side |
| `equal_with_custom_equals(map, eq, hash)` | Custom equality/hash |
| `less_than(map, cmp)` | Match where left < right |
| `less_than_with_mappings(left, right, cmp)` | Different mappings |
| `less_than_or_equal(map, cmp)` | Match where left <= right |
| `greater_than(map, cmp)` | Match where left > right |
| `greater_than_or_equal(map, cmp)` | Match where left >= right |
| `overlapping(start, end)` | Match overlapping ranges |
| `overlapping_with_mappings(ls, le, rs, re)` | Different range mappings |
| `overlapping_with_comparator(start, end, cmp)` | Custom comparator |
| `filtering(filter)` | Custom predicate |
