use std::time::Duration;

use solverforge::{SolverConfig, SolverEvent, SolverManager};

use super::{solve_to_end, terminal};
use crate::domain::Schedule;
use crate::{probe, probe_config, visits};

static PROBE: SolverManager<probe::Plan> = SolverManager::new();
static ROUTES: SolverManager<visits::RoutePlan> = SolverManager::new();

pub fn run() {
    time_limits_add_up();
    fallback_time_guard();
    omitted_phases_need_a_limit();
    cancel(Schedule::demo(24, 30));
}

/// The installed time guard of a retained run, read from its candidate-trace
/// header: (effective limit in seconds, where it came from).
fn installed_time_guard<S: solverforge::Solvable>(manager: &'static SolverManager<S>, solution: S, toml: &str) -> (f64, String) {
    probe_config::set(SolverConfig::from_toml_str(toml).expect("probe config"));
    let (job_id, mut rx) = manager.solve(solution).expect("solver job should start");
    let event = terminal(&mut rx);
    assert!(matches!(event, SolverEvent::Completed { .. }), "probe run must complete");
    let detail = manager.get_telemetry_detail(job_id).expect("telemetry detail");
    manager.delete(job_id).expect("delete terminal job");
    let trace = detail.candidate_trace.expect("candidate trace enabled");
    let attribute = |key: &str| {
        trace
            .header
            .execution_policy
            .attributes
            .iter()
            .find(|attribute| attribute.key == key)
            .unwrap_or_else(|| panic!("no {key} attribute"))
            .value
            .clone()
    };
    let nanos: f64 = attribute("effective_time_limit_ns").parse().expect("nanoseconds");
    (nanos / 1e9, attribute("time_limit_source"))
}

/// `seconds_spent_limit` and `minutes_spent_limit` are one budget: they add.
fn time_limits_add_up() {
    let (seconds, source) = installed_time_guard(
        &PROBE,
        probe::Plan::demo(12),
        "[candidate_trace]\nmax_entries = 1\n\n[termination]\nminutes_spent_limit = 1\nseconds_spent_limit = 30\nstep_count_limit = 50\n",
    );
    println!("minutes 1 + seconds 30 -> {seconds} s ({source})");
    assert_eq!(seconds, 90.0);
    assert_eq!(source, "configured");
}

/// A work criterion without a time limit runs under a fallback guard: 30 s on
/// a scalar-only model, 60 s on a model with a list variable.
fn fallback_time_guard() {
    let toml = "[candidate_trace]\nmax_entries = 1\n\n[termination]\nstep_count_limit = 50\n";
    let (scalar, source) = installed_time_guard(&PROBE, probe::Plan::demo(12), toml);
    println!("step limit only, scalar model -> {scalar} s ({source})");
    assert_eq!(scalar, 30.0);
    assert_eq!(source, "configured_entrypoint_fallback");
    let (list, source) = installed_time_guard(&ROUTES, visits::RoutePlan::demo(12), toml);
    println!("step limit only, list model -> {list} s ({source})");
    assert_eq!(list, 60.0);
    assert_eq!(source, "configured_entrypoint_fallback");
}

/// With phases omitted, local search follows construction only when
/// top-level termination holds a limit.
fn omitted_phases_need_a_limit() {
    for (toml, expected) in [("", 1), ("[termination]\n", 1), ("[termination]\nstep_count_limit = 50\n", 2)] {
        probe_config::set(SolverConfig::from_toml_str(toml).expect("probe config"));
        match solve_to_end(&PROBE, probe::Plan::demo(12)) {
            SolverEvent::Completed { metadata, .. } => {
                let phases: Vec<_> = metadata.telemetry.phases.iter().map(|p| p.phase_type.clone()).collect();
                let selectors: Vec<_> =
                    metadata.telemetry.selector_telemetry.iter().map(|s| s.selector_label.clone()).collect();
                println!("omitted phases with {toml:?} -> {phases:?} selectors {selectors:?}");
                assert_eq!(phases.len(), expected, "{toml:?}");
            }
            other => panic!("expected Completed, got {:?}", other.metadata().lifecycle_state),
        }
    }
}

fn cancel(problem: Schedule) {
    // page: src/docs/solverforge/solver/termination.md cancel
    use solverforge::SolverManager;

    static MANAGER: SolverManager<Schedule> = SolverManager::new();

    let (job_id, rx) = MANAGER.solve(problem).expect("solver job should start");

    // Later...
    MANAGER.cancel(job_id).expect("cancel should be accepted");
    // end page
    let mut rx = rx;
    let event = terminal(&mut rx);
    assert!(matches!(event, SolverEvent::Cancelled { .. }), "cancel ends the job as Cancelled");
    MANAGER.delete(job_id).expect("delete cancelled job");
    let _ = Duration::ZERO;
}
