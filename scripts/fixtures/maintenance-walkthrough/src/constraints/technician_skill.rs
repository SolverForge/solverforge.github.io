use crate::domain::{Job, Plan, Technician};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::IncrementalConstraint;

/// HARD: the assigned technician must have the skill the job needs.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .join((
            Plan::technicians(),
            equal_bi(entity_join_key, fact_join_key),
        ))
        .penalize(hard_weight(join_weight))
        .named("technician_skill")
}

fn entity_join_key(job: &Job) -> Option<usize> {
    job.technician_idx
}

fn fact_join_key(technician: &Technician) -> Option<usize> {
    Some(technician.index)
}

fn join_condition(job: &Job, technician: &Technician) -> bool {
    !technician.skills.iter().any(|skill| skill == &job.skill)
}

fn join_weight(job: &Job, technician: &Technician) -> HardSoftScore {
    if join_condition(job, technician) {
        <HardSoftScore as Score>::one_hard()
    } else {
        <HardSoftScore as Score>::zero()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use solverforge::ConstraintSet;

    fn score_for(technician_idx: Option<usize>) -> HardSoftScore {
        let technicians = vec![
            Technician::new("t0", "Mechanic", 0, vec!["mechanical".to_string()]),
            Technician::new("t1", "Electrician", 1, vec!["electrical".to_string()]),
        ];
        let mut job = Job::new("j0", 0, "electrical".to_string(), 0, 9);
        job.technician_idx = technician_idx;
        job.day = Some(0);
        let plan = Plan::new(technicians, vec![], vec![job]);
        (constraint(),).evaluate_all(&plan)
    }

    #[test]
    fn penalizes_technician_without_skill() {
        assert_eq!(score_for(Some(0)), HardSoftScore::of_hard(-1));
    }

    #[test]
    fn ignores_skilled_or_unassigned_technician() {
        assert_eq!(score_for(Some(1)), HardSoftScore::ZERO);
        assert_eq!(score_for(None), HardSoftScore::ZERO);
    }
}
