//! One module per page. Each `// page:` region is a Rust block of that page,
//! verbatim; the code around it supplies the inputs and asserts the outcome
//! the page states.

mod configuration;
mod index;
mod solver_manager;
mod termination;

use std::time::{Duration, Instant};

use solverforge::{SolverEvent, SolverEventReceiver, SolverManager, Solvable};

pub fn run(name: &str) {
    match name {
        "index" => index::run(),
        "configuration" => configuration::run(),
        "config-load" => configuration::load(),
        "cwd-ignored" => configuration::cwd_ignored(),
        "termination" => termination::run(),
        "solver-manager" => solver_manager::run(),
        other => panic!("unknown scenario {other}"),
    }
    println!("SCENARIO {name} OK");
}

/// Reads events until a terminal one and returns it.
pub fn terminal<S: Solvable>(rx: &mut SolverEventReceiver<S>) -> SolverEvent<S> {
    let deadline = Instant::now() + Duration::from_secs(120);
    while let Some(event) = rx.blocking_recv() {
        if matches!(
            event,
            SolverEvent::Completed { .. } | SolverEvent::Cancelled { .. } | SolverEvent::Failed { .. }
        ) {
            return event;
        }
        assert!(Instant::now() < deadline, "no terminal event within 120 s");
    }
    panic!("event stream closed before a terminal event");
}

/// Solves `solution` on `manager` and returns its terminal event, then deletes
/// the job.
pub fn solve_to_end<S: Solvable>(manager: &'static SolverManager<S>, solution: S) -> SolverEvent<S> {
    let (job_id, mut rx) = manager.solve(solution).expect("solver job should start");
    let event = terminal(&mut rx);
    manager.delete(job_id).expect("delete terminal job");
    event
}
