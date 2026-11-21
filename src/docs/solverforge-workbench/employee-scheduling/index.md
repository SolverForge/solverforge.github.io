---
title: "Employee scheduling"
linkTitle: "Employee scheduling"
description: >
  Gives every shift to an employee, or leaves it open, under skills,
  availability, contracts, rest, rotations, demand, cost and fairness.
---

## What it decides

A dataset lists **shifts**, each with a start, an end and what it needs, and
**employees**. The solver decides one thing per shift: who works it, or that
nobody does. The shifts themselves never move: their times, breaks and tags
are given. Shifts before the schedule's `start` or after its `end` are history
or context; they count toward rules (a week's hours, rest after a night) but
are never reassigned. A shift with `pinned: true` keeps its employee.

## What a dataset describes

- **Employees** with skills (and levels, valid between dates), contracts,
  tags, a priority, a home location, availability (unavailable spans,
  available-only spans, requested days off) and preferences: preferred and
  unwanted times, the shifts they may or like to work, colleagues to work with
  or apart from.
- **Shifts** with start, end and breaks, required and preferred skills, tags,
  risk factors, a location, preferred, unwanted or barred employees, an
  importance, and whether the shift is optional or one version of an
  alternative.
- **Contracts**, each a list of **rules**: a kind (minutes worked, days in a
  row, rest between shifts, a rotation...), a level (`required` or
  `preferred`), a weight, the shifts it counts (by tags) and its limits per
  period or rolling window.
- **The calendar**: the schedule's start and end, the first day of the week,
  the weekend days and named periods (a fortnight, a pay month).
- **Schedule rules** over everyone at once: staff wanted per time slot
  (**demand**), shift counts, distinct tags, how many may work at once, cost
  budgets and fairness; plus **teams**, **cost groups** and **alternatives**.

Every table and field is on the [data page](data/).

## When a schedule is feasible

A schedule is feasible when every hard rule holds:

- each employee holds the skills a shift requires, at its start, and is not
  exposed to a risk they must avoid;
- nobody works while unavailable, outside their available-only hours, a shift
  that bars them, or a kind of shift they may not work;
- no employee works two overlapping shifts;
- every `required` contract and schedule rule holds: hours, days, rest,
  runs, rotations, patterns, travel, budgets;
- partners who must work together do, those who must not don't, and teams
  keep their leads and tags.

## What it optimises

A **mandatory** shift left open costs its importance at the medium level, and
so does every person missing from (or extra in) a **required** demand slot.
Medium counts only once every hard rule holds: the solver staffs as much as
it can without breaking one.

The soft level then weighs everything preferred: open optional shifts,
preferred skills, preferred and unwanted times and colleagues, `preferred`
contract rules, travel, pay and activation costs, fairness, and changes to a
published roster. An employee's `priority` multiplies their soft preferences
and their contract rules, so a senior's wishes can weigh more.

## Contract rules in practice

Most real constraints are contract rules. A full-time nurse might work under:

```json
{"id": "full-time", "rules": [
  {"kind": "minutesWorked", "level": "required", "period": "week", "max": 2880},
  {"kind": "minutesWorked", "level": "preferred", "period": "week", "min": 2280, "max": 2280},
  {"kind": "restBetween", "level": "required", "min": 660},
  {"kind": "consecutiveDaysWorked", "level": "required", "max": 6},
  {"kind": "weekendsWorked", "level": "preferred", "period": "month", "max": 2},
  {"kind": "dailyPairing", "stance": "barred", "withTags": ["night"],
   "paired": {"withTags": ["early"]}, "dayOffset": 1}
]}
```

Hard caps on hours, rest and days in a row, a preferred target of 38 hours a
week, at most two weekends a month, and never an early the morning after a
night.

## Breaks and demand

Breaks are not worked time and do not cover demand. A break is fixed (its
`from` and `to`) or floating: with `minutes` shorter than its window, it lasts
that long somewhere inside it, placed in 15-minute steps where it leaves the
fewest required slots short, then the fewest preferred ones. A ward that needs
two nurses from 10:00 to 12:00 gets its nurses' breaks after noon when their
windows allow it.

## Replanning

A shift with a `published` employee is part of the roster people have seen.
The replanning rules count every change to it, so a replan after a sick call
moves as few shifts as it can, and `disruption` contract rules can require
that anyone who loses a shift gets a close one back.

## The demo

**A month of shifts** (`LARGE_MONTH`) is a hospital with three wards on two
sites: 50 employees and 536 shifts from 28 February to 29 March 2027, under
three contracts, using every feature of the model. It is written in the
dataset format itself, so it doubles as a worked example of every field.

## Constraints

<%= render Workbench::Groups.new(site: site, model: "employee-scheduling") %>

Each rule is explained, with the fields it reads, what it costs and an
example, on the [constraints page](constraints/).
