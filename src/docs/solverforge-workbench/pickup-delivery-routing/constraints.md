---
title: "Pick-up and delivery routing constraints"
linkTitle: "Constraints"
description: >
  The 39 rules that score a pick-up and delivery plan: what each one checks,
  which fields it reads, what one violation costs, and an example.
---

<% m = "pickup-delivery-routing" %>

Every rule below scores one plan. Click a rule to read it. Field names are the
dataset's JSON names, documented on the [data page](../data/); a job's stops
are `jobs[].stops[]`, a driver's shifts `drivers[].shifts[]`. Times are scored
in seconds. Rules that count something rather than time (a missing skill, a
unit over capacity) cost **one hour** (3,600) per count, so they weigh like an
hour of lateness. A **weight** multiplies a rule's cost: 1 as designed, 0 off,
10 ten times as important.

<%= render Workbench::RulesToolbar.new(site: site, model: m) %>

## Dependencies between stops {#group-dependencies-between-stops}

A job's stops are served in the order they are listed, all by one driver
shift: picked up first, then delivered. Every rule here adds one hour to its
cost, so a broken job always costs more than the lateness it might save.

<%= render Workbench::Rule.new(site: site, model: m, name: "Stop served before the stop it follows") %>

A stop starts before the job's previous stop has finished, on the same shift.
It also fires when the previous stop is left unplanned while this one is
planned.

- **Reads:** the order of `jobs[].stops`, each stop's service time.
- **Cost:** the seconds of overlap plus one hour; with the previous stop
  unplanned, its service seconds plus one hour.
- **Example:** the drop-off starts 5 minutes before the pick-up ends. That
  costs 300 + 3,600 = 3,900 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Job split across shifts") %>

A job's stop is planned on a different shift from the stop before it, so one
driver would pick up and another deliver.

- **Reads:** `jobs[].stops`, the shift serving each stop.
- **Cost:** the stop's service seconds plus one hour.
- **Example:** a patient picked up by Anna and dropped off by Marco, with a
  5-minute drop-off: 300 + 3,600 = 3,900 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Stop planned while the stop before it is not") %>

A stop is planned while the job's previous stop is left unplanned: a drop-off
of something never picked up.

- **Reads:** `jobs[].stops`.
- **Cost:** the service seconds of both stops plus one hour.
- **Example:** a 10-minute drop-off planned without its 5-minute pick-up costs
  600 + 300 + 3,600 = 4,500 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Ride past a destination") %>

The vehicle serves another stop at the very place a job on board is going to,
without dropping that job off. The passenger rides past their own door.

- **Reads:** the stops' `location`, what is on board at each stop.
- **Cost:** one hour per job ridden past, per stop.
- **Example:** a van stops at the Policlinico for another patient while a
  patient for the Policlinico stays on board. That costs 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Job partly planned") %>

Some of a job's stops are planned and others are not. A job is planned whole
or not at all.

- **Reads:** `jobs[].stops`.
- **Cost:** per unplanned stop, its service seconds plus one hour.
- **Example:** a three-stop job with its last 10-minute stop unplanned costs
  600 + 3,600 = 4,200 hard.
- **Weight:** on.

## Vehicle capacity {#group-vehicle-capacity}

<%= render Workbench::Rule.new(site: site, model: m, name: "Vehicle capacity exceeded") %>

After a stop, the vehicle carries more of a kind than it has room for. Each
shift's `capacities` give its room per kind (seats, wheelchair places,
parcels). A stop's `demands` pick up and deliver units of a kind; a two-stop
job may instead set `demands` on the job, picked up at the first stop and
delivered at the second.

- **Reads:** `drivers[].shifts[].capacities`, `jobs[].demands`,
  `jobs[].stops[].demands`.
- **Cost:** one hour per unit over, per stop and kind.
- **Example:** a van with 1 wheelchair place picks up a second wheelchair
  user. That costs 3,600 hard until one is dropped off; if the van stops once
  more first, that stop costs another 3,600.
- **Weight:** on.

## Job requirements and tags {#group-job-requirements-and-tags}

<%= render Workbench::Rule.new(site: site, model: m, name: "Driver not among the required") %>

A stop is served by a driver its job does not list in `requiredDrivers`.

- **Reads:** `jobs[].requiredDrivers`, the driver of the serving shift.
- **Cost:** one hour per stop.
- **Example:** a job requiring Anna is served by Marco at both stops. That
  costs 7,200 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prohibited driver assigned") %>

A stop is served by a driver its job lists in `prohibitedDrivers`.

- **Reads:** `jobs[].prohibitedDrivers`.
- **Cost:** one hour per stop.
- **Example:** a job prohibits Marco and he serves its pick-up: 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred driver not assigned") %>

A stop is served by a driver its job does not list in `preferredDrivers`,
such as a regular patient who knows one driver.

- **Reads:** `jobs[].preferredDrivers`.
- **Cost:** one per stop.
- **Example:** a two-stop job that prefers Anna, served by Marco, costs 2 soft.
  Raise the weight to make preferences count against travel.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Time burden over the maximum") %>

Pooling makes a job's ride longer than its limit allows. The ride runs from
the start of its first stop to the start of its last; the direct ride is the
service at each stop plus the straight drive to the next. The difference must
stay within the job's `maximumTimeBurden`, or the `maximumTimeBurden`
parameter for jobs that set none. Unset means no limit.

- **Reads:** `jobs[].maximumTimeBurden`, the parameter `maximumTimeBurden`.
- **Cost:** the seconds over the limit, on the job's last stop.
- **Example:** direct, a patient's trip takes 20 minutes; with two detours it
  takes 45. With a 15-minute limit, the 10 minutes over cost 600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prohibited jobs on board together") %>

Two jobs where one lists the other in `prohibitedJobs` are on board at the
same time.

- **Reads:** `jobs[].prohibitedJobs`.
- **Cost:** the seconds they ride together, at least one.
- **Example:** a lab sample and a patient that may not share the van ride
  together for 12 minutes. That costs 720 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Pooled with a job that forbids pooling") %>

A job with `prohibitJobPooling` is on board together with any other job.

- **Reads:** `jobs[].prohibitJobPooling`.
- **Cost:** the seconds they ride together, at least one.
- **Example:** an exclusive transfer shares the van for 8 minutes: 480 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required tags missing") %>

The shift serving a stop lacks a tag the job requires, such as a refrigerated
van or a stretcher.

- **Reads:** `jobs[].requiredTags`, `drivers[].shifts[].tags`.
- **Cost:** one hour per missing tag, per stop.
- **Example:** a job requiring `refrigerated` served by a plain van at both
  stops costs 7,200 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Parts out of stock") %>

A stop uses parts from its shift's own stock, as when a driver installs what
they deliver. The shift loads its `stock` before setting off; its stops use
their `parts` in route order. A stop that finds too few units left is short.

- **Reads:** `drivers[].shifts[].stock`, `jobs[].stops[].parts`.
- **Cost:** one hour per unit short.
- **Example:** a van loads 3 oxygen cylinders; its fourth delivery needs one
  more. That costs 3,600 hard.
- **Weight:** on. A dataset without `stock` or `parts` never triggers it.

## Breaks and appointments {#group-breaks-and-appointments}

A shift's `requiredBreaks` are **fixed** (`kind: "FIXED"`), from `startTime` to `endTime`, or
**floating** (`"FLOATING"`), lasting `duration` minutes between `minStartTime` and
`maxEndTime`. A break with a `location` is taken there, like an appointment;
otherwise wherever the driver is.

<%= render Workbench::Rule.new(site: site, model: m, name: "Late for a fixed break") %>

Work runs into a fixed break without a location, so the break starts after
its `startTime`. It still lasts as long as planned.

- **Reads:** `requiredBreaks[]` with `kind: "FIXED"`.
- **Cost:** the seconds the break starts late.
- **Example:** lunch is fixed at 12:30; the driver finishes a stop at 12:40.
  That costs 600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Late for an appointment") %>

The driver reaches a fixed break at a `location` of its own, such as a
vehicle inspection, after it should start.

- **Reads:** fixed `requiredBreaks[]` with a `location`.
- **Cost:** the seconds late on arrival.
- **Example:** a depot meeting at 14:00, reached at 14:07, costs 420 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Floating break ends too late") %>

A floating break cannot start early enough to end by its `maxEndTime`.

- **Reads:** floating `requiredBreaks[]` (`minStartTime`, `maxEndTime`,
  `duration`).
- **Cost:** the seconds it ends late.
- **Example:** a 30-minute break must end by 14:00 and starts at 13:50. That
  costs 1,200 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Fixed break while a job is on board") %>

A fixed break falls while a job is on board, and either the break's `policy`
is `REJECT_JOBS` or the job's `allowInterruption` is `NONE`.

- **Reads:** `requiredBreaks[].policy`, `jobs[].allowInterruption`.
- **Cost:** the break seconds, per job held.
- **Example:** a 30-minute lunch taken with a patient on board who may not
  wait costs 1,800 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Floating break while a job is on board") %>

A floating break falls while a job is on board, and either the break's `policy` is `REJECT_JOBS` or the job's `allowInterruption` is `NONE`.

- **Reads:** `requiredBreaks[].policy`, `jobs[].allowInterruption`.
- **Cost:** the break seconds, per job held.
- **Example:** a 15-minute break with two jobs on board under a `REJECT_JOBS`
  break costs 1,800 hard.
- **Weight:** on.

## Multi-day schedules {#group-multi-day-schedules}

<%= render Workbench::Rule.new(site: site, model: m, name: "Stop later than its earliest day") %>

A stop whose time windows span several days is served after the first day it
could be. That day is the first on which a shift that may serve it (right
driver, skills and tags) works inside one of its windows. Work that can be
done Monday should not drift to Tuesday.

- **Reads:** `jobs[].stops[].timeWindows`, the shifts' days and fit.
- **Cost:** 1,000 per day later.
- **Example:** a delivery open Monday to Wednesday, servable Monday, is served
  Wednesday. That costs 2,000 soft.
- **Weight:** on.

## Priority and optional jobs {#group-priority-and-optional-jobs}

A job's `priority` is `1` to `10` (mandatory) or `opt-1` to `opt-10`
(optional), the `defaultPriority` parameter when unset. Level 1 weighs most;
each level weighs ten times the next, from 1,000,000,000 for `1` down to 1 for
`10`. `priorityWeights` can rename levels or change their weights.

<%= render Workbench::Rule.new(site: site, model: m, name: "Mandatory stop unplanned") %>

A stop of a mandatory job is left unplanned. This is medium: the solver plans
as many mandatory jobs as it can without breaking a hard rule.

- **Reads:** `jobs[].priority`, `priorityWeights`.
- **Cost:** the priority's weight, per stop.
- **Example:** a two-stop job at priority 6 (weight 10,000) left out costs
  20,000 medium.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Optional stop unplanned") %>

A stop of an optional job is left unplanned. Optional work is soft: it is
done when it pays for its travel.

- **Reads:** `jobs[].priority`, `priorityWeights`.
- **Cost:** the priority's weight, per stop.
- **Example:** a two-stop job at `opt-8` (weight 100) left out costs 200 soft.
- **Weight:** on.

## Replanning {#group-replanning}

A shift's `itinerary` is its plan. An item with `pin: true` keeps its shift,
and keeps its `startServiceTime` when one is given.

<%= render Workbench::Rule.new(site: site, model: m, name: "Pinned stop off its shift") %>

A pinned stop is not on the shift it is pinned to, or is unplanned.

- **Reads:** `itinerary[].pin`.
- **Cost:** 10,000,000,000, so nothing outweighs it.
- **Example:** a stop pinned to Anna's Monday shift moves to Marco: 10^10 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Pinned stop starts late") %>

A pinned stop waits for its kept start; arriving later moves it. It must not.

- **Reads:** `itinerary[].startServiceTime`.
- **Cost:** 100,000 per second late.
- **Example:** a pinned stop kept at 10:00 starts at 10:01. That costs
  6,000,000 hard.
- **Weight:** on.

## Route optimization {#group-route-optimization}

<%= render Workbench::Rule.new(site: site, model: m, name: "Unreachable leg in a route") %>

A shift's route has a leg no road connects, anywhere from its start location
through its stops and breaks to its end location.

- **Reads:** the travel matrix (`null` legs), the shifts' start and end
  locations.
- **Cost:** one hour per unreachable leg.
- **Example:** the drive back to a depot on an island with no road costs
  3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Stop unreachable from the previous place") %>

No road leads to a stop or break from the place before it. It names the visit
the leg leads to; the route rule above counts the same leg for the shift.

- **Reads:** the travel matrix.
- **Cost:** one hour per visit.
- **Example:** a stop snapped to a footpath no car can reach costs 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Travel time") %>

The time a shift spends driving, from its start location through its stops to
its end location. Roads, busy periods, the driver's travel mode and driving
rests all count.

- **Reads:** the travel matrix or road network, `traffic`,
  `drivers[].travelMode`, `drivingRest`.
- **Cost:** the driving seconds.
- **Example:** a shift that drives 3 h 20 min costs 12,000 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Waiting time") %>

A driver arrives before a stop's window opens and waits. A driver sets off
just in time for the first stop, so only later waits count.

- **Reads:** `jobs[].stops[].timeWindows`.
- **Cost:** the seconds waited.
- **Example:** arriving at 09:40 for a window opening at 10:00 costs 1,200
  soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Driver used") %>

A driver serves at least one stop. Weighting it makes the plan use fewer
drivers, each doing more.

- **Reads:** `drivers`.
- **Cost:** one hour per driver who works.
- **Example:** 12 drivers working cost 43,200 soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Work unbalanced between drivers") %>

Drivers work different amounts. Each driver's working minutes, start to end
over all their shifts, are squared and summed; for a fixed total the sum is
least when the work is shared evenly.

- **Reads:** every shift's start and end.
- **Cost:** the sum of the squared working minutes.
- **Example:** two drivers working 300 and 500 minutes cost 340,000; at 400
  and 400 they cost 320,000.
- **Weight:** off unless weighted.

## Service level agreements {#group-service-level-agreements}

<%= render Workbench::Rule.new(site: site, model: m, name: "SLA missed") %>

A stop ends after its `latestSlaEndTime`. A stop left unplanned whose SLA
falls inside the `planningWindow` misses it too, by the time from the SLA to
the window's end.

- **Reads:** `jobs[].stops[].latestSlaEndTime`, `planningWindow`.
- **Cost:** the seconds late.
- **Example:** a lab sample due by 11:00 delivered at 11:25 costs 1,500 soft.
- **Weight:** on.

## Shift hours and overtime {#group-shift-hours-and-overtime}

<%= render Workbench::Rule.new(site: site, model: m, name: "Last stop departs after the latest time") %>

A shift leaves its last stop after `maxLastStopDepartureTime`.

- **Reads:** `drivers[].shifts[].maxLastStopDepartureTime`.
- **Cost:** the seconds late.
- **Example:** latest departure 17:30, left at 17:42: 720 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift ends after the latest time") %>

A shift reaches its end location after `maxEndTime`.

- **Reads:** `drivers[].shifts[].maxEndTime`, `endLocation`.
- **Cost:** the seconds late.
- **Example:** must be back by 18:00, back at 18:15: 900 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Last stop departs after the preferred time") %>

A shift leaves its last stop after `maxSoftLastStopDepartureTime`.

- **Reads:** `drivers[].shifts[].maxSoftLastStopDepartureTime`.
- **Cost:** the seconds late.
- **Example:** preferred 17:00, left at 17:20: 1,200 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift ends after the preferred time") %>

A shift reaches its end location after `maxSoftEndTime`: overtime.

- **Reads:** `drivers[].shifts[].maxSoftEndTime`.
- **Cost:** the seconds of overtime.
- **Example:** preferred end 17:30, back at 18:00: 1,800 soft.
- **Weight:** on.

## Skills {#group-skills}

A job's `requiredSkills` name skills with an optional `minLevel`; a shift's
`skills` have a `level` (1 when unset) and an optional `multiplier` that
scales the service time of stops needing them.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required skills missing") %>

The shift serving a stop lacks a required skill or holds it below
`minLevel`.

- **Reads:** `jobs[].requiredSkills`, `drivers[].shifts[].skills`.
- **Cost:** one hour per level short; a skill held not at all is short by
  1 plus its `minLevel`.
- **Example:** a job needs `wheelchair` at level 2 and the driver holds level
  1: 3,600 hard per stop.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Driver more skilled than needed") %>

The shift serving a stop holds a required skill above its `minLevel`. Keeping
highly skilled drivers for the jobs that need them leaves them free.

- **Reads:** `jobs[].requiredSkills[].minLevel`, `drivers[].shifts[].skills`.
- **Cost:** the stop's service seconds times the levels above.
- **Example:** a 10-minute stop needing level 1, served at level 3, costs
  1,200 soft.
- **Weight:** on.

## Time windows {#group-time-windows}

A stop's `timeWindows` each give `minStartTime`, an optional `maxStartTime`
and `maxEndTime`. A driver arriving early waits for the window to open.

<%= render Workbench::Rule.new(site: site, model: m, name: "Service ends after its window") %>

A stop's service ends after its window's `maxEndTime`.

- **Reads:** `jobs[].stops[].timeWindows`, `duration`.
- **Cost:** the seconds late.
- **Example:** window until 12:00, a 15-minute stop starting at 11:55 ends at
  12:10: 600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Service starts after its window") %>

A stop's service starts after its window's `maxStartTime`.

- **Reads:** `jobs[].stops[].timeWindows[].maxStartTime`.
- **Cost:** the seconds late.
- **Example:** must start by 09:30, starts at 09:34: 240 hard.
- **Weight:** on.
