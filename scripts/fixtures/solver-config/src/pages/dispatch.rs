//! Runs one scenario by name.

use super::{configuration, index, solver_manager, termination};

pub fn run(name: &str) {
    match name {
        "index" => index::run(),
        "configuration" => configuration::run(),
        "config-load" => configuration::load(),
        "cwd-ignored" => configuration::cwd_ignored(),
        "termination" => termination::run(),
        "solver-manager" => solver_manager::run(),
        other => panic!("unknown scenario {other}"),
    }
    println!("SCENARIO {name} OK");
}
