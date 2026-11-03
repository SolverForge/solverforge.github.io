use solverforge::prelude::*;
use solverforge::stream::ConstraintFactory;

use super::{Operation, Route};

#[planning_solution(constraints = "define_constraints")]
pub struct JobPlan {
    #[problem_fact_collection]
    pub operations: Vec<Operation>,
    #[planning_entity_collection]
    pub routes: Vec<Route>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

fn define_constraints() -> impl ConstraintSet<JobPlan, HardSoftScore> {
    (ConstraintFactory::<JobPlan, HardSoftScore>::new()
        .for_each(JobPlan::routes())
        .penalize(|route: &Route| {
            let load: usize = route.operations.len();
            HardSoftScore::of_soft((load * load) as i64)
        })
        .named("balance"),)
}

impl JobPlan {
    /// Chains of three operations each, two routes.
    pub fn demo(operations: usize) -> Self {
        JobPlan {
            operations: (0..operations)
                .map(|id| Operation {
                    id,
                    duration: 1 + id % 4,
                    next: if id % 3 == 2 || id + 1 == operations { None } else { Some(id + 1) },
                })
                .collect(),
            routes: (0..2).map(|id| Route { id, operations: Vec::new() }).collect(),
            score: None,
        }
    }
}
