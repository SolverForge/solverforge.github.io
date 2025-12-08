---
title: "Shadow Variables"
linkTitle: "Shadow Variables"
weight: 40
tags: [concepts, python]
description: >
  Define calculated variables that update automatically.
---

A **shadow variable** is a planning variable whose value is calculated from other variables, not directly assigned by the solver. Shadow variables update automatically when their source variables change.

## When to Use Shadow Variables

Use shadow variables for:
- **Derived values** - Arrival times calculated from routes
- **Inverse relationships** - A visit knowing which vehicle it belongs to
- **Cascading calculations** - End times derived from start times and durations

## Shadow Variable Types

### Inverse Relation Shadow Variable

Maintains a reverse reference when using list variables:

```python
from solverforge_legacy.solver.domain import InverseRelationShadowVariable

@planning_entity
@dataclass
class Vehicle:
    id: Annotated[str, PlanningId]
    visits: Annotated[list[Visit], PlanningListVariable] = field(default_factory=list)

@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    location: Location
    # Automatically set to the vehicle that contains this visit
    vehicle: Annotated[
        Vehicle | None,
        InverseRelationShadowVariable(source_variable_name="visits")
    ] = field(default=None)
```

When a visit is added to `vehicle.visits`, `visit.vehicle` is automatically set.

### Previous Element Shadow Variable

Tracks the previous element in a list variable:

```python
from solverforge_legacy.solver.domain import PreviousElementShadowVariable

@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    # The visit that comes before this one in the route
    previous_visit: Annotated[
        Visit | None,
        PreviousElementShadowVariable(source_variable_name="visits")
    ] = field(default=None)
```

### Next Element Shadow Variable

Tracks the next element in a list variable:

```python
from solverforge_legacy.solver.domain import NextElementShadowVariable

@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    # The visit that comes after this one in the route
    next_visit: Annotated[
        Visit | None,
        NextElementShadowVariable(source_variable_name="visits")
    ] = field(default=None)
```

### Index Shadow Variable

Tracks the position in a list variable:

```python
from solverforge_legacy.solver.domain import IndexShadowVariable

@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    # Position in the vehicle's visit list (0-based)
    index: Annotated[
        int | None,
        IndexShadowVariable(source_variable_name="visits")
    ] = field(default=None)
```

### Cascading Update Shadow Variable

For custom calculations that depend on other variables:

```python
from solverforge_legacy.solver.domain import CascadingUpdateShadowVariable
from datetime import datetime, timedelta

@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    location: Location
    service_duration: timedelta

    vehicle: Annotated[
        Vehicle | None,
        InverseRelationShadowVariable(source_variable_name="visits")
    ] = field(default=None)

    previous_visit: Annotated[
        Visit | None,
        PreviousElementShadowVariable(source_variable_name="visits")
    ] = field(default=None)

    # Calculated arrival time
    arrival_time: Annotated[
        datetime | None,
        CascadingUpdateShadowVariable(target_method_name="update_arrival_time")
    ] = field(default=None)

    def update_arrival_time(self):
        """Called automatically when previous_visit or vehicle changes."""
        if self.vehicle is None:
            self.arrival_time = None
        elif self.previous_visit is None:
            # First visit: departure from depot
            travel_time = self.vehicle.depot.driving_time_to(self.location)
            self.arrival_time = self.vehicle.departure_time + travel_time
        else:
            # Subsequent visit: after previous visit's departure
            travel_time = self.previous_visit.location.driving_time_to(self.location)
            self.arrival_time = self.previous_visit.departure_time + travel_time

    @property
    def departure_time(self) -> datetime | None:
        """Time when service at this visit completes."""
        if self.arrival_time is None:
            return None
        return self.arrival_time + self.service_duration
```

### Piggyback Shadow Variable

For variables that should be updated at the same time as another shadow variable:

```python
from solverforge_legacy.solver.domain import PiggybackShadowVariable

@planning_entity
@dataclass
class Visit:
    arrival_time: Annotated[
        datetime | None,
        CascadingUpdateShadowVariable(target_method_name="update_times")
    ] = field(default=None)

    # Updated by the same method as arrival_time
    departure_time: Annotated[
        datetime | None,
        PiggybackShadowVariable(shadow_variable_name="arrival_time")
    ] = field(default=None)

    def update_times(self):
        # Update both arrival_time and departure_time
        if self.vehicle is None:
            self.arrival_time = None
            self.departure_time = None
        else:
            self.arrival_time = self.calculate_arrival()
            self.departure_time = self.arrival_time + self.service_duration
```

## Complete Vehicle Routing Example

```python
from dataclasses import dataclass, field
from typing import Annotated
from datetime import datetime, timedelta

from solverforge_legacy.solver.domain import (
    planning_entity,
    PlanningId,
    PlanningListVariable,
    InverseRelationShadowVariable,
    PreviousElementShadowVariable,
    NextElementShadowVariable,
    CascadingUpdateShadowVariable,
)


@dataclass
class Location:
    latitude: float
    longitude: float

    def driving_time_to(self, other: "Location") -> timedelta:
        # Simplified: assume 1 second per km
        distance = ((self.latitude - other.latitude)**2 +
                   (self.longitude - other.longitude)**2) ** 0.5
        return timedelta(seconds=int(distance * 1000))


@planning_entity
@dataclass
class Vehicle:
    id: Annotated[str, PlanningId]
    depot: Location
    departure_time: datetime
    capacity: int
    visits: Annotated[list["Visit"], PlanningListVariable] = field(default_factory=list)


@planning_entity
@dataclass
class Visit:
    id: Annotated[str, PlanningId]
    location: Location
    demand: int
    service_duration: timedelta
    ready_time: datetime    # Earliest arrival
    due_time: datetime      # Latest arrival

    # Shadow variables
    vehicle: Annotated[
        Vehicle | None,
        InverseRelationShadowVariable(source_variable_name="visits")
    ] = field(default=None)

    previous_visit: Annotated[
        "Visit | None",
        PreviousElementShadowVariable(source_variable_name="visits")
    ] = field(default=None)

    next_visit: Annotated[
        "Visit | None",
        NextElementShadowVariable(source_variable_name="visits")
    ] = field(default=None)

    arrival_time: Annotated[
        datetime | None,
        CascadingUpdateShadowVariable(target_method_name="update_arrival_time")
    ] = field(default=None)

    def update_arrival_time(self):
        if self.vehicle is None:
            self.arrival_time = None
            return

        if self.previous_visit is None:
            # First visit in route
            travel = self.vehicle.depot.driving_time_to(self.location)
            self.arrival_time = self.vehicle.departure_time + travel
        else:
            # After previous visit
            prev_departure = self.previous_visit.departure_time
            if prev_departure is None:
                self.arrival_time = None
                return
            travel = self.previous_visit.location.driving_time_to(self.location)
            self.arrival_time = prev_departure + travel

    @property
    def departure_time(self) -> datetime | None:
        if self.arrival_time is None:
            return None
        # Wait until ready_time if arriving early
        start = max(self.arrival_time, self.ready_time)
        return start + self.service_duration

    def is_late(self) -> bool:
        return self.arrival_time is not None and self.arrival_time > self.due_time
```

## Shadow Variable Evaluation Order

Shadow variables are evaluated in dependency order:

1. `InverseRelationShadowVariable` - First (depends only on list variable)
2. `PreviousElementShadowVariable` - Second
3. `NextElementShadowVariable` - Second
4. `IndexShadowVariable` - Second
5. `CascadingUpdateShadowVariable` - After their dependencies
6. `PiggybackShadowVariable` - With their shadow source

## Using Shadow Variables in Constraints

Shadow variables can be used in constraints just like regular properties:

```python
def arrival_after_due_time(factory: ConstraintFactory) -> Constraint:
    return (
        factory.for_each(Visit)
        .filter(lambda visit: visit.is_late())
        .penalize(
            HardSoftScore.ONE_SOFT,
            lambda visit: int((visit.arrival_time - visit.due_time).total_seconds())
        )
        .as_constraint("Arrival after due time")
    )
```

## Best Practices

### Do

- Use `InverseRelationShadowVariable` when entities need to know their container
- Use `CascadingUpdateShadowVariable` for calculated values like arrival times
- Keep update methods simple and fast

### Don't

- Create circular shadow variable dependencies
- Do expensive calculations in update methods
- Forget to handle `None` cases

## Next Steps

- [Pinning](pinning.md) - Lock specific assignments
- [Vehicle Routing Quickstart](../quickstarts/vehicle-routing/) - Full routing example
