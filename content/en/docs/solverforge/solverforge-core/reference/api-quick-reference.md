---
title: "API Quick Reference"
linkTitle: "Quick Reference"
weight: 10
description: "Cheat sheet for common SolverForge APIs"
---

# API Quick Reference

## Domain Model

### DomainModel

```rust
DomainModel::builder()
    .add_class(class)
    .build()                    // Build without validation
    .build_validated()?         // Build with validation
```

### DomainClass

```rust
DomainClass::new("ClassName")
    .with_annotation(PlanningAnnotation::PlanningEntity)
    .with_field(field)
```

### FieldDescriptor

```rust
FieldDescriptor::new("fieldName", FieldType::...)
    .with_planning_annotation(PlanningAnnotation::...)
```

### Field Types

| Type | Rust |
|------|------|
| Primitives | `FieldType::Primitive(PrimitiveType::String)` |
| Object | `FieldType::object("ClassName")` |
| List | `FieldType::list(element_type)` |
| Set | `FieldType::set(element_type)` |
| Array | `FieldType::array(element_type)` |
| Map | `FieldType::map(key_type, value_type)` |
| Score | `FieldType::Score(ScoreType::HardSoft)` |

### Primitive Types

| Type | Rust |
|------|------|
| Boolean | `PrimitiveType::Bool` |
| Int (32-bit) | `PrimitiveType::Int` |
| Long (64-bit) | `PrimitiveType::Long` |
| Float | `PrimitiveType::Float` |
| Double | `PrimitiveType::Double` |
| String | `PrimitiveType::String` |
| Date | `PrimitiveType::Date` |
| DateTime | `PrimitiveType::DateTime` |

### Planning Annotations

| Annotation | Rust |
|------------|------|
| PlanningId | `PlanningAnnotation::PlanningId` |
| PlanningEntity | `PlanningAnnotation::PlanningEntity` |
| PlanningSolution | `PlanningAnnotation::PlanningSolution` |
| PlanningVariable | `PlanningAnnotation::planning_variable(vec!["id"])` |
| PlanningVariable (nullable) | `PlanningAnnotation::planning_variable_unassigned(vec![])` |
| PlanningListVariable | `PlanningAnnotation::planning_list_variable(vec![])` |
| PlanningScore | `PlanningAnnotation::planning_score()` |
| PlanningScore (bendable) | `PlanningAnnotation::planning_score_bendable(2, 3)` |
| ValueRangeProvider | `PlanningAnnotation::value_range_provider("id")` |
| ProblemFactCollectionProperty | `PlanningAnnotation::ProblemFactCollectionProperty` |
| PlanningEntityCollectionProperty | `PlanningAnnotation::PlanningEntityCollectionProperty` |
| PlanningPin | `PlanningAnnotation::PlanningPin` |
| InverseRelationShadow | `PlanningAnnotation::inverse_relation_shadow("var")` |

---

## Constraint Streams

### StreamComponent

| Operation | Rust |
|-----------|------|
| forEach | `StreamComponent::for_each("Class")` |
| forEach (unassigned) | `StreamComponent::for_each_including_unassigned("Class")` |
| forEachUniquePair | `StreamComponent::for_each_unique_pair("Class")` |
| forEachUniquePair (joiners) | `StreamComponent::for_each_unique_pair_with_joiners("Class", joiners)` |
| filter | `StreamComponent::filter(WasmFunction::new("pred"))` |
| join | `StreamComponent::join("Class")` |
| join (joiners) | `StreamComponent::join_with_joiners("Class", joiners)` |
| ifExists | `StreamComponent::if_exists("Class")` |
| ifNotExists | `StreamComponent::if_not_exists("Class")` |
| groupBy | `StreamComponent::group_by(keys, collectors)` |
| groupBy (key only) | `StreamComponent::group_by_key(key)` |
| groupBy (collect only) | `StreamComponent::group_by_collector(collector)` |
| map | `StreamComponent::map(mappers)` |
| map (single) | `StreamComponent::map_single(mapper)` |
| flattenLast | `StreamComponent::flatten_last()` |
| expand | `StreamComponent::expand(mappers)` |
| complement | `StreamComponent::complement("Class")` |
| penalize | `StreamComponent::penalize("1hard/0soft")` |
| penalize (weigher) | `StreamComponent::penalize_with_weigher("1hard", weigher)` |
| reward | `StreamComponent::reward("1soft")` |

### Joiners

| Joiner | Rust |
|--------|------|
| equal | `Joiner::equal(map)` |
| equal (separate) | `Joiner::equal_with_mappings(left, right)` |
| lessThan | `Joiner::less_than(map, comparator)` |
| greaterThan | `Joiner::greater_than(map, comparator)` |
| overlapping | `Joiner::overlapping(start, end)` |
| filtering | `Joiner::filtering(filter)` |

### Collectors

| Collector | Rust |
|-----------|------|
| count | `Collector::count()` |
| countDistinct | `Collector::count_distinct()` |
| sum | `Collector::sum(map)` |
| average | `Collector::average(map)` |
| min | `Collector::min(map, comparator)` |
| max | `Collector::max(map, comparator)` |
| toList | `Collector::to_list()` |
| toSet | `Collector::to_set()` |
| loadBalance | `Collector::load_balance(map)` |
| loadBalance (with load) | `Collector::load_balance_with_load(map, load)` |
| compose | `Collector::compose(collectors, combiner)` |
| conditionally | `Collector::conditionally(pred, collector)` |
| collectAndThen | `Collector::collect_and_then(collector, mapper)` |

---

## Scores

### Score Types

| Type | Create | Parse |
|------|--------|-------|
| SimpleScore | `SimpleScore::of(-5)` | `SimpleScore::parse("-5")` |
| HardSoftScore | `HardSoftScore::of(-2, 10)` | `HardSoftScore::parse("-2hard/10soft")` |
| HardMediumSoftScore | `HardMediumSoftScore::of(-1, 5, 10)` | `HardMediumSoftScore::parse(...)` |
| BendableScore | `BendableScore::of(hard_vec, soft_vec)` | N/A |

### Score Methods

```rust
score.is_feasible()     // hard >= 0
score + other           // Addition
score - other           // Subtraction
-score                  // Negation
```

---

## Solver Configuration

### SolverConfig

```rust
SolverConfig::new()
    .with_solution_class("Schedule")
    .with_entity_class("Shift")
    .with_environment_mode(EnvironmentMode::Reproducible)
    .with_random_seed(42)
    .with_move_thread_count(MoveThreadCount::Auto)
    .with_termination(termination)
```

### TerminationConfig

```rust
TerminationConfig::new()
    .with_spent_limit("PT5M")
    .with_unimproved_spent_limit("PT30S")
    .with_best_score_feasible(true)
    .with_best_score_limit("0hard/-100soft")
    .with_step_count_limit(1000)
    .with_move_count_limit(10000)
```

---

## WASM Expressions

### Expr Builder

| Expression | Rust |
|------------|------|
| Integer | `Expr::int(42)` |
| Boolean | `Expr::bool(true)` |
| Null | `Expr::null()` |
| Parameter | `Expr::param(0)` |
| Field access | `expr.get("Class", "field")` |
| Equal | `Expr::eq(left, right)` |
| Not equal | `Expr::ne(left, right)` |
| Less than | `Expr::lt(left, right)` |
| Greater than | `Expr::gt(left, right)` |
| AND | `Expr::and(left, right)` |
| OR | `Expr::or(left, right)` |
| NOT | `Expr::not(expr)` |
| Is null | `Expr::is_null(expr)` |
| Is not null | `Expr::is_not_null(expr)` |
| Add | `Expr::add(left, right)` |
| Subtract | `Expr::sub(left, right)` |
| Multiply | `Expr::mul(left, right)` |
| Divide | `Expr::div(left, right)` |
| List contains | `Expr::list_contains(list, elem)` |
| String equals | `Expr::string_equals(left, right)` |
| Ranges overlap | `Expr::ranges_overlap(s1, e1, s2, e2)` |
| If-then-else | `Expr::if_then_else(cond, then, else)` |

### WasmModuleBuilder

```rust
WasmModuleBuilder::new()
    .with_domain_model(model)
    .with_host_functions(HostFunctionRegistry::with_standard_functions())
    .with_initial_memory(16)
    .with_max_memory(Some(256))
    .add_predicate(PredicateDefinition::from_expression(name, arity, expr))
    .build()?                    // Vec<u8>
    .build_base64()?            // String
```
