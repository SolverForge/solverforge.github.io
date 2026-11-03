use solverforge::prelude::*;
use solverforge::stream::ConstraintFactory;

use super::{Task, Worker};

/// A scalar-only model whose retained solves run exactly the config the
/// scenario installs with `crate::probe_config::set`.
#[planning_solution(constraints = "define_constraints", config = "crate::probe_config::apply")]
pub struct Plan {
    #[problem_fact_collection]
    pub workers: Vec<Worker>,
    #[planning_entity_collection]
    pub tasks: Vec<Task>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

fn define_constraints() -> impl ConstraintSet<Plan, HardSoftScore> {
    (
        ConstraintFactory::<Plan, HardSoftScore>::new()
            .for_each(Plan::tasks())
            .filter(|task: &Task| task.worker.is_none())
            .penalize(HardSoftScore::of(1, 0))
            .named("unassigned task"),
        ConstraintFactory::<Plan, HardSoftScore>::new()
            .for_each(Plan::tasks())
            .filter(|task: &Task| task.worker.is_some())
            .penalize(|task: &Task| {
                HardSoftScore::of(0, ((task.id * 7 + task.worker.unwrap_or_default() * 3) % 11) as i64)
            })
            .named("preference"),
    )
}

impl Plan {
    pub fn demo(tasks: usize) -> Self {
        Plan {
            workers: (0..5).map(|id| Worker { id }).collect(),
            tasks: (0..tasks).map(|id| Task { id, worker: None }).collect(),
            score: None,
        }
    }
}
