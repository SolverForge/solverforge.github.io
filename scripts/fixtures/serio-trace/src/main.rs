// One move traced through SERIO, the example on /docs/concepts/serio/.
//
// scripts/verify-serio-page.rb copies the page's model and constraint files
// beside this file, builds the crate against the published solverforge
// release, runs it, and compares every printed line with the page: the input
// shifts, the score after each step, and a fresh full evaluation beside each
// kept score.

mod constraints;
mod domain;

use constraints::define_constraints;
use domain::{Employee, Schedule, Shift};
use solverforge::prelude::*;
use solverforge::ScoreDirector;

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
