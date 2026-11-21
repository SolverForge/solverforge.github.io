---
title: "Field service routing"
linkTitle: "Field service routing"
description: >
  Puts every visit on a technician's shift and orders each route, so the right
  technician arrives in time with the parts and tools the job needs, on real
  roads.
---

## What it decides

A dataset lists **visits** and **vehicles**, each a technician with their van
and their **shifts**. The solver decides which shift serves each visit and the
order of every shift's visits and breaks. It can leave a visit out when it does
not fit.

Times follow from the route. A technician leaves just in time for the first
visit, drives along the roads (slower in busy periods), waits for the visit's
window, for the visits it depends on and for any shared tool it needs, then
serves it. Service time depends on who serves: a skill's multiplier speeds up
or slows down the part of the job that needs it.

## What a dataset describes

- **Vehicles** with a technician rating, a travel mode, coverage areas and
  their **shifts**: start and end locations, hours (hard and preferred),
  skills with levels and multipliers, tags, breaks, limits on travel, service
  and visits, a cost, the parts the van loads and a driving rest. **Linked
  shifts** join consecutive days into one trip that stays out overnight.
- **Visits** with a location, service minutes (with a part per skill), time
  windows and preferred windows, an SLA, a priority, required skills and tags,
  required, preferred or prohibited vehicles, dependencies on other visits,
  exclusions, a profit, the parts it uses and the shared tools it needs.
- **Visit groups**: one job done by several technicians at once, starting or
  ending together.
- **Tools**: equipment technicians share, such as a lift, and how many the
  plan owns.
- **Busy periods** (`traffic`): hours of the week when chosen roads are
  slower.

Every table and field is on the [data page](data/).

## When a plan is feasible

A plan is feasible when every hard rule holds:

- each visit is served inside its window, by a vehicle it allows, inside the
  technician's coverage area, with the skills, tags, parts and tools it needs;
- dependent visits keep their delays, vehicle or shift and pooling type, and
  are planned together or not at all;
- group visits are planned whole, and no visit waits on one after it;
- breaks happen on time;
- every shift keeps its latest departure and end and its hard limits on
  travel, service and visits, and every leg has a road.

## What it optimises

A **mandatory** visit left out costs its priority's weight at the medium
level: priorities `1` to `10` weigh 1,000,000,000 down to 1, each ten times
the next. Medium counts only once every hard rule holds: the solver plans as
much as it can without breaking one.

The soft level weighs driving time, optional visits, SLAs, overtime and soft
limits, preferred windows, vehicles and areas, overqualified technicians,
visits pushed to later days, shift costs against visit profits, and fairness.
Several soft rules start off and change the plan's shape once weighted:
waiting, travel distance, co-located and consecutive grouping, moving towards
home, technician rating, disruption and the SLA tie-breakers.

## Multi-day plans

A **movable** visit, one whose windows span several days or reach past the
planning window, should be served on the first day it can be; every day later
costs. A shift's movable work is capped by its
`movableOccupationRatioThreshold`, so movable visits never crowd out work due
today. A linked shift plans its days as one route and keeps the technician out
only when the work is too far to reach from home in a day.

## Parts and shared tools

A shift loads its `stock` before it sets off, and each visit takes the parts
it needs in route order. A shared tool serves one visit at a time and is
carried from the site that used it last, so a visit that needs it starts once
it is free and brought over.

## Travel

Travel times and distances come from the OpenStreetMap road network, measured
for each dataset's area, then scaled by the shift's `travelTimeAdjustment`. A
technician on a bicycle or on foot travels that mode's own paths at its own
speed and is not slowed by busy periods. With a `drivingRest`, the technician
stops for the set time once driving since the last rest passes the limit; a
break or a wait at least as long counts as the rest.

## The demo

**Turin, two days** (`TURIN_TWO_DAYS`): 30 technicians on 60 shifts and 223
visits around Turin and Aosta, with linked visits, lunch breaks and a two-day
lift job in the Aosta valley.

## Constraints

<%= render Workbench::Groups.new(site: site, model: "field-service-routing") %>

Each rule is explained, with the fields it reads, what it costs and an
example, on the [constraints page](constraints/).
