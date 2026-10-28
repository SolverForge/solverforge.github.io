use crate::domain::{Job, Plan};
use solverforge::prelude::*;
use solverforge::stream::collector::LoadBalance;
use solverforge::IncrementalConstraint;

/// SOFT: spread work evenly across technicians.
///
/// Penalizes the sum of squared job counts per technician. With a fixed number
/// of jobs this is smallest when the counts are equal (20 jobs over 4
/// technicians: 5+5+5+5 → 100), and moving one job from a busy technician to an
/// idle one always improves it.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .group_by(
            balance_scope,
            load_balance(balance_group_key, balance_metric),
        )
        .penalize(balance_weight)
        .named("balanced_workload")
}

fn balance_scope(_job: &Job) -> usize {
    0
}

fn balance_group_key(job: &Job) -> Option<usize> {
    job.technician_idx
}

fn balance_metric(_job: &Job) -> i64 {
    1
}

fn balance_weight(_scope: &usize, load: &LoadBalance<Option<usize>>) -> HardSoftScore {
    let squared_loads = load
        .loads()
        .iter()
        .filter(|(technician_idx, _)| technician_idx.is_some())
        .map(|(_, jobs)| jobs * jobs)
        .sum();
    HardSoftScore::of_soft(squared_loads)
}

#[cfg(test)]
mod tests {
    use super::*;
    use solverforge::ConstraintSet;

    fn score_for(assignments: &[Option<usize>]) -> HardSoftScore {
        let jobs = assignments
            .iter()
            .enumerate()
            .map(|(idx, technician_idx)| {
                let mut job = Job::new(format!("j{idx}"), idx, "mechanical".to_string(), 0, 9);
                job.technician_idx = *technician_idx;
                job.day = Some(0);
                job
            })
            .collect();
        (constraint(),).evaluate_all(&Plan::new(vec![], vec![], jobs))
    }

    #[test]
    fn even_spread_scores_better_than_uneven() {
        // 2 + 2 → 4 + 4 = 8
        assert_eq!(score_for(&[Some(0), Some(0), Some(1), Some(1)]), HardSoftScore::of_soft(-8));
        // 3 + 1 → 9 + 1 = 10
        assert_eq!(score_for(&[Some(0), Some(0), Some(0), Some(1)]), HardSoftScore::of_soft(-10));
    }

    #[test]
    fn ignores_unassigned_jobs() {
        assert_eq!(score_for(&[Some(0), None, None]), HardSoftScore::of_soft(-1));
    }
}
