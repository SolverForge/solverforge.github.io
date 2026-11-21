---
title: "Task scheduling"
linkTitle: "Task scheduling"
description: >
  Puts every task on a machine or a person, in an order, and times it, so the
  work finishes early, on time and with few changeovers.
---

## What it decides

A dataset lists **tasks** and **resources**: machines and people. The solver
decides two things for each task: which resource runs it, and where it goes in
that resource's sequence. It can also leave a task unassigned when nothing
fits.

It does not choose start times. A task starts as soon as everything allows:

1. its resource has finished the task before it;
2. the machine is set up for its task type (a **changeover**, when the type
   changes);
3. its `minStart` has come;
4. every task it depends on has ended or started, plus the dependency's
   minimum offset.

The task then runs for its duration on that resource. It pauses over the
resource's unavailable spans (nights, maintenance, holidays) and resumes after
them, unless it sets `noInterruptions`; then it waits for a gap long enough to
run in one piece. Moving a task therefore re-times everything after it on its
resource and every task that depends on it.

Work you have already fixed stays where it is. A pinned task, or one placed
before its resource's `freezeTasksUntil`, keeps its resource and start; the
solver plans the rest around it.

## What a dataset describes

- **Machines and people**, each with the time it starts, unavailable spans,
  tags (capabilities or skills, optionally only for a time), a machine type and
  the task type a machine is set up for at the start.
- **Tasks** with a duration, or durations per resource, a task type, an
  earliest start, deadline, ideal end and due date, a priority, the resources
  it may run on, the tags it needs, and whether it may pause over unavailable
  time.
- **Dependencies** between tasks: counted from the other task's end or start,
  with a minimum and maximum offset, optionally on the same resource and with
  nothing in between.
- **Changeovers**: the setup time a machine type needs from one task type to
  another.
- **Hand-overs** between resources: forbidden, or preferred with a reward.
- **Stock**: parts on hand from the start or arriving at a time. A task
  `consumes` parts when it starts and `produces` parts when it ends.

Every table and field is on the [data page](data/).

## When a schedule is feasible

A schedule is feasible when every hard rule holds:

- every task keeps its earliest start and deadline;
- dependent tasks keep their offsets, and stay together on one resource with
  nothing in between when the dependency asks for it;
- every task runs on a resource it may use, holding every tag it needs for the
  whole time it runs;
- no work moves between two resources that may not hand over to each other;
- every task finds the parts it uses in stock when it starts.

A task the solver cannot fit without breaking one of these is left unassigned.
That costs its priority at the medium level, which counts only once every hard
rule holds. So the solver plans as many tasks as it can, the most important
first, and never buys a planned task with a broken rule.

## What it optimises

Among feasible schedules with the same work planned, the soft rules decide:

- **Makespan**: finish the whole job sooner.
- **Due dates**: end tasks by their due date, and close to their ideal end.
- **Changeovers**: fewer type switches and less setup time per machine.
- **Hand-overs**: send work between the resources that prefer it.
- **Idle time**: keep machines busy (off until you weigh it).

These trade against each other through their weights. Raising the changeover
weights batches tasks of one type together even if a few end later; raising
lateness does the opposite.

## Dependencies in practice

A dependency describes how two operations of one job relate:

- `minOffset` after the end: *cure at least 60 minutes after coating*.
- `maxOffset` after the end: *weld within 4 hours of cutting*.
- `anchor: "start"` with a `minOffset`: *start inspecting 30 minutes after
  production starts*, so the two overlap.
- `sameResource` with `noIntermediateTasks`: *mill both setups on one machine,
  back to back*.

## The demo

**Factory week** (`FACTORY`) is a sheet-metal and machining plant over one
working week in March 2027. Sixteen machines on two shifts and eight people on
day shift run 76 orders of up to seven operations each, 409 tasks in all:
cutting, bending or turning, milling (sometimes two setups on one machine),
welding, painting and inspection. Lasers change over between materials, paint
lines between powder colours, and each coat uses a box of its colour's powder
from stock.

## Constraints

<%= render Workbench::Groups.new(site: site, model: "task-scheduling") %>

Each rule is explained, with the fields it reads, what it costs and an
example, on the [constraints page](constraints/).

## Measures

A finished schedule reports its makespan, lateness, changeover time and count,
and each machine's idle time.
