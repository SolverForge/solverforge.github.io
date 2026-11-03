solverforge::planning_model! {
    root = "src/domain";

    mod employee;
    mod room;
    mod shift;
    mod schedule;

    pub use employee::Employee;
    pub use room::Room;
    pub use shift::Shift;
    pub use schedule::Schedule;
}
