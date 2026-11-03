use solverforge::prelude::*;

use super::JobPlan;

#[planning_entity]
pub struct Route {
    #[planning_id]
    pub id: usize,

    #[planning_list_variable(
        element_collection = "operations",
        precedence_duration_fn = "operation_duration",
        precedence_successors_fn = "operation_successors"
    )]
    pub operations: Vec<usize>,
}

pub(super) fn operation_duration(plan: &JobPlan, operation: usize) -> usize {
    plan.operations[operation].duration
}

pub(super) fn operation_successors(plan: &JobPlan, operation: usize, out: &mut Vec<usize>) {
    if let Some(next) = plan.operations[operation].next {
        out.push(next);
    }
}
