---
title: "Task scheduling constraints"
linkTitle: "Constraints"
description: >
  The 18 rules that score a task schedule: what each one checks, which fields
  it reads, what one violation costs, and an example.
---

<% m = "task-scheduling" %>

Every rule below scores one schedule. Click a rule to read it. Field names are
the dataset's JSON names, documented on the [data page](../data/). A
**weight** multiplies a rule's cost: 1 as designed, 0 off, 10 ten times as
important. The **broken-link penalty** is the model parameter
`brokenLinkPenalty`, 1,000 unless set.

<%= render Workbench::RulesToolbar.new(site: site, model: m) %>

## Time windows {#group-time-windows}

<%= render Workbench::Rule.new(site: site, model: m, name: "Started before earliest start") %>

A task must not start before its `minStart`. The solver never schedules a task
early by itself: a task it places waits for its earliest start. This rule
catches the tasks it cannot move, the ones pinned at a fixed start (`pinned`,
or placed before the resource's `freezeTasksUntil`) whose start lies before
their earliest start.

- **Reads:** `tasks[].minStart`; the pinned start in `resources[].tasks[].start`.
- **Cost:** the minutes between the start and the earliest start.
- **Example:** a task pinned at 07:30 with `minStart` 08:00 costs 30 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Finished after deadline") %>

A task must end by its `maxEnd`. The end includes any pause over its
resource's unavailable spans, so a task that runs into a holiday ends after it.

- **Reads:** `tasks[].maxEnd`, the task's duration on its resource, the
  resource's `unavailable` spans.
- **Cost:** the minutes the task ends after its deadline.
- **Example:** a 120-minute task that starts at 15:00 on a resource free all
  afternoon ends at 17:00; with `maxEnd` 16:30 it costs 30 hard.
- **Weight:** on.

## Dependencies {#group-dependencies}

A task's `dependencies` name the tasks it waits for. Each dependency counts
from the other task's end (`anchor: "end"`, the default) or its start, and may
set a `minOffset` and a `maxOffset` in minutes, require the `sameResource`, and
forbid `noIntermediateTasks` between the two.

<%= render Workbench::Rule.new(site: site, model: m, name: "Dependency left unassigned") %>

A task is planned while a task it depends on is not: the predecessor sits in
the unassigned queue, so the plan does work whose input never happens.

- **Reads:** `tasks[].dependencies[].task`.
- **Cost:** the broken-link penalty, once per unplanned predecessor.
- **Example:** *Paint* depends on *Weld*; *Weld* is left unassigned while
  *Paint* is planned. That costs 1,000 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Dependency offset broken") %>

A task starts outside the window its dependency allows. The earliest start is
the anchor (the predecessor's end or start) plus `minOffset`; the latest is the
anchor plus `maxOffset`, when set. The solver delays a task for its
`minOffset` by itself, so the early side bites only for pinned tasks; the late
side bites whenever a task waits too long, for example behind other work on its
resource.

A task can also be impossible to time: it waits on a task that comes after it
on the same resource, or follows such a task. It then costs the broken-link
penalty instead.

- **Reads:** `tasks[].dependencies[]` (`task`, `anchor`, `minOffset`,
  `maxOffset`).
- **Cost:** the minutes outside the window; the broken-link penalty for a task
  that cannot be timed.
- **Example:** *Cure* must start 60 to 240 minutes after *Coat* ends. *Coat*
  ends at 10:00 and *Cure* starts at 15:00, 300 minutes later. That costs 60
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Dependency split across resources") %>

Two dependent tasks whose dependency sets `sameResource` run on different
resources, such as two steps that must stay on one fixture.

- **Reads:** `tasks[].dependencies[].sameResource`.
- **Cost:** the broken-link penalty per split dependency.
- **Example:** *Rough cut* and *Finish cut* must share a machine; they run on
  Mill 1 and Mill 2. That costs 1,000 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Dependency interrupted by other tasks") %>

Two dependent tasks that set `noIntermediateTasks` run on the same resource
with other tasks between them. It applies only when both share a resource;
pair it with `sameResource` to force that.

- **Reads:** `tasks[].dependencies[].noIntermediateTasks`, the order of tasks
  on the resource.
- **Cost:** the broken-link penalty per task in between.
- **Example:** two other tasks run between *Heat* and *Forge* on one press.
  That costs 2,000 hard.
- **Weight:** on.

## Resource fit {#group-resource-fit}

<%= render Workbench::Rule.new(site: site, model: m, name: "Required tag missing") %>

A task runs on a resource without a tag it needs, a skill or a capability. A
resource's tag can hold only for a time (`from`, `until`); then the task must
run entirely inside that time.

- **Reads:** `tasks[].requiredTags`, `resources[].tags[]` (`tag`, `from`,
  `until`).
- **Cost:** per missing tag, the task's minutes not covered by it; at least 1.
- **Example:** a 90-minute welding task runs on a person certified for welding
  until 10:00, from 09:30 to 11:00. The 60 minutes after 10:00 cost 60 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Resource not allowed") %>

A task runs on a resource outside the ones it may use. Those are its
`requiredResources`; a task with no `duration` may also run only on the
resources listed in its `durationOn`, since only they say how long it takes.

- **Reads:** `tasks[].requiredResources`, `tasks[].durationOn`.
- **Cost:** the task's `priority` (or the `defaultPriority` parameter).
- **Example:** a task with priority 3 that may run only on Lathe A runs on
  Lathe B. That costs 3 hard.
- **Weight:** on.

## Resource hand-overs {#group-resource-hand-overs}

`resourceTransitions` describe moving work from one resource to another
between dependent tasks: forbidden, or preferred with a reward.

<%= render Workbench::Rule.new(site: site, model: m, name: "Forbidden resource hand-over") %>

A task runs on a resource that its predecessor's resource may not hand over
to, such as a part that cannot travel between two halls.

- **Reads:** `resourceTransitions[]` with `forbidden: true`, the resources of
  each dependent pair.
- **Cost:** the broken-link penalty per forbidden hand-over.
- **Example:** hand-overs from Hall A to Hall B are forbidden; *Assemble* on a
  Hall B station depends on *Cut* on a Hall A saw. That costs 1,000 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred resource hand-over") %>

A task runs on a resource that its predecessor's resource prefers to hand over
to. This is a reward, so it makes the score better.

- **Reads:** `resourceTransitions[].reward`, the resources of each dependent
  pair.
- **Cost:** none; it earns the transition's `reward` per dependent pair.
- **Example:** Press 1 to Oven 1 has reward 20, because they stand side by
  side. Each dependent pair that goes from Press 1 to Oven 1 earns 20 soft.
- **Weight:** on.

## Parts {#group-parts}

<%= render Workbench::Rule.new(site: site, model: m, name: "Parts out of stock") %>

A task starts while the stock lacks parts it uses. The plan's `stock` lists
units on hand from the start (no `at`) or arriving at a time. A task takes the
parts it `consumes` when it starts and adds the parts it `produces` when it
ends. The rule replays every placed task in time order and counts the units
missing. Parts that arrive or are made at a minute are there for a task that
starts that minute.

- **Reads:** `stock[]` (`part`, `quantity`, `at`), `tasks[].consumes`,
  `tasks[].produces`.
- **Cost:** one hour (60) per unit short.
- **Example:** two boxes of red powder are on hand and two more arrive on
  Tuesday. Three coating tasks that each use one box run on Monday; the third
  finds none. That costs 60 hard.
- **Weight:** on. A dataset without `stock`, `consumes` or `produces` never
  triggers it.

## Throughput {#group-throughput}

<%= render Workbench::Rule.new(site: site, model: m, name: "Task left unassigned") %>

A task is left in the unassigned queue. It weighs only after every hard rule
holds, so the solver plans as much as it can without breaking one, and the
most important tasks first.

- **Reads:** `tasks[].priority` (or `defaultPriority`).
- **Cost:** the task's priority.
- **Example:** two tasks with priorities 5 and 1 are left out. That costs 6
  medium.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Makespan") %>

The length of the schedule: the longest time any resource takes from its
`start` to the end of its last task. Pinned tasks count too. Shortening the
makespan finishes the whole job sooner.

- **Reads:** `resources[].start`, every task's end.
- **Cost:** that longest time, in minutes, once for the whole plan.
- **Example:** resources start Monday 06:00 and the last task ends Wednesday
  14:00. That costs 3,360 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Machine idle time") %>

A machine waits before a task without working, changing over or being
unavailable. People are not counted.

- **Reads:** resources with `kind: "Machine"`, their `unavailable` spans and
  changeovers.
- **Cost:** the idle minutes before each task.
- **Example:** a machine finishes at 10:00 and its next task waits for its
  earliest start at 10:45 after a 15-minute changeover. The 30 minutes idle cost
  30 soft.
- **Weight:** off unless weighted.

## Due dates {#group-due-dates}

<%= render Workbench::Rule.new(site: site, model: m, name: "Distance from ideal end") %>

A task ends before or after its `idealEnd`, for work that should be ready at a
moment, neither earlier nor later.

- **Reads:** `tasks[].idealEnd`, `tasks[].priority`.
- **Cost:** the minutes off, early or late, times the task's priority.
- **Example:** a priority-2 task with ideal end 12:00 ends at 11:15. That costs
  90 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Lateness after due date") %>

A task ends after its `dueDate`. Unlike the deadline this is a cost, not a
rule that must hold, and ending early earns nothing.

- **Reads:** `tasks[].dueDate`.
- **Cost:** the minutes late.
- **Example:** due Friday 17:00, ended Friday 18:20. That costs 80 soft.
- **Weight:** on.

## Changeovers {#group-changeovers}

A machine is set up for one task type at a time. Its `initialTaskType` is the
setup at its start; `changeovers` give the setup minutes a machine type needs
from one task type to another.

<%= render Workbench::Rule.new(site: site, model: m, name: "Changeover time") %>

A machine spends setup time between two consecutive tasks. Setup pauses over
unavailable spans like work does.

- **Reads:** `changeovers[]` (`machineType`, `from`, `to`, `duration`),
  `resources[].machineType`, `resources[].initialTaskType`, `tasks[].taskType`.
- **Cost:** the setup minutes.
- **Example:** a coating line goes from red to blue powder, a 45-minute
  changeover. That costs 45 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Changeover count") %>

A machine switches task type between consecutive tasks, or sets up between
them. Count and time are separate so a plan can prefer fewer switches even
when they are short.

- **Reads:** the same fields as changeover time.
- **Cost:** one per changeover.
- **Example:** red, blue, red on one line is two changeovers: 2 soft.
- **Weight:** on.
