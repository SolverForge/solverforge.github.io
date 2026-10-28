Use the solverforge-modeling skill to turn this planning problem into a runnable SolverForge app.

## The problem

We run a city bus depot with 12 buses. Over the next 10 working days we have 20
maintenance jobs to schedule. Each job belongs to one bus, needs one skill
(mechanical, electrical, or bodywork), and takes one full day. A job cannot
start before its parts arrive (an earliest day), and it has a due day.

We have 4 technicians. Each technician has one or more of the three skills and
can work on at most one job per day.

A bus that is in the workshop on a given day is out of service that day. The
depot must keep at least 10 of its 12 buses in service every day, so no more
than 2 different buses may be in the workshop on the same day.

For every job we need to decide which technician does it and on which day.

## Intake answers (treat these as confirmed; do not stop to ask)

- Output shell: `api` (headless HTTP API, no browser UI).
- Hard constraints (a plan that breaks any of these is invalid):
  1. The technician has the skill the job needs.
  2. A technician does at most one job per day.
  3. A job is not scheduled before its parts arrive.
  4. At most 2 different buses are in the workshop on any day.
  5. Every job gets a technician and a day.
- Soft constraints (optimize):
  1. Finish jobs by their due day; penalize each day late.
  2. Spread work evenly across technicians.
- Score type: `HardSoftScore`.
- Name the app `depot-maintenance` and create it in the current directory.
- Demo data: replace the generic sample data with the depot described above
  (12 buses, 20 jobs, 4 technicians, 10 days), deterministic, with a feasible
  plan possible.

When you echo the model back, keep going instead of waiting for confirmation.
Finish only after a real solve completes with a score, as the skill requires.
At the end, list every `solverforge` command you ran, in order, and the final
score of the verification solve.
