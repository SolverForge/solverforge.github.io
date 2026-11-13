use solverforge::cvrp::{EuclideanMetric, ProblemData, VrpSolution};
use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::stream::ConstraintFactory;

#[problem_fact]
pub struct Stop {
    #[planning_id]
    pub id: usize,
}

#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    #[planning_list_variable(element_collection = "stop_locations", domain = "cvrp")]
    pub visits: Vec<usize>,
}

/// A stock `domain = "cvrp"` plan on `EuclideanMetric`, so the profile's
/// Clarke-Wright savings and neighbour hooks are the ones the pages describe.
#[planning_solution(constraints = "define_constraints")]
pub struct VehiclePlan {
    pub routing: ProblemData<EuclideanMetric>,
    #[problem_fact_collection]
    pub stops: Vec<Stop>,
    #[planning_list_element_collection(owner = "vehicles")]
    pub stop_locations: Vec<usize>,
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

impl VrpSolution for VehiclePlan {
    type Metric = EuclideanMetric;

    fn vehicle_data(&self, _vehicle: usize) -> Option<&ProblemData<EuclideanMetric>> {
        Some(&self.routing)
    }

    fn vehicle_visits(&self, vehicle: usize) -> &[usize] {
        &self.vehicles[vehicle].visits
    }

    fn vehicle_visits_mut(&mut self, vehicle: usize) -> &mut Vec<usize> {
        &mut self.vehicles[vehicle].visits
    }

    fn vehicle_count(&self) -> usize {
        self.vehicles.len()
    }
}

fn define_constraints() -> impl ConstraintSet<VehiclePlan, HardSoftScore> {
    (ConstraintFactory::<VehiclePlan, HardSoftScore>::new()
        .for_each(VehiclePlan::stops())
        .if_not_exists((
            ConstraintFactory::<VehiclePlan, HardSoftScore>::new()
                .for_each(VehiclePlan::vehicles())
                .flattened(|vehicle: &Vehicle| &vehicle.visits),
            equal_bi(|stop: &Stop| stop.id, |location: &usize| *location),
        ))
        .penalize(HardSoftScore::ONE_HARD)
        .named("unrouted stop"),)
}

impl VehiclePlan {
    /// A depot at the origin, `stops` stops on a spiral around it, and
    /// three vehicles.
    pub fn demo(stops: usize) -> Self {
        let coordinates: Vec<(f64, f64)> = std::iter::once((0.0, 0.0))
            .chain((1..=stops).map(|stop| {
                let angle = stop as f64 * 2.4;
                let radius = 2.0 + stop as f64 * 0.5;
                (radius * angle.cos(), radius * angle.sin())
            }))
            .collect();
        let locations = coordinates.len();
        VehiclePlan {
            routing: ProblemData {
                capacity: stops as i64,
                depot: 0,
                demands: std::iter::once(0).chain(std::iter::repeat_n(1, stops)).collect(),
                metric: EuclideanMetric::new(coordinates, 1.0),
                time_windows: vec![(0, i64::MAX); locations],
                service_durations: vec![0; locations],
                vehicle_departure_time: 0,
            },
            stops: (1..locations).map(|id| Stop { id }).collect(),
            stop_locations: (1..locations).collect(),
            vehicles: (0..3).map(|id| Vehicle { id, visits: Vec::new() }).collect(),
            score: None,
        }
    }
}
