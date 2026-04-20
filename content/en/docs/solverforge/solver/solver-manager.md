---
title: "SolverManager"
linkTitle: "SolverManager"
weight: 50
description: >
  Run retained solver jobs with lifecycle-complete streaming, snapshots, and exact pause/resume.
---

`SolverManager` is the retained runtime API for running solver jobs. It owns the
authoritative lifecycle state, streams `SolverEvent` values, retains snapshots
for later inspection, and exposes exact in-process pause/resume.

## Creating a SolverManager

`SolverManager::new()` is a `const fn` that takes no arguments. It's designed to be used as a static:

```rust
use solverforge::prelude::*;

static MANAGER: SolverManager<Schedule> = SolverManager::new();
```

## Solving

Call `.solve()` with your planning solution. It returns a `Result` containing a
`(job_id, Receiver)` tuple:

```rust
let (job_id, rx) = MANAGER.solve(solution).expect("solver job should start");
```

The receiver yields `SolverEvent<S>` values, not raw `(solution, score)` tuples.
Each event carries `SolverEventMetadata` with the job id, event sequence,
lifecycle state, telemetry, current/best score, and the latest
`snapshot_revision` when one exists.

In `0.8.10`, retained telemetry keeps exact generated, evaluated, and accepted
move counts together with generation and evaluation durations. Any displayed
`moves/s` value is derived at the edge rather than stored as the canonical
runtime metric.

Consume them in a loop:

```rust
use solverforge::SolverEvent;

let (job_id, mut rx) = MANAGER.solve(solution).expect("solver job should start");

while let Some(event) = rx.blocking_recv() {
    match event {
        SolverEvent::Progress { metadata } => {
            println!(
                "job {} state {:?} current {:?} best {:?}",
                metadata.job_id,
                metadata.lifecycle_state,
                metadata.current_score,
                metadata.best_score
            );
        }
        SolverEvent::BestSolution { metadata, .. } => {
            println!(
                "new best at snapshot {:?}",
                metadata.snapshot_revision
            );
        }
        SolverEvent::PauseRequested { metadata } => {
            println!("pause requested for job {}", metadata.job_id);
        }
        SolverEvent::Paused { metadata } => {
            println!(
                "job {} paused at snapshot {:?}",
                metadata.job_id,
                metadata.snapshot_revision
            );
        }
        SolverEvent::Resumed { metadata } => {
            println!("job {} resumed", metadata.job_id);
        }
        SolverEvent::Completed { metadata, .. } => {
            println!(
                "job {} completed with reason {:?}",
                metadata.job_id,
                metadata.terminal_reason
            );
            break;
        }
        SolverEvent::Cancelled { metadata } => {
            println!("job {} cancelled", metadata.job_id);
            break;
        }
        SolverEvent::Failed { metadata, error } => {
            println!("job {} failed: {}", metadata.job_id, error);
            break;
        }
    }
}
```

The event variants are:

- `Progress` — telemetry plus lifecycle metadata
- `BestSolution` — an owned improving solution plus a retained snapshot
- `PauseRequested` — pause has been requested but not yet settled
- `Paused` — the runtime reached a safe checkpoint and retained a resumable snapshot
- `Resumed` — a paused job continued from its retained checkpoint
- `Completed` — the final owned best solution
- `Cancelled` — the job was explicitly cancelled
- `Failed` — the runtime aborted with an error

## Solver Status

Check the current state of a job:

```rust
let status = MANAGER.get_status(job_id).expect("job should exist");

println!("state: {:?}", status.lifecycle_state);
println!("terminal reason: {:?}", status.terminal_reason);
println!("checkpoint available: {}", status.checkpoint_available);
println!("event sequence: {}", status.event_sequence);
println!("latest snapshot: {:?}", status.latest_snapshot_revision);
```

`SolverStatus` is a struct, not a two-state enum. The lifecycle state is one
of:

- `Solving`
- `PauseRequested`
- `Paused`
- `Completed`
- `Cancelled`
- `Failed`

Terminal jobs also expose a separate `terminal_reason`:

- `Completed`
- `TerminatedByConfig`
- `Cancelled`
- `Failed`

This distinction matters because a job can be `Completed` for a normal solve end
or for a configured termination condition.

## Pause, Resume, and Cancel

Use lifecycle controls when you need interactive job management:

```rust
MANAGER.pause(job_id).expect("pause should be accepted");
MANAGER.resume(job_id).expect("resume should be accepted");
MANAGER.cancel(job_id).expect("cancel should be accepted");
```

`pause()` is not a best-effort hint. The runtime settles it at a safe boundary,
retains a checkpoint-backed snapshot, emits `Paused`, and only then allows
`resume()`.

The built-in construction, local-search, and retained phase flow poll control
state during large neighborhood work aggressively enough that `pause()`,
`cancel()`, and config termination unwind promptly without extra watchdog code
in the application.

## Snapshots and Analysis

Every retained solution snapshot has a monotonic `snapshot_revision` within its
job. Fetch the latest or a specific revision:

```rust
let latest = MANAGER.get_snapshot(job_id, None).expect("latest snapshot");
let exact = MANAGER
    .get_snapshot(job_id, Some(latest.snapshot_revision))
    .expect("requested snapshot");
```

If your planning solution is `Analyzable`, you can request score analysis for a
specific snapshot revision:

```rust
let analysis = MANAGER
    .analyze_snapshot(job_id, Some(latest.snapshot_revision))
    .expect("snapshot analysis");

println!("analysis score: {:?}", analysis.analysis.score);
```

Analysis is snapshot-bound. You do not analyze the live mutable job directly.

After `pause()` is accepted, `PauseRequested` is published before any later
worker-side event already carrying `PauseRequested` state. Treat that ordering
as authoritative when synchronizing UI or service-layer state.

## Delete and Slot Reuse

Jobs remain retained after `Completed`, `Cancelled`, or `Failed` so you can read
their final status, snapshots, and analysis. Delete the terminal job when you
are done with it:

```rust
MANAGER.delete(job_id).expect("delete terminal job");
```

Deleting a retained terminal job is what frees the slot for reuse.

## Active Jobs

Check how many jobs are currently running:

```rust
let count = MANAGER.active_job_count();
```

This counts visible retained jobs, including paused and terminal jobs that have
not been deleted yet.

## The `Solvable` Trait

Your planning solution must implement `Solvable` to be used with
`SolverManager`. This is generated automatically when `#[planning_solution]`
includes a `constraints = "..."` path.

## See Also

- [Configuration](../configuration/) — Solver configuration
- [Termination](../termination/) — Termination conditions
