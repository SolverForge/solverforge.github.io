solverforge::planning_model! {
    root = "src/grouped";

    mod employee;
    mod shift;
    mod schedule;

    pub use employee::Employee;
    pub use shift::Shift;
    pub use schedule::{group_with_limits, Schedule};
}
