#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)

REQUIRED_TEXT = {
  "src/_posts/releases/2026-05-23-solverforge-0-15-x.md" => [
    "`solverforge 0.21.3` is the current core",
    "0.21.x release note"
  ],
  "src/_posts/releases/2026-06-12-solverforge-0-16-x.md" => [
    "`solverforge 0.21.3` is the current core",
    "0.21.x release note"
  ],
  "src/_posts/releases/2026-06-15-solverforge-0-17-x.md" => [
    "`solverforge 0.21.3` is the current core",
    "0.21.x release note"
  ],
  "src/_posts/releases/2026-07-13-solverforge-0-18-x.md" => [
    "`solverforge 0.21.3` is the current core",
    "0.21.x release note"
  ],

  "src/docs/solverforge/solver/phases.md" => [
    "effective parsed limit",
    "empty termination object",
    "construction-only"
  ],
  "src/docs/solverforge/solver/local-search.md" => [
    "effective parsed limit",
    "empty termination object",
    "construction-only"
  ],
  "src/docs/solverforge/solver/index.md" => [
    "effective parsed limit",
    "construction-only"
  ],
  "src/docs/solverforge/solver/construction.md" => [
    "Completed optional roots are skipped before reading their",
    "candidate domains or generating moves",
    "required augmenting", "retained feasibility evidence"
  ],
  "src/docs/solverforge/constraints/constraint-streams.md" => [
    "CollectionExtract",
    "PentaConstraintStream",
    "composed-condition",
    "before key extraction"
  ],
  "src/docs/solverforge/constraints/joiners.md" => [
    "CollectionExtract",
    "PentaConstraintStream",
    "drops the authored penta filter",
    "prevent key extraction"
  ],
  "src/docs/solverforge/constraints/constraint-factory-methods.md" => [
    "CollectionExtract",
    "source membership",
    "pushdown does not apply"
  ],
  "src/docs/solverforge/constraints/index.md" => [
    "CollectionExtract",
    "PentaConstraintStream",
    "before keys and pairs"
  ],

          "src/_posts/releases/2026-10-12-solverforge-0-20-x.md" => [
    "**solverforge 0.20.x** follows `solverforge 0.19.14`", "(2026-10-12 through 2026-10-13)",
    "patches through `0.20.4`",
    "`AcceptedCount(256)`",
    "FirstLastStepScoreImproving", "`DiversifiedLateAcceptanceAcceptor::new(size)`",
    "search_entity_order_key", "search_value_order_key",
    "`search_entity_order_key` / `search_value_order_key`", "score-authoritative",
    "`0.20.4` | 2026-10-13", "`0.20.3` | 2026-10-12", "`0.20.2` | 2026-10-12",
    "`0.20.1` | 2026-10-12", "`0.20.0` | 2026-10-12",
    "Historical core line | `solverforge 0.20.0`–`0.20.4`",
    "compare/v0.19.14...v0.20.4"
  ],
  "src/_posts/releases/2026-10-14-solverforge-0-21-x.md" => [
    "**solverforge 0.21.x** follows `solverforge 0.20.4`", "published on
crates.io on 2026-10-14",
    "`cargo add solverforge`\ninstalls 0.21.3",
    "docs.rs serves the 0.21.3 API",
    "70aa9f71ab305265cfe7d83753af2f86fb06acf9", "cb916a73d86c46c25b0e4182626f9adc2c9aa5ad",
    "1000a7d471aafe4aa10e900ad075230b9df51ca8",
    "(#74)", "is_doable_with_working_preview", "`&mut self`",
    "each compiled selector node lowers exactly once", "no artifact carries",
    "Previous core runtime | `solverforge 0.21.2` | Registry and release artifacts remain available",
    "`0.21.3` | 2026-10-14", "`0.21.2` | 2026-10-14", "`0.21.0` | 2026-10-14",
    "compare/v0.20.4...v0.21.2", "compare/v0.20.1...v0.21.0"
  ],
  "src/docs/solverforge/constraints/shift-group-uniformity.md" => [
    "number of distinct groups minus one",
    "same-block", "medium penalty",
    "group_by", "collect_vec", "equal_on",
    "shift.index", "start, end, location",
    "/docs/solverforge/constraints/constraint-streams/",
    "/docs/solverforge/constraints/joiners/",
    "/docs/solverforge/constraints/collectors/"
  ],
    "scripts/verify-rust-snippets.rb" => [
    'DEFAULT_SOLVERFORGE_RS_REF = "v0.21.3"'
  ],

  "src/docs/solverforge/index.md" => [
    "These pages track the `solverforge 0.21.3` release",
    "The `0.21.3` workspace declares Rust `1.95`.",
    "/blog/releases/2026/10/14/solverforge-0-21-x/",
    "solverforge-cli 3.5.1",
    "apps scaffolded by earlier lines pin older cores"
  ],

  "src/docs/solverforge/solver/solver-manager.md" => ["holding the worker's pause gate", "does not restart from the best solution"],
  "src/docs/solverforge/constraints/node-sharing.md" => ["The compiler supports sharing"],
  "src/docs/solverforge/constraints/existence-and-flattening.md" => [
    "DenseKeys::add", "per event", "at most once"
  ],
  "src/reference/integration-surfaces.md" => [
    "tracks `solverforge 0.21.3`", "the current CLI 3.5.1 line scaffolds core 0.21.2"
  ],
  "src/docs/solverforge-python/index.md" => [
    "solverforge-py 0.6.14",
    "solverforge==0.6.14",
    "solverforge 0.21.3",
    "solverforge-ui 0.9.0"
  ],
  "src/docs/solverforge-python/modeling.md" => [
    "`candidate_values` is also the native hard domain",
    "`same_value_conflict_field`"
  ],
  "src/docs/solverforge-cli/index.md" => [
    "solverforge-cli 3.5.1",
    "`web`, `api`, `cli`, or `mcp`"
  ],
  "src/docs/solverforge-cli/command-reference.md" => [
    "solverforge-cli 3.5.1",
    "CLI version: 3.5.1",
    "SolverForge crate target 0.21.2",
    "Scaffold MCP target: rmcp 3.5.1",
    "solverforge connect"
  ],
  "src/docs/solverforge-cli/generator-commands.md" => [
    "`--countable-range <FROM..TO>`",
    "`--runs`",
    "`--projected-group`",
    "`SimpleScore` is not accepted",
    "computing all rewrites before it writes any of them",
    "re-renders\n`src/data/data_seed.rs`"
  ],
  "src/docs/solverforge-cli/configuration.md" => [
    "cli_version = \"3.5.1\"",
    "target = \"solverforge 0.21.2\""
  ],
  "src/docs/solverforge-cli/getting-started.md" => [
    "cannot localize entity indexes"
  ],
  "src/docs/solverforge-cli/scaffold-commands.md" => [
    "`web`, `api`, `cli`, and `mcp`",
    "rmcp",
    "cargo run -- demo-data"
  ],
  "src/docs/solverforge/solver/configuration.md" => [
    "SolverForge 0.21.3",
    "effective parsed limit", "construction-only",
    "Keeping an optional assignment unassigned completes that group-slot decision"
  ],
  "src/docs/solverforge-maps/index.md" => [
    "solverforge-maps 2.1.4",
    "solverforge-cli 3.5.1"
  ],
  "src/docs/solverforge-python/getting-started.md" => [
    "SolverForge 0.21.3"
  ],
  "src/docs/solverforge-python/solving-and-runtime.md" => [
    "0.21.3 runtime graph"
  ],
  "src/docs/solverforge-cli/mcp-shell.md" => [
    "get_candidate_trace",
    "Streamable HTTP",
    "solverforge connect",
    "MCP 2026-07-28",
    "unauthenticated"
  ],
  "src/docs/solverforge-cli/agent-skill.md" => [
    "skills/solverforge-modeling/",
    "solve-smoke-test.sh",
    "make install-skill",
    "--agent opencode|claude|codex",
    "--layout covering"
  ],
  "src/docs/solverforge-ui/index.md" => [
    "solverforge-ui 0.9.0",
    "solverforge-cli 3.5.1",
    "`0.7.0`",
    "/sf/sf.0.9.0.css",
    "SF.version"
  ],
  "src/docs/solverforge-ui/integration-assets.md" => [
    "solverforge-ui 0.9.0",
    "solverforge_ui::assets::version()",
    "SF.version",
    "onFailure",
    "onCancelled"
  ],
  "src/docs/solverforge-ui/components.md" => [
    "content: { unsafeHtml:",
    "tabs[].content.unsafeHtml"
  ],
  "src/docs/solverforge-ui/scheduling-views.md" => [
    "isWeekend",
    "non-zero layout dimensions",
    "unsafePopupHtml"
  ],
  "src/docs/solverforge-ui/agent-skill.md" => [
    "solverforge-cli repository",
    "skills/solverforge-ui/",
    "solverforge-ui 0.9.0"
  ],
  "src/_data/docs_nav.yml" => [
    "/docs/solverforge-ui/agent-skill/",
    "/docs/solverforge-cli/mcp-shell/",
    "/docs/solverforge-cli/agent-skill/",
    "/docs/solverforge/constraints/shift-group-uniformity/"
  ],
  "src/reference/crate-map.md" => [
    "solverforge 0.21.3",
    "AcceptedCount(256)",
    "solverforge 0.6.14",
    "solverforge-py v0.6.14"
  ],
  "src/reference/lifecycle-pause-resume-contract.md" => [
    "solverforge 0.21.3",
    "solverforge-ui 0.9.0",
    "solverforge-cli 3.5.1"
  ],
  "src/_posts/releases/2026-09-16-solverforge-cli-3-1-x.md" => [
    "`3.1.0` | 2026-09-16",
    "rmcp 3.4.0",
    "--agent opencode|claude|codex",
    "`solverforge 0.19.5`",
    "`solverforge-ui 0.9.0`"
  ],
  "src/_posts/releases/2026-05-31-solverforge-cli-2-2-x.md" => [
    "`solverforge-cli 3.0.0` is published on crates.io",
    "`solverforge-cli 3.1.0` is published on crates.io"
  ],
  "src/_posts/releases/2026-09-15-solverforge-ui-0-8-x.md" => [
    "`0.8.0` | 2026-09-15",
    "SF.version",
    "solverforge_ui::assets::version()",
    "scripts/install-skill"
  ],
  "src/_posts/releases/2026-09-15-solverforge-cli-3-0-x.md" => [
    "`3.0.0` | 2026-09-15",
    "rmcp 3.3.0",
    "solverforge connect",
    "solverforge-modeling"
  ],
  "src/docs/status-and-roadmap.md" => [
    "BENCH_TOLERANCE_PERCENT", "default 5%", "equal-length staging paths",
    "documentation tracks the `solverforge 0.21.3` release",
    "`cargo add solverforge` installs 0.21.3",
    "docs.rs serves the 0.21.3 API",
    "cb916a73d86c46c25b0e4182626f9adc2c9aa5ad",
    "38640704980", "38640708258", "38640708277",
    "38598708211", "38598906107", "38598906248",
    "Native Rust constraint solver published as `solverforge 0.21.3`",
    "The independently published CLI line is `solverforge-cli 3.5.1`",
    "- **Core runtime line**", "- **Joined-tuple grouping**", "- **Guided native scalar search**",
    "- **Score-authoritative grouped search**", "- **Late acceptance**",
    "- **Lending extensions**", "- **Owned runtime state**",
    "**0.19.13 existence-engine rewrite**",
    "**0.19.11 construction and scoring fixes**",
    "**0.19.12 retained bookkeeping**",
    "occurrence count per right-side key", "idempotently per event",
    "**Grouped-scalar foraging**", "AcceptedCount(256)",
    "**0.20.1 pooled scratch**", "0-20-x",
    "retained `KeyOf` keys", "caller-owned", "`RowChanges` is gone",
    "lists are updated in place", "residual predicates", "duplicate",
    "benchmark results or measured performance gains",
    "solverforge-py 0.6.14",
    "solverforge-cli 3.5.1",
    "solverforge-ui 0.9.0",
    "solverforge-hospital@2.0.9",
    "solverforge-lessons@2.0.11",
    "solverforge-deliveries@2.0.10",
    "solverforge-fsr@2.0.11"
  ],
  "src/docs/getting-started/solverforge-hospital-use-case.md" => [
    "solverforge-hospital@2.0.9",
    "solverforge 0.21.2"
  ],
  "src/docs/getting-started/solverforge-lessons-use-case.md" => [
    "solverforge-lessons@2.0.11",
    "solverforge 0.21.2"
  ],
  "src/docs/getting-started/solverforge-deliveries-use-case.md" => [
    "solverforge-deliveries@2.0.10",
    "solverforge 0.21.2"
  ],
  "src/docs/getting-started/solverforge-fsr-use-case.md" => [
    "solverforge-fsr@2.0.11",
    "solverforge 0.21.2"
  ],
  "src/_posts/releases/2026-07-17-solverforge-0-19-x.md" => [
    "`solverforge 0.21.3` is the current core",
    "0.21.x release note",
    "## October 2026 Core Patches (0.19.8–0.19.14)",
    "per-key occurrence counts", "arity-generic cross-join engine", "worker wakeup", "caller-owned buffers",
    "`0.19.13` | 2026-10-11",
    "`0.19.12` | 2026-10-10",
    "`0.19.11` | 2026-10-10",
    "`0.19.10` | 2026-10-09",
    "`0.19.9` | 2026-10-08",
    "`0.19.8` | 2026-10-02",
    "`0.19.7` | 2026-09-25",
    "`0.19.6` | 2026-09-25",
    "`0.19.5` | 2026-09-15",
    "`0.19.4` | 2026-08-11",
    "`0.19.3` | 2026-07-29",
    "`0.19.2` | 2026-07-19",
    "solverforge-hospital@2.0.7"
  ],
  "src/_posts/releases/2026-09-25-solverforge-0-19-6-7-x.md" => [
    "`solverforge 0.21.3` is the current core",
    "`0.19.13` | 2026-10-11",
    "`0.19.12` | 2026-10-10",
    "`0.19.11` | 2026-10-10",
    "`0.19.10` | 2026-10-09",
    "solverforge 0.19.6",
    "solverforge 0.19.7",
    "`0.19.9` | 2026-10-08",
    "0.21.x release note",
    "`0.19.8` | 2026-10-02",
    "`0.19.6` | 2026-09-25",
    "`0.19.7` | 2026-09-25",
    "pinned"
  ],
      "src/_posts/releases/2026-09-29-solverforge-python-0-6-10-x.md" => [
    "solverforge-py 0.6.14",
    "solverforge==0.6.14",
    "solverforge 0.21.3",
    "Pins the six SolverForge Rust dependencies to the published `0.21.0` registry base", "Current published package; direct list-precedence dispatch on the `solverforge 0.21.3` registry base",
    "solverforge-ui 0.9.0"
  ],
  "src/_posts/releases/2026-09-27-solverforge-usecases-repository-apps.md" => [
    "solverforge-furnace 2.0.2",
    "solverforge-orders 0.1.2",
    "solverforge-fleet 0.1.5",
    "solverforge-flightcrew 0.1.2",
    "repository-only"
  ],
  "src/_posts/releases/2026-07-13-solverforge-python-0-6-x.md" => [
    "`0.6.10` | 2026-09-29",
    "`0.6.6` | 2026-08-11",
    "`0.6.5` | 2026-07-29",
    "`0.6.4` | 2026-07-26"
  ],
  "src/_posts/releases/2026-09-29-solverforge-cli-3-2-3-3-x.md" => [
    "`3.2.0` | 2026-09-29",
    "`3.3.1` | 2026-09-29",
    "`3.3.2` | 2026-10-01",
    "`3.3.3` | 2026-10-02",
    "`3.4.0` | 2026-10-14", "`3.5.0` | 2026-10-14", "`3.5.1` | 2026-10-14",
    "rmcp 3.5.0",
    "solverforge 0.19.7",
    "csemver",
    "`solverforge 0.21.2`, web `solverforge-ui 0.9.0` + `solverforge-maps 2.1.4`, MCP `rmcp 3.5.1`",
    "src/data/data_seed.rs"
  ],
}.freeze

FORBIDDEN_TEXT = {
  "src/docs/solverforge/index.md" => [
    "These pages track the `solverforge 0.20.1` crate",
    "The `0.20.1` workspace declares Rust `1.95`.",
    "docs.rs/solverforge/0.20.1/",
    "These pages track the `solverforge 0.19.14` crate",
    "The `0.19.14` workspace declares Rust `1.95`.",
    "docs.rs/solverforge/0.19.14/solverforge/",
    "solverforge 0.19.1",
    "solverforge-cli 2.2.2",
    "solverforge 0.19.3",
    "docs.rs/solverforge/0.19.4/",
    "These pages track the `solverforge 0.19.12` crate",
    "The `0.19.12` workspace declares Rust `1.95`.",
    "docs.rs/solverforge/0.19.12/solverforge/"
  ],
  "src/docs/solverforge-ui/index.md" => ["solverforge-ui 0.8.0", "sf.0.8.0", "solverforge-cli 3.2.0"],
  "src/docs/solverforge-ui/integration-assets.md" => ["solverforge-ui 0.8.0", "sf.0.8.0"],
  "src/docs/solverforge-python/index.md" => ["solverforge-py 0.6.3", "solverforge==0.6.3", "solverforge-py 0.6.10", "solverforge==0.6.10"],
  "src/docs/solverforge-cli/index.md" => [
    "solverforge-cli 3.0.0",
    "solverforge-cli 3.3.1",
    "solverforge-cli 3.3.2",
    "--only"
  ],
  "src/docs/solverforge-cli/command-reference.md" => [
    "CLI version: 3.3.3",
    "SolverForge crate target 0.19.7",
    "solverforge-cli 3.0.0",
    "solverforge-cli 3.3.1",
    "solverforge-cli 3.3.2",
    "solverforge-cli 2.2.2",
    "crate target 0.15.2",
    "rmcp 3.3.0",
    "SolverForge crate target 0.19.3",
    "SolverForge crate target 0.19.4",
    "Scaffold UI target: solverforge-ui 0.8.0"
  ],
  "src/docs/solverforge-cli/configuration.md" => [
    "cli_version = \"3.3.3\"",
    "cli_version = \"3.0.0\"",
    "cli_version = \"3.3.2\"",
    "target = \"solverforge 0.19.4\"",
    "solverforge-ui 0.7.0"
  ],
  "src/docs/solverforge/solver/configuration.md" => [
    "SolverForge 0.19.12", "SolverForge 0.19.14"
  ],
  "src/docs/solverforge-cli/scaffold-commands.md" => [
    "rmcp 3.3.0",
    "solverforge-ui 0.7.0"
  ],
  "src/docs/solverforge-cli/operations-commands.md" => [
    "only `vscode`"
  ],
  "src/docs/solverforge-cli/mcp-shell.md" => [
    "only `vscode`"
  ],
  "src/docs/solverforge-cli/agent-skill.md" => [
    "--only"
  ],
  "src/docs/status-and-roadmap.md" => [
    "documentation tracks the `solverforge 0.19.14` tag",
    "documentation tracks the `solverforge 0.20.0` tag",
    "The `v0.19.14` tag, workspace, and crates.io package are the",
    "- **0.19.14 runtime line**:",
    "Native Rust constraint solver published as `solverforge 0.19.14`",
    "documentation tracks the `solverforge 0.20.1` tag",
    "The `v0.20.1` tag, workspace, and crates.io package are the",
    "Native Rust constraint solver published as `solverforge 0.20.1`",
    "- **0.20.x runtime line**: `v0.20.1` and the crates.io `solverforge 0.20.1`",
    "documentation tracks the `solverforge 0.19.8` tag",
    "documentation tracks the `solverforge 0.19.9` tag",
    "documentation tracks the `solverforge 0.19.10` tag",
    "documentation tracks the `solverforge 0.19.11` tag",
    "documentation tracks the `solverforge 0.19.12` tag",
    "The `v0.19.12` tag, workspace, and crates.io package are the",
    "published on 2026-10-10, and docs.rs serves the 0.19.12 API.",
    "- **0.19.12 runtime line**: `v0.19.12` and the crates.io `solverforge 0.19.12`",
    "Native Rust constraint solver published as `solverforge 0.19.12`",
    "**Three-source keyed joins**",
    "solverforge-py 0.6.3",
    "solverforge 0.19.1",
    "solverforge-cli 2.2.2` package",
    "solverforge-cli 3.3.1",
    "solverforge-cli 3.3.2` package",
    "solverforge-ui 0.8.0",
    "solverforge-hospital@2.0.6",
    "solverforge-lessons@2.0.6",
    "solverforge-deliveries@2.0.6",
    "solverforge-fsr@2.0.7"
  ],
  "src/docs/getting-started/solverforge-hospital-use-case.md" => ["solverforge-hospital@2.0.6"],
  "src/docs/getting-started/solverforge-lessons-use-case.md" => ["solverforge-lessons@2.0.6"],
  "src/docs/getting-started/solverforge-deliveries-use-case.md" => ["solverforge-deliveries@2.0.6"],
  "src/docs/getting-started/solverforge-fsr-use-case.md" => ["solverforge-fsr@2.0.7"],
  "src/reference/lifecycle-pause-resume-contract.md" => ["solverforge-cli 3.3.1", "solverforge-cli 3.3.2"],
  "src/_posts/releases/2026-09-29-solverforge-cli-3-2-3-3-x.md" => [
    "**solverforge-cli 3.3.1** is published",
    "installs 3.3.1 directly",
    "installs 3.3.2 directly",
    "installs 3.3.3 directly"
  ],
  "src/_posts/releases/2026-09-25-solverforge-0-19-6-7-x.md" => [
    "`cargo add solverforge` installs 0.19.7",
    "`solverforge 0.19.12` is the current core"
  ],
  "src/_posts/releases/2026-05-23-solverforge-0-15-x.md" => [
    "`solverforge 0.19.12` is the current core"
  ],
  "src/_posts/releases/2026-06-12-solverforge-0-16-x.md" => [
    "`solverforge 0.19.12` is the current core"
  ],
  "src/_posts/releases/2026-06-15-solverforge-0-17-x.md" => [
    "`solverforge 0.19.12` is the current core"
  ],
  "src/_posts/releases/2026-07-13-solverforge-0-18-x.md" => [
    "`solverforge 0.19.12` is the current core"
  ],
  "src/_posts/releases/2026-07-17-solverforge-0-19-x.md" => [
    "`solverforge 0.19.12` is the current core"
  ],
          "scripts/verify-rust-snippets.rb" => [
    'DEFAULT_SOLVERFORGE_RS_REF = "v0.19.14"'
  ]
}.freeze

failures = []

def normalize(text)
  text.gsub(/\s+/, " ")
end

REQUIRED_TEXT.each do |relative_path, needles|
  path = File.join(ROOT, relative_path)
  unless File.file?(path)
    failures << "missing file: #{relative_path}"
    next
  end

  # Prose needles must survive markdown line wrapping: compare normalized text.
  text = normalize(File.read(path))
  needles.each do |needle|
    failures << "#{relative_path} is missing #{needle.inspect}" unless text.include?(normalize(needle))
  end
end

FORBIDDEN_TEXT.each do |relative_path, needles|
  path = File.join(ROOT, relative_path)
  unless File.file?(path)
    failures << "missing file: #{relative_path}"
    next
  end

  # Version tokens must match at a numeric boundary, so forbidden matching stays
  # regex-based; whitespace runs are still collapsed first.
  text = File.read(path)
  needles.each do |needle|
    pattern = Regexp.escape(needle)
    pattern = pattern.gsub(/\\\s+\\\s*/, "\\s+") if pattern.include?("\\n")
    pattern += "(?![0-9])" if needle.match?(/[0-9]\z/)
    failures << "#{relative_path} still contains #{needle.inspect}" if text.match?(Regexp.new(pattern))
  end
end

unless failures.empty?
  warn "[verify-release-surface] ERROR"
  failures.each { |failure| warn "- #{failure}" }
  exit 1
end

puts "[verify-release-surface] Verified #{REQUIRED_TEXT.length} current release surfaces"