use std::collections::HashSet;

use crate::domain::{Job, Plan};
use solverforge::prelude::*;
use solverforge::IncrementalConstraint;

/// Most buses that may be in the workshop on one day (12 buses, 10 must stay in service).
const MAX_BUSES_IN_WORKSHOP: usize = 2;

/// HARD: at most two different buses are in the workshop on any day.
///
/// Penalizes one hard point per bus over the limit on each day.
pub fn constraint() -> impl IncrementalConstraint<Plan, HardSoftScore> {
    ConstraintFactory::<Plan, HardSoftScore>::new()
        .for_each(Plan::jobs())
        .filter(has_day)
        .group_by(day_group_key, collect_vec(collected_bus))
        .penalize(hard_weight(collected_values_weight))
        .named("workshop_capacity")
}

fn has_day(job: &Job) -> bool {
    job.day.is_some()
}

fn day_group_key(job: &Job) -> usize {
    job.day.unwrap_or(usize::MAX)
}

fn collected_bus(job: &Job) -> usize {
    job.bus_idx
}

fn buses_over_limit(buses: &CollectedVec<usize>) -> usize {
    let distinct = buses.iter().collect::<HashSet<_>>().len();
    distinct.saturating_sub(MAX_BUSES_IN_WORKSHOP)
}

fn collected_values_weight(_day: &usize, buses: &CollectedVec<usize>) -> HardSoftScore {
    HardSoftScore::of_hard(buses_over_limit(buses) as i64)
}

#[cfg(test)]
mod tests {
    use super::*;
    use solverforge::ConstraintSet;

    fn job(id: &str, bus_idx: usize, day: Option<usize>) -> Job {
        let mut job = Job::new(id, bus_idx, "mechanical".to_string(), 0, 9);
        job.day = day;
        job
    }

    fn score_for(jobs: Vec<Job>) -> HardSoftScore {
        (constraint(),).evaluate_all(&Plan::new(vec![], vec![], jobs))
    }

    #[test]
    fn penalizes_each_bus_over_the_limit() {
        let jobs = vec![job("a", 0, Some(1)), job("b", 1, Some(1)), job("c", 2, Some(1))];
        assert_eq!(score_for(jobs), HardSoftScore::of_hard(-1));
        let jobs = vec![
            job("a", 0, Some(1)),
            job("b", 1, Some(1)),
            job("c", 2, Some(1)),
            job("d", 3, Some(1)),
        ];
        assert_eq!(score_for(jobs), HardSoftScore::of_hard(-2));
    }

    #[test]
    fn counts_distinct_buses_per_day() {
        // Three jobs, but only two different buses on day 1.
        let jobs = vec![job("a", 0, Some(1)), job("b", 0, Some(1)), job("c", 1, Some(1))];
        assert_eq!(score_for(jobs), HardSoftScore::ZERO);
        // Three buses spread over two days.
        let jobs = vec![job("a", 0, Some(1)), job("b", 1, Some(1)), job("c", 2, Some(2))];
        assert_eq!(score_for(jobs), HardSoftScore::ZERO);
        // Unscheduled jobs are not in the workshop.
        let jobs = vec![job("a", 0, Some(1)), job("b", 1, Some(1)), job("c", 2, None)];
        assert_eq!(score_for(jobs), HardSoftScore::ZERO);
    }
}
