use solverforge::prelude::*;

#[problem_fact]
pub struct Operation {
    #[planning_id]
    pub id: usize,
    pub duration: usize,
    pub next: Option<usize>,
}
