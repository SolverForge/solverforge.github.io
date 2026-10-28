#[allow(dead_code)] // compiler-owned seed; only its DemoData catalog is used
mod data_seed;
mod depot;

pub use data_seed::{available_demo_data, default_demo_data, DemoData};

use crate::domain::Plan;

/// Every demo-data id serves the depot scenario; the generic index-based seed
/// in `data_seed.rs` stays compiler-owned and is only used for the id catalog.
pub fn generate(_demo: DemoData) -> Plan {
    depot::depot_plan()
}
