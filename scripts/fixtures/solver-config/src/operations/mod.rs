solverforge::planning_model! {
    root = "src/operations";

    mod operation;
    mod route;
    mod plan;

    pub use operation::Operation;
    pub use route::Route;
    pub use plan::JobPlan;
}
