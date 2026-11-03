use solverforge::prelude::*;
use solverforge::stream::ConstraintFactory;

use super::route::RouteVisits;
use super::{Route, Visit};

#[planning_solution(constraints = "define_constraints", config = "crate::probe_config::apply")]
#[shadow_variable_updates(
    list_owner = "routes",
    inverse_field = "route",
    index_field = "index",
    previous_field = "previous",
    next_field = "next"
)]
pub struct RoutePlan {
    #[planning_entity_collection]
    pub routes: Vec<Route>,
    #[problem_fact_collection]
    pub visits: Vec<Visit>,
    #[planning_score]
    pub score: Option<HardSoftScore>,
}

fn define_constraints() -> impl ConstraintSet<RoutePlan, HardSoftScore> {
    (
        ConstraintFactory::<RoutePlan, HardSoftScore>::new()
            .for_each(RoutePlan::visits())
            .filter(|visit: &Visit| visit.route.is_none())
            .penalize(HardSoftScore::ONE_HARD)
            .named("unrouted visit"),
        ConstraintFactory::<RoutePlan, HardSoftScore>::new()
            .for_each(RoutePlan::visits())
            .filter(|visit: &Visit| visit.index.is_some())
            .penalize(|visit: &Visit| {
                let index = visit.index.unwrap_or_default() as i64;
                let route = visit.route.unwrap_or_default() as i64;
                HardSoftScore::of_soft((visit.demand * (index + 2) + route * 5) % 13)
            })
            .named("position cost"),
        ConstraintFactory::<RoutePlan, HardSoftScore>::new()
            .for_each(RoutePlan::visits())
            .filter(|visit: &Visit| visit.previous.is_some())
            .penalize(|visit: &Visit| {
                let previous = visit.previous.unwrap_or_default() as i64;
                HardSoftScore::of_soft((previous - visit.id as i64).abs() % 7)
            })
            .named("leg cost"),
        ConstraintFactory::<RoutePlan, HardSoftScore>::new()
            .for_each(RoutePlan::routes())
            .penalize(|route: &Route| HardSoftScore::of_soft((route.visits.len() as i64).pow(2)))
            .named("balance"),
    )
}

impl RoutePlan {
    /// Three empty routes and `visits` unrouted visits.
    pub fn demo(visits: usize) -> Self {
        RoutePlan {
            routes: (0..3).map(|id| Route { id, visits: Vec::new() }).collect(),
            visits: (0..visits)
                .map(|id| Visit {
                    id,
                    demand: ((id * 5 + 2) % 9) as i64,
                    route: None,
                    index: None,
                    previous: None,
                    next: None,
                })
                .collect(),
            score: None,
        }
    }
}

impl RouteVisits for RoutePlan {
    fn route_visits(&self, route: usize) -> &Vec<usize> {
        &self.routes[route].visits
    }

    fn route_visits_mut(&mut self, route: usize) -> &mut Vec<usize> {
        &mut self.routes[route].visits
    }
}
