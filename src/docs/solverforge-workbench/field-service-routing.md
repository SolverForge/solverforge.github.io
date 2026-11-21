---
title: "Field service routing"
linkTitle: "Field service routing"
description: >
  Visits to technician shifts and their order: skills and levels, time windows and SLAs, breaks, dependencies, joint visits, coverage areas, parts, shared tools and shift limits, on real roads.
---

Field service routing puts each visit on a technician's shift, in an order.
The solver chooses who serves each visit and the route; arrival and start
times follow from travel along the roads, opening hours, breaks and the visits
a visit depends on. A plan is feasible when every visit is served by a
technician with the skills and tags it needs, inside its window and coverage
area, with the parts and tools it needs, and every shift keeps its hours.

## What a dataset describes

- **Technicians** (vehicles) with a rating, skills with levels, tags, coverage
  areas, a travel mode, and their **shifts**: start and end locations, hours,
  breaks, limits on travel, service and visits, costs, the parts the van loads
  and an optional driving rest. **Overnight trips** link shifts on consecutive
  days into one trip away from home.
- **Visits** with a location, service time (and its parts per skill), time
  windows and opening hours, an SLA, a priority (`1` to `10` mandatory,
  `opt-1` to `opt-10` optional), required skills and tags, required,
  preferred or prohibited technicians, dependencies on other visits, exclusions, profit,
  the parts it uses up and the shared tools it needs.
- **Joint visits**: a group of visits served at the same time by several
  technicians.
- **Shared tools**: equipment technicians share, such as a lift or a test rig,
  with the number of units the plan owns.
- **Busy periods**: hours of the week when chosen roads are slower.

## Parts and shared tools

A shift loads its `stock` before it sets off, and each visit takes the parts
it needs in route order; a visit that finds them gone costs one hour per unit
short. A shared tool serves one visit at a time and is carried from the site
that used it last, so a visit that needs it waits until it is free and brought
over; the wait costs its seconds.

## Travel

Travel times and distances come from the OpenStreetMap road network, measured
for each dataset. A technician on a bicycle or on foot travels that mode's own
paths at its own speed and is not slowed by busy periods. With a driving rest
on the shift, the technician stops for the set time each time the driving
since the last rest passes the limit; a break or a wait at least as long counts
as the rest.

## Multi-day plans

A movable visit, one whose windows span several days, should be served on
the first day a technician who may serve it works; every day later costs. A linked overnight
trip plans its days as one route.

<%= render Workbench::Model.new(site: site, id: "field-service-routing") %>
