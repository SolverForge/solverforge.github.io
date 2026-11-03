use solverforge::prelude::*;
use solverforge::stream::ConstraintFactory;

use super::{Employee, Shift};

// page: src/docs/solverforge/solver/construction.md scalar groups
#[planning_solution(
    constraints = "define_constraints",
    scalar_groups = "scalar_groups"
)]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,

    #[planning_entity_collection]
    pub shifts: Vec<Shift>,

    #[planning_score]
    pub score: Option<HardSoftScore>,
}

pub(super) fn scalar_groups() -> Vec<ScalarGroup<Schedule>> {
    vec![
        ScalarGroup::assignment(
            "required_shift_assignment",
            Schedule::shifts().scalar("employee_idx"),
        )
        .with_required_entity(required_shift)
        .with_capacity_key(employee_day_capacity)
        .with_entity_order(shift_order)
        .with_value_order(employee_preference),
    ]
}

fn required_shift(_schedule: &Schedule, _shift_idx: usize) -> bool {
    true
}

fn employee_day_capacity(
    schedule: &Schedule,
    shift_idx: usize,
    employee_idx: usize,
) -> Option<usize> {
    let shift = &schedule.shifts[shift_idx];
    shift
        .date
        .checked_mul(schedule.employees.len())
        .and_then(|base| base.checked_add(employee_idx))
}

fn shift_order(schedule: &Schedule, shift_idx: usize) -> i64 {
    i64::try_from(schedule.shifts[shift_idx].date).unwrap_or(i64::MAX)
}

fn employee_preference(
    schedule: &Schedule,
    shift_idx: usize,
    employee_idx: usize,
) -> i64 {
    let preferred = schedule.shifts[shift_idx].date % schedule.employees.len();
    let distance = (employee_idx + schedule.employees.len() - preferred)
        % schedule.employees.len();
    i64::try_from(distance).unwrap_or(i64::MAX)
}
// end page

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    (
        ConstraintFactory::<Schedule, HardSoftScore>::new()
            .for_each(Schedule::shifts())
            .filter(|shift: &Shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::of(1, 0))
            .named("unassigned shift"),
        ConstraintFactory::<Schedule, HardSoftScore>::new()
            .for_each(Schedule::shifts())
            .filter(|shift: &Shift| shift.employee_idx.is_some())
            .penalize(|shift: &Shift| {
                let employee = shift.employee_idx.unwrap_or_default();
                HardSoftScore::of(0, ((shift.id * 7 + employee * 3) % 11) as i64)
            })
            .named("preference"),
    )
}

/// Builds the group with explicit limits, as the construction page shows.
pub fn group_with_limits() -> ScalarGroup<Schedule> {
    // page: src/docs/solverforge/solver/construction.md limits
    let group = ScalarGroup::assignment(
        "required_shift_assignment",
        Schedule::shifts().scalar("employee_idx"),
    )
    .with_limits(ScalarGroupLimits {
        max_augmenting_depth: Some(3),
        max_rematch_size: Some(4),
        ..ScalarGroupLimits::new()
    });
    // end page
    group
}

impl Schedule {
    /// Four shifts a day over six employees.
    pub fn demo(shifts: usize) -> Self {
        Schedule {
            employees: (0..6).map(|id| Employee { id }).collect(),
            shifts: (0..shifts)
                .map(|id| Shift { id, date: id / 4, employee_idx: None })
                .collect(),
            score: None,
        }
    }
}
