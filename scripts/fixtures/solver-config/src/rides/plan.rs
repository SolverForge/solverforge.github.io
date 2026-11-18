use solverforge::prelude::*;
use solverforge::stream::joiner::equal_bi;
use solverforge::stream::ConstraintFactory;

#[problem_fact]
pub struct Stop {
    #[planning_id]
    pub id: usize,
    pub ride: Option<usize>,
    pub pickup: bool,
    pub location: i64,
    pub vehicle: Option<usize>,
    pub index: Option<usize>,
    pub previous: Option<usize>,
}

#[planning_entity]
pub struct Vehicle {
    #[planning_id]
    pub id: usize,
    #[planning_list_variable(element_collection = "stops", element_group_fn = "ride_stops")]
    pub stops: Vec<usize>,
}

/// A ride's pick-up and drop-off, in that order; a single stop has no group.
pub(super) fn ride_stops(plan: &super::Rides, stop: usize, members: &mut Vec<usize>) {
    if let Some(ride) = plan.stops[stop].ride {
        members.extend([2 * ride, 2 * ride + 1]);
    }
}

/// The element-group plan of the list pages: rides whose pick-up and drop-off
/// travel together, so group selectors and joint construction have groups.
#[planning_solution(constraints = "define_constraints", config = "crate::probe_config::apply")]
#[shadow_variable_updates(
    list_owner = "vehicles",
    inverse_field = "vehicle",
    index_field = "index",
    previous_field = "previous"
)]
pub struct Rides {
    #[planning_entity_collection]
    pub vehicles: Vec<Vehicle>,
    #[problem_fact_collection]
    pub stops: Vec<Stop>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

fn define_constraints() -> impl ConstraintSet<Rides, HardSoftScore> {
    (
        ConstraintFactory::<Rides, HardSoftScore>::new()
            .for_each(Rides::stops())
            .filter(|stop: &Stop| stop.vehicle.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("unassigned stop"),
        ConstraintFactory::<Rides, HardSoftScore>::new()
            .for_each(Rides::stops())
            .filter(|stop: &Stop| stop.pickup)
            .join((
                ConstraintFactory::<Rides, HardSoftScore>::new().for_each(Rides::stops()),
                equal_bi(|pickup: &Stop| pickup.ride, |stop: &Stop| stop.ride),
            ))
            .filter(|pickup: &Stop, dropoff: &Stop| {
                !dropoff.pickup && pickup.index > dropoff.index
            })
            .penalize(HardSoftScore::ONE_HARD)
            .named("drop-off before pick-up"),
        ConstraintFactory::<Rides, HardSoftScore>::new()
            .for_each(Rides::stops())
            .join((
                ConstraintFactory::<Rides, HardSoftScore>::new().for_each(Rides::stops()),
                equal_bi(|stop: &Stop| stop.previous, |before: &Stop| Some(before.id)),
            ))
            .penalize(|stop: &Stop, before: &Stop| {
                HardSoftScore::of_soft((stop.location - before.location).abs())
            })
            .named("driving"),
    )
}

impl Rides {
    /// `rides` rides on a line plus two single stops, and three vehicles.
    pub fn demo(rides: usize) -> Self {
        let mut stops = Vec::new();
        for ride in 0..rides {
            let from = ((ride * 37) % 101) as i64;
            let to = ((ride * 53 + 29) % 101) as i64;
            for (offset, location) in [(0, from), (1, to)] {
                stops.push(Stop {
                    id: 2 * ride + offset,
                    ride: Some(ride),
                    pickup: offset == 0,
                    location,
                    vehicle: None,
                    index: None,
                    previous: None,
                });
            }
        }
        for location in [17, 64] {
            stops.push(Stop {
                id: stops.len(),
                ride: None,
                pickup: false,
                location,
                vehicle: None,
                index: None,
                previous: None,
            });
        }
        Rides {
            vehicles: (0..3).map(|id| Vehicle { id, stops: Vec::new() }).collect(),
            stops,
            score: None,
        }
    }
}
