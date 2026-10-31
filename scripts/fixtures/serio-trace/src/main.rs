// One move traced through SERIO, the example on /docs/concepts/serio/.
//
// scripts/verify-serio-page.rb builds this against the documented solverforge
// tag, runs it, and compares every printed line with the page: the input
// shifts, the score after each step, and a fresh full evaluation beside each
// cached score. The constraint function must stay verbatim on the page.

use solverforge::prelude::*;
use solverforge::stream::{joiner::*, ConstraintFactory};
use solverforge::ScoreDirector;

#[problem_fact]
pub struct Employee {
    #[planning_id]
    pub id: usize,
}

#[planning_entity]
pub struct Shift {
    #[planning_id]
    pub id: usize,
    pub start: usize,
    pub end: usize,
    #[planning_variable(value_range_provider = "employees", allows_unassigned = true)]
    pub employee_idx: Option<usize>,
}

#[planning_solution(constraints = "define_constraints")]
pub struct Schedule {
    #[planning_entity_collection]
    pub shifts: Vec<Shift>,
    #[problem_fact_collection]
    pub employees: Vec<Employee>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl solverforge::__internal::PlanningModelSupport for Schedule {
    fn attach_descriptor_hooks(_descriptor: &mut solverforge::__internal::SolutionDescriptor) {}

    fn attach_runtime_scalar_hooks(
        slot: solverforge::__internal::ScalarVariableSlot<Self>,
    ) -> solverforge::__internal::ScalarVariableSlot<Self> {
        slot
    }

    fn attach_scalar_groups(
        _scalar_variables: &[solverforge::__internal::ScalarVariableSlot<Self>],
    ) -> Vec<solverforge::__internal::ScalarGroupBinding<Self>> {
        Vec::new()
    }

    fn validate_model(_descriptor: &solverforge::__internal::SolutionDescriptor) {}

    fn update_entity_shadows(_solution: &mut Self, _descriptor: usize, _entity: usize) -> bool {
        false
    }

    fn update_all_shadows(_solution: &mut Self) -> bool {
        false
    }
}

fn define_constraints() -> impl ConstraintSet<Schedule, HardSoftScore> {
    type Streams = ConstraintFactory<Schedule, HardSoftScore>;
    (
        Streams::new()
            .for_each(Schedule::shifts())
            .join(equal(|shift: &Shift| shift.employee_idx))
            .filter(|a: &Shift, b: &Shift| {
                a.employee_idx.is_some() && a.start < b.end && b.start < a.end
            })
            .penalize(HardSoftScore::ONE_HARD)
            .named("Overlapping shifts"),
        Streams::new()
            .for_each(Schedule::shifts())
            .filter(|shift: &Shift| shift.employee_idx.is_none())
            .penalize(HardSoftScore::ONE_SOFT)
            .named("Unassigned shift"),
    )
}

// The shift collection is the first entity collection: descriptor 0.
const SHIFTS: usize = 0;
const MOVED: usize = 1;

fn fresh(solution: &Schedule) -> HardSoftScore {
    ScoreDirector::new(solution.clone(), define_constraints()).calculate_score()
}

fn report(step: &str, director: &mut ScoreDirector<Schedule, impl ConstraintSet<Schedule, HardSoftScore>>) {
    let cached = director.calculate_score();
    let fresh = fresh(director.working_solution());
    println!("step={step} score={cached} fresh={fresh}");
}

fn main() {
    let schedule = Schedule {
        shifts: vec![
            Shift { id: 0, start: 8, end: 16, employee_idx: Some(0) },
            Shift { id: 1, start: 12, end: 20, employee_idx: Some(0) },
            Shift { id: 2, start: 6, end: 10, employee_idx: Some(1) },
            Shift { id: 3, start: 18, end: 22, employee_idx: None },
        ],
        employees: vec![Employee { id: 0 }, Employee { id: 1 }],
        score: None,
    };
    for shift in &schedule.shifts {
        let employee = shift.employee_idx.map_or("none".to_string(), |e| e.to_string());
        println!("shift={} start={} end={} employee={employee}", shift.id, shift.start, shift.end);
    }

    let mut director = ScoreDirector::new(schedule, define_constraints());
    report("initialize", &mut director);

    // A change move: shift 1 goes from employee 0 to employee 1.
    director.before_variable_changed(SHIFTS, MOVED);
    let retracted = director.calculate_score();
    println!("step=retract score={retracted}");
    director.working_solution_mut().shifts[MOVED].employee_idx = Some(1);
    director.after_variable_changed(SHIFTS, MOVED);
    report("insert", &mut director);

    // Undo is the same protocol with the old value.
    director.before_variable_changed(SHIFTS, MOVED);
    director.working_solution_mut().shifts[MOVED].employee_idx = Some(0);
    director.after_variable_changed(SHIFTS, MOVED);
    report("undo", &mut director);
}
