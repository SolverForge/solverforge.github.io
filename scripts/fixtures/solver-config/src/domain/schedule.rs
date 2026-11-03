use solverforge::prelude::*;
use solverforge::stream::ConstraintFactory;
use solverforge::SolverConfig;

use super::{Employee, Room, Shift};

// page: src/docs/solverforge/solver/configuration.md overlay
#[planning_solution(
    constraints = "define_constraints",
    solver_toml = "../../solver.toml",
    config = "solver_config_for_solution"
)]
pub struct Schedule {
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[problem_fact_collection]
    pub rooms: Vec<Room>,
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
    pub time_limit_secs: u64,
}

fn solver_config_for_solution(solution: &Schedule, config: SolverConfig) -> SolverConfig {
    config.with_termination_seconds(solution.time_limit_secs)
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
                let employee = shift.employee_idx.unwrap_or_default() as i64;
                HardSoftScore::of(0, (shift.weight * (employee + 3)) % 17)
            })
            .named("employee cost"),
        ConstraintFactory::<Schedule, HardSoftScore>::new()
            .for_each(Schedule::shifts())
            .filter(|shift: &Shift| shift.room_idx.is_some())
            .penalize(|shift: &Shift| {
                let room = shift.room_idx.unwrap_or_default() as i64;
                let employee = shift.employee_idx.unwrap_or_default() as i64;
                HardSoftScore::of(0, (shift.weight + room * 5 + employee) % 13)
            })
            .named("room cost"),
    )
}

impl Schedule {
    /// A fixed instance: `shifts` shifts over six employees and three rooms.
    pub fn demo(shifts: usize, time_limit_secs: u64) -> Self {
        let employees = 6;
        Schedule {
            employees: (0..employees).map(|id| Employee { id }).collect(),
            rooms: (0..3).map(|id| Room { id }).collect(),
            shifts: (0..shifts)
                .map(|id| Shift {
                    id,
                    weight: ((id * 7 + 3) % 11) as i64,
                    nearby_employees: vec![id % employees, (id + 1) % employees, (id + 2) % employees],
                    nearby_shifts: (1..=3).map(|d| (id + d) % shifts).collect(),
                    employee_idx: None,
                    room_idx: None,
                })
                .collect(),
            score: None,
            time_limit_secs,
        }
    }
}
