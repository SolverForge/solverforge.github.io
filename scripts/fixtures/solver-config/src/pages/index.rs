use crate::domain::Schedule;

pub fn run() {
    quick_start(Schedule::demo(24, 1));
}

#[allow(unused_imports)]
fn quick_start(problem: Schedule) {
    // page: src/docs/solverforge/solver/index.md quick start
    use solverforge::prelude::*;
    use solverforge::{SolverEvent, SolverManager};

    static MANAGER: SolverManager<Schedule> = SolverManager::new();

    let (job_id, mut rx) = MANAGER.solve(problem).expect("solver job should start");

    while let Some(event) = rx.blocking_recv() {
        match event {
            SolverEvent::Progress { metadata } => {
                println!("best so far: {:?}", metadata.best_score);
            }
            SolverEvent::BestSolution { metadata, .. } => {
                println!("new best at snapshot {:?}", metadata.snapshot_revision);
            }
            SolverEvent::Completed { metadata, .. } => {
                println!("finished with reason {:?}", metadata.terminal_reason);
                break;
            }
            SolverEvent::Cancelled { .. } | SolverEvent::Failed { .. } => break,
            SolverEvent::PauseRequested { .. } | SolverEvent::Paused { .. } | SolverEvent::Resumed { .. } => {}
        }
    }

    MANAGER.delete(job_id).expect("delete retained job");
    // end page

    // The page promises a finished job (its last line is checked by the gate)
    // and a freed slot.
    assert!(MANAGER.get_status(job_id).is_err(), "deleted job must be gone");
    assert_eq!(MANAGER.active_job_count(), 0);
}
