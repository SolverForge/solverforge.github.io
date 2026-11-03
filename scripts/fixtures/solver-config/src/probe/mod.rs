solverforge::planning_model! {
    root = "src/probe";

    mod worker;
    mod task;
    mod plan;

    pub use worker::Worker;
    pub use task::Task;
    pub use plan::Plan;
}
