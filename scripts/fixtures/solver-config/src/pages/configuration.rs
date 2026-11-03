#![allow(unused_imports)]

use std::time::{Duration, Instant};

use solverforge::{EnvironmentMode, MoveThreadCount, SolverEvent, SolverManager, SolverTerminalReason};

use super::terminal;
use crate::domain::Schedule;

// page: src/docs/solverforge/solver/configuration.md imports
use solverforge::{
    AcceptorConfig, CandidateTraceConfig, ForagerConfig, MoveSelectorConfig, PhaseConfig,
    SolverConfig, SolverConfigOverride,
};
// end page

static MANAGER: SolverManager<Schedule> = SolverManager::new();

pub fn run() {
    from_string();
    builders();
    embedded_file_and_callback();
    // The construction page's explicit-limits group builds.
    let _group = crate::grouped::group_with_limits();
}

fn from_string() {
    // page: src/docs/solverforge/solver/configuration.md from a TOML string
    let config = SolverConfig::from_toml_str(r#"
        environment_mode = "reproducible"
        move_thread_count = { count = 4 }

        [termination]
        seconds_spent_limit = 120

        [[phases]]
        type = "construction_heuristic"
        construction_heuristic_type = "first_fit"

        [[phases]]
        type = "local_search"
        [phases.acceptor]
        type = "late_acceptance"
        late_acceptance_size = 400
    "#).expect("config should parse");
    // end page
    assert_eq!(config.environment_mode, EnvironmentMode::Reproducible);
    assert_eq!(config.move_thread_count, MoveThreadCount::Count(4));
    assert_eq!(config.time_limit(), Some(Duration::from_secs(120)));
    assert_eq!(config.phases.len(), 2);
}

/// `SolverConfig::load` reads a path relative to the working directory; the
/// gate runs this with the page's example file there.
pub fn load() {
    // page: src/docs/solverforge/solver/configuration.md from a TOML file
    let config = SolverConfig::load("solver.toml").expect("solver.toml should parse");
    // end page
    assert_eq!(config.phases.len(), 2);
    assert_eq!(config.time_limit(), Some(Duration::from_secs(300)));
}

fn builders() {
    // page: src/docs/solverforge/solver/configuration.md builders
    let config = SolverConfig::new()
        .with_random_seed(42)
        .with_termination_seconds(30);
    // end page
    assert_eq!(config.random_seed, Some(42));
    assert_eq!(config.time_limit(), Some(Duration::from_secs(30)));
}

/// Solves with the embedded `solver_toml` and the `config` callback, and
/// returns the terminal telemetry's selector labels and phase count.
fn retained_solve(time_limit_secs: u64) -> (Vec<String>, usize, Option<SolverTerminalReason>, f64) {
    let started = Instant::now();
    let (job_id, mut rx) = MANAGER.solve(Schedule::demo(24, time_limit_secs)).expect("solver job should start");
    let event = terminal(&mut rx);
    let wall = started.elapsed().as_secs_f64();
    MANAGER.delete(job_id).expect("delete terminal job");
    match event {
        SolverEvent::Completed { metadata, .. } => (
            metadata.telemetry.selector_telemetry.iter().map(|s| s.selector_label.clone()).collect(),
            metadata.telemetry.phases.len(),
            metadata.terminal_reason,
            wall,
        ),
        other => panic!("expected Completed, got {:?}", other.metadata().lifecycle_state),
    }
}

/// The solution names `solver_toml = "../../solver.toml"` (the page's example
/// file: construction, then local search over `change_move_selector` only) and
/// a callback that sets the time limit from `time_limit_secs`.
fn embedded_file_and_callback() {
    let (labels, phases, reason, wall) = retained_solve(2);
    println!("embedded solve: phases={phases} selectors={labels:?} reason={reason:?} wall={wall:.2}s");
    assert_eq!(phases, 2, "the embedded file has two phases");
    assert!(!labels.is_empty(), "local search ran");
    assert!(
        labels.iter().all(|label| !label.to_lowercase().contains("swap")),
        "the embedded local search uses change moves only, not the default union: {labels:?}"
    );
    assert_eq!(reason, Some(SolverTerminalReason::TerminatedByConfig));
    assert!((1.8..6.0).contains(&wall), "callback's 2 s limit replaces the file's 300 s, took {wall:.2}s");
}

/// The gate runs this from a directory whose solver.toml holds a single
/// construction phase. A retained solve must not read it.
pub fn cwd_ignored() {
    let cwd_file = std::fs::read_to_string("solver.toml").expect("gate writes ./solver.toml");
    let cwd_config = SolverConfig::from_toml_str(&cwd_file).expect("cwd file is valid TOML");
    assert_eq!(cwd_config.phases.len(), 1);
    let (labels, phases, reason, _) = retained_solve(1);
    println!("solve beside a one-phase ./solver.toml: phases={phases} selectors={labels:?}");
    assert_eq!(phases, 2, "./solver.toml must not replace the embedded file");
    assert_eq!(reason, Some(SolverTerminalReason::TerminatedByConfig));
}
