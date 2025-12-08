---
title: "Serialization"
linkTitle: "Serialization"
weight: 20
tags: [reference, python]
description: >
  JSON serialization with dataclasses and Pydantic.
---

SolverForge domain objects are Python dataclasses, making them easy to serialize to JSON for APIs and storage.

## Basic JSON Serialization

### Using dataclasses

```python
from dataclasses import dataclass, asdict
import json

@dataclass
class Timeslot:
    day: str
    start_time: str
    end_time: str

@dataclass
class Room:
    name: str

# Serialize
timeslot = Timeslot("MONDAY", "08:30", "09:30")
json_str = json.dumps(asdict(timeslot))
# {"day": "MONDAY", "start_time": "08:30", "end_time": "09:30"}

# Deserialize
data = json.loads(json_str)
timeslot = Timeslot(**data)
```

### Handling Complex Types

For types like `datetime` and `time`:

```python
from dataclasses import dataclass
from datetime import time
import json

class TimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, time):
            return obj.isoformat()
        return super().default(obj)

def time_decoder(dct):
    for key, value in dct.items():
        if key.endswith('_time') and isinstance(value, str):
            try:
                dct[key] = time.fromisoformat(value)
            except ValueError:
                pass
    return dct

# Serialize
json_str = json.dumps(asdict(obj), cls=TimeEncoder)

# Deserialize
data = json.loads(json_str, object_hook=time_decoder)
```

## Pydantic Integration

Pydantic provides automatic validation and serialization:

### DTO Pattern

Separate API models from domain models:

```python
from pydantic import BaseModel
from datetime import time

# API model
class TimeslotDTO(BaseModel):
    day: str
    start_time: str
    end_time: str

    def to_domain(self) -> Timeslot:
        return Timeslot(
            self.day,
            time.fromisoformat(self.start_time),
            time.fromisoformat(self.end_time),
        )

    @classmethod
    def from_domain(cls, timeslot: Timeslot) -> "TimeslotDTO":
        return cls(
            day=timeslot.day,
            start_time=timeslot.start_time.isoformat(),
            end_time=timeslot.end_time.isoformat(),
        )


# Domain model (unchanged)
@dataclass
class Timeslot:
    day: str
    start_time: time
    end_time: time
```

### Full Example

```python
from pydantic import BaseModel
from datetime import time


class LessonDTO(BaseModel):
    id: str
    subject: str
    teacher: str
    student_group: str
    timeslot: TimeslotDTO | None = None
    room: RoomDTO | None = None

    def to_domain(self, timeslots: list[Timeslot], rooms: list[Room]) -> Lesson:
        ts = None
        if self.timeslot:
            ts = find_timeslot(timeslots, self.timeslot)

        rm = None
        if self.room:
            rm = find_room(rooms, self.room)

        return Lesson(
            id=self.id,
            subject=self.subject,
            teacher=self.teacher,
            student_group=self.student_group,
            timeslot=ts,
            room=rm,
        )

    @classmethod
    def from_domain(cls, lesson: Lesson) -> "LessonDTO":
        return cls(
            id=lesson.id,
            subject=lesson.subject,
            teacher=lesson.teacher,
            student_group=lesson.student_group,
            timeslot=TimeslotDTO.from_domain(lesson.timeslot) if lesson.timeslot else None,
            room=RoomDTO.from_domain(lesson.room) if lesson.room else None,
        )


class TimetableDTO(BaseModel):
    id: str
    timeslots: list[TimeslotDTO]
    rooms: list[RoomDTO]
    lessons: list[LessonDTO]
    score: str | None = None

    def to_domain(self) -> Timetable:
        timeslots = [t.to_domain() for t in self.timeslots]
        rooms = [r.to_domain() for r in self.rooms]
        lessons = [l.to_domain(timeslots, rooms) for l in self.lessons]
        return Timetable(self.id, timeslots, rooms, lessons)

    @classmethod
    def from_domain(cls, timetable: Timetable) -> "TimetableDTO":
        return cls(
            id=timetable.id,
            timeslots=[TimeslotDTO.from_domain(t) for t in timetable.timeslots],
            rooms=[RoomDTO.from_domain(r) for r in timetable.rooms],
            lessons=[LessonDTO.from_domain(l) for l in timetable.lessons],
            score=str(timetable.score) if timetable.score else None,
        )
```

## Reference Resolution

When deserializing, resolve references to shared objects:

```python
def find_timeslot(timeslots: list[Timeslot], dto: TimeslotDTO) -> Timeslot:
    """Find matching timeslot by properties."""
    for ts in timeslots:
        if (ts.day == dto.day and
            ts.start_time.isoformat() == dto.start_time):
            return ts
    raise ValueError(f"Timeslot not found: {dto}")


def find_room(rooms: list[Room], dto: RoomDTO) -> Room:
    """Find matching room by name."""
    for room in rooms:
        if room.name == dto.name:
            return room
    raise ValueError(f"Room not found: {dto}")
```

## Score Serialization

```python
from solverforge_legacy.solver.score import HardSoftScore

# To string
score_str = str(solution.score)  # "-2hard/-15soft"

# From string
score = HardSoftScore.parse("-2hard/-15soft")

# To dict
score_dict = {
    "hard": solution.score.hard_score,
    "soft": solution.score.soft_score,
    "feasible": solution.score.is_feasible,
}
```

## Database Persistence

### SQLAlchemy Example

```python
from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.orm import relationship

class TimeslotModel(Base):
    __tablename__ = "timeslots"

    id = Column(Integer, primary_key=True)
    day = Column(String)
    start_time = Column(String)
    end_time = Column(String)

    def to_domain(self) -> Timeslot:
        return Timeslot(
            self.day,
            time.fromisoformat(self.start_time),
            time.fromisoformat(self.end_time),
        )


class LessonModel(Base):
    __tablename__ = "lessons"

    id = Column(String, primary_key=True)
    subject = Column(String)
    teacher = Column(String)
    student_group = Column(String)
    timeslot_id = Column(Integer, ForeignKey("timeslots.id"), nullable=True)
    room_id = Column(Integer, ForeignKey("rooms.id"), nullable=True)

    timeslot = relationship("TimeslotModel")
    room = relationship("RoomModel")
```

## Best Practices

### Do

- Use DTOs for API boundaries
- Validate input with Pydantic
- Handle None values explicitly
- Use consistent naming conventions

### Don't

- Serialize domain objects directly (may expose internals)
- Forget to handle score serialization
- Ignore reference resolution
- Mix API and domain models

## Next Steps

- [FastAPI](fastapi.md) - Build REST APIs
- [Logging](logging.md) - Configure logging
