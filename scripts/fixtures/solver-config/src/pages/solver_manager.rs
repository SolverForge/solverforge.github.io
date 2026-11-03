#![allow(unused_variables)]

use std::time::{Duration, Instant};

use solverforge::{SolverConfig, SolverEvent, SolverEventReceiver, SolverLifecycleState, SolverManagerError};

use super::terminal;
use crate::domain::Schedule;

// page: src/docs/solverforge/solver/solver-manager.md manager
use solverforge::SolverManager;

static MANAGER: SolverManager<Schedule> = SolverManager::new();
// end page

pub fn run() {
    start(Schedule::demo(24, 1));
    event_loop(Schedule::demo(24, 1));
    controls(Schedule::demo(24, 30));
    resume_before_paused_is_rejected(Schedule::demo(24, 30));
    paused_time_is_not_charged(Schedule::demo(24, 30));
    solve_without_a_manager(Schedule::demo(24, 0));
    assert_eq!(MANAGER.active_job_count(), 0, "every job was deleted");
}

fn start(solution: Schedule) {
    // page: src/docs/solverforge/solver/solver-manager.md solve
    let (job_id, rx) = MANAGER.solve(solution).expect("solver job should start");
    // end page
    let mut rx = rx;
    terminal(&mut rx);
    MANAGER.delete(job_id).expect("delete terminal job");
}

fn event_loop(solution: Schedule) {
    // page: src/docs/solverforge/solver/solver-manager.md event loop
    use solverforge::SolverEvent;

    let (job_id, mut rx) = MANAGER.solve(solution).expect("solver job should start");

    while let Some(event) = rx.blocking_recv() {
        match event {
            SolverEvent::Progress { metadata } => {
                println!(
                    "job {} state {:?} current {:?} best {:?}",
                    metadata.job_id,
                    metadata.lifecycle_state,
                    metadata.current_score,
                    metadata.best_score
                );
            }
            SolverEvent::BestSolution { metadata, .. } => {
                println!(
                    "new best at snapshot {:?}",
                    metadata.snapshot_revision
                );
            }
            SolverEvent::PauseRequested { metadata } => {
                println!("pause requested for job {}", metadata.job_id);
            }
            SolverEvent::Paused { metadata } => {
                println!(
                    "job {} paused at snapshot {:?}",
                    metadata.job_id,
                    metadata.snapshot_revision
                );
            }
            SolverEvent::Resumed { metadata } => {
                println!("job {} resumed", metadata.job_id);
            }
            SolverEvent::Completed { metadata, .. } => {
                println!(
                    "job {} completed with reason {:?}",
                    metadata.job_id,
                    metadata.terminal_reason
                );
                break;
            }
            SolverEvent::Cancelled { metadata } => {
                println!("job {} cancelled", metadata.job_id);
                break;
            }
            SolverEvent::Failed { metadata, error } => {
                println!("job {} failed: {}", metadata.job_id, error);
                break;
            }
        }
    }
    // end page
    let status = MANAGER.get_status(job_id).expect("job should exist");
    assert_eq!(status.lifecycle_state, SolverLifecycleState::Completed);
    MANAGER.delete(job_id).expect("delete terminal job");
}

/// Reads events until local search has published a best solution.
fn until_local_search(rx: &mut SolverEventReceiver<Schedule>, construction_steps: u64) {
    let deadline = Instant::now() + Duration::from_secs(30);
    while let Some(event) = rx.blocking_recv() {
        if let SolverEvent::BestSolution { metadata, .. } = &event {
            if metadata.telemetry.step_count > construction_steps {
                return;
            }
        }
        assert!(!matches!(event, SolverEvent::Completed { .. } | SolverEvent::Failed { .. }), "ended early");
        assert!(Instant::now() < deadline, "local search never improved");
    }
    panic!("stream closed");
}

/// Status, pause, resume, a problem change, snapshots, analysis, cancel and
/// delete on one retained job, in the order the page shows them.
fn controls(solution: Schedule) {
    let original_weight = solution.shifts[0].weight;
    let (job_id, mut rx) = MANAGER.solve(solution).expect("solver job should start");

    // page: src/docs/solverforge/solver/solver-manager.md status
    let status = MANAGER.get_status(job_id).expect("job should exist");

    println!("state: {:?}", status.lifecycle_state);
    println!("terminal reason: {:?}", status.terminal_reason);
    println!("checkpoint available: {}", status.checkpoint_available);
    println!("event sequence: {}", status.event_sequence);
    println!("latest snapshot: {:?}", status.latest_snapshot_revision);
    // end page
    assert_eq!(status.terminal_reason, None);

    until_local_search(&mut rx, 48);

    // page: src/docs/solverforge/solver/solver-manager.md pause and resume
    MANAGER.pause(job_id).expect("pause should be accepted");

    // resume() is accepted once the job has settled in Paused.
    while let Some(event) = rx.blocking_recv() {
        if let SolverEvent::Paused { metadata } = event {
            println!("paused at snapshot {:?}", metadata.snapshot_revision);
            break;
        }
    }
    MANAGER.resume(job_id).expect("resume should be accepted");
    // end page

    // page: src/docs/solverforge/solver/solver-manager.md problem change
    use solverforge::ClosureProblemChange;

    let change = MANAGER
        .add_problem_change(
            job_id,
            ClosureProblemChange::<Schedule, _>::new("raise shift 0 weight", |director| {
                director.working_solution_mut().shifts[0].weight += 5;
            }),
        )
        .expect("problem change should be queued");
    // end page

    // Applied once telemetry.problem_changes_applied reaches the id; the
    // next BestSolution carries the changed problem.
    let mut applied = false;
    let deadline = Instant::now() + Duration::from_secs(30);
    loop {
        let event = rx.blocking_recv().expect("job still running");
        let metadata = event.metadata();
        if metadata.telemetry.problem_changes_applied >= change.get() {
            applied = true;
        }
        if let SolverEvent::BestSolution { solution, .. } = &event {
            if applied {
                assert_eq!(solution.shifts[0].weight, original_weight + 5, "best solution carries the change");
                break;
            }
        }
        assert!(Instant::now() < deadline, "problem change never applied");
    }

    // page: src/docs/solverforge/solver/solver-manager.md snapshots
    let latest = MANAGER.get_snapshot(job_id, None).expect("latest snapshot");
    let exact = MANAGER
        .get_snapshot(job_id, Some(latest.snapshot_revision))
        .expect("requested snapshot");
    // end page
    assert_eq!(exact.snapshot_revision, latest.snapshot_revision);

    // page: src/docs/solverforge/solver/solver-manager.md analysis
    let analysis = MANAGER
        .analyze_snapshot(job_id, Some(latest.snapshot_revision))
        .expect("snapshot analysis");

    println!("analysis score: {:?}", analysis.analysis.score);
    // end page
    assert_eq!(analysis.snapshot_revision, latest.snapshot_revision);
    assert_eq!(analysis.lifecycle_state, SolverLifecycleState::Solving, "analysis does not end the job");

    // page: src/docs/solverforge/solver/solver-manager.md cancel
    MANAGER.cancel(job_id).expect("cancel should be accepted");
    // end page
    assert!(matches!(terminal(&mut rx), SolverEvent::Cancelled { .. }));

    // A terminal job stays retained until it is deleted.
    assert_eq!(MANAGER.active_job_count(), 1);
    // page: src/docs/solverforge/solver/solver-manager.md delete
    MANAGER.delete(job_id).expect("delete terminal job");
    // end page
    // page: src/docs/solverforge/solver/solver-manager.md active jobs
    let count = MANAGER.active_job_count();
    // end page
    assert_eq!(count, 0, "deleting the terminal job frees its slot");
}

/// resume() before the pause settles is an invalid transition.
fn resume_before_paused_is_rejected(solution: Schedule) {
    let (job_id, mut rx) = MANAGER.solve(solution).expect("solver job should start");
    until_local_search(&mut rx, 48);
    MANAGER.pause(job_id).expect("pause should be accepted");
    match MANAGER.resume(job_id) {
        Err(SolverManagerError::InvalidStateTransition { action: "resume", state: SolverLifecycleState::PauseRequested, .. }) => {
            println!("resume while PauseRequested -> InvalidStateTransition");
        }
        Ok(()) => panic!("resume accepted before Paused"),
        Err(other) => {
            // The pause can settle between the two calls; then resume is legal.
            println!("pause settled before resume: {other:?}");
        }
    }
    MANAGER.cancel(job_id).ok();
    terminal(&mut rx);
    MANAGER.delete(job_id).expect("delete terminal job");
}

/// Paused wall time is not charged to the job's time budget, and resume
/// continues the run instead of restarting it.
fn paused_time_is_not_charged(solution: Schedule) {
    let (job_id, mut rx) = MANAGER.solve(solution).expect("solver job should start");
    until_local_search(&mut rx, 48);
    MANAGER.pause(job_id).expect("pause should be accepted");
    let paused = loop {
        if let SolverEvent::Paused { metadata } = rx.blocking_recv().expect("event") {
            break metadata;
        }
    };
    let before = MANAGER.get_status(job_id).expect("status");
    assert_eq!(before.lifecycle_state, SolverLifecycleState::Paused);
    assert!(before.checkpoint_available, "a pause after construction retains a checkpoint");
    assert!(paused.snapshot_revision.is_some(), "a pause after construction has a snapshot");
    std::thread::sleep(Duration::from_millis(1500));
    let after = MANAGER.get_status(job_id).expect("status");
    let charged = after.telemetry.elapsed.saturating_sub(before.telemetry.elapsed);
    println!("1.5 s paused charged {charged:?}");
    assert!(charged < Duration::from_millis(200), "paused time charged: {charged:?}");
    MANAGER.resume(job_id).expect("resume should be accepted");
    let next = loop {
        let event = rx.blocking_recv().expect("event");
        if !matches!(event, SolverEvent::Resumed { .. }) {
            break event;
        }
    };
    assert!(
        next.metadata().telemetry.step_count >= before.telemetry.step_count,
        "resume continues from the paused step count"
    );
    MANAGER.cancel(job_id).expect("cancel should be accepted");
    terminal(&mut rx);
    MANAGER.delete(job_id).expect("delete terminal job");
}

fn solve_without_a_manager(problem: Schedule) {
    // page: src/docs/solverforge/solver/solver-manager.md solve with config
    let config = SolverConfig::from_toml_str(r#"
        random_seed = 7

        [termination]
        seconds_spent_limit = 1
    "#)
    .expect("config should parse");

    let solved = problem.solve_with_config(config).expect("solve should finish");
    println!("best score: {:?}", solved.score);
    // end page
    assert!(solved.score.is_some());
}
