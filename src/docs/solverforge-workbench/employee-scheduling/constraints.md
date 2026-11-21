---
title: "Employee scheduling constraints"
linkTitle: "Constraints"
description: >
  The 127 rules that score an employee schedule: what each one checks, which
  fields it reads, what one violation costs, and an example.
---

<% m = "employee-scheduling" %>

Every rule below scores one schedule. Click a rule to read it. Field names are
the dataset's JSON names, documented on the [data page](../data/).

Most rules fire only when the dataset asks for them. A **contract** is a list
of `rules`, each with a `kind` (`minutesWorked`, `restBetween`...), a `level`
(`required` scores hard, `preferred` soft), a `weight` (1 when unset), a
window (`period`: `day`, `week`, `month`, `year`, `schedule` or a custom period;
or `rollingDays`, every run of that many days), `min` and `max`, and the shifts
it counts (`withTags`, `withoutTags`, `matchAll`). An employee works under the
contracts listed in `contracts`. A contract rule's cost is multiplied by its
`weight` and by the employee's `priority`. **Schedule rules**
(`scheduleRules`) look at every employee at once. A profile **weight**
multiplies a rule's cost again: 1 as designed, 0 off.

<%= render Workbench::RulesToolbar.new(site: site, model: m) %>

## Staffing {#group-staffing}

<%= render Workbench::Rule.new(site: site, model: m, name: "Mandatory shift left open") %>

A shift inside the schedule (`schedule.start` to `schedule.end`) has no
employee. Mandatory shifts weigh at the medium level, so the solver fills as
many as it can without breaking a hard rule. Shifts of an alternatives group
are left to that group's count instead.

- **Reads:** `shifts[].employee`, `optional`, `importance` (1 when unset).
- **Cost:** the shift's `importance`.
- **Example:** two open night shifts with importance 3 cost 6 medium.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Optional shift left open") %>

A shift with `optional: true` has no employee. It is filled when filling it
costs less than it earns.

- **Reads:** `shifts[].optional`, `importance`.
- **Cost:** the shift's `importance`.
- **Example:** an optional on-call shift with importance 5 left open costs 5
  soft.
- **Weight:** on.

## Skills and risk {#group-skills-and-risk}

An employee's `skills` are ids, or `{id, level, from, to}` for a level and
the dates it is valid. A shift's `requiredSkills` and `preferredSkills` ask for
an id and optionally a least `level`. A skill counts when it is held at the
shift's start.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required skill lacking") %>

The employee lacks a skill the shift requires, or holds it below the level or
outside its dates. With `anyRequiredSkill`, one of the listed skills is enough.

- **Reads:** `shifts[].requiredSkills`, `anyRequiredSkill`,
  `employees[].skills`.
- **Cost:** one per missing skill; with `anyRequiredSkill`, one when none is
  held.
- **Example:** a shift needs `icu` and `triage`; the nurse holds only `icu`:
  1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred skill lacking") %>

The employee lacks a skill the shift would like.

- **Reads:** `shifts[].preferredSkills`, `employees[].skills`.
- **Cost:** one per missing skill, times the employee's priority.
- **Example:** a shift prefers `mentor`; an employee with priority 2 without it
  costs 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Prohibited risk exposure") %>

The shift exposes the employee to a risk factor they must avoid, such as
radiation during a pregnancy.

- **Reads:** `shifts[].risks`, `employees[].avoidRisks`.
- **Cost:** one per risk hit.
- **Example:** a shift with `radiation` given to an employee avoiding it: 1
  hard.
- **Weight:** on.

## Availability {#group-availability}

Time spans are `{from, to}`, optionally limited to some shifts by tags, with a
`weight` (1 when unset) for preferences.

<%= render Workbench::Rule.new(site: site, model: m, name: "Works while unavailable") %>

Part of a shift falls in a time the employee cannot work.

- **Reads:** `employees[].unavailable`.
- **Cost:** the minutes of overlap.
- **Example:** unavailable from 14:00, assigned 08:00 to 16:00: 120 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Works outside available hours") %>

When an employee lists `availableOnly` spans that apply to a shift, the shift
must lie inside them.

- **Reads:** `employees[].availableOnly`.
- **Cost:** the minutes of the shift outside those spans.
- **Example:** available only 09:00 to 13:00, assigned 08:00 to 14:00: 120
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Works in preferred hours") %>

A shift falls in a time the employee would like to work. This is a reward.

- **Reads:** `employees[].preferredTimes` and their `weight`.
- **Cost:** none; it rewards the minutes inside, times the span's weight and
  the employee's priority.
- **Example:** a 4-hour overlap with a weight-2 preference earns 480 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Works in unwanted hours") %>

A shift falls in a time the employee would rather not work.

- **Reads:** `employees[].unwantedTimes` and their `weight`.
- **Cost:** the minutes inside, times the span's weight and the employee's
  priority.
- **Example:** 90 minutes of a shift on an unwanted Friday evening: 90 soft.
- **Weight:** on.

## Shift assignment {#group-shift-assignment}

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred employee on shift") %>

A shift goes to an employee it lists in `preferredEmployees`. This is a
reward.

- **Reads:** `shifts[].preferredEmployees`.
- **Cost:** none; it rewards the employee's priority.
- **Example:** a home visit given to the patient's usual carer earns 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Unwanted employee on shift") %>

A shift goes to an employee it lists in `unwantedEmployees`.

- **Reads:** `shifts[].unwantedEmployees`.
- **Cost:** the employee's priority.
- **Example:** a shift that would rather not have Marco goes to him; his priority is 1: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Barred employee on shift") %>

A shift goes to an employee it lists in `barredEmployees`.

- **Reads:** `shifts[].barredEmployees`.
- **Cost:** one per shift.
- **Example:** a patient's home visit, which bars a carer they complained about, goes to that carer: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Concurrent shifts over limit") %>

More matching shifts run at the same moment than a `scheduleRules.concurrency`
rule allows, optionally only between its `from` and `to`. It is checked at the
start of each matching shift.

- **Reads:** `scheduleRules.concurrency[]` (`max`, tags, `from`, `to`).
- **Cost:** the shifts over the limit, at each matching shift's start.
- **Example:** at most 2 people on leave-cover at once; a third starts at
  09:00 while two run: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift count per period outside required range") %>

The assigned matching shifts across all employees in a period fall outside a
required `scheduleRules.shiftCounts` range, optionally counting only some
employees.

- **Reads:** `scheduleRules.shiftCounts[]` (`period`, `min`, `max`, tags,
  `employees`).
- **Cost:** the distance outside the range, times the rule's weight.
- **Example:** at least 14 night shifts a week are staffed, 12 are: 2 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift count per period outside preferred range") %>

The assigned matching shifts across all employees in a period fall outside a preferred `scheduleRules.shiftCounts` range (`level: "preferred"`), optionally counting only some employees. Use it for targets the plan should approach rather than must meet.

- **Reads:** `scheduleRules.shiftCounts[]`.
- **Cost:** the distance outside the range, times the rule's weight.
- **Example:** at most 3 agency shifts a week preferred, 5 worked: 2 soft.
- **Weight:** on.

## Shift variety {#group-shift-variety}

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift outside employee's required tags") %>

An employee with `requiredShifts` (a tag filter) is given a shift it does not
accept, such as a day-only employee on a night shift.

- **Reads:** `employees[].requiredShifts`, `shifts[].tags`.
- **Cost:** one per shift.
- **Example:** an employee whose `requiredShifts` accepts only `day` shifts gets a `night`: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift has employee's preferred tags") %>

A shift matches the employee's `preferredShifts`. This is a reward.

- **Reads:** `employees[].preferredShifts`, `shifts[].tags`.
- **Cost:** none; it rewards the employee's priority per shift.
- **Example:** three preferred early shifts earn 3 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift types per period outside required range") %>

A `shiftTypes` contract rule names `categories` (tags). Per category, the
employee's shifts of it in a period must stay in range.

- **Reads:** contract rules `{"kind": "shiftTypes", "categories": [...]}`.
- **Cost:** the distance outside the range per category, times weight and
  priority.
- **Example:** at most 4 `night` shifts a month, 6 worked: 2 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Shift types per period outside preferred range") %>

A preferred `shiftTypes` contract rule: per category tag in `categories`, the employee's shifts of that category in a period should stay in range, such as a fair share of nights.

- **Reads:** `shiftTypes` contract rules.
- **Cost:** the distance per category, times weight and priority.
- **Example:** at least 2 `weekend` shifts a month preferred, none worked: 2
  soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Distinct tags per period for employee outside required range") %>

A `distinctTags` contract rule counts the distinct tags of some types (from the
plan's `tags` list, each with a `type`) on an employee's shifts in a period.

- **Reads:** contract rules `{"kind": "distinctTags", "tagTypes": [...]}`,
  `tags[].type`.
- **Cost:** the distance outside the range, times weight and priority.
- **Example:** at most 2 wards a week (type `ward`), 3 worked: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Distinct tags per period for employee outside preferred range") %>

A preferred `distinctTags` contract rule: the distinct tags of the given types on an employee's shifts in a period should stay in range, such as working on as few wards as possible.

- **Reads:** `distinctTags` contract rules, `tags[].type`.
- **Cost:** the distance outside the range, times weight and priority.
- **Example:** one ward a week preferred, 2 worked: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Distinct tags per period across schedule outside required range") %>

A `scheduleRules.distinctTags` rule counts the distinct tags of some types on
all assigned matching shifts in a period.

- **Reads:** `scheduleRules.distinctTags[]` (`period`, `tagTypes`, `min`,
  `max`).
- **Cost:** the distance outside the range, times the rule's weight.
- **Example:** at least 3 sites staffed every day, 2 are: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Distinct tags per period across schedule outside preferred range") %>

A preferred `scheduleRules.distinctTags` rule: the distinct tags of the given types on all assigned matching shifts in a period should stay in range.

- **Reads:** `scheduleRules.distinctTags[]`.
- **Cost:** the distance outside the range, times the rule's weight.
- **Example:** at most 4 wards open on a Sunday preferred; the staffed shifts cover 5: 1 soft.
- **Weight:** on.

## Travel and locations {#group-travel-and-locations}

An employee's `home` and a shift's `location` are `{lat, lon}`. Distances are
straight lines between them.

<%= render Workbench::Rule.new(site: site, model: m, name: "Travel distance over limit") %>

A shift lies farther from the employee's home than a `travel` contract rule's
`maxMeters` allows.

- **Reads:** contract rules `{"kind": "travel", "maxMeters": ...}`, `home`,
  `location`.
- **Cost:** the kilometres beyond the limit, rounded up.
- **Example:** at most 30 km, a shift 34.2 km away: 5 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Travel distance") %>

The distance from each employee's home to their shift, to keep travel short.

- **Reads:** `employees[].home`, `shifts[].location`.
- **Cost:** the kilometres, rounded, times the employee's priority.
- **Example:** a shift 12 km from home costs 12 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Too little time to change location") %>

Two successive shifts at different locations leave less time between them
than a `travel` rule's `minChangeMinutes` for the later shift.

- **Reads:** `travel` contract rules' `minChangeMinutes`, `location`.
- **Cost:** the minutes missing.
- **Example:** 45 minutes needed between sites, 20 given: 25 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Locations per period outside required range") %>

A `locationsWorked` contract rule counts the distinct locations of an
employee's shifts in a period.

- **Reads:** contract rules `{"kind": "locationsWorked"}`.
- **Cost:** the distance outside the range, times weight and priority.
- **Example:** at most 2 sites a week, 3 worked: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Locations per period outside preferred range") %>

A preferred `locationsWorked` contract rule: the distinct locations of an employee's shifts in a period should stay in range.

- **Reads:** `locationsWorked` contract rules.
- **Cost:** the distance outside the range, times weight and priority.
- **Example:** one site a day preferred, 2 worked: 1 soft.
- **Weight:** on.

## Work limits {#group-work-limits}

These are window rules: per period, or per rolling window of `rollingDays`
days, a measure of the employee's matching shifts must stay within `min` and
`max`. A shift counts in the window it starts in, or only when wholly inside
it with `wholeShift`. The cost is the distance outside the range, times the
rule's weight and the employee's priority.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minutes per period outside required range") %>

Minutes worked in a period: shift length minus breaks.

- **Reads:** `{"kind": "minutesWorked", "period": ...}`, `shifts[].breaks`.
- **Cost:** the minutes outside the range, times weight and priority.
- **Example:** at most 2,400 minutes a week, 2,520 worked: 120 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minutes per period outside preferred range") %>

The same with `level: "preferred"`, such as contracted hours someone should
reach.

- **Reads:** `minutesWorked` rules with a `period`.
- **Cost:** the minutes outside the range, times weight and priority.
- **Example:** at least 1,800 minutes a week preferred, 1,440 worked: 360
  soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minutes in rolling window outside required range") %>

Minutes worked in every run of `rollingDays` days.

- **Reads:** `{"kind": "minutesWorked", "rollingDays": ...}`.
- **Cost:** per window, the minutes outside the range, times weight and
  priority.
- **Example:** at most 3,000 minutes in any 7 days; two overlapping windows
  each 60 over: 120 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Minutes in rolling window outside preferred range") %>

A preferred `minutesWorked` rule with `rollingDays`: the minutes worked in every run of that many days should stay in range.

- **Reads:** `minutesWorked` rules with `rollingDays`.
- **Cost:** per window, the minutes outside, times weight and priority.
- **Example:** at most 2,700 minutes in any 7 days preferred; one window holds 2,730: 30 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Logged minutes per period outside required range") %>

Logged minutes in a period: each shift's `loggedMinutes` (its worked minutes
when unset) plus the minutes logged before the data in `loggedBefore`.

- **Reads:** `{"kind": "minutesLogged"}`, `shifts[].loggedMinutes`,
  `employees[].loggedBefore`.
- **Cost:** the minutes outside the range, times weight and priority.
- **Example:** at most 9,600 minutes a month; 4,000 logged before the data
  plus 5,700 planned: 100 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Logged minutes per period outside preferred range") %>

A preferred `minutesLogged` rule: the minutes logged in a period, each shift's `loggedMinutes` plus the minutes in `loggedBefore`, should stay in range.

- **Reads:** `minutesLogged` rules.
- **Cost:** the minutes outside, times weight and priority.
- **Example:** at most 9,000 logged minutes a month preferred; 3,000 logged before the data plus 6,100 planned: 100 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Days worked per period outside required range") %>

Days with at least one matching shift starting, per period.

- **Reads:** `{"kind": "daysWorked", "period": ...}`.
- **Cost:** the days outside the range, times weight and priority.
- **Example:** at most 5 days a week, 6 worked: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Days worked per period outside preferred range") %>

A preferred `daysWorked` rule with a `period`: the days with a matching shift starting should stay in range.

- **Reads:** `daysWorked` rules with a `period`.
- **Cost:** the days outside, times weight and priority.
- **Example:** 4 days a week preferred, 5 worked: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Days worked in rolling window outside required range") %>

Days worked in every run of `rollingDays` days.

- **Reads:** `{"kind": "daysWorked", "rollingDays": ...}`.
- **Cost:** per window, the days outside, times weight and priority.
- **Example:** at most 12 days in any 14: one window with 13 costs 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Days worked in rolling window outside preferred range") %>

A preferred `daysWorked` rule with `rollingDays`: the days worked in every run of that many days should stay in range.

- **Reads:** `daysWorked` rules with `rollingDays`.
- **Cost:** per window, the days outside, times weight and priority.
- **Example:** at most 10 days in any 14 preferred; two windows hold 11: 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Employee shifts per period outside required range") %>

The employee's matching shifts per period.

- **Reads:** `{"kind": "shiftsWorked", "period": ...}`.
- **Cost:** the shifts outside the range, times weight and priority.
- **Example:** at most 3 night shifts a week, 4 worked: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Employee shifts per period outside preferred range") %>

A preferred `shiftsWorked` rule with a `period`: the employee's matching shifts per period should stay in range.

- **Reads:** `shiftsWorked` rules with a `period`.
- **Cost:** the shifts outside, times weight and priority.
- **Example:** at least 8 shifts a month preferred, 6 worked: 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Employee shifts in rolling window outside required range") %>

Matching shifts in every run of `rollingDays` days.

- **Reads:** `{"kind": "shiftsWorked", "rollingDays": ...}`.
- **Cost:** per window, the shifts outside, times weight and priority.
- **Example:** at most 4 nights in any 7 days; one window with 5: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Employee shifts in rolling window outside preferred range") %>

A preferred `shiftsWorked` rule with `rollingDays`: the matching shifts in every run of that many days should stay in range.

- **Reads:** `shiftsWorked` rules with `rollingDays`.
- **Cost:** per window, the shifts outside, times weight and priority.
- **Example:** at most 3 nights in any 7 days preferred; one window holds 4: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Weekends worked per period outside required range") %>

Weekends with a matching shift starting on a weekend day, per period. The
weekend is `schedule.weekend`, Saturday and Sunday unless set.

- **Reads:** `{"kind": "weekendsWorked", "period": ...}`, `schedule.weekend`.
- **Cost:** the weekends outside the range, times weight and priority.
- **Example:** at most 2 weekends a month, 3 worked: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Weekends worked per period outside preferred range") %>

A preferred `weekendsWorked` rule with a `period`: the weekends with a matching shift starting on a weekend day should stay in range.

- **Reads:** `weekendsWorked` rules with a `period`.
- **Cost:** the weekends outside, times weight and priority.
- **Example:** at most 1 weekend a month preferred, 2 worked: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Weekends worked in rolling window outside required range") %>

Weekends worked in every run of `rollingDays` days.

- **Reads:** `{"kind": "weekendsWorked", "rollingDays": ...}`.
- **Cost:** per window, the weekends outside, times weight and priority.
- **Example:** at most 2 weekends in any 21 days; a window with 3: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Weekends worked in rolling window outside preferred range") %>

A preferred `weekendsWorked` rule with `rollingDays`: the weekends worked in every run of that many days should stay in range.

- **Reads:** `weekendsWorked` rules with `rollingDays`.
- **Cost:** per window, the weekends outside, times weight and priority.
- **Example:** at most 1 weekend in any 14 days preferred; one window holds 2: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Weekend minutes per period outside required range") %>

Minutes worked on weekend days, per period.

- **Reads:** `{"kind": "weekendMinutes"}`, `schedule.weekend`.
- **Cost:** the minutes outside the range, times weight and priority.
- **Example:** at most 960 weekend minutes a month, 1,200 worked: 240 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Weekend minutes per period outside preferred range") %>

A preferred `weekendMinutes` rule: the minutes worked on weekend days in a period should stay in range.

- **Reads:** `weekendMinutes` rules.
- **Cost:** the minutes outside, times weight and priority.
- **Example:** at most 720 weekend minutes a month preferred, 960 worked: 240 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive weekends worked outside required range") %>

Each run of weekends worked one after another, inside a period, must stay in
range.

- **Reads:** `{"kind": "consecutiveWeekendsWorked", "period": ...}`.
- **Cost:** per run, its distance outside the range, times weight and
  priority.
- **Example:** at most 2 weekends in a row; a run of 3: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive weekends worked outside preferred range") %>

A preferred `consecutiveWeekendsWorked` rule: each run of weekends worked one after another, inside a period, should stay in range.

- **Reads:** `consecutiveWeekendsWorked` rules.
- **Cost:** per run, its distance outside, times weight and priority.
- **Example:** at most 1 weekend in a row preferred; two in a row: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive days worked outside required range") %>

Each run of days worked one after another must stay in range. With
`categories`, a run holds one category only (a tag such as `early` or `night`)
and a change of category starts a new run.

- **Reads:** `{"kind": "consecutiveDaysWorked", "min": ..., "max": ...}`,
  `categories`.
- **Cost:** per run, its distance outside the range, times weight and
  priority.
- **Example:** at most 6 days in a row; a run of 8: 2 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive days worked outside preferred range") %>

A preferred `consecutiveDaysWorked` rule: each run of days worked one after another (one category per run when `categories` is set) should stay in range.

- **Reads:** `consecutiveDaysWorked` rules.
- **Cost:** per run, its distance outside, times weight and priority.
- **Example:** at least 2 days in a row preferred; a lone day costs 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive shifts outside required range") %>

Each run of shifts close together must stay in range. Two shifts belong to
one run when the next starts at most `linkMinutes` (720 unless set) after the
run's last end.

- **Reads:** `{"kind": "consecutiveShifts"}`, `linkMinutes`.
- **Cost:** per run, its distance outside the range, times weight and
  priority.
- **Example:** at most 3 nights in a run; 4 nights back to back: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive shifts outside preferred range") %>

A preferred `consecutiveShifts` rule: each run of shifts close together (the next starting at most `linkMinutes` after the last end, 720 unless set) should stay in range.

- **Reads:** `consecutiveShifts` rules.
- **Cost:** per run, its distance outside, times weight and priority.
- **Example:** at most 2 nights in a run preferred; 3 nights back to back: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Rest after a run of shifts below required minimum") %>

After a run of at least `restAfterRunsOf` shifts (1 unless set), the employee
needs `restAfterMinutes` off before the next run.

- **Reads:** `consecutiveShifts` rules' `restAfterMinutes`,
  `restAfterRunsOf`.
- **Cost:** the minutes of rest missing, times weight and priority.
- **Example:** 2,880 minutes off after 3 nights; the next shift comes after
  2,400: 480 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Rest after a run of shifts below preferred minimum") %>

A preferred `consecutiveShifts` rule with `restAfterMinutes`: after a run of at least `restAfterRunsOf` shifts, the employee should get that many minutes off.

- **Reads:** `consecutiveShifts` rules' `restAfterMinutes`.
- **Cost:** the minutes missing, times weight and priority.
- **Example:** 2,880 minutes off after a run of nights preferred; the next shift comes after 2,400: 480 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Gap between differing runs below required minimum") %>

With `categories` and `minGapMinutes`, a run of one category must not follow
a run of another too soon, such as days right after nights.

- **Reads:** `consecutiveDaysWorked` rules' `categories`, `minGapMinutes`.
- **Cost:** the minutes missing, times weight and priority.
- **Example:** 2,160 minutes between night and day runs; given 1,440: 720
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Gap between differing runs below preferred minimum") %>

A preferred `consecutiveDaysWorked` rule with `categories` and `minGapMinutes`: a run of one category should not follow a run of another sooner than that.

- **Reads:** `consecutiveDaysWorked` rules' `minGapMinutes`.
- **Cost:** the minutes missing, times weight and priority.
- **Example:** 2,160 minutes between a night run and a day run preferred; given 1,440: 720 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Run starts on a disallowed day") %>

With `startDays` on a required `consecutiveDaysWorked` rule, a run of worked
days must start on one of those weekdays.

- **Reads:** `consecutiveDaysWorked` rules' `startDays`.
- **Cost:** one per run, times weight and priority.
- **Example:** runs must start on Monday; one starts on Wednesday: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Run starts on an allowed day") %>

With `startDays` on a preferred rule, each run that starts on one of those
weekdays is rewarded.

- **Reads:** preferred `consecutiveDaysWorked` rules' `startDays`.
- **Cost:** none; it rewards one per run, times weight and priority.
- **Example:** two runs starting on Monday earn 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Run ends on a start day") %>

A run of worked days ends on a weekday listed in `startDays`, the day new
runs should begin.

- **Reads:** `consecutiveDaysWorked` rules' `startDays` (either level).
- **Cost:** one per run, times weight and priority.
- **Example:** a run that ends on Monday when runs start on Monday: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Compact run of one category") %>

With `compact: true`, each day that continues the previous day's category
within a run is rewarded, so runs stay long and uniform.

- **Reads:** `consecutiveDaysWorked` rules' `compact`, `categories`.
- **Cost:** none; it rewards one per continuing day, times weight and
  priority.
- **Example:** 4 nights in a row earn 3 soft.
- **Weight:** on.

## Time off {#group-time-off}

<%= render Workbench::Rule.new(site: site, model: m, name: "Days off per period outside required range") %>

Days without a matching shift starting, per period; with `weekdays`, only
those weekdays count.

- **Reads:** `{"kind": "daysOff", "period": ...}`, `weekdays`.
- **Cost:** the days outside the range, times weight and priority.
- **Example:** at least 8 days off a month, 6 given: 2 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Days off per period outside preferred range") %>

A preferred `daysOff` rule: the days without a matching shift starting in a period (only the listed `weekdays`, when set) should stay in range.

- **Reads:** `daysOff` rules.
- **Cost:** the days outside, times weight and priority.
- **Example:** at least 2 Sundays off a month preferred, 1 given: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive days off per period below required minimum") %>

The longest run of days off in a period is shorter than `min`.

- **Reads:** `{"kind": "consecutiveDaysOff", "period": ...}`.
- **Cost:** the days missing, times weight and priority.
- **Example:** 2 days off in a row each week; the longest is 1: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive days off per period below preferred minimum") %>

A preferred `consecutiveDaysOff` rule with a `period`: the longest run of days off in each period should be at least `min` days.

- **Reads:** `consecutiveDaysOff` rules with a `period`.
- **Cost:** the days missing, times weight and priority.
- **Example:** 3 in a row preferred, 2 given: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive days off in rolling window below required minimum") %>

The longest run of days off in every run of `rollingDays` days is shorter
than `min`.

- **Reads:** `{"kind": "consecutiveDaysOff", "rollingDays": ...}`.
- **Cost:** per window, the days missing, times weight and priority.
- **Example:** 2 days off together in any 14 days; one window has only single
  days: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive days off in rolling window below preferred minimum") %>

A preferred `consecutiveDaysOff` rule with `rollingDays`: the longest run of days off in every run of that many days should be at least `min` days.

- **Reads:** `consecutiveDaysOff` rules with `rollingDays`.
- **Cost:** per window, the days missing, times weight and priority.
- **Example:** 3 days off together in any 21 days preferred; one window has at most 2: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Continuous rest in rolling window below required minimum") %>

The longest stretch without work in every run of `rollingDays` days is
shorter than `min` minutes, such as a weekly rest of 35 hours.

- **Reads:** `{"kind": "consecutiveMinutesOff", "rollingDays": ...}`.
- **Cost:** per window, the minutes missing, times weight and priority.
- **Example:** 2,100 minutes off in any 7 days; the longest is 1,980: 120
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Continuous rest in rolling window below preferred minimum") %>

A preferred `consecutiveMinutesOff` rule: the longest stretch without work in every run of `rollingDays` days should be at least `min` minutes.

- **Reads:** `consecutiveMinutesOff` rules.
- **Cost:** per window, the minutes missing, times weight and priority.
- **Example:** 2,880 minutes off in any 7 days preferred; the longest is 2,760: 120 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive weekends off per period below required minimum") %>

The longest run of weekends off in a period is shorter than `min`.

- **Reads:** `{"kind": "consecutiveWeekendsOff", "period": ...}`.
- **Cost:** the weekends missing, times weight and priority.
- **Example:** 2 weekends off together each month, none given: 2 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Consecutive weekends off per period below preferred minimum") %>

A preferred `consecutiveWeekendsOff` rule: the longest run of weekends off in each period should be at least `min` weekends.

- **Reads:** `consecutiveWeekendsOff` rules.
- **Cost:** the weekends missing, times weight and priority.
- **Example:** 2 weekends off in a row each month preferred; the longest is 1: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Barred shift next to a requested day off") %>

A `nearDayOff` rule with `stance: "barred"` names shifts (`before`, `after`)
that must not fall on the day before or after a day the employee asked off in
`daysOff`, such as a night shift ending on the morning of a day off.

- **Reads:** `{"kind": "nearDayOff", "stance": "barred"}`, `before`,
  `after`, `employees[].daysOff`.
- **Cost:** one per such shift, times weight and priority.
- **Example:** a night the evening before a requested day off: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Unwanted shift next to a requested day off") %>

A `nearDayOff` rule with `stance: "unwanted"`: the shifts it names in `before` should not fall on the day before a day the employee asked off in `daysOff`, nor those in `after` on the day after.

- **Reads:** `nearDayOff` rules, `employees[].daysOff`.
- **Cost:** one per such shift, times weight and priority.
- **Example:** a late shift the day after a day off: 1 soft.
- **Weight:** on.

## Rotations and patterns {#group-rotations-and-patterns}

<%= render Workbench::Rule.new(site: site, model: m, name: "Overlapping shifts") %>

Two shifts of one employee overlap in time. An `overlapAllowed` contract rule
lets matching shifts overlap, such as an on-call shift over a day shift.

- **Reads:** `shifts[].start`, `end`; `{"kind": "overlapAllowed"}` rules.
- **Cost:** the minutes of overlap.
- **Example:** 08:00 to 16:00 and 15:00 to 23:00: 60 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Rest between shifts outside required range") %>

The minutes from one shift's end to the employee's next shift must stay in
range. `before` and `after` limit which pairs count; pairs further apart than
`withinMinutes` are ignored.

- **Reads:** `{"kind": "restBetween", "min": ...}`, `before`, `after`,
  `withinMinutes`.
- **Cost:** per pair, the minutes outside the range, times weight and
  priority.
- **Example:** at least 660 minutes between shifts; a late at 23:00 then an
  early at 07:00 gives 480: 180 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Rest between shifts outside preferred range") %>

A preferred `restBetween` rule: the minutes from one shift's end to the employee's next shift should stay in range. `before` and `after` limit which pairs count; pairs further apart than `withinMinutes` are ignored.

- **Reads:** `restBetween` rules.
- **Cost:** per pair, the minutes outside, times weight and priority.
- **Example:** 720 minutes preferred, 660 given: 60 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Start time spread per period outside required range") %>

The earliest and latest start times of day of an employee's shifts in a
period must not lie further apart than `max` minutes, so their days look
alike.

- **Reads:** `{"kind": "startSpread", "period": ...}`.
- **Cost:** the minutes beyond the range, times weight and priority.
- **Example:** at most 120 minutes a week; starts at 06:00 and 09:00: 60
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Start time spread per period outside preferred range") %>

A preferred `startSpread` rule: the earliest and latest start times of day of an employee's shifts in a period should lie no further apart than `max` minutes.

- **Reads:** `startSpread` rules.
- **Cost:** the minutes beyond, times weight and priority.
- **Example:** starts within 60 minutes a week preferred; starts at 07:00 and 09:00: 60 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Split shifts close together") %>

A `splitShifts` rule rewards two successive shifts of a split day (`before`,
then `after`) for every minute their gap stays under `max`, so the employee is
not left waiting half a day between them.

- **Reads:** `{"kind": "splitShifts", "max": ...}`, `before`, `after`,
  `withinMinutes`.
- **Cost:** none; it rewards the minutes under `max`, times weight and
  priority.
- **Example:** `max` 180; a 60-minute gap earns 120 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required shift pairing missing") %>

A `dailyPairing` rule with `stance: "required"`: each of the rule's shifts
must come with a `paired` shift `dayOffset` days later (0 is the same day),
such as an on-call night after a late shift.

- **Reads:** `{"kind": "dailyPairing"}`, `paired`, `dayOffset`, `stance`.
- **Cost:** one per shift without its pair, times weight and priority.
- **Example:** every late shift must have an on-call night the same day (`dayOffset` 0); one late has none: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred shift pairing missing") %>

A `dailyPairing` rule with `stance: "preferred"`: each of the rule's shifts should come with a `paired` shift `dayOffset` days later (0 is the same day).

- **Reads:** `dailyPairing` rules.
- **Cost:** one per shift without its pair, times weight and priority.
- **Example:** a Saturday shift should come with the Sunday one (`dayOffset` 1); one Saturday is worked alone: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Barred shift pairing worked") %>

A `dailyPairing` rule with `stance: "barred"`: the rule's shift must never
come with the `paired` shift `dayOffset` days later, such as an early the day
after a night.

- **Reads:** `dailyPairing` rules.
- **Cost:** one per shift with that pair, times weight and priority.
- **Example:** a `night` must never be followed by an `early` the next day; one is: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Unwanted shift pairing worked") %>

A `dailyPairing` rule with `stance: "unwanted"`: the rule's shift should not come with the `paired` shift `dayOffset` days later.

- **Reads:** `dailyPairing` rules.
- **Cost:** one per shift with that pair, times weight and priority.
- **Example:** a `late` should not be followed by an `early` the next day; two are: 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required day pattern broken") %>

A `dayPattern` rule lists `steps`, one tag filter per shift of one day (in
that order with `ordered`). With `stance: "required"`, a day that has shifts of
the pattern must complete it, such as a split day with both halves.

- **Reads:** `{"kind": "dayPattern", "steps": [...]}`, `ordered`, `stance`.
- **Cost:** one per day started and not completed, times weight and
  priority.
- **Example:** a morning half without its evening half: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred day pattern worked") %>

With `stance: "preferred"`, each day that completes the pattern is rewarded.

- **Reads:** `dayPattern` rules.
- **Cost:** none; it rewards one per day, times weight and priority.
- **Example:** two complete days earn 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Barred day pattern worked") %>

With `stance: "barred"`, a day's shifts must never complete the pattern.

- **Reads:** `dayPattern` rules.
- **Cost:** one per day, times weight and priority.
- **Example:** an early and a late on one day when barred: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Unwanted day pattern worked") %>

With `stance: "unwanted"`, a day that completes the pattern costs.

- **Reads:** `dayPattern` rules.
- **Cost:** one per day, times weight and priority.
- **Example:** an `early` and a `late` on one day are unwanted (two `steps`); one such day: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required multi-day pattern broken") %>

A `multiDayPattern` rule lists `days`, each `work: true` with a tag filter or
`work: false`. With `stance: "required"`, a run of days that starts like the
pattern must follow it, such as two days off after three nights.

- **Reads:** `{"kind": "multiDayPattern", "days": [...]}`, `stance`.
- **Cost:** one per start day that matches the first day and breaks the
  rest, times weight and priority.
- **Example:** night, night, night, then work the next day: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred multi-day pattern worked") %>

With `stance: "preferred"`, each run of days that follows the pattern is
rewarded.

- **Reads:** `multiDayPattern` rules.
- **Cost:** none; it rewards one per start day, times weight and priority.
- **Example:** two days off after three nights preferred; each run that follows it earns 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Barred multi-day pattern worked") %>

With `stance: "barred"`, no run of days may follow the pattern, such as
work, off, work.

- **Reads:** `multiDayPattern` rules.
- **Cost:** one per start day, times weight and priority.
- **Example:** work, off, work is barred; one such run: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Unwanted multi-day pattern worked") %>

With `stance: "unwanted"`, a run that follows the pattern costs.

- **Reads:** `multiDayPattern` rules.
- **Cost:** one per start day, times weight and priority.
- **Example:** a single day off between two worked days is unwanted; two such runs: 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required weekly rotation broken") %>

A `rotation` rule with `cycle: "weekly"` lists `groups` (tag filters), worked
one per week in turn: earlies, then lates, then nights. In each week, the
group of the first shift is the week's group.

- **Reads:** `{"kind": "rotation", "cycle": "weekly", "groups": [...]}`.
- **Cost:** one per shift outside the week's group, plus one per week that
  does not move on to the next group, times weight and priority.
- **Example:** a lates week with one early, then lates again: 2 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred weekly rotation broken") %>

A preferred `rotation` rule with `cycle: "weekly"`: the `groups` should be worked one per week in turn, the first shift of each week setting the week's group.

- **Reads:** weekly `rotation` rules.
- **Cost:** the same count, times weight and priority.
- **Example:** earlies, lates, nights by week preferred; a lates week with one early, then lates again: 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Rotation block longer than required maximum") %>

A `rotation` rule with `cycle: "blocks"`: shifts of one group form a block,
from its first to its last day. Each block must not run longer than `max`
days.

- **Reads:** `{"kind": "rotation", "cycle": "blocks", "max": ...}`.
- **Cost:** the days beyond `max` per block, times weight and priority.
- **Example:** blocks of at most 5 days; a 7-day block of nights: 2 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Rotation block length outside preferred range") %>

With `level: "preferred"`, each block should stay between `min` and `max`
days.

- **Reads:** block `rotation` rules' `min`, `max`.
- **Cost:** the days outside the range per block, times weight and priority.
- **Example:** 3 to 5 days preferred; a 2-day block: 1 soft.
- **Weight:** on.

## Cost and activation {#group-cost-and-activation}

<%= render Workbench::Rule.new(site: site, model: m, name: "Contract cost outside required range") %>

A `cost` contract rule pays `hourly` for the first `baseMinutes` of each
period, then each `overtime` tier at its own `hourly` for its `minutes` (the
last tier without a limit). With `level: "required"`, the pay must stay
between `min` and `max`, in currency units.

- **Reads:** `{"kind": "cost", "hourly": ..., "baseMinutes": ..., "overtime": [...]}`.
- **Cost:** the distance outside the range in cents, times weight and
  priority.
- **Example:** a weekly budget of at most 900.00; pay of 960.00 costs 6,000
  hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Contract cost") %>

A preferred `cost` rule: with `min` or `max`, the distance from that range;
without, the pay itself, to keep it low.

- **Reads:** preferred `cost` contract rules.
- **Cost:** in cents, times weight and priority.
- **Example:** 40 hours at 20.00 with 38 base hours, overtime at 30.00: 760.00
  + 60.00, 82,000 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Cost per period outside required range") %>

A `scheduleRules.costs` rule prices the matching assignments of all
employees: each assignment's minutes at the first `rates` entry that matches
the employee's `costGroup` and the shift's `costGroup`. With `level:
"required"`, the total per period must stay in range.

- **Reads:** `scheduleRules.costs[]` (`period`, `rates`, `min`, `max`).
- **Cost:** the distance outside the range in cents, times the rule's weight.
- **Example:** a daily budget of 5,000.00 exceeded by 120.00: 12,000 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Cost per period outside preferred range") %>

The same with `level: "preferred"` and a `min` or `max`.

- **Reads:** `scheduleRules.costs[]`.
- **Cost:** the distance in cents, times the rule's weight.
- **Example:** a weekly budget of 30,000.00 preferred, 30,120.00 spent: 12,000 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Cost per period") %>

A preferred `scheduleRules.costs` rule without `min` or `max`: the total
itself, to keep it low.

- **Reads:** `scheduleRules.costs[]`.
- **Cost:** the period's cost in cents, times the rule's weight.
- **Example:** a day costing 4,200.00 adds 420,000 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Employee activated") %>

An employee works at least one shift in the schedule, and their cost group
has an `activationCost`, such as calling in an agency worker.

- **Reads:** `costGroups[].activationCost`, `employees[].costGroup`.
- **Cost:** the activation cost, once per employee.
- **Example:** two agency nurses at 500 each: 1,000 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Activated employee filled up") %>

For a cost group with `fillUp: true`, the square of the shifts each employee
works is rewarded, so work concentrates on fewer people.

- **Reads:** `costGroups[].fillUp`.
- **Cost:** none; it rewards the shifts squared per employee.
- **Example:** one agency nurse with 4 shifts earns 16; two with 2 each earn
  8.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Activated employees off target share") %>

Cost groups with a `share` should make up that share of the employees who
work. The rule sums, over the groups, how far each group's activated
employees are from its share of all activated ones.

- **Reads:** `costGroups[].share`.
- **Cost:** the employees off target, rounded.
- **Example:** shares 3 (staff) and 1 (agency); of 8 working, 4 are agency
  instead of 2: 4 soft.
- **Weight:** on.

## Fairness {#group-fairness}

A `scheduleRules.fairness` rule balances `shifts` or `minutes` over the
matching employees, counting what each already worked in `history`. Squares
make the sum least when the load is even.

<%= render Workbench::Rule.new(site: site, model: m, name: "Uneven shift counts") %>

With `balance: "shifts"`: each employee's matching shifts plus their history,
squared.

- **Reads:** `scheduleRules.fairness[]` (`balance`, `history`, tags,
  `employees`).
- **Cost:** the sum of squares.
- **Example:** 6 and 2 weekend shifts cost 40; 4 and 4 cost 32.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Uneven time worked") %>

With `balance: "minutes"`: each employee's matching hours plus their history,
squared.

- **Reads:** `scheduleRules.fairness[]`, `history` in minutes.
- **Cost:** the sum of squared hours.
- **Example:** 40 and 20 hours cost 2,000; 30 and 30 cost 1,800.
- **Weight:** on.

## Replanning {#group-replanning}

A shift's `published` names the employee it was published to. These rules
apply once any shift has one.

<%= render Workbench::Rule.new(site: site, model: m, name: "Published assignment changed") %>

A shift in the schedule no longer goes to the employee it was published to.

- **Reads:** `shifts[].published`.
- **Cost:** one per shift.
- **Example:** a sick call moves 3 shifts: 3 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Published shifts lost by employee") %>

An employee loses shifts that were published to them.

- **Reads:** `shifts[].published`, `employees[].priority`.
- **Cost:** one per shift lost, times the employee's priority.
- **Example:** 2 shifts lost by a priority-3 employee: 6 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Unpublished shifts gained by employee") %>

An employee gets shifts that were not published to them.

- **Reads:** `shifts[].published`, `employees[].priority`.
- **Cost:** one per shift gained, times the employee's priority.
- **Example:** after a sick call an employee with priority 1 takes 2 shifts they were not published: 2 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Gained shifts keep tags of lost ones") %>

When an employee loses shifts, each tag of a gained shift that a lost one
carried is rewarded, so replacements resemble what they replace.

- **Reads:** `shifts[].tags`, `published`.
- **Cost:** none; it rewards one per kept tag.
- **Example:** a lost `ward-a`, `early` shift replaced by `ward-a`, `late`
  earns 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Close replacements keep rule tags") %>

A `disruption` contract rule's `keepTags` are made good when a close
replacement keeps them; each kept tag is rewarded.

- **Reads:** `{"kind": "disruption", "keepTags": [...]}`.
- **Cost:** none; it rewards one per kept tag.
- **Example:** a lost `ward-a` early replaced by a `ward-a` shift within the rule's minutes, with `keepTags` [`ward-a`]: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Lost shift without required close replacement") %>

A required `disruption` rule: an employee who loses a matching shift must get
one back whose start and end are within `withinMinutes` of it and that keeps
the rule's `keepTags`.

- **Reads:** `{"kind": "disruption", "withinMinutes": ..., "keepTags": [...]}`.
- **Cost:** the rule's weight per lost shift with no such replacement.
- **Example:** an early lost and nothing within 60 minutes of it given back:
  1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Lost shift without preferred close replacement") %>

A preferred `disruption` rule: an employee who loses a matching published shift should get one back whose start and end are within `withinMinutes` of it and that keeps the rule's `keepTags`.

- **Reads:** `disruption` contract rules.
- **Cost:** the rule's weight per unreplaced shift.
- **Example:** an employee loses a published early and gets nothing within 60 minutes of it back: 1 soft.
- **Weight:** on.

## Working together {#group-working-together}

An employee's `pairings` each have a `stance`, a partner (`with`, an employee
id, or any employee with `withTags`), and optionally `onTags`, the shifts it
concerns. Two shifts are together when they overlap in time.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required partner absent") %>

An employee works a shift without the partner they must work with, such as
a trainee without their mentor.

- **Reads:** `employees[].pairings[]` with `stance: "required"`.
- **Cost:** one per shift.
- **Example:** a trainee works a shift while their mentor is off: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred partner present") %>

A preferred partner works at the same time. This is a reward.

- **Reads:** `pairings[]` with `stance: "preferred"`.
- **Cost:** none; it rewards the employee's priority per shift.
- **Example:** two friends who like to work together share three shifts: 3 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Unwanted partner present") %>

An unwanted partner works at the same time.

- **Reads:** `pairings[]` with `stance: "unwanted"`.
- **Cost:** the employee's priority per shift.
- **Example:** two colleagues who would rather not meet overlap on one shift: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Barred partner present") %>

A barred partner works at the same time.

- **Reads:** `pairings[]` with `stance: "barred"`.
- **Cost:** one per shift.
- **Example:** two people barred from working together overlap on one shift: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Team members split across tags") %>

A team (`teams[]`, with `leads` and `members`) and a `tagType`: two team
members working at the same time must share a tag of that type, such as the
same ward.

- **Reads:** `teams[].tagType`, `shifts[].tags`, `tags[].type`.
- **Cost:** one per pair of overlapping shifts sharing no such tag.
- **Example:** two members on at once on different wards: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Team member without a lead") %>

A team member who is not a lead works a shift with no lead of the team on at
the same time.

- **Reads:** `teams[].leads`, `members`.
- **Cost:** one per shift.
- **Example:** a junior on the night team works while no lead of the team is on: 1 hard.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Team lead works with the team") %>

A lead's shift during which another member of the team also works. This is a
reward.

- **Reads:** `teams[].leads`, `members`.
- **Cost:** none; it rewards one per such lead shift.
- **Example:** a lead's shift overlaps a member's shift: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Team shifts per day over limit") %>

With `maxShiftsPerDay`, a team's work on each tag of its `tagType` may use at
most that many distinct shift times a day, so the team arrives and leaves
together.

- **Reads:** `teams[].maxShiftsPerDay`, `tagType`.
- **Cost:** the distinct shift times beyond the limit, per tag and day.
- **Example:** at most 2 shift times a day on a ward, 3 used: 1 hard.
- **Weight:** on.

## Demand {#group-demand}

A `scheduleRules.demand` rule lists `slots` (`from`, `to`, `min`, `max`) and
the shifts and employees that count. A shift covers a slot when it spans the
whole slot and none of its breaks falls inside it. Floating breaks are placed
where they leave the fewest slots short.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required demand under-staffed") %>

A required slot has fewer covering staff than its `min`. This weighs at the
medium level, like an open mandatory shift.

- **Reads:** `scheduleRules.demand[]` with `level: "required"`.
- **Cost:** one per missing person, per slot.
- **Example:** 3 nurses needed from 07:00 to 09:00, 2 there: 1 medium.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Required demand over-staffed") %>

A required slot has more covering staff than its `max`.

- **Reads:** `scheduleRules.demand[]` with `level: "required"`.
- **Cost:** one per extra person, per slot.
- **Example:** at most 4 in the clinic at noon, 5 there: 1 medium.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred demand under-staffed") %>

A preferred slot has fewer covering staff than its `min`.

- **Reads:** `scheduleRules.demand[]` with `level: "preferred"`.
- **Cost:** one per missing person, per slot.
- **Example:** 4 staff preferred from 08:00 to 10:00, 3 there: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Preferred demand over-staffed") %>

A preferred slot has more covering staff than its `max`.

- **Reads:** `scheduleRules.demand[]` with `level: "preferred"`.
- **Cost:** one per extra person, per slot.
- **Example:** at most 2 preferred in the evening slot, 3 there: 1 soft.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Surplus staff unevenly spread over demand") %>

Staff beyond a slot's `min`, squared, at any level. For a fixed surplus the
sum is least when the extra people spread evenly over the day.

- **Reads:** `scheduleRules.demand[]`.
- **Cost:** the square of the surplus per slot.
- **Example:** 2 extra in one slot cost 4; one extra in each of two slots
  costs 2.
- **Weight:** on.

<%= render Workbench::Rule.new(site: site, model: m, name: "Alternative shifts worked off count") %>

Shifts with the same `alternativeOf` are versions of one shift, such as an
8-hour and a 12-hour night. The `alternatives` entry with that id says how
many to work: exactly `count`, or at most with `atMost`.

- **Reads:** `shifts[].alternativeOf`, `alternatives[]` (`count`,
  `atMost`).
- **Cost:** the versions worked away from the count (only beyond it with
  `atMost`).
- **Example:** one version of a night wanted, two worked: 1 hard.
- **Weight:** on.
