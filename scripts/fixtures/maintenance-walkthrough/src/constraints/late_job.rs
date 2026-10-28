use crate::domain::{Job, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// Soft points per day a job finishes after its due day. Weighted above the
/// workload-balance penalty so meeting due days takes priority over evenness.
const SOFT_PER_LATE_DAY: i64 = 10;

/// SOFT: finish jobs by their due day; penalize each day late.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .penalize(unary_weight)
        .named("late_job")
}

fn days_late(job: &Job) -> usize {
    job.day.map_or(0, |day| day.saturating_sub(job.due_day))
}

fn unary_weight(job: &Job) -> HardSoftScore {
    HardSoftScore::of_soft(days_late(job) as i64 * SOFT_PER_LATE_DAY)
}

#[cfg(test)]
mod tests {
    use super::*;
    use solverforge::ConstraintSet;

    fn score_for(day: Option<usize>) -> HardSoftScore {
        let mut job = Job::new("j0", 0, "mechanical".to_string(), 0, 4);
        job.day = day;
        (constraint(),).evaluate_all(&Plan::new(vec![], vec![], vec![job]))
    }

    #[test]
    fn penalizes_each_day_late() {
        assert_eq!(score_for(Some(5)), HardSoftScore::of_soft(-SOFT_PER_LATE_DAY));
        assert_eq!(score_for(Some(7)), HardSoftScore::of_soft(-3 * SOFT_PER_LATE_DAY));
    }

    #[test]
    fn ignores_on_time_or_unscheduled_job() {
        assert_eq!(score_for(Some(4)), HardSoftScore::ZERO);
        assert_eq!(score_for(Some(0)), HardSoftScore::ZERO);
        assert_eq!(score_for(None), HardSoftScore::ZERO);
    }
}
