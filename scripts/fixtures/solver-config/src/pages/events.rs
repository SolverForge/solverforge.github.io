//! Waiting for a solve to reach a terminal event.

use std::time::{Duration, Instant};

use solverforge::{SolverEvent, SolverEventReceiver, SolverManager, Solvable};

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
