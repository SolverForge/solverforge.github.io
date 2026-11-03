solverforge::planning_model! {
    root = "src/visits";

    mod visit;
    mod route;
    mod plan;

    pub use visit::Visit;
    pub use route::Route;
    pub use plan::RoutePlan;
}
