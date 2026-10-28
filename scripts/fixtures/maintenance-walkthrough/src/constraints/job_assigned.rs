use crate::domain::{Job, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: every job gets a technician and a day.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .penalize(hard_weight(unary_weight))
        .named("job_assigned")
}

fn unary_condition(job: &Job) -> bool {
    job.technician_idx.is_none() || job.day.is_none()
}

fn unary_weight(job: &Job) -> HardSoftScore {
    if unary_condition(job) {
        <HardSoftScore as Score>::one_hard()
    } else {
        <HardSoftScore as Score>::zero()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use solverforge::ConstraintSet;

    fn score_for(technician_idx: Option<usize>, day: Option<usize>) -> HardSoftScore {
        let mut job = Job::new("j0", 0, "mechanical".to_string(), 0, 9);
        job.technician_idx = technician_idx;
        job.day = day;
        (constraint(),).evaluate_all(&Plan::new(vec![], vec![], vec![job]))
    }

    #[test]
    fn penalizes_missing_technician_or_day() {
        assert_eq!(score_for(None, Some(1)), HardSoftScore::of_hard(-1));
        assert_eq!(score_for(Some(0), None), HardSoftScore::of_hard(-1));
        assert_eq!(score_for(None, None), HardSoftScore::of_hard(-1));
    }

    #[test]
    fn ignores_fully_assigned_job() {
        assert_eq!(score_for(Some(0), Some(1)), HardSoftScore::ZERO);
    }
}
