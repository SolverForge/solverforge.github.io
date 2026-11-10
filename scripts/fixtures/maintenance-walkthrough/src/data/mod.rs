#[allow(dead_code)] // compiler-owned seed; only its DemoData catalog is used
mod data_seed;
mod depot;

pub use data_seed::{available_demo_data, default_demo_data, DemoData};
pub use depot::generate;
