solverforge::planning_model! {
    root = "src/savings";

    mod plan;

    pub use plan::{Stop, Vehicle, VehiclePlan};
}
