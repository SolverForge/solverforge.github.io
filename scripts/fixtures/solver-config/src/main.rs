//! Runs the solver documentation against crates.io solverforge 0.26.0.
//!
//!   solver-config-fixture check <scalar|grouped|visits|operations|parse> <block.toml>
//!   solver-config-fixture scenario <name>
//!
//! `check` parses one documentation block with `SolverConfig::from_toml_str`
//! and, unless the model is `parse`, solves a fixed instance with it under a
//! one-second time limit. `scenario` runs the Rust snippets of one page and
//! asserts the outcomes the page states.

mod domain;
mod grouped;
mod operations;
mod pages;
mod probe;
mod visits;

/// The config a scenario hands to the probe models' retained solves.
pub mod probe_config {
    use solverforge::SolverConfig;
    use std::sync::Mutex;

    static CONFIG: Mutex<Option<SolverConfig>> = Mutex::new(None);

    pub fn set(config: SolverConfig) {
        *CONFIG.lock().unwrap() = Some(config);
    }

    pub fn apply<S>(_: &S, base: SolverConfig) -> SolverConfig {
        CONFIG.lock().unwrap().clone().unwrap_or(base)
    }
}

use solverforge::config::TerminationConfig;
use solverforge::{RuntimeBuildError, SolverConfig};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("check") => check(&args[2], &args[3]),
        Some("scenario") => pages::run(&args[2]),
        _ => {
            eprintln!("usage: solver-config-fixture check <model> <file> | scenario <name>");
            std::process::exit(2);
        }
    }
}

fn one_line(text: impl ToString) -> String {
    text.to_string().split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Keeps every key of the block but caps the run at one second and 200
/// steps, so a block that names a five-minute budget still finishes quickly.
fn bounded(mut config: SolverConfig) -> SolverConfig {
    let termination = config.termination.take().unwrap_or_default();
    let steps = termination.step_count_limit.map_or(200, |steps| steps.min(200));
    config.termination = Some(TerminationConfig {
        seconds_spent_limit: Some(1),
        minutes_spent_limit: None,
        step_count_limit: Some(steps),
        ..termination
    });
    config.random_seed.get_or_insert(7);
    config
}

fn check(model: &str, path: &str) {
    let text = std::fs::read_to_string(path).expect("block file");
    let config = match SolverConfig::from_toml_str(&text) {
        Ok(config) => config,
        Err(error) => {
            println!("PARSE_ERR {}", one_line(error));
            return;
        }
    };
    println!("PARSE_OK");
    if model == "parse" {
        return;
    }
    let config = bounded(config);
    let solved: Result<String, RuntimeBuildError> = match model {
        "scalar" => domain::Schedule::demo(24, 1)
            .solve_with_config(config)
            .map(|s| format!("{:?}", s.score)),
        "grouped" => grouped::Schedule::demo(24)
            .solve_with_config(config)
            .map(|s| format!("{:?}", s.score)),
        "visits" => visits::RoutePlan::demo(20)
            .solve_with_config(config)
            .map(|s| format!("{:?}", s.score)),
        "operations" => operations::JobPlan::demo(12)
            .solve_with_config(config)
            .map(|s| format!("{:?}", s.score)),
        other => panic!("unknown model {other}"),
    };
    match solved {
        Ok(score) if score != "None" => println!("SOLVE_OK {score}"),
        Ok(_) => println!("SOLVE_ERR solved without a score"),
        Err(error) => println!("SOLVE_ERR {}", one_line(error)),
    }
}
