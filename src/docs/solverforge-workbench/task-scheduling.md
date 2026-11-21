---
title: "Task scheduling"
linkTitle: "Task scheduling"
description: >
  Tasks to machines and people over time under time windows, dependencies, resource fit, parts in stock, changeovers and due dates.
---

Task scheduling puts each task on a machine or a person, in an order, and times
it: a task starts when its resource is free, set up and available, and when the
tasks it depends on allow. The solver chooses the resource and the order; the
start times follow. A schedule is feasible when every task keeps its time window
and dependencies, runs on a resource that may run it, and finds the parts it
needs in stock.

## What a dataset describes

- **Machines and people**, each with its working calendar, unavailable spans,
  tags (capabilities or skills, optionally only for a time), a machine type
  and the task type it is set up for at the start.
- **Tasks** with a default length and lengths per resource, a task type,
  earliest start, deadline, ideal end and due date, priority, the resources it
  may run on, the tags it needs, and whether it may pause over unavailable time.
- **Dependencies** between tasks: counted from the other task's end or start,
  with a minimum and maximum offset, optionally on the same resource and with
  nothing in between.
- **Changeovers**: the setup time a machine type needs between two task types.
- **Hand-overs** between resources: forbidden, or preferred with a reward.
- **Stock**: parts on hand from the start or arriving at a time. A task
  `consumes` parts when it starts and `produces` parts when it ends; a task
  that starts while the stock lacks what it needs costs one hour per unit short.

## Measures

A finished schedule reports its makespan, lateness, changeover time and count,
and each machine's idle time. Idle time is off unless weighted.

<%= render Workbench::Model.new(site: site, id: "task-scheduling") %>
