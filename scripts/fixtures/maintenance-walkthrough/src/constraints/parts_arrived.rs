use crate::domain::{Job, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: a job cannot be scheduled before its parts arrive.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .penalize(hard_weight(unary_weight))
        .named("parts_arrived")
}

fn unary_condition(job: &Job) -> bool {
    job.day.is_some_and(|day| day < job.earliest_day)
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

    fn score_for(day: Option<usize>) -> HardSoftScore {
        let mut job = Job::new("j0", 0, "mechanical".to_string(), 3, 9);
        job.day = day;
        (constraint(),).evaluate_all(&Plan::new(vec![], vec![], vec![job]))
    }

    #[test]
    fn penalizes_job_before_parts_arrive() {
        assert_eq!(score_for(Some(2)), HardSoftScore::of_hard(-1));
    }

    #[test]
    fn ignores_job_on_or_after_arrival_or_unscheduled() {
        assert_eq!(score_for(Some(3)), HardSoftScore::ZERO);
        assert_eq!(score_for(Some(7)), HardSoftScore::ZERO);
        assert_eq!(score_for(None), HardSoftScore::ZERO);
    }
}
