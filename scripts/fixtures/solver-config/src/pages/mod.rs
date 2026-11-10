//! One module per page. Each `// page:` region is a Rust block of that page,
//! verbatim; the code around it supplies the inputs and asserts the outcome
//! the page states.

mod configuration;
mod dispatch;
mod events;
mod index;
mod solver_manager;
mod termination;

pub use dispatch::run;
pub use events::{solve_to_end, terminal};
