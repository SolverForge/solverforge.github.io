use solverforge::prelude::*;

#[planning_entity]
pub struct Route {
    #[planning_id]
    pub id: usize,

    #[planning_list_variable(
        element_collection = "visits",
        distance_meter = "VisitDistance",
        intra_distance_meter = "VisitDistance",
        route_hooks = "route_hooks",
        solution_trait = "RouteVisits"
    )]
    pub visits: Vec<usize>,
}

/// What the route hooks need from the solution.
pub trait RouteVisits {
    fn route_visits(&self, route: usize) -> &Vec<usize>;
    fn route_visits_mut(&mut self, route: usize) -> &mut Vec<usize>;
}

mod route_hooks {
    use super::RouteVisits;

    pub(crate) fn get<S: RouteVisits>(plan: &S, route: usize) -> Vec<usize> {
        plan.route_visits(route).clone()
    }

    pub(crate) fn set<S: RouteVisits>(plan: &mut S, route: usize, visits: Vec<usize>) {
        *plan.route_visits_mut(route) = visits;
    }

    pub(crate) fn depot<S>(_: &S, _: usize) -> usize {
        0
    }

    pub(crate) fn distance<S>(_: &S, _: usize, from: usize, to: usize) -> i64 {
        from.abs_diff(to) as i64
    }

    pub(crate) fn feasible<S>(_: &S, _: usize, _: &[usize]) -> bool {
        true
    }
}

/// Distance between two list positions: the gap between them, plus one per
/// route crossed.
#[derive(Debug, Clone, Copy, Default)]
pub struct VisitDistance;

impl<S> solverforge::CrossEntityDistanceMeter<S> for VisitDistance {
    fn distance(
        &self,
        _plan: &S,
        source_entity: usize,
        source_position: usize,
        destination_entity: usize,
        destination_position: usize,
    ) -> f64 {
        (source_position.abs_diff(destination_position) + source_entity.abs_diff(destination_entity)) as f64
    }
}
