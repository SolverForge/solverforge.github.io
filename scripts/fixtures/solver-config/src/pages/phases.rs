//! The Phases page's resolved phase plan, and the defaults the Construction,
//! Local Search and List Move Selectors pages state for a list with element
//! groups, read from that plan.

use solverforge::{CandidateTracePhasePlan, SolverConfig, SolverEvent, SolverManager};

use crate::{probe_config, rides};

static RIDES: SolverManager<rides::Rides> = SolverManager::new();

pub fn run() {
    probe_config::set(
        SolverConfig::from_toml_str("random_seed = 7\n\n[termination]\nstep_count_limit = 20\n")
            .expect("probe config"),
    );
    let (job_id, mut rx) = RIDES.solve(rides::Rides::demo(8)).expect("solver job should start");
    let plan = loop {
        match rx.blocking_recv().expect("event stream reaches a terminal event") {
            SolverEvent::Progress { metadata } | SolverEvent::BestSolution { metadata, .. } => {
                assert!(
                    metadata.telemetry.resolved_phase_plan.is_none(),
                    "the resolved plan is set only when the solve ends"
                );
            }
            SolverEvent::Completed { metadata, .. } => {
                break metadata.telemetry.resolved_phase_plan.expect("a completed solve reports its plan");
            }
            SolverEvent::Failed { error, .. } => panic!("solve failed: {error}"),
            SolverEvent::Cancelled { .. } => panic!("solve was cancelled"),
            _ => {}
        }
    };
    RIDES.delete(job_id).expect("delete terminal job");
    assert!(plan.is_complete(), "{plan:#?}");

    let construction = nodes(&plan)
        .into_iter()
        .find(|node| attribute(node, "reason").is_some())
        .unwrap_or_else(|| panic!("no construction reason: {plan:#?}"));
    println!("construction {} reason {}", construction.kind, attribute(construction, "reason").unwrap());
    assert_eq!(attribute(construction, "reason"), Some("element_groups_declared"));

    let search = nodes(&plan)
        .into_iter()
        .find(|node| node.kind == "solverforge.runtime.default_local_search")
        .unwrap_or_else(|| panic!("no default local search: {plan:#?}"));
    for key in ["acceptor", "forager_accepted_count_limit", "selection_order", "weighting"] {
        println!("local search {key} {}", attribute(search, key).unwrap_or("-"));
    }
    assert_eq!(attribute(search, "acceptor"), Some("late_acceptance"));
    assert_eq!(attribute(search, "forager_accepted_count_limit"), Some("4"));
    let rendered = format!("{search:?}");
    assert!(
        rendered.contains("max_member_distance=Some(7),max_group_owners=Some(4)"),
        "a grouped list gets its own ruin bounds: {search:#?}"
    );
    for family in ["list_group_change", "list_group_swap"] {
        assert!(rendered.contains(family), "default search lacks {family}: {search:#?}");
    }
}

fn nodes(plan: &CandidateTracePhasePlan) -> Vec<&CandidateTracePhasePlan> {
    let mut all = vec![plan];
    for child in &plan.children {
        all.extend(nodes(child));
    }
    all
}

fn attribute<'a>(node: &'a CandidateTracePhasePlan, key: &str) -> Option<&'a str> {
    node.attributes.iter().find(|attribute| attribute.key == key).map(|attribute| attribute.value.as_str())
}
