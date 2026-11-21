---
title: "Employee scheduling"
linkTitle: "Employee scheduling"
description: >
  Shifts to employees under skills, availability, contract limits, rest, rotations, hourly demand, cost and fairness.
---

Employee scheduling assigns each shift to an employee, or leaves it open. The
shifts are given, with their start, end, skills and tags; the solver chooses who
works them. A roster is feasible when every hard rule holds: the employee has the
skills, is available, stays inside the contract and gets the rest it requires.

## What a dataset describes

- **Employees** with skills (and levels), contracts, tags, home location,
  availability (unavailable spans, available-only spans, days off) and
  preferences: preferred and unwanted times, required and preferred shifts,
  colleagues to pair with or keep apart.
- **Shifts** with start, end and breaks, required and preferred skills, tags,
  risks, a location, preferred, unwanted or barred employees, and whether the
  shift is optional or an alternative of another.
- **Contracts**, each a list of **rules**. A rule has a kind (minutes or
  days worked, weekends, days or shifts in a row, days off, rest between
  shifts, start-time spread, split shifts, patterns within a day or over days,
  rotations, travel, locations, cost, changes to a published roster), a level
  (required or preferred), a weight, the shifts it counts (by tags) and its
  limits over a period or a rolling window.
- **The calendar**: the schedule's start and end, the first day of the week,
  which days are weekend, and named periods (a fortnight, a month) that rules
  count over.
- **Schedule rules** for the whole roster: hourly **demand** (staff needed per
  time slot, required or preferred), shift counts, distinct tags, how many may
  work at the same time, cost limits and fairness, plus **teams**, **cost
  groups** and **alternative shifts**.

## Breaks and demand

An employee on a break does not cover demand. A break is either fixed (its
`from` and `to`) or floating: with `minutes` shorter than its window, the break
lasts that long somewhere inside the window, placed in 15-minute steps where it
leaves the fewest required slots short, then the fewest preferred ones. A ward
that needs two nurses from 10:00 to 12:00 gets its nurses' breaks after noon
when their windows allow it.

## Replanning

A shift with a `published` employee is part of the roster people have seen.
The replanning rules count every change to it, so a replan after a sick call
moves as few shifts as it can; pinned shifts never move.

<%= render Workbench::Model.new(site: site, id: "employee-scheduling") %>
