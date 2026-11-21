---
title: "Pick-up and delivery routing"
linkTitle: "Pick-up and delivery routing"
description: >
  Multi-stop jobs to driver shifts and their order: stop order, vehicle capacity, parts in stock, skills, breaks, time windows, priorities and shift limits, on real roads.
---

Pick-up and delivery routing puts each job's stops on a driver's shift, in an
order. A job is a sequence of stops, usually a pick-up and a drop-off, served
in that order by one vehicle. The solver chooses which shift serves each job
and the route; arrival times follow from travel along the roads. A plan is
feasible when every stop keeps its order, its time window and its job's
requirements, no vehicle carries more than its capacity, and every shift keeps
its hours.

## What a dataset describes

- **Drivers** and their **shifts**: start and end locations, working hours,
  capacities per load type, skills and tags, breaks, the parts the van loads,
  how the driver travels (car, bicycle or on foot) and an optional driving rest.
- **Jobs** with a priority (`1` to `10` mandatory, `opt-1` to `opt-10`
  optional, each level ten times the weight of the next), required skills and
  tags, required, preferred or prohibited drivers, and pooling rules.
- **Stops** with a location, service time, time windows, an SLA, the load
  picked up or dropped, and the parts the stop uses up from the van's stock.
- **Busy periods**: hours of the week when chosen roads are slower.

## Travel

Travel times and distances come from the OpenStreetMap road network, measured
for each dataset. A driver on a bicycle or on foot travels that mode's own
paths at its own speed and is not slowed by busy periods. With a driving rest
on the shift, the driver stops for the set time each time the driving since
the last rest passes the limit; the rest delays arrival but is not travel.

## Fleet size and fairness

Two soft rules, off unless weighted, shape the fleet: **Driver used** costs an
hour for every driver who serves any stop, so weighting it serves the jobs
with fewer drivers; **Work unbalanced between drivers** costs the square of
each driver's working minutes, so weighting it spreads the work evenly.

<%= render Workbench::Model.new(site: site, id: "pickup-delivery-routing") %>
