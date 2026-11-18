solverforge::planning_model! {
    root = "src/rides";

    mod plan;

    pub use plan::{Rides, Stop, Vehicle};
}
