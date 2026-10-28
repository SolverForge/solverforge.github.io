//! Depot demo data: 12 buses, 20 one-day maintenance jobs, 4 technicians, and a
//! 10 working-day horizon (days 0..=9). Deterministic; a zero-hard plan exists
//! (see the `reference_plan_is_feasible` test).

use crate::domain::{Bus, Job, Plan, Technician};

const MECHANICAL: &str = "mechanical";
const ELECTRICAL: &str = "electrical";
const BODYWORK: &str = "bodywork";

const BUS_COUNT: usize = 12;

/// (name, skills)
const TECHNICIANS: &[(&str, &[&str])] = &[
    ("Alice", &[MECHANICAL, ELECTRICAL]),
    ("Ben", &[MECHANICAL, BODYWORK]),
    ("Chloe", &[ELECTRICAL, BODYWORK]),
    ("Dev", &[MECHANICAL]),
];

/// (bus index, skill, earliest day parts arrive, due day)
const JOBS: &[(usize, &str, usize, usize)] = &[
    (0, MECHANICAL, 0, 2),
    (0, ELECTRICAL, 0, 3),
    (1, BODYWORK, 0, 3),
    (2, MECHANICAL, 1, 4),
    (2, BODYWORK, 1, 4),
    (3, ELECTRICAL, 2, 5),
    (4, MECHANICAL, 2, 5),
    (5, BODYWORK, 3, 6),
    (5, ELECTRICAL, 3, 6),
    (6, MECHANICAL, 4, 7),
    (7, ELECTRICAL, 4, 7),
    (7, BODYWORK, 5, 8),
    (8, MECHANICAL, 5, 8),
    (9, ELECTRICAL, 6, 9),
    (9, MECHANICAL, 6, 9),
    (10, BODYWORK, 7, 9),
    (11, MECHANICAL, 7, 9),
    (11, ELECTRICAL, 8, 9),
    (3, BODYWORK, 8, 9),
    (6, ELECTRICAL, 2, 9),
];

pub fn depot_plan() -> Plan {
    let technicians = TECHNICIANS
        .iter()
        .enumerate()
        .map(|(idx, (name, skills))| {
            Technician::new(
                format!("tech-{idx}"),
                *name,
                idx,
                skills.iter().map(|skill| skill.to_string()).collect(),
            )
        })
        .collect();

    let buses = (0..BUS_COUNT)
        .map(|idx| Bus::new(format!("bus-{idx}"), format!("Bus {:03}", 101 + idx), idx))
        .collect();

    let jobs = JOBS
        .iter()
        .enumerate()
        .map(|(idx, (bus_idx, skill, earliest_day, due_day))| {
            Job::new(format!("job-{idx}"), *bus_idx, skill.to_string(), *earliest_day, *due_day)
        })
        .collect();

    Plan::new(technicians, buses, jobs)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::constraints::create_constraints;
    use solverforge::prelude::*;
    use solverforge::ConstraintSet;

    #[test]
    fn matches_the_depot_description() {
        let plan = depot_plan();
        assert_eq!(plan.buses.len(), 12);
        assert_eq!(plan.jobs.len(), 20);
        assert_eq!(plan.technicians.len(), 4);
        for job in &plan.jobs {
            assert!(job.bus_idx < plan.buses.len());
            assert!(job.earliest_day <= job.due_day && job.due_day < 10);
        }
    }

    #[test]
    fn unsolved_plan_violates_assignment() {
        let score = create_constraints().evaluate_all(&depot_plan());
        assert_eq!(score.hard(), -20);
    }

    /// Hand-built schedule proving the demo is feasible with no late jobs.
    #[test]
    fn reference_plan_is_feasible() {
        // (technician, day) per job, in JOBS order.
        const REFERENCE: [(usize, usize); 20] = [
            (3, 0), (0, 0), (1, 0), (3, 1), (2, 1),
            (0, 2), (3, 2), (1, 3), (2, 3), (3, 4),
            (0, 4), (1, 5), (3, 5), (0, 6), (3, 6),
            (1, 7), (3, 7), (0, 8), (2, 8), (2, 4),
        ];
        let mut plan = depot_plan();
        for (job, (technician_idx, day)) in plan.jobs.iter_mut().zip(REFERENCE) {
            job.technician_idx = Some(technician_idx);
            job.day = Some(day);
        }
        let score = create_constraints().evaluate_all(&plan);
        assert_eq!(score.hard(), 0);
        // Only the balance penalty remains: loads 5/4/4/7 → 25+16+16+49.
        assert_eq!(score, HardSoftScore::of_soft(-106));
    }
}
