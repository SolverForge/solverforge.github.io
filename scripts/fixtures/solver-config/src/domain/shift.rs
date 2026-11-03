use solverforge::prelude::*;

use super::Schedule;

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub weight: i64,
    pub nearby_employees: Vec<usize>,
    pub nearby_shifts: Vec<usize>,

    #[planning_variable(
        value_range_provider = "employees",
        allows_unassigned = true,
        nearby_value_candidates = "nearby_employees",
        nearby_entity_candidates = "nearby_shifts"
    )]
    pub employee_idx: Option<usize>,

    #[planning_variable(value_range_provider = "rooms", allows_unassigned = true)]
    pub room_idx: Option<usize>,
}

pub(super) fn nearby_employees(schedule: &Schedule, shift_idx: usize, _variable: usize) -> &[usize] {
    &schedule.shifts[shift_idx].nearby_employees
}

pub(super) fn nearby_shifts(schedule: &Schedule, shift_idx: usize, _variable: usize) -> &[usize] {
    &schedule.shifts[shift_idx].nearby_shifts
}
