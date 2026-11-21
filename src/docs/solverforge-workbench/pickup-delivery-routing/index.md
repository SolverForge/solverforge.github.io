---
title: "Pick-up and delivery routing"
linkTitle: "Pick-up and delivery routing"
description: >
  Puts every job's stops on a driver's shift and orders each route, so
  everything is picked up and delivered in time, on real roads, with few hours
  driven.
---

## What it decides

A dataset lists **jobs** and **drivers** with their **shifts**. A job is a
sequence of stops, usually a pick-up and a drop-off, served in that order by
one shift: a patient taken from home to a hospital, a lab sample from a clinic
to a lab. The solver decides which shift serves each job and the order of
every shift's stops and breaks. It can leave a job out when it does not fit.

Times follow from the route. A driver leaves just in time for the first stop,
drives along the roads at each road's speed (slower in busy periods), waits
when a stop's window has not opened, serves the stop and drives on. Each job
on board rides until its drop-off, so jobs share the vehicle as long as
capacity, pooling rules and ride-time limits allow.

## What a dataset describes

- **Drivers** with a travel mode (car, bicycle or on foot) and their
  **shifts**: start and end locations, earliest start and latest end (hard
  and preferred), capacities per kind (seats, wheelchair places, parcels),
  skills with levels, tags, breaks, the parts the van loads and a driving
  rest.
- **Jobs** with a priority, required skills and tags, required, preferred or
  prohibited drivers, demands, whether they may pool with other jobs and for
  how long, and whether breaks may happen while they are on board.
- **Stops** with a location, service minutes, time windows, an SLA, the load
  picked up or dropped, and the parts the stop uses from the van.
- **Busy periods** (`traffic`): hours of the week when chosen roads are
  slower.

Every table and field is on the [data page](data/).

## When a plan is feasible

A plan is feasible when every hard rule holds:

- each job is planned whole, on one shift, its stops in order, and nobody
  rides past their own destination;
- no vehicle carries more of a kind than it has room for;
- each stop is served inside its time window by a driver the job allows,
  with the skills, tags and parts it needs;
- jobs that must ride alone, or apart, do, and pooling never stretches a ride
  past its limit;
- breaks happen on time, and only with jobs on board that allow it;
- every shift keeps its latest departure and end, and every leg has a road.

## What it optimises

A **mandatory** job left out costs its priority's weight at the medium level,
per stop. Priorities `1` to `10` weigh 1,000,000,000 down to 1, each ten times
the next, so a priority-1 job outweighs any number of priority-2 jobs. Medium
counts only once every hard rule holds: the solver plans as much as it can
without breaking one.

The soft level weighs driving time, optional jobs, SLAs, overtime, preferred
drivers, overqualified drivers and stops later than their earliest day. Three
soft rules start off and change the plan's shape once weighted: **Waiting
time**, **Driver used** (fewer drivers, each doing more) and **Work unbalanced
between drivers** (work shared evenly).

## Travel

Travel times and distances come from the OpenStreetMap road network, measured
for each dataset's area. A driver on a bicycle or on foot travels that mode's
own paths at its own speed and is not slowed by busy periods. With a
`drivingRest`, the driver stops for the set time once driving since the last
rest passes the limit; a break or a wait at least as long counts as the rest.
A dataset may bring its own travel matrix instead.

## The demo

**Milan, two days** (`MILAN_TWO_DAYS`) is a transport cooperative over two
weekdays: patient transport to and from hospitals, and a medical courier
service between labs, pharmacies and clinics, on one shared fleet. 15 drivers
on 30 shifts serve 155 jobs, each a pick-up and a drop-off.

## Constraints

<%= render Workbench::Groups.new(site: site, model: "pickup-delivery-routing") %>

Each rule is explained, with the fields it reads, what it costs and an
example, on the [constraints page](constraints/).
