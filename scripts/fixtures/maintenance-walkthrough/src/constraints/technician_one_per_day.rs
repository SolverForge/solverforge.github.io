use crate::domain::{Job, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// HARD: a technician does at most one job per day.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .join(joiner::equal(technician_idx_join_key))
        .penalize(hard_weight(pair_weight))
        .named("technician_one_per_day")
}

fn technician_idx_join_key(job: &Job) -> Option<usize> {
    job.technician_idx
}

fn pair_condition(left: &Job, right: &Job) -> bool {
    left.technician_idx.is_some() && left.day.is_some() && left.day == right.day
}

fn pair_weight(left: &Job, right: &Job) -> HardSoftScore {
    if pair_condition(left, right) {
        <HardSoftScore as Score>::one_hard()
    } else {
        <HardSoftScore as Score>::zero()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::Technician;
    use solverforge::ConstraintSet;

    fn job(id: &str, technician_idx: Option<usize>, day: Option<usize>) -> Job {
        let mut job = Job::new(id, 0, "mechanical".to_string(), 0, 9);
        job.technician_idx = technician_idx;
        job.day = day;
        job
    }

    fn score_for(jobs: Vec<Job>) -> HardSoftScore {
        let technicians = vec![
            Technician::new("t0", "A", 0, vec!["mechanical".to_string()]),
            Technician::new("t1", "B", 1, vec!["mechanical".to_string()]),
        ];
        (constraint(),).evaluate_all(&Plan::new(technicians, vec![], jobs))
    }

    #[test]
    fn penalizes_each_same_day_pair_once() {
        let jobs = vec![job("a", Some(0), Some(2)), job("b", Some(0), Some(2))];
        assert_eq!(score_for(jobs), HardSoftScore::of_hard(-1));
        let jobs = vec![
            job("a", Some(0), Some(2)),
            job("b", Some(0), Some(2)),
            job("c", Some(0), Some(2)),
        ];
        assert_eq!(score_for(jobs), HardSoftScore::of_hard(-3));
    }

    #[test]
    fn ignores_other_day_other_technician_or_unassigned() {
        let jobs = vec![job("a", Some(0), Some(2)), job("b", Some(0), Some(3))];
        assert_eq!(score_for(jobs), HardSoftScore::ZERO);
        let jobs = vec![job("a", Some(0), Some(2)), job("b", Some(1), Some(2))];
        assert_eq!(score_for(jobs), HardSoftScore::ZERO);
        let jobs = vec![job("a", None, Some(2)), job("b", None, Some(2))];
        assert_eq!(score_for(jobs), HardSoftScore::ZERO);
        let jobs = vec![job("a", Some(0), None), job("b", Some(0), None)];
        assert_eq!(score_for(jobs), HardSoftScore::ZERO);
    }
}
