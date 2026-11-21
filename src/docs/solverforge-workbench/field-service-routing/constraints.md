---
title: "Field service routing constraints"
linkTitle: "Constraints"
description: >
  The 66 rules that score a field service plan: what each one checks, which
  fields it reads, what one violation costs, and an example.
---

<% m = "field-service-routing" %>

Every rule below scores one plan. Click a rule to read it. Field names are the
dataset's JSON names, documented on the [data page](../data/); a vehicle's
shifts are `vehicles[].shifts[]`, and a shift's limits, skills, tags and breaks
sit on the shift itself. Times are scored in seconds. Rules that count
something rather than time (a missing skill, a vehicle the visit rules out)
cost **one hour** (3,600) per count, so they weigh like an hour of lateness. A
**weight** multiplies a rule's cost: 1 as designed, 0 off, 10 ten times as
important.

<%= render Workbench::RulesToolbar.new(site: site, model: m) %>

## Dependencies between visits {#group-dependencies-between-visits}

A visit's `visitDependencies` name the visits it waits for. Each dependency
counts from the preceding visit's departure: at least `minDelay` and at most
`maxDelay` minutes later, or no earlier than `minDelayTo` / no later than
`maxDelayTo`, a time on a later day (`NEXT_DAY`, or `NEXT_WORKING_DAY`, which
skips weekends and the `holidays` parameter). The technician waits for the
earliest start by itself. Broken links add one hour, so a broken dependency
costs more than the lateness it might save.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require visit dependency delay") %>

A visit starts later than its dependency's maximum delay allows.

- **Reads:** `visitDependencies[]` (`maxDelay`, `maxDelayTo`).
- **Cost:** the seconds late.
- **Example:** a follow-up must start within 2 days of the installation and
  starts 3 hours after that. That costs 10,800 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require the same vehicle for dependent visit") %>

A dependency with `coordination: "SAME_VEHICLE"` is served by another vehicle
than the visit it depends on, such as a second visit the same technician must
make.

- **Reads:** `visitDependencies[].coordination`.
- **Cost:** the visit's service seconds plus one hour.
- **Example:** a 30-minute follow-up served by another technician costs
  1,800 + 3,600 = 5,400 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require the same vehicle shift for dependent visit") %>

A dependency with `coordination: "SAME_SHIFT"` is served on another shift
than the visit it depends on.

- **Reads:** `visitDependencies[].coordination`.
- **Cost:** the visit's service seconds plus one hour.
- **Example:** the second half of a job lands on the next day's shift: a
  60-minute visit costs 3,600 + 3,600 = 7,200 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require visit dependency prerequisite assigned") %>

A visit is planned while a visit it depends on is left unplanned.

- **Reads:** `visitDependencies[].precedingVisit`.
- **Cost:** the visit's service seconds plus one hour.
- **Example:** a 45-minute commissioning planned without its installation
  costs 2,700 + 3,600 = 6,300 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require visit dependency dependent assigned") %>

The other side of the rule above: a visit is planned while a visit that
depends on it is left unplanned, so work starts that will not be finished.

- **Reads:** `visitDependencies[].precedingVisit`.
- **Cost:** the dependent's service seconds plus one hour.
- **Example:** an installation is planned and its 45-minute commissioning is
  not: 6,300 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require visit dependency pooling type") %>

The visit served right before a dependent visit is one its dependency's
`poolingType` rules out. The types are `ALLOW_POOLING_ALL` (anything may run
between), `ALLOW_POOLING_VISITS` (only visits in no dependency),
`ALLOW_POOLING_DEPENDENCIES` (only visits of other dependencies) and
`DISALLOW_POOLING` (the visit follows its preceding visit directly). Unset, the
`defaultDependencyPoolingType` parameter applies.

- **Reads:** `visitDependencies[].poolingType`.
- **Cost:** one hour per dependency.
- **Example:** a `DISALLOW_POOLING` repair has another call between it and its
  diagnosis. That costs 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require no mutually exclusive visits assigned") %>

Two visits where one lists the other in `exclusions` are both planned, such
as two alternative appointments for the same customer.

- **Reads:** `visits[].exclusions`.
- **Cost:** one hour per pair.
- **Example:** both the morning and the afternoon slot offered to one customer
  get planned: 3,600 hard.
- **Weight:** on.

## Lunch breaks and personal appointments {#group-lunch-breaks-and-personal-appointments}

A shift's `requiredBreaks` are **fixed** (`kind: "FIXED"`), from `startTime`
to `endTime`, or **floating** (`"FLOATING"`), lasting `duration` minutes
between `minStartTime` and `maxEndTime`. A break with a `location` is taken
there, like a personal appointment; otherwise where the technician is.

<%= render Workbench::Rule.new(site: site, model: m, name: "No conflict with fixed break") %>

Work runs past the start of a fixed break without a location, so the break
starts late.

- **Reads:** fixed `requiredBreaks[]` without `location`.
- **Cost:** the seconds work overlaps the break's start.
- **Example:** lunch at 12:30; the visit before it ends at 12:45. That costs
  900 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "No conflict with fixed location break") %>

Work runs past the start of a fixed break that has a `location`.

- **Reads:** fixed `requiredBreaks[]` with `location`.
- **Cost:** the seconds work overlaps the break's start.
- **Example:** a doctor's appointment at 15:00; the visit before ends at 15:10.
  That costs 600 hard, and the drive there counts in the next rule.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Fixed break not delayed (hard)") %>

The technician reaches a fixed break at a `location` after it starts because
of the drive there.

- **Reads:** fixed `requiredBreaks[]` with `location`, the travel time.
- **Cost:** the seconds late, less any overlap the rule above already counts.
- **Example:** the last visit ends at 14:50 and the 20-minute drive reaches a
  15:00 appointment at 15:10: 600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max floating break end time (hard)") %>

A floating break cannot start early enough to end by its `maxEndTime`.

- **Reads:** floating `requiredBreaks[]`.
- **Cost:** the seconds it ends late.
- **Example:** a 30-minute lunch must end by 14:00 and starts at 13:45: 900
  hard.
- **Weight:** on.

## Multi-day schedules and movable visits {#group-multi-day-schedules-and-movable-visits}

A visit is **movable** when its time windows span more than one day or reach
past the end of the `planningWindow`: it could be done now or later.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer visits scheduled to the earliest day") %>

A movable visit is served after the first day it could be. That day is the
first on which a shift that may serve it works inside one of its windows.

- **Reads:** `visits[].timeWindows`, the shifts' days and fit.
- **Cost:** 1,000 per day later.
- **Example:** a maintenance visit open all week, servable Monday, is served
  Thursday: 3,000 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Balance movable and non-movable visits") %>

Movable visits take more of a shift's working time than its
`movableOccupationRatioThreshold` allows, crowding out work that must happen
today. Their drive and service count; working time is the shift's span less
its breaks.

- **Reads:** `movableOccupationRatioThreshold` (1 when unset).
- **Cost:** the seconds over the threshold.
- **Example:** threshold 0.5 on an 8-hour shift allows 4 hours of movable
  work; 4 h 30 min costs 1,800 hard.
- **Weight:** on.

## Priority visits and optional visits {#group-priority-visits-and-optional-visits}

A visit's `priority` is `1` to `10` (mandatory) or `opt-1` to `opt-10`
(optional), the `defaultPriority` parameter when unset. Level 1 weighs most;
each level weighs ten times the next, from 1,000,000,000 for `1` down to 1 for
`10`. `priorityWeights` can rename levels or change their weights.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require scheduling mandatory visits") %>

A mandatory visit is left unplanned. This is medium: the solver plans as many
mandatory visits as it can without breaking a hard rule, the most important
first.

- **Reads:** `visits[].priority`, `priorityWeights`.
- **Cost:** the priority's weight.
- **Example:** a priority-6 visit (weight 10,000) left out costs 10,000
  medium.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer scheduling optional visits") %>

An optional visit is left unplanned. Optional work is done when it pays for
its travel.

- **Reads:** `visits[].priority`, `priorityWeights`.
- **Cost:** the priority's weight.
- **Example:** an `opt-7` visit (weight 1,000) left out costs 1,000 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize the visit completion risk") %>

An important visit ends close to its shift's end, where any delay would leave
it unfinished. It applies to visits at the `visitCompletionRiskMinimalPriority`
or more important, and the margin is
`visitCompletionRiskMinimalTimeToShiftEnd` minutes before the shift's latest
last departure (or its latest end).

- **Reads:** the two parameters, `maxLastVisitDepartureTime`, `maxEndTime`.
- **Cost:** the seconds the visit ends inside the margin.
- **Example:** margin 60 minutes, latest departure 17:00: a priority-2 visit
  ending at 16:40 costs 2,400 soft.
- **Weight:** on.

## Profit maximization {#group-profit-maximization}

<%= render Workbench::Rule.new(site: site, model: m, name: "Maximize profit") %>

A planned visit earns its `profit`. Set against shift costs and travel, it
decides which optional work is worth doing.

- **Reads:** `visits[].profit`.
- **Cost:** none; it rewards the profit in cents.
- **Example:** a visit with profit 85.50 earns 8,550 soft.
- **Weight:** on.

## Replanning {#group-replanning}

A shift's `itinerary` is its plan. An item with `pin: true` keeps its shift and
its `startServiceTime`.

<%= render Workbench::Rule.new(site: site, model: m, name: "Keep a pinned visit's vehicle shift") %>

A pinned visit is not on the shift it is pinned to, or is unplanned.

- **Reads:** `itinerary[].pin`.
- **Cost:** 10,000,000,000, so nothing outweighs it.
- **Example:** a visit pinned to Monday's shift moves to Tuesday: 10^10 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Keep a pinned visit's start service time") %>

A pinned visit starts later than its kept start plus the allowed delay, the
`pinnedStartAllowedDelay` parameter.

- **Reads:** `itinerary[].startServiceTime`, `pinnedStartAllowedDelay`.
- **Cost:** 100,000 per second beyond the allowed delay.
- **Example:** allowed delay 0, kept at 10:00, starts at 10:01: 6,000,000
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize a pinned visit's start service time allowed delay") %>

A pinned visit starts after its kept start but within the allowed delay.

- **Reads:** `itinerary[].startServiceTime`, `pinnedStartAllowedDelay`.
- **Cost:** the seconds of delay, up to the allowed delay.
- **Example:** allowed 15 minutes, starts 10 minutes late: 600 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize disruption on replanning") %>

A replan changes what the input plan said: a visit moves to another shift
(100), to another vehicle as well (another 100), or starts at another time.

- **Reads:** the input `itinerary` and its `startServiceTime`s.
- **Cost:** 100 per change of shift, 100 more per change of vehicle, plus
  the seconds the start moved; 200 for a visit that was planned and is not.
- **Example:** a visit moved to another technician and 15 minutes later costs
  100 + 100 + 900 = 1,100 soft.
- **Weight:** off unless weighted.

## Route optimization {#group-route-optimization}

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize travel time") %>

The time a shift that serves visits spends driving, from its start location
through its visits and breaks to its end. Roads, busy periods, the vehicle's
travel mode, the shift's `travelTimeAdjustment` and driving rests all count.

- **Reads:** the road network or travel matrix, `traffic`,
  `vehicles[].travelMode`, `travelTimeAdjustment`, `drivingRest`.
- **Cost:** the driving seconds.
- **Example:** a shift that drives 2 h 10 min costs 7,800 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize travel distance") %>

The distance a shift that serves visits drives, start to end.

- **Reads:** the road network or travel matrix.
- **Cost:** the meters.
- **Example:** 84 km costs 84,000 soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Penalize inactive shift travel time") %>

A shift that serves no visit still drives to its breaks with a location and
home.

- **Reads:** the shift's breaks and locations.
- **Cost:** the driving seconds.
- **Example:** an idle shift that drives 25 minutes to an appointment and
  back costs 1,500 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Penalize inactive shift travel distance") %>

A shift that serves no visit still drives to its breaks with a location and home; this rule counts those meters.

- **Reads:** the shift's breaks and locations.
- **Cost:** the meters.
- **Example:** 18 km costs 18,000 soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max travel time per visit (hard)") %>

The drive to one visit takes longer than the shift's
`maxTravelTimePerVisit`.

- **Reads:** `maxTravelTimePerVisit`.
- **Cost:** the seconds over.
- **Example:** at most 45 minutes per drive; a 55-minute drive costs 600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max shift travel time (hard)") %>

A shift's total driving exceeds its `maxTravelTime`.

- **Reads:** `maxTravelTime`.
- **Cost:** the seconds over.
- **Example:** at most 3 hours, drives 3 h 20 min: 1,200 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max shift travel time (soft)") %>

A shift's total driving exceeds its `maxSoftTravelTime`.

- **Reads:** `maxSoftTravelTime`.
- **Cost:** the seconds over.
- **Example:** preferred 2 hours, drives 2 h 30 min: 1,800 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max shift service duration (hard)") %>

A shift's total service time exceeds its `maxServiceDuration`.

- **Reads:** `maxServiceDuration`.
- **Cost:** the seconds over.
- **Example:** at most 6 hours on site, 6 h 15 min planned: 900 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max shift service duration (soft)") %>

A shift's total service time exceeds its `maxSoftServiceDuration`.

- **Reads:** `maxSoftServiceDuration`.
- **Cost:** the seconds over.
- **Example:** preferred 5 hours, 5 h 30 min planned: 1,800 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max visits per shift (hard)") %>

A shift serves more visits than its `maxVisits`.

- **Reads:** `maxVisits`.
- **Cost:** one hour per visit over.
- **Example:** at most 8 visits, 9 planned: 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max visits per shift (soft)") %>

A shift serves more visits than its `maxSoftVisits`.

- **Reads:** `maxSoftVisits`.
- **Cost:** one per visit over.
- **Example:** preferred 6, 8 planned: 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize waiting time") %>

A technician arrives before a visit can start and waits. The technician sets
off just in time for the first visit, so only later waits count.

- **Reads:** `visits[].timeWindows`, dependencies, tools.
- **Cost:** the seconds waited.
- **Example:** arriving at 13:35 for a window opening at 14:00: 1,500 soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer grouping co-located visits") %>

Two consecutive items of a route are at the same place, or closer than the
shift's `preferGroupingColocatedVisitsRadiusMeters` (the parameter when unset,
at most 200): one parking, one check-in.

- **Reads:** visit and break `location`s, the radius.
- **Cost:** none; it rewards one per pair.
- **Example:** three flats in one building served in a row earn 2 soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer grouping visits in the same consecutive group") %>

Two consecutive visits of a route share a `preferredConsecutiveGroupId`.

- **Reads:** `visits[].preferredConsecutiveGroupId`.
- **Cost:** none; it rewards one per pair.
- **Example:** four visits of one client's sites in a row earn 3 soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer moving towards end location") %>

After the first visit, a drive takes the technician farther from the shift's
end location, so the day ends far from home.

- **Reads:** visit `location`s, `endLocation`.
- **Cost:** the meters farther from the end, per drive.
- **Example:** a visit 6 km farther from home than the one before costs 6,000
  soft.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require reachable visits") %>

No road leads to a visit from the place before it.

- **Reads:** the travel matrix (`null` legs).
- **Cost:** one hour per visit.
- **Example:** a visit on a mountain hut with no road: 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require reachable itineraries") %>

A shift's route has a leg no road connects, from its start through its visits
and breaks to its end.

- **Reads:** the travel matrix, start and end locations.
- **Cost:** one hour per leg.
- **Example:** no road back to the depot after the last visit: 3,600 hard.
- **Weight:** on.

## Service level agreements {#group-service-level-agreements}

A visit's `latestSlaEndTime` is when its service should be done.

<%= render Workbench::Rule.new(site: site, model: m, name: "Latest SLA end time") %>

A visit ends after its `latestSlaEndTime`, the moment its service agreement says the work should be done.

- **Reads:** `visits[].latestSlaEndTime`.
- **Cost:** the seconds late.
- **Example:** SLA 16:00, done at 16:30: 1,800 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer scheduling visits with tight SLAs earlier") %>

Visits with an SLA are served early in the time their SLA leaves. The cost is
how much of the time from the start of the `planningWindow` to the SLA has
passed when the visit ends, so tight SLAs pull their visits forward.

- **Reads:** `latestSlaEndTime`, `planningWindow.startDate`.
- **Cost:** that share in thousandths: 1,000 when the visit ends exactly at
  its SLA.
- **Example:** the window opens Monday 00:00, the SLA is Wednesday 00:00, and
  the visit ends Monday 12:00: 250 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require scheduling mandatory visits with tighter SLA") %>

A mandatory visit with an SLA is left unplanned. The cost grows the tighter
the SLA, so among mandatory visits left out, those with the nearest SLA go in
first.

- **Reads:** `latestSlaEndTime`, `planningWindow`.
- **Cost:** 1,000 times the planning window's length divided by the time from
  its start to the SLA.
- **Example:** a 4-day window with an SLA one day in costs 4,000 medium.
- **Weight:** off unless weighted.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer scheduling optional visits with tighter SLA") %>

The same for an optional visit, at the soft level.

- **Reads:** `latestSlaEndTime`, `planningWindow`.
- **Cost:** 1,000 times the window's length over the time to the SLA.
- **Example:** an SLA half-way through the window costs 2,000 soft.
- **Weight:** off unless weighted.

## Skills {#group-skills}

A visit's `requiredSkills` name skills with an optional `minLevel` (1 when
unset). A shift's `skills` have a `level` (1 when unset) and an optional
`multiplier` that scales the part of the service in the visit's
`serviceDurationBreakdown` that needs the skill. `temporarySkillSets` add
skills for part of a shift.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require skills") %>

The technician lacks a skill the visit needs at its start, or holds it below
`minLevel`.

- **Reads:** `visits[].requiredSkills`, shift `skills`, `temporarySkillSets`.
- **Cost:** one hour per level short; a skill held not at all is short by its
  whole `minLevel`.
- **Example:** a gas boiler needs `gas` at level 2; the technician holds level
  1: 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize scheduling vehicles with unnecessary skill levels") %>

The technician holds a needed skill above its `minLevel`; the expert would be
better used where their level is needed.

- **Reads:** `visits[].requiredSkills`, shift `skills`.
- **Cost:** the visit's service seconds times the levels above.
- **Example:** a 30-minute visit needing level 1, done at level 3: 3,600 soft.
- **Weight:** on.

## Technician coverage area {#group-technician-coverage-area}

Areas are polygons of `[latitude, longitude]` corners, on the vehicle or, to
replace them for one shift, on the shift.

<%= render Workbench::Rule.new(site: site, model: m, name: "No visits outside coverage area") %>

A visit lies outside the technician's `requiredArea`.

- **Reads:** `requiredArea`.
- **Cost:** one hour per visit.
- **Example:** a technician covering Turin only gets a visit in Asti: 3,600
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize scheduling visits outside the preferred area") %>

A visit lies outside the technician's `preferredArea`.

- **Reads:** `preferredArea`.
- **Cost:** one per visit.
- **Example:** two visits outside the preferred district: 2 soft.
- **Weight:** on.

## Technician rating {#group-technician-rating}

<%= render Workbench::Rule.new(site: site, model: m, name: "Maximize technician rating") %>

A visit is served by a rated technician. Longer visits gain more from a
better technician.

- **Reads:** `vehicles[].technicianRating`, the parameter
  `defaultTechnicianRating`.
- **Cost:** none; it rewards the rating times the service seconds.
- **Example:** a 60-minute visit by a technician rated 4.5 earns 16,200 soft.
- **Weight:** off unless weighted.

## Time windows and opening hours {#group-time-windows-and-opening-hours}

A visit's `timeWindows` each give `minStartTime`, an optional `maxStartTime`
and `maxEndTime`. A technician arriving early waits for the window to open.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require service max end time") %>

A visit's service ends after its window's `maxEndTime`.

- **Reads:** `visits[].timeWindows`, the service time.
- **Cost:** the seconds late.
- **Example:** the shop closes at 18:00, the visit ends at 18:20: 1,200 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require service max start time") %>

A visit starts after its window's `maxStartTime`.

- **Reads:** `visits[].timeWindows[].maxStartTime`.
- **Cost:** the seconds late.
- **Example:** must start by 10:00, starts at 10:12: 720 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred visit time window") %>

A visit's service falls outside its `preferredTimeWindows`, such as a
customer who would rather be visited in the morning.

- **Reads:** `visits[].preferredTimeWindows`.
- **Cost:** the seconds of service outside the closest preferred window.
- **Example:** preferred 09:00 to 12:00, served 11:30 to 12:30: 1,800 soft.
- **Weight:** on.

## Visit requirements and tags {#group-visit-requirements-and-tags}

<%= render Workbench::Rule.new(site: site, model: m, name: "Require visit vehicle match required vehicles") %>

A visit is served by a vehicle it does not list in `requiredVehicles`.

- **Reads:** `visits[].requiredVehicles`.
- **Cost:** one hour.
- **Example:** a contract visit for one technician served by another: 3,600
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require visit vehicle not match prohibited vehicles") %>

A visit is served by a vehicle it lists in `prohibitedVehicles`.

- **Reads:** `visits[].prohibitedVehicles`.
- **Cost:** one hour.
- **Example:** a customer who refused one technician gets them: 3,600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prefer visit vehicle match preferred vehicles") %>

A visit is served by a vehicle it prefers: listed in `preferredVehicles`
(weight 1) or in `preferredVehiclesWeights` with its own weight.

- **Reads:** `preferredVehicles`, `preferredVehiclesWeights`.
- **Cost:** none; it rewards the weight times the service seconds.
- **Example:** a 40-minute visit by a vehicle preferred with weight 2 earns
  4,800 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require tags") %>

The shift serving a visit lacks a tag it needs at its start, such as a van
with a ladder rack. `temporaryTagSets` add tags for part of a shift.

- **Reads:** `visits[].requiredTags`, shift `tags`, `temporaryTagSets`.
- **Cost:** one hour per missing tag.
- **Example:** a visit needing `ladder` served by a van without one: 3,600
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require parts in stock") %>

A visit uses parts from its shift's own stock. The shift loads its `stock`
before setting off; its visits use their `parts` in route order. A visit that
finds too few units left is short.

- **Reads:** shift `stock`, `visits[].parts`.
- **Cost:** one hour per unit short.
- **Example:** a van loads 2 filters; its third filter change finds none:
  3,600 hard.
- **Weight:** on. A dataset without `stock` or `parts` never triggers it.

<%= render Workbench::Rule.new(site: site, model: m, name: "Require shared tools free") %>

A visit starts before a shared tool it needs is free. The plan's `tools` say
how many units of each exist; a visit names its `requiredTools`. A tool serves
one visit at a time and is driven from the site that used it last, so the next
visit can start only once its last user has finished and the tool has arrived.

- **Reads:** `tools[]` (`id`, `count`), `visits[].requiredTools`.
- **Cost:** the seconds each visit starts before its tool is there.
- **Example:** the one lift finishes in Turin at 11:00, 40 minutes' drive from
  a visit in Ivrea that starts at 11:15. That costs 1,500 hard.
- **Weight:** on. A dataset without `tools` never triggers it.

## Multi-vehicle visits {#group-multi-vehicle-visits}

A `visitGroups` entry is one job done by several technicians at once, each
serving one of its `visits`. With `alignment: "START"` they all start
together; with `"END"` they all finish together.

<%= render Workbench::Rule.new(site: site, model: m, name: "No semi-assigned visit groups") %>

Some visits of a group are planned and others are not: one technician turns
up for a two-person job.

- **Reads:** `visitGroups[].visits`.
- **Cost:** per unplanned member, its service seconds plus one hour.
- **Example:** one of a pair for a 2-hour lift job is unplanned: 7,200 +
  3,600 = 10,800 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "No loops allowed") %>

A visit cannot be timed because it waits on a visit planned after it, either
directly through a dependency or through a group visit whose partner waits on
it. The solver cannot give it a start.

- **Reads:** `visitDependencies`, `visitGroups`, the order of each route.
- **Cost:** its service seconds plus one hour.
- **Example:** A waits on B, but B comes after A on the same route; a
  30-minute A costs 1,800 + 3,600 = 5,400 hard.
- **Weight:** on.

## Shift hours and overtime {#group-shift-hours-and-overtime}

<%= render Workbench::Rule.new(site: site, model: m, name: "Max last visit departure time (hard)") %>

A shift leaves its last visit after `maxLastVisitDepartureTime`.

- **Reads:** `maxLastVisitDepartureTime`.
- **Cost:** the seconds late.
- **Example:** latest departure 17:30, left at 17:45: 900 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max last visit departure time (soft)") %>

A shift leaves its last visit after `maxSoftLastVisitDepartureTime`.

- **Reads:** `maxSoftLastVisitDepartureTime`.
- **Cost:** the seconds late.
- **Example:** preferred 17:00, left at 17:20: 1,200 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max shift end time (hard)") %>

A shift reaches its end location after `maxEndTime`.

- **Reads:** `maxEndTime`, `endLocation`.
- **Cost:** the seconds late.
- **Example:** must be home by 18:00, home at 18:10: 600 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Max shift end time (soft)") %>

A shift reaches its end location after `maxSoftEndTime`: overtime.

- **Reads:** `maxSoftEndTime`.
- **Cost:** the seconds of overtime.
- **Example:** preferred end 17:30, home at 18:00: 1,800 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Avoid overnight stay in local area") %>

A vehicle's `linkedShifts` join consecutive shifts into one, so the
technician can stay out overnight near distant work instead of driving home. A
night out between two visits that are both within reach of home in a day
wastes that.

- **Reads:** `vehicles[].linkedShifts`, the round trip from home to each visit.
- **Cost:** ten times the weight of the most important mandatory priority in
  the plan, per such night.
- **Example:** with priority 1 in use (weight 10^9), one needless night costs
  10^10 medium.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Excludes shifts") %>

A linked shift and one of the shifts it joins both serve visits. The
technician works either the linked shift or the single days, never both.

- **Reads:** `linkedShifts[].shifts` (`fromShiftId`, `toShiftId`).
- **Cost:** one hour per visit on the component shift.
- **Example:** the Mon-Tue linked shift serves visits and Monday's own shift
  serves 3: 10,800 hard.
- **Weight:** on.

## Technician costs {#group-technician-costs}

<%= render Workbench::Rule.new(site: site, model: m, name: "Minimize shift costs") %>

A shift that serves visits costs money: its `cost.fixedCost`, then its
`rates` one after another from the shift's start. Each rate has an
`activationCost` charged when it starts to apply and a `costPerUnit` per
`MINUTE` or `HOUR`, for its `duration` minutes; the last runs to the shift's
end.

- **Reads:** shift `cost` (`fixedCost`, `rates[]`).
- **Cost:** the shift's cost in cents.
- **Example:** fixed 50, then 30 per hour for 8 hours, then 45 per hour: a
  9-hour shift costs 50 + 240 + 45 = 335.00, 33,500 soft.
- **Weight:** on.

## Fairness {#group-fairness}

<%= render Workbench::Rule.new(site: site, model: m, name: "Balance time utilization") %>

Technicians are used unevenly. Each technician's utilization is the time they
work (service plus driving), plus `historicalTimeUtilized`, over the time they
have, plus `historicalTimeCapacity`. The rule squares each utilization and
sums them; for a fixed total, the sum is least when everyone is equally busy.

- **Reads:** `vehicles[].historicalTimeUtilized`,
  `historicalTimeCapacity`, each shift's working time.
- **Cost:** per technician, the utilization in ten-thousandths squared and
  divided by ten thousand.
- **Example:** two technicians at 90% and 50% cost 8,100 + 2,500 = 10,600; at
  70% each they cost 9,800.
- **Weight:** on.
