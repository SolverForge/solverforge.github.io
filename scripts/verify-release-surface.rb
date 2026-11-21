#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "release_pins"

ROOT = File.expand_path("..", __dir__)
CORE = ReleasePins::RUNTIME
CLI = ReleasePins::CLI
CLI_RUNTIME = ReleasePins::CLI_SCAFFOLD_RUNTIME
APP_RUNTIME = "0.31.2"
NOTE_CORE = "/blog/releases/2026/11/17/solverforge-0-31-x/"
NOTE_CORE_30 = "/blog/releases/2026/11/15/solverforge-0-30-x/"
NOTE_CORE_29 = "/blog/releases/2026/11/14/solverforge-0-29-x/"
NOTE_CORE_28 = "/blog/releases/2026/11/14/solverforge-0-28-x/"
NOTE_CORE_27 = "/blog/releases/2026/11/13/solverforge-0-27-x/"
NOTE_CORE_26 = "/blog/releases/2026/11/10/solverforge-0-26-x/"
NOTE_CORE_25 = "/blog/releases/2026/11/09/solverforge-0-25-x/"
NOTE_CLI = "/blog/releases/2026/11/18/solverforge-cli-4-1-4-2-x/"
NOTE_CLI_40 = "/blog/releases/2026/11/10/solverforge-cli-4-0-x/"
NOTE_CLI_39 = "/blog/releases/2026/11/09/solverforge-cli-3-9-x/"
NOTE_APPS = "/blog/releases/2026/11/03/solverforge-usecases-3-0/"

REQUIRED_TEXT = {
  ".github/workflows/site.yml" => [
    "cargo install solverforge-cli --version #{CLI} --locked --force",
    "walkthrough-solverforge-cli-#{CLI}-",
    "SOLVERFORGE_GETTING_STARTED_TARGET_DIR"
  ],
  "scripts/verify-cli-release.rb" => [
    "EXPECTED_CLI_VERSION = ReleasePins::CLI", "EXPECTED_RUNTIME_VERSION = ReleasePins::CLI_SCAFFOLD_RUNTIME",
    'EXPECTED_MCP_VERSION = "3.9.0"',
    "bd0b5427cc985067a905d4a9361a9fc160429551",
    "84ae9fc20bb838d42e7954404c5adf24ca9ee47f13b6e7a3a2da0e66641762c7",
    "pub resolved_phase_plan: Option<CandidateTracePhasePlanDto>",
    "super::assigned::constraint()", "module roots may hold only module declarations",
    "pub phases: Vec<PhaseTelemetryDto>", "pub moves_speculative: u64",
    "duplicates the built-in", "The project was not compiled.",
    "because source files still reference it"
  ],
  "scripts/verify-maintenance-walkthrough.rb" => [
    %(EXPECTED_CLI_VERSION = "#{CLI}"), %(EXPECTED_RUNTIME_VERSION = "#{CLI_RUNTIME}"),
    %(run!(git_identity, [cli, "check"], chdir: app))
  ],
  "src/docs/getting-started/maintenance-planning-with-the-agent-skill.md" => [
    "`solverforge-cli #{CLI}`, which scaffolds `solverforge #{CLI_RUNTIME}`",
    "`src/constraints/assemble.rs`", "pub use depot::generate;"
  ],
  "scripts/fixtures/maintenance-walkthrough/src/data/mod.rs" => [
    "pub use depot::generate;"
  ],
  "src/_posts/releases/2026-11-17-solverforge-0-31-x.md" => [
    "**solverforge 0.31.x** follows `solverforge 0.30.1`",
    "`cargo add solverforge` installs #{CORE}", "docs.rs serves the #{CORE}\nAPI",
    "| Core runtime | `solverforge #{CORE}` |",
    "| CLI | `solverforge-cli #{CLI}` | Fresh scaffolds target core `#{CLI_RUNTIME}`",
    "`solverforge-cli #{CLI}` scaffolds\n#{CLI_RUNTIME}, and the nine worked use cases pin #{APP_RUNTIME}",
    "All nine pin core `#{APP_RUNTIME}` and UI `0.9.1`", "#november-18-releases-solverforge-0312",
    "`0.31.2` | 2026-11-17", "`0.31.1` | 2026-11-17", "`0.31.0` | 2026-11-17",
    "c2d4fa27bf0081a6b0db6a0c5ca5961802a3b93a", "f5b6940b80070446130a11b9288ae11c7f6b662800fe92afc2a36071bc729bdf",
    "43996989765", "43999401432",
    "ff945a3bef3b53ef3ade3f70b86392a8a00137c2", "f594cb77fd5b91cfeb9fcd767c954be865660e5be1c487419e9f09429db88076",
    "44076144517", "44076147858",
    "78889c3ff9fda158c70e6a1f67f8c7f0fdae922e", "a702c08aac207bd5e22763d7f70b1021efdccbb0149c8b82cd1c018ddf940b11",
    "44182372301", "44185759448",
    "compare/v0.30.1...v0.31.0", "compare/v0.31.0...v0.31.1", "compare/v0.31.1...v0.31.2", "blob/v0.31.2/CHANGELOG.md",
    "`element_group_fn`", "`list_group_change_move_selector`", "`list_group_swap_move_selector`",
    "`max_member_distance = 7`", "`cascading_peers`", "`PlanningSolution::list_structure_unchanged`",
    "`list_elements_remain_unassigned`", "keeps 40 savings per element", "list variables collect 4",
    "`time_budget_seconds`", "`ListGroupChangeMoveSelector`", "`ListGroupSwapMoveSelector`",
    "https://github.com/SolverForge/solverforge/pull/274", "https://github.com/SolverForge/solverforge/pull/275",
    "https://github.com/SolverForge/solverforge/pull/276",
    NOTE_CORE_30, NOTE_CLI, NOTE_APPS
  ],
  "src/_posts/releases/2026-11-15-solverforge-0-30-x.md" => [
    "**solverforge 0.30.x** follows `solverforge 0.29.0`",
    "At publication `cargo add solverforge` installed 0.30.1",
    "The current core release is\n`solverforge #{CORE}`", NOTE_CORE, NOTE_CORE_29,
    "`0.30.1` | 2026-11-16", "`0.30.0` | 2026-11-15",
    "147011d92b93fcfa4a2bd02344f6c965a2915293", "4f9af00f82a984651a8287f33973b98b261ca3138450d8e7cd2177af2bec4cd4",
    "43752268061", "43753275831",
    "ebab46ba9595f52703b178b372b0281cecafaa22", "5c9314f4fa01d96fdfe1a151c83508ad41bc4ea9257345c0ec45f34c31972ae4",
    "43875154430", "43879691165",
    "`cascading_field`", "`cascading_compute`", "`cascading_dependencies`", "PlanningSolution::HAS_CASCADING_SHADOWS",
    "filter type parameter `Fi`", "https://github.com/SolverForge/solverforge/pull/269",
    "compare/v0.29.0...v0.30.0", "compare/v0.30.0...v0.30.1"
  ],
  "src/_posts/releases/2026-11-14-solverforge-0-29-x.md" => [
    "**solverforge 0.29.x** follows `solverforge 0.28.0`",
    "At publication `cargo add solverforge` installed\n0.29.0",
    "The current core release is\n`solverforge #{CORE}`", NOTE_CORE, NOTE_CORE_28,
    "`0.29.0` | 2026-11-14",
    "59672a2b579f4ee0bbb58054af42d085f7c71ace", "23609c517d38e69c6b3223b444382fe742a31acfb4408db11da8f742a5d6b10b",
    "43644117741", "43644869186", "`planning_id: Option<String>`", "`ExplainOperator`",
    "https://github.com/SolverForge/solverforge/pull/267", "compare/v0.28.0...v0.29.0"
  ],
  "src/_posts/releases/2026-11-14-solverforge-0-28-x.md" => [
    "**solverforge 0.28.x** follows `solverforge 0.27.0`",
    "At publication `cargo add solverforge` installed\n0.28.0",
    "The current core release is\n`solverforge #{CORE}`", NOTE_CORE, NOTE_CORE_27,
    "`0.28.0` | 2026-11-14",
    "d8acec768522a068f22556bd8c5288612d1b8bb0", "63d7032cb6ad713fe60b739c5b49539031a5b2267e3af37a0750650b0f516d77",
    "43585162853", "43586479995", "`EntityRef::as_entity` and `EntityRef::with_display` are removed",
    "`SolverTelemetry::resolved_phase_plan`",
    "https://github.com/SolverForge/solverforge/pull/260", "https://github.com/SolverForge/solverforge/pull/262",
    "https://github.com/SolverForge/solverforge/pull/264", "compare/v0.27.0...v0.28.0"
  ],
  "src/_posts/releases/2026-11-18-solverforge-cli-4-1-4-2-x.md" => [
    "**solverforge-cli #{CLI} was published on November 21, 2026**",
    "`solverforge-cli #{CLI}` targets\n`solverforge #{CLI_RUNTIME}`",
    "| CLI | `solverforge-cli #{CLI}` | Fresh scaffolds target `solverforge #{CLI_RUNTIME}` |",
    "`#{CLI}` | 2026-11-21", "`4.2.1` | 2026-11-20", "`4.2.0` | 2026-11-18", "`4.1.0` | 2026-11-17", "8a5c3e206fcbcffb5c44f68b5b23f29d263c185d",
    "9428468cd009bdea80fd24f0eaba9c79dcfd36cc", "74cfe8f3a3f4a1d5182f594f646897fa85f8f63557a58f4a7c7e45da420ddb51",
    "44835073190", "44835077788", "44835077773", "compare/v4.2.0...v4.2.1",
    "bd0b5427cc985067a905d4a9361a9fc160429551", "84ae9fc20bb838d42e7954404c5adf24ca9ee47f13b6e7a3a2da0e66641762c7",
    "44878598757", "44878601505", "44878601542", "compare/v4.2.1...v4.2.2",
    "### `solver.toml` checked by the runtime's parser (4.2.1, 4.2.2)", "`` cannot set `move_thread_count.count` ``",
    "cedbfb4ff9ab1b08934ac7e1e88255bbba0a0631bae561f0c31d53b6bfe9801f", "44268676566", "44268681409", "44268681516",
    "compare/v4.1.0...v4.2.0",
    "b0d2bf99006c581a144ccdcb9e71e672878dc5ae", "13e9d9ff39b28442affc9004d202926d52f956bc937cb3bc0183e03cf54bbe41",
    "44152833105", "44152837060", "44152836862", "`resolvedPhasePlan`",
    "cargo install solverforge-cli --version #{CLI} --locked --force",
    "from a `solverforge-cli` checkout at `v#{CLI}`", NOTE_CORE, NOTE_CLI_40
  ],
  "src/docs/solverforge/constraints/score-analysis.md" => [
    "## Constraint Matches", "ScoreDirector::constraint_analyses()", "`planning_id`",
    "Unavailable employee: -1hard/0soft [Shift 7]", "no\nconstraint requires `Clone`"
  ],
  "src/docs/solverforge/solver/list-move-selectors.md" => [
    "## Element Groups", "type = \"list_group_change_move_selector\"",
    "type = \"list_group_swap_move_selector\"", "`max_member_distance = 7` and `max_group_owners = 4`"
  ],
  "src/_posts/releases/2026-11-13-solverforge-0-27-x.md" => [
    "**solverforge 0.27.x** follows `solverforge 0.26.1`",
    "At publication `cargo add solverforge` installed 0.27.0", "docs.rs\nserved the 0.27.0 API",
    "| Core runtime at publication | `solverforge 0.27.0` |",
    "| CLI at publication | `solverforge-cli 4.0.4` | Scaffolded core `0.26.1`",
    "All eight pinned core `0.26.1`",
    "The current core release is\n`solverforge #{CORE}`", NOTE_CORE,
    "`0.27.0` | 2026-11-13",
    "6ffcacabf117f9a5adf9abd4f4f96c01b9235859",
    "c8e84a99102b10b9237712d8742595e5634864c0ad088b7c28279581e253febe",
    "43416730323", "43417890887", "compare/v0.26.1...v0.27.0", "blob/v0.27.0/CHANGELOG.md",
    "`metric: DenseMatrix::new(distance_matrix, travel_times)`", "`type Metric = DenseMatrix;`",
    "EuclideanMetric::new(coordinates, speed)", "savings_neighbors = 40", "`savings_neighbors_fn`",
    "https://github.com/SolverForge/solverforge/pull/256", "https://github.com/SolverForge/solverforge/pull/257",
    "https://github.com/SolverForge/solverforge/pull/258", "https://github.com/SolverForge/solverforge/pull/259",
    NOTE_CORE_26, NOTE_CLI_40, NOTE_APPS
  ],
  "src/_posts/releases/2026-11-10-solverforge-0-26-x.md" => [
    "**solverforge 0.26.x** follows `solverforge 0.25.1`",
    "The current core release is\n`solverforge #{CORE}`", NOTE_CORE,
    "At publication `cargo add solverforge` installed 0.26.1",
    "| Last 0.26 release | `solverforge 0.26.1` |",
    "| CLI | `solverforge-cli 4.0.4` | Fresh scaffolds target core `0.26.1`",
    "All eight pin core `0.26.1`",
    "`solverforge-cli 4.0.4`\nscaffolds 0.26.1, and all eight worked use cases pinned it at publication",
    "`0.26.0` | 2026-11-10",
    "720fdaded42f16a131cdb8820b624b407b275d5f", "42797763891", "42797767461",
    "ScoreDirector::with_replicas", "`DirectorDescriptor::replica()` is replaced by `share()`",
    "from 2.82 GB to 0.37 GB", "compare/v0.25.1...v0.26.0",
    "`0.26.1` | 2026-11-11", "### Late acceptance keeps its score history (0.26.1)",
    "keeps its score history across a new best score unless a\nhard or medium level of the best score changes",
    "[slapers](https://github.com/slapers)", "https://github.com/SolverForge/solverforge/pull/242",
    "f3b41788e7519f3b707f8a9aa450fc545e0d5c08",
    "a00f06d8db244d619f556a25165115015bda50f01c811db0d515c9e6e3c28458",
    "42947324720", "42947327153", "compare/v0.26.0...v0.26.1", "blob/v0.26.1/CHANGELOG.md",
    NOTE_CORE_25, NOTE_CLI_40, NOTE_APPS
  ],
  "src/_posts/releases/2026-11-09-solverforge-0-25-x.md" => [
    "**solverforge 0.25.x** follows `solverforge 0.24.0`",
    "The current core release is\n`solverforge #{CORE}`", NOTE_CORE,
    "At publication\n`cargo add solverforge` installed 0.25.0",
    "`0.25.1` | 2026-11-09", "`0.25.0` | 2026-11-09",
    "### 0.25.1: bounded nearby list candidates",
    "3115b4dd6b40bc72a472b042f5e6b665cb9720c7", "42552915915", "42552934483",
    "6069763dffdf57786b703f113e5d290f3695ed02",
    "c899657c17ae3a41d67b583ec400e5d79fe253f0ed62a38a2efcb5d04d1171bb",
    "42663097755", "42663102655", "compare/v0.25.0...v0.25.1"
  ],
  "src/_posts/releases/2026-11-01-solverforge-0-24-x.md" => [
    "**solverforge 0.24.x** follows `solverforge 0.23.0`",
    "At publication `cargo add solverforge` installed 0.24.0", "docs.rs\nserved the 0.24.0 API",
    "`0.24.0` | 2026-11-01",
    "588a097929d85401d12561bda10dd20cdf784aa78abc6b19120b12ab50d9a852",
    "c114e2d2bfabaada78beb5ee77318b847b964489", "41314986907", "41314989365",
    "solver_toml", "weight_multiplier", "ProblemChange", "SingleConstraint",
    "from_yaml_str", "| CLI | `solverforge-cli 3.8.3` | Fresh scaffolds target core `0.24.0`",
    "/blog/releases/2026/11/03/solverforge-cli-3-8-x/", NOTE_APPS, NOTE_CORE
  ],
  "src/_posts/releases/2026-11-03-solverforge-cli-3-8-x.md" => [
    "**solverforge-cli 3.8.3 was published on November 7, 2026**",
    "`3.8.3` | 2026-11-07", "`3.8.2` | 2026-11-03", "`3.8.1` | 2026-11-03", "`3.8.0` | 2026-11-03",
    "f346415e833091586e0dcec0daf2c8ea4f9e07d4", "d4c4a680248e15e9a002beb6c2f93795d5762973b411be75ef50bb921f682fb3", "42416451385", "42416451305", "42416448853",
    "`solverforge-ui 0.9.1` and\n`solverforge-maps 2.3.3` for the web shell and `rmcp 3.9.0` for the MCP shell",
    "e842faa9c774eb342f29de4529de1ca18e91e171", "5f4253813e86c9c19b3df26404f0714608e1623b51104463c16013c4c20bbba3", "41718367762", "41718367773", "41718364701",
    "1e14044e924164a9aaf974628135b7a75a1f341f",
    "40e017937e0df564f2c767291bf1dc7eda4bded3f67cd4928b3f7566497851c0",
    "96ddbeefc5076761b9d69ad667a177330fd374dd",
    "2bfd9820d774bb33229a8044979a2b89673c65b0149d198c620b12dd12be61f3",
    "41640965796", "41640965834", "41640961789",
    "41625988555", "41625988624", "41625985949", "Windows failed",
    "BendableScore", "`solverforge test -- --nocapture`", "PORT",
    "| CLI | `solverforge-cli 3.8.3` | Fresh scaffolds target `solverforge 0.24.0` |",
    "/blog/releases/2026/11/01/solverforge-0-24-x/", NOTE_CLI
  ],
  "src/_posts/releases/2026-11-03-solverforge-usecases-3-0.md" => [
    "`solverforge-hospital@3.0.0`", "`solverforge-lessons@3.0.0`",
    "`solverforge-deliveries@3.0.0`", "`solverforge-fsr@3.0.0`",
    "`solverforge-furnace@3.0.0`", "`solverforge-orders@0.3.0`",
    "`solverforge-fleet@0.2.0`", "`solverforge-flightcrew@0.3.0`",
    "41637155114", "41637164072", "41637120152", "41637141120",
    "41637114103", "41637463799", "50371ec410b363864420ba97d6c5ee94771709d4",
    "`solverforge-deliveries@3.0.1`", "`solverforge-fsr@3.0.1`", "`solverforge-flightcrew@0.3.1`",
    "41718266892", "41718285190", "41718256141",
    "weightMultiplier", "make install-e2e", NOTE_CORE_25,
    "### November 10 releases: solverforge 0.25.1 and the CLI 4 layout",
    "`solverforge-hospital@3.0.2`", "`solverforge-lessons@3.0.2`",
    "`solverforge-deliveries@3.0.3`", "`solverforge-fsr@3.0.3`",
    "`solverforge-furnace@4.0.0`", "`solverforge-orders@0.3.2`",
    "`solverforge-fleet@0.2.2`", "`solverforge-flightcrew@0.3.3`",
    "42736874938", "42736880673", "42736842886", "42736861096", "42736837747",
    "`changeover_gap` instead of `changeoverGap`", NOTE_CLI_40,
    "| `solverforge-hospital@3.0.3` | `944329d87a029aa61696ce74ce9fd660368bb72c` |",
    "| `solverforge-lessons@3.0.3` | `922eb1d2e8712445572b7bfeb7df2de463009191` |",
    "| `solverforge-deliveries@3.0.4` | `73dd1cf0fea6cd29fa584ec309d9d72d18c4916b` |",
    "| `solverforge-fsr@3.0.4` | `93eeb265d050d15a542cb5b04fe225393b63f334` |",
    "| `solverforge-furnace@4.0.1` | `2992c2f824bf75d393e21a5bd8c09a29de6b13d7` |",
    "| `solverforge-orders@0.3.3` | `48c73d626e0bd0758a2885bf4ef6014a32cb077c` |",
    "| `solverforge-fleet@0.2.3` | `98bd6bfb10072355d4df0068a44e172d755c4d57` |",
    "| `solverforge-flightcrew@0.3.4` | `bdd055e7814ce6974286d209dd7949304aa7cb09` |",
    "42810005593", "42810012066", "42809974394", "42809991743", "42809967938",
    "### November 10 releases: solverforge 0.26.0",
    "all eight apps released on `solverforge 0.26.0`",
    "### November 11 releases: solverforge 0.26.1",
    "all eight apps released on `solverforge 0.26.1`",
    "### November 18 releases: solverforge #{APP_RUNTIME}", "the bundle gained a ninth app",
    "| `solverforge-hospital@3.0.6` | `67cc197b27eb422032ccf540af9c72658454b895` |",
    "| `solverforge-lessons@3.0.6` | `47b88cef9dd7194c0a5cb155ec22c354c8111a63` |",
    "| `solverforge-deliveries@3.0.7` | `2612a887130c2f9cbf78e4773f9d3d691d0841f4` |",
    "| `solverforge-fsr@3.0.7` | `07589e13da83c8a745c497322df2e8ea928ffc2b` |",
    "| `solverforge-ev@0.1.0` | `971ca9fcf793e8b28e45ddf20bced55b553759af` |",
    "44286407400", "44286416781", "44286389321", "44286400504", "44286382345",
    "| `solverforge-hospital@3.0.4` | `54e37f83e263a3283ab609857e4a9b028db0fc79` |",
    "| `solverforge-lessons@3.0.4` | `c2e40f912ddba49b41ed5a372d888b67e25faecb` |",
    "| `solverforge-deliveries@3.0.5` | `2c1326dbb20ac44e0760bc6fd35a4991471ab36d` |",
    "| `solverforge-fsr@3.0.5` | `3344a74cdb76981dc58143b2d38ee150135cf996` |",
    "| `solverforge-furnace@4.0.2` | `60250351a17358be9ab83731936ba6ffcfffed44` |",
    "| `solverforge-orders@0.3.4` | `28520582d57c012b3df1db64859311ec60186f3e` |",
    "| `solverforge-fleet@0.2.4` | `e02a6877c4382b85a6346b1d7d4d3bb9dcfd9403` |",
    "| `solverforge-flightcrew@0.3.5` | `d1ea42572f6b13115bfcd68029d48d66ef481c3e` |",
    "42958140633", "42958145776", "42958112416", "42958131088", "42958108105", NOTE_CORE_26
  ],
  "src/_posts/releases/2026-11-10-solverforge-cli-4-0-x.md" => [
    "**solverforge-cli 4.0.4 was published on November 11, 2026**",
    "`solverforge-cli 4.0.4` targets `solverforge 0.26.1`;\n4.0.0 and 4.0.1 target `solverforge 0.25.1`",
    "Historical release note", NOTE_CLI,
    "`4.0.4` | 2026-11-11", "`4.0.3` | 2026-11-10", "`4.0.2` | 2026-11-10", "`4.0.1` | 2026-11-10", "`4.0.0` | 2026-11-10",
    "### Fresh scaffolds target SolverForge 0.26.1 (4.0.4)", "issues/17",
    "5d879665ec375b154d72f00dfcadf8613216b159",
    "63adb8f592464b8cafe04dbe7556824fd221dc3b83794241b4e5de64bacc39f9",
    "42960000938", "42960004422", "42960004417",
    "9a780eaf9d6a77bfb6f311ba943558faced14935", "b8e0e989da0e8531d2def434243de35dcc2afa99689bfeb873f3ee82228fe28e",
    "42809532226", "42809536259", "42809536103", NOTE_CORE_26,
    "5f2cafaa09a1d27ca4a6aa37e829a42138a2ee07",
    "e94c83bda45341f815cecd73bad3e80186004f9a2e0de40028170a6a9cdc4745",
    "42845606910", "42845615766", "42845615729",
    "The `solverforge-modeling` skill loads in agents that scan skills (4.0.3)",
    "issues/15", "| Previous 4.0 release | `solverforge-cli 4.0.3` | Scaffolds `solverforge 0.26.0`",
    "from a `solverforge-cli` checkout at `v4.0.4`",
    "| Last 4.0 release | `solverforge-cli 4.0.4` | Scaffolds `solverforge 0.26.1` |",
    "bd43abb00a4079450b5b8275d0538b47a2da686e",
    "6c78ad746eed5a3088ea2a54342ff0e0cbf3059a57c11d00c06b3215d837b585",
    "42724970762", "42724972681", "42724973029",
    "21d405519c41bc773b3bc27ba1280ae0d29081f8",
    "b48647fc356fa419580c58596d5d7247565cf402ec34cefc3f20f913f569ad11",
    "42739815706", "42739818624", "42739818604",
    "`src/constraints/assemble.rs`", "`super::<id>::constraint()`",
    "cargo install solverforge-cli --version 4.0.4 --locked --force",
    NOTE_CLI_39, NOTE_CORE_25
  ],
  "src/_posts/releases/2026-11-09-solverforge-cli-3-9-x.md" => [
    "**solverforge-cli 3.9.0 was published on November 9, 2026**",
    "`3.9.0` | 2026-11-09", "f33d836f", "42557490301", "42557496537", "42557496534",
    "Historical release note", NOTE_CLI
  ],
  "src/_posts/releases/2026-10-27-solverforge-cli-3-7-x.md" => [
    "The current CLI is `solverforge-cli #{CLI}`,\nwhich scaffolds `solverforge #{CLI_RUNTIME}`", NOTE_CLI,
    "`3.7.1` | 2026-10-27", "`3.7.0` | 2026-10-27", "`3.6.0` | 2026-10-18",
    "fcaad8e3ef59444cb28f7e4742494e2b0cbb64ca",
    "ba476ea2862d6e0a6e2f0a9a434428d2887f8863abdd1e932b6ef87598d7d538",
    "ServerConfig", "rmcp 3.8.0", "40546507692", "40546507680", "40546499568",
    "ab79f437bf7694bbb166d1247cde30c5c5a00e42",
    "41e70042260d7ed88e7f310822f3c0f583dea2d5dd28fa92e48820919d72841e",
    "40525393646", "40525393731", "40525390383",
    "Windows failed", "test_new_creates_neutral_project_files",
    "Integration Tests job were skipped", "move_thread_count.count 4",
    "`phases` array", "movesSpeculative", "discarded_speculative",
    "RAYON_NUM_THREADS", "32"
  ],
  "src/_posts/releases/2026-06-02-solverforge-python-0-4-x.md" => [
    "The current binding is `solverforge 0.8.1` on core `0.31.2`",
    "/blog/releases/2026/11/20/solverforge-python-0-8-x/"
  ],
  "src/_posts/releases/2026-07-03-solverforge-python-0-5-x.md" => [
    "The current binding is `solverforge 0.8.1` on core `0.31.2`",
    "/blog/releases/2026/11/20/solverforge-python-0-8-x/"
  ],
  "src/_posts/releases/2026-10-27-solverforge-python-0-7-x.md" => [
    "The current binding is `solverforge 0.8.1` on core `0.31.2`",
    "/blog/releases/2026/11/20/solverforge-python-0-8-x/",
    "**SolverForge Python 0.7.x** follows `solverforge 0.6.15`",
    "solverforge==0.7.2", "`0.7.2` | 2026-10-28", "`0.7.1` | 2026-10-28", "`0.7.0` | 2026-10-27",
    "22833923229c008a70c385e05c76072a5d87c75f",
    "40672018229", "40672022045", "40665034987", "40665037880",
    "3f9bac5b0196c33dbe8906aa7e7c3293873cfd3488331a390ce426db0fe7e218",
    "c2945fad91e450cd6dbf691090ea91753adcde45e513805d6bc8df01a7810288",
    "KeyboardInterrupt", "SolverPanicPayload", "previous hook",
    "0f739eb5d427a8a7748b21009ca70bbfa4697750",
    "40499986297", "40499989425", "32 evaluators",
    "db040cc537d5f281822ac438b123cc281966c344eab23cbf6b80ac7f1125872c",
    "258dc6279865d67b2503eae775cc03114cc6db71d8bd96276ae5ba27c830be6c",
    "releases the GIL", "Stateful ruin selectors", "discarded_speculative",
    "replace the single `phase` dictionary with\n`phases`",
    "pinned exactly to `=0.23.0`", "Fresh scaffolds target core `0.23.0`"
  ],
  "src/docs/solverforge/modeling/planning-entities.md" => [
    "per-entity legal domain", "search hint, not a legal-domain restriction",
    "swap families ignore it", "pub allowed_employees: Vec<usize>"
  ],
  "src/docs/solverforge/modeling/list-variables.md" => [
    "list_shadow_elements", "clear_list_shadows", "list_shadow_source",
    "`DenseMatrix::new(distances, travel_times)`", "`EuclideanMetric::new(coordinates, speed)`",
    "type Metric = EuclideanMetric;", "| `savings_neighbors_fn` |",
    "## Element Groups", "element_group_fn = \"ride_stops\"", "### Cascading Shadows Across Lists",
    "cascading_dependencies = \"task_dependencies\"", "### Joint Groups", "cascading_peers = \"visit_partners\"",
    "0hard/-60soft [Some(10), Some(14), Some(17), Some(0)]"
  ],
  "src/docs/solverforge/constraints/score-types.md" => [
    "It has no family field", "active_dynamic_score_family()"
  ],
  "src/docs/solverforge/solver/termination.md" => [
    "Parallel Evaluation Budgets", "not\nadded to `moves_evaluated` or `score_calculations`"
  ],
  "src/reference/extend-solver.md" => [
    "Cow<'_, MoveTabuSignature>", "fn(&S) -> C", "DiscardedSpeculative",
    "list_shadow_elements", "not mutable aggregate fields",
    "list slots with element groups receive group change and group swap first"
  ],
  "src/_posts/releases/2026-10-27-solverforge-0-23-x.md" => [
    "**solverforge 0.23.x** follows `solverforge 0.22.0`",
    "`0.23.0` | 2026-10-27",
    "1f8c86c2a087fa16102100ba0e2f4eb80b501904853e9baf701533df1b19a063",
    "e835624a7c04a8ecd2a2ac9a1bcbd92cbc6aca89",
    "40473570696", "40473570732", "40473567305",
    "macOS failed", "integration tests were skipped",
    "32 evaluators", "given evaluator count", "DiscardedSpeculative",
    "SolverTelemetry.phase", "phases: Vec<PhaseTelemetry>",
    "Cow<'_, MoveTabuSignature>", "list_shadow_elements",
    "active_dynamic_score_family", "not a new swap restriction",
    "fresh scaffolds target core `0.23.0`",
    "The current core release is\n`solverforge #{CORE}`", NOTE_CORE
  ],
  "src/_posts/releases/2026-05-23-solverforge-0-15-x.md" => [
    "`solverforge #{CORE}` is the current core",
    "0.31.x release note", "The `solverforge-cli #{CLI}` line scaffolds core `#{CLI_RUNTIME}`", "3.9.0 targeted\n`0.25.0`"
  ],
  "src/_posts/releases/2026-06-12-solverforge-0-16-x.md" => [
    "`solverforge #{CORE}` is the current core",
    "0.31.x release note", "The `solverforge-cli #{CLI}` line scaffolds core `#{CLI_RUNTIME}`", "3.9.0 targeted\n`0.25.0`"
  ],
  "src/_posts/releases/2026-06-15-solverforge-0-17-x.md" => [
    "`solverforge #{CORE}` is the current core",
    "0.31.x release note", "The `solverforge-cli #{CLI}` line scaffolds core `#{CLI_RUNTIME}`", "3.9.0 targeted\n`0.25.0`"
  ],
  "src/_posts/releases/2026-07-13-solverforge-0-18-x.md" => [
    "`solverforge #{CORE}` is the current core",
    "0.31.x release note", "The `solverforge-cli #{CLI}` line scaffolds core `#{CLI_RUNTIME}`", "3.9.0 targeted\n`0.25.0`"
  ],

  "src/docs/solverforge/solver/phases.md" => [
    "### Resolved Phase Plan", "`telemetry.resolved_phase_plan`",
    "`SolverTelemetry::phases` retains every started phase in execution order",
    "effective parsed limit",
    "empty termination object",
    "construction-only"
  ],
  "src/docs/solverforge/solver/local-search.md" => [
    "refills the entire ring\nwith that score only when one of its hard or medium levels differs from the\nprevious best",
    "A new best that improves only soft levels\nleaves the ring as it is",
    "Parallel Candidate Evaluation", "DiscardedSpeculative",
    "trajectory can depend on the evaluator count",
    "Cow<'_, MoveTabuSignature>",
    "effective parsed limit",
    "empty termination object",
    "construction-only",
    "## Default Policy", "| list variables | Late Acceptance, history 400 | accepted count 4 |",
    "| scalar groups, no list variables | Diversified Late Acceptance, history 400 | accepted count 32 |",
    "draw weight 1 against 4"
  ],
  "src/docs/solverforge/solver/index.md" => [
    "effective parsed limit",
    "construction-only"
  ],
  "src/docs/solverforge/solver/construction.md" => [
    "Completed optional roots are skipped before reading their",
    "candidate domains or generating moves",
    "required augmenting", "retained feasibility evidence",
    "### Bounded Clarke-Wright savings", "savings_neighbors = 40", "`savings_neighbors_fn`",
    "## Default Construction", "`element_groups_declared`", "`list_elements_remain_unassigned`",
    "keeps 40 savings per element", "once a fifth of the solve's time limit has passed",
    "`time_budget_seconds`", "### Element Group Placement", "max_group_owners = 6"
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
  "src/_posts/releases/2026-10-18-solverforge-0-22-x.md" => [
    "**solverforge 0.22.x** follows `solverforge 0.21.3`", "published on\ncrates.io on 2026-10-18",
    "At publication, `cargo add solverforge` installed\n0.22.0", "docs.rs served the 0.22.0 API",
    "5c882fc55b59e28632a276df4e8f820ec0a3b52ecaf5d4a7afe69139c954db6b",
    "df1ce37b4a69a61fe249e71852ea694de94b4493",
    "`0.22.0` | 2026-10-18", "compare/v0.21.3...v0.22.0"
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
    "Previous core runtime | `solverforge 0.21.3` | Registry and release artifacts remain available",
    "see the [0.22.x line note](/blog/releases/2026/10/18/solverforge-0-22-x/)",
    "`0.21.3` | 2026-10-14", "`0.21.2` | 2026-10-14", "`0.21.0` | 2026-10-14",
    "compare/v0.20.4...v0.21.3", "compare/v0.20.1...v0.21.0",
    "The current core release is\n`solverforge #{CORE}`"
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
  "scripts/lib/rust_pages.rb" => [
    %(RELEASE = "#{CORE}")
  ],

  "src/docs/solverforge/index.md" => [
    "cargo add solverforge@=#{CORE}",
    "These pages track `solverforge #{CORE}`",
    "The workspace declares Rust `1.95`.",
    "`solverforge-cli #{CLI}` scaffolds `solverforge #{CLI_RUNTIME}`; an app"
  ],

  "src/docs/solverforge/solver/solver-manager.md" => ["holding the worker's pause gate", "does not restart from the best solution"],
  "src/docs/solverforge/constraints/node-sharing.md" => ["The compiler supports sharing"],
  "src/docs/solverforge/constraints/existence-and-flattening.md" => [
    "DenseKeys::add", "per event", "at most once"
  ],
  "src/docs/solverforge-python/index.md" => [
    "solverforge-py v0.8.1",
    "solverforge==0.8.1",
    "solverforge 0.31.2",
    "solverforge-ui 0.9.1",
    "/blog/releases/2026/11/20/solverforge-python-0-8-x/"
  ],
  "src/_posts/releases/2026-11-20-solverforge-python-0-8-x.md" => [
    "**SolverForge Python 0.8.x** follows `solverforge 0.7.2`",
    "solverforge==0.8.1", "`0.8.1` | 2026-11-20", "`0.8.0` | 2026-11-20",
    "never published", "6776c18c76134b40ecc8a459c6d74fe771c49210",
    "7c8a5f8a3dbfbbedd7e72e4295b797d8faca7dce",
    "44814575001", "44814580348", "44812794516", "44812798819",
    "44eea1e3f1f5035e128e7d1c1ae9814c53347730b98e54fb49877def76e7f064",
    "5e6e05d284e1430571e2f50051fb4d71c717327150c66996517cf076005d81bf",
    "6ad1f1285a01c663f75efb8c864eb3c9239b5eb43a2cf6d12bdd381b95825862",
    "7b9c92a1a86dabb94176316161062641c225c0e53af13db353f19ba57074c377",
    "exactly\n`=0.31.2`", "`resolved_phase_plan`", "`problem_changes_applied`",
    "score_director.constraint_provider", "no implicit time limit"
  ],
  "src/docs/solverforge-python/modeling.md" => [
    "`candidate_values` is also the native hard domain",
    "`same_value_conflict_field`", "## Entity Pinning", "`planning_pin()`",
    "`planning_variable(pinning=True)` is not supported",
    "assert [shift.employee_idx for shift in solved.shifts] == [0, 1]",
    "mandatory planning work incomplete", "actual `bool`"
  ],
  "src/docs/solverforge-cli/index.md" => [
    "This manual documents the `solverforge-cli #{CLI}` interface",
    "Fresh scaffolds target `solverforge #{CLI_RUNTIME}`",
    "panics: a solve fails until you\nreplace it",
    "evaluates local search on up to four evaluators when its measurements say",
    "`web`, `api`, `cli`, or `mcp`"
  ],
  "src/docs/solverforge-cli/command-reference.md" => [
    "solverforge-cli #{CLI} command surface",
    "CLI version: #{CLI}",
    "SolverForge crate target #{CLI_RUNTIME}",
    "`solverforge-cli #{CLI}` line starts new scaffolds on the published\n`solverforge #{CLI_RUNTIME}` runtime",
    "Scaffold MCP target: rmcp 3.9.0",
    "solverforge connect"
  ],
  "src/docs/solverforge-cli/generator-commands.md" => [
    "`--countable-range <FROM..TO>`",
    "`--runs`",
    "`--projected-group`",
    "`SimpleScore` is not a score type",
    "computing all rewrites before it writes any of them",
    "`// @generated by solverforge-cli: data v1` header",
    "`BendableScore` is refused", "rejects `--field id:...`",
    "Remove dependents before what they depend on",
    "because source files still reference it",
    "`super::<NAME>::constraint()`", "`src/constraints/assemble.rs`"
  ],
  "src/docs/solverforge-cli/configuration.md" => [
    "cli_version = \"#{CLI}\"",
    "target = \"solverforge #{CLI_RUNTIME}\"",
    "solver_toml = \"../../solver.toml\"", "does not look for `solver.toml` in the\nworking directory",
    "move_thread_count.count 4", "RAYON_NUM_THREADS", "32",
    "`\"auto\"`", "`\"none\"`", "one positive integer `count`; `count = 0` is rejected"
  ],
  "src/docs/solverforge-cli/getting-started.md" => [
    "solverforge solverforge-cli #{CLI}", "Scaffold runtime target: SolverForge crate target #{CLI_RUNTIME}",
    "cargo install solverforge-cli --locked", "solverforge test -- --nocapture",
    "adds its `constraint()` call to\n`create_constraints` in `src/constraints/assemble.rs`"
  ],
  "src/docs/solverforge-cli/operations-commands.md" => [
    "It does not compile the project", "[-- <HARNESS_ARGS>...]", "chained methods",
    "has a call in `src/constraints/assemble.rs`", "holds only declarations",
    "helper modules\ndeclared outside that block are not listed"
  ],
  "src/docs/solverforge-cli/project-anatomy.md" => [
    "`resolvedPhasePlan` carries the policy the solve actually ran",
    "| `src/constraints/assemble.rs` |", "## Module Roots Hold Declarations Only",
    "super::task_assigned::constraint(),", "pub use assemble::create_constraints;"
  ],
  "src/docs/solverforge-cli/scaffold-commands.md" => [
    "`web`, `api`, `cli`, and `mcp`",
    "rmcp",
    "cargo run -- demo-data", "`PORT` environment variable"
  ],
  "src/docs/solverforge/solver/configuration.md" => [
    "### Bounded Clarke-Wright Savings", "`phases[N].construction.savings_neighbors`",
    "Move Thread Count", "`min(N, rayon::current_num_threads(), 32)` evaluators",
    "effective parsed limit", "construction-only",
    "Keeping an optional assignment unassigned completes that group-slot decision",
    "An explicit `list_clarke_wright` phase scores every pair", "`list_group_change_move_selector` and `list_group_swap_move_selector` move"
  ],
  "src/docs/solverforge-maps/index.md" => [
    "This section tracks the published `solverforge-maps #{ReleasePins::MAPS}` crate.",
    "web scaffolds declare `solverforge-maps = \"#{ReleasePins::CLI_SCAFFOLD_MAPS}\"`",
    "**Car-legal road graphs**", "**Street names on every route**", "**Access-aware snapping**",
    "**Slowdowns for busy periods**", "**Bicycle and foot networks**"
  ],
  "src/docs/solverforge-maps/routing.md" => [
    "## Read the Streets Along a Route", "`StreetRun`", "edges_with_names_iter()",
    "### Snap by Itinerary Role", "compute_matrix_with_access", "SnapAccess::Incoming",
    "snap_road_index_with_access", "## Measure Travel at Busy Times", "network.slowed(&[streets, centre])",
    "## Travel by Bicycle or on Foot", "TravelMode::Bicycle", "load_or_fetch_for"
  ],
  "src/docs/solverforge-maps/getting-started.md" => [
    "motorway_link", "`destination` stays open", "route.streets"
  ],
  "src/docs/solverforge-maps/caching.md" => ["`solverforge-maps #{ReleasePins::MAPS}` writes cache version `8`", "`~bicycle` or `~foot`"],
  "src/_posts/releases/2026-11-21-solverforge-maps-2-5-x.md" => [
    "**solverforge-maps #{ReleasePins::MAPS} was published on November 21, 2026**",
    "44897281664", "44897281646", "44897279372", "`384bbd2`",
    "`2.5.0` | 2026-11-21", "RoadNetwork::load_or_fetch_for()", "TravelMode::ALL",
    "| `solverforge-cli` web scaffold | `#{CLI}` | `solverforge-maps = { version = \"#{ReleasePins::CLI_SCAFFOLD_MAPS}\" }`, which resolves to `#{ReleasePins::MAPS}` |"
  ],
  "src/_posts/releases/2026-11-21-solverforge-maps-2-4-x.md" => [
    "Historical release note", "/blog/releases/2026/11/21/solverforge-maps-2-5-x/",
    "**solverforge-maps 2.4.0 was published on November 21, 2026**",
    "44889903862", "44889903928", "44889902327", "`efaa2ed`",
    "`2.4.0` | 2026-11-21", "RoadNetwork::slowed()", "cache moves to version `8`"
  ],
  "src/_posts/releases/2026-11-06-solverforge-maps-2-2-2-3-x.md" => [
    "Historical release note", "/blog/releases/2026/11/21/solverforge-maps-2-5-x/",
    "**solverforge-maps 2.3.4 was published on November 18, 2026**",
    "44396715207", "44396715198", "44394585321", "`79edff5`",
    "`2.3.4` | 2026-11-18", "`2.3.3` | 2026-11-06", "`2.3.2` | 2026-11-06", "`2.3.1` | 2026-11-06",
    "`2.3.0` | 2026-11-06", "`2.2.0` | 2026-11-06",
    "| `solverforge-cli` web scaffold | `#{CLI}` | `solverforge-maps = { version = \"#{ReleasePins::CLI_SCAFFOLD_MAPS}\" }` |"
  ],
  "src/_posts/releases/2026-05-03-solverforge-maps-2-1-x.md" => [
    "Historical release note", "/blog/releases/2026/11/21/solverforge-maps-2-5-x/",
    "`2.1.5` | 2026-11-03"
  ],
  "src/_posts/releases/2026-11-07-solverforge-ui-0-9-x.md" => [
    "**solverforge-ui #{ReleasePins::UI} was published on November 7, 2026**",
    "42411875031", "42411875086", "42411873082", "`94cfd9e`",
    "`0.9.1` | 2026-11-07", "`0.9.0` | 2026-09-15", "dashArray",
    "| `solverforge-cli` web scaffold | `#{CLI}` | `solverforge-ui = { version = \"#{ReleasePins::UI}\" }` |"
  ],
  "src/docs/solverforge-python/getting-started.md" => [
    "SolverForge 0.31.2", "`cp314` ABI, not `cp314t`", "solverforge==0.8.1"
  ],
  "src/docs/solverforge-python/solving-and-runtime.md" => [
    "0.31.2 runtime graph", "`resolved_phase_plan`", "`problem_changes_applied`",
    "No time limit is added for you", "`score_director.constraint_provider`",
    "`{\"count\": 0}` is a configuration error", "moves_speculative", "discarded_speculative",
    "phases = telemetry[\"phases\"]", "releases the GIL",
    "not a universal cross-count guarantee",
    "## Callback Errors And Interrupts", "`KeyboardInterrupt`", "`except Exception`",
    "`AttributeError` means an optional attribute is absent", "SolverPanicPayload",
    "previously installed panic hook", "`FAILED`", "manager.wait(...)"
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
    "never pipes `curl` output\ninto an interpreter",
    "make install-skill",
    "--agent opencode|claude|codex",
    "--layout covering"
  ],
  "src/docs/solverforge-ui/index.md" => [
    "solverforge-ui #{ReleasePins::UI}",
    "/sf/sf.#{ReleasePins::UI}.css",
    "SF.version"
  ],
  "src/docs/solverforge-ui/integration-assets.md" => [
    "solverforge-ui #{ReleasePins::UI}",
    "dashArray",
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
    "does not bundle it"
  ],
  "src/_data/docs_nav.yml" => [
    "/docs/solverforge-ui/agent-skill/",
    "/docs/solverforge-cli/mcp-shell/",
    "/docs/solverforge-cli/agent-skill/",
    "/docs/solverforge/constraints/shift-group-uniformity/"
  ],
  "src/reference/crate-map.md" => [
    "solverforge #{CORE}",
    "`AcceptedCount(4)` for list models and `AcceptedCount(32)` for\nscalar groups",
    "solverforge 0.8.1",
    "solverforge-py v0.8.1"
  ],
  "src/reference/lifecycle-pause-resume-contract.md" => [
    "solverforge #{CORE}",
    "solverforge-ui #{ReleasePins::UI}",
    "is not\nmove-for-move exact"
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
    "documentation tracks the `solverforge #{CORE}` release",
    "`cargo add solverforge` installs #{CORE}", "docs.rs serves the #{CORE} API",
    "Native Rust constraint solver published as `solverforge #{CORE}`",
    "The independently published CLI line is `solverforge-cli #{CLI}`",
    "Fresh\nscaffolds target `solverforge #{CLI_RUNTIME}`",
    "`solverforge-cli #{CLI}` targets `solverforge #{CLI_RUNTIME}`",
    "`v#{CORE}` points to `78889c3ff9fda158c70e6a1f67f8c7f0fdae922e`", "44182372301", "44185759448",
    "list element groups, cascading list shadows across owners, constraint matches with planning ids, and a measured default search policy",
    "- **List element groups**", "- **Cascading list shadows**", "- **Constraint matches**", "- **Resolved phase plan**",
    "commits the routes that fit, and the default construction places the rest",
    NOTE_CORE_28, NOTE_CORE_29, NOTE_CORE_30,
    "refills its window with a new phase best only when a hard or medium level of\n  the best score changes",
    "bd0b5427cc985067a905d4a9361a9fc160429551", "44878601505", "44878601542", "44878598757",
    "`0.31.1` from 4.1.0, `0.26.1` from\n4.0.4, `0.26.0` from 4.0.2 and 4.0.3", "`0.25.1` from 4.0.0 and 4.0.1",
    "assembled in `src/constraints/assemble.rs`",
    "The current UI line is `solverforge-ui #{ReleasePins::UI}`, and the current maps line is\n`solverforge-maps #{ReleasePins::MAPS}`",
    "solverforge-hospital@3.0.6", "solverforge-lessons@3.0.6", "solverforge-deliveries@3.0.7",
    "solverforge-fsr@3.0.7", "solverforge-furnace@4.0.3", "solverforge-orders@0.3.5",
    "solverforge-fleet@0.2.5", "solverforge-flightcrew@0.3.6", "solverforge-ev@0.1.0", "44286382345",
    "nine apps on `solverforge #{APP_RUNTIME}`", "all nine target `solverforge #{APP_RUNTIME}` and `solverforge-ui 0.9.1`",
    "- **Termination**",
    NOTE_CORE, NOTE_CLI, NOTE_APPS,
    "- **Parallel local search**", "- **Per-phase telemetry**", "- **List-shadow scoring**",
    "- **Core runtime line**", "- **Joined-tuple grouping**", "- **Guided native scalar search**",
    "- **Score-authoritative grouped search**", "- **Late acceptance**",
    "- **Lending extensions**", "- **Owned runtime state**",
    "**0.19.13 existence-engine rewrite**",
    "**0.19.11 construction and scoring fixes**",
    "**0.19.12 retained bookkeeping**",
    "occurrence count per right-side key", "idempotently per event",
    "**Measured default policy**", "`AcceptedCount(4)`\n  for list models, `AcceptedCount(32)` for scalar groups",
    "**0.20.1 pooled scratch**", "0-20-x",
    "retained `KeyOf` keys", "caller-owned", "`RowChanges` is gone",
    "lists are updated in place", "residual predicates", "duplicate",
    "benchmark results or measured performance gains",
    "solverforge-py 0.8.1",
    "44814575001", "44814580348",
    "6776c18c76134b40ecc8a459c6d74fe771c49210",
    "Callback failures and interrupts",
    "over one compiled SolverForge 0.31.2 runtime graph",
    "`moves_speculative`, `discarded_speculative`",
    "solverforge-ui 0.9.1",
    "**Explicit configuration**", "**Constraint weights and problem changes**"
  ],
  "src/docs/getting-started/solverforge-hospital-use-case.md" => [
    "solverforge-hospital@3.0.6", "solverforge-ui 0.9.1",
    "solverforge #{APP_RUNTIME}",
    "super::assigned_shift::constraint(),", "`src/constraints/assemble.rs`"
  ],
  "src/docs/getting-started/solverforge-lessons-use-case.md" => [
    "solverforge-lessons@3.0.6", "solverforge-ui 0.9.1",
    "solverforge #{APP_RUNTIME}", "`src/constraints/assemble.rs`"
  ],
  "src/docs/getting-started/solverforge-deliveries-use-case.md" => [
    "solverforge-deliveries@3.0.7", "solverforge-ui 0.9.1",
    "solverforge #{APP_RUNTIME}",
    "super::all_deliveries_assigned::constraint(),", "`src/constraints/assemble.rs`"
  ],
  "src/docs/getting-started/solverforge-fsr-use-case.md" => [
    "solverforge-fsr@3.0.7", "solverforge-ui 0.9.1",
    "solverforge #{APP_RUNTIME}", "`src/constraints/assemble.rs`"
  ],
  "src/_posts/releases/2026-07-17-solverforge-0-19-x.md" => [
    "`solverforge #{CORE}` is the current core",
    "0.31.x release note",
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
    "`solverforge #{CORE}` is the current core",
    "`0.19.13` | 2026-10-11",
    "`0.19.12` | 2026-10-10",
    "`0.19.11` | 2026-10-10",
    "`0.19.10` | 2026-10-09",
    "solverforge 0.19.6",
    "solverforge 0.19.7",
    "`0.19.9` | 2026-10-08",
    "0.31.x release note",
    "`0.19.8` | 2026-10-02",
    "`0.19.6` | 2026-09-25",
    "`0.19.7` | 2026-09-25",
    "pinned"
  ],
      "src/_posts/releases/2026-09-29-solverforge-python-0-6-10-x.md" => [
    "The current binding is `solverforge 0.8.1` on core `0.31.2`",
    "/blog/releases/2026/11/20/solverforge-python-0-8-x/",
    "solverforge-py 0.6.15",
    "solverforge==0.6.15",
    "solverforge 0.22.0",
    "Pins the six SolverForge Rust dependencies to the published `0.21.0` registry base", "Targets the `solverforge 0.22.0` registry base",
    "solverforge-ui 0.9.0"
  ],
  "src/_posts/releases/2026-09-27-solverforge-usecases-repository-apps.md" => [
    "solverforge-furnace 2.0.2",
    "solverforge-orders 0.1.2",
    "solverforge-fleet 0.1.5",
    "solverforge-flightcrew 0.1.2",
    "## October Runtime Updates",
    "| Hospital | `2.0.9` | `2.0.10` | `2.0.11` |",
    "| Lessons | `2.0.11` | `2.0.12` | `2.0.13` |",
    "| Deliveries | `2.0.10` | `2.0.11` | `2.0.12` |",
    "| Field service | `2.0.11` | `2.0.12` | `2.0.13` |",
    "| Furnace | `2.0.3` | `2.0.4` | `2.0.5` |",
    "| Orders | `0.1.3` | `0.1.4` | `0.1.5` |",
    "| Fleet | `0.1.6` | `0.1.7` | `0.1.8` |",
    "| Flight crew | `0.1.3` | `0.1.4` | `0.1.5` |",
    "38723058914", "39113251530", "39113256126", "39113229026", "39113242845", "39113224930",
    "October 27 (core 0.23.0)",
    "| Hospital | `2.0.9` | `2.0.10` | `2.0.11` | `2.0.12` |",
    "| Lessons | `2.0.11` | `2.0.12` | `2.0.13` | `2.0.14` |",
    "| Deliveries | `2.0.10` | `2.0.11` | `2.0.12` | `2.0.13` |",
    "| Field service | `2.0.11` | `2.0.12` | `2.0.13` | `2.0.14` |",
    "| Furnace | `2.0.3` | `2.0.4` | `2.0.5` | `2.0.6`, then `2.0.7` |",
    "| Orders | `0.1.3` | `0.1.4` | `0.1.5` | `0.2.0` |",
    "| Fleet | `0.1.6` | `0.1.7` | `0.1.8` | `0.1.9` |",
    "| Flight crew | `0.1.3` | `0.1.4` | `0.1.5` | `0.2.0` |",
    "40524550543", "40524558093", "40524507822", "40524530701",
    "40537219778", "2da90f5e8d3994e8f91186bd268fc301472f9dfb",
    "movesSpeculative", "discarded_speculative", "does not make that pull interruptible",
    "repository-only"
  ],
  "src/_posts/releases/2026-07-13-solverforge-python-0-6-x.md" => [
    "The current Python source line is `solverforge-py 0.8.1`",
    "/blog/releases/2026/11/20/solverforge-python-0-8-x/",
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
  "src/_posts/releases/2026-11-09-solverforge-0-25-x.md" => [
    "`cargo add solverforge` installs 0.25.0", "docs.rs serves the 0.25.0", "Fresh `solverforge-cli 3.9.x` scaffolds target it"
  ],
  "src/reference/extend-solver.md" => ["ReplicaDescriptor"],
  "src/docs/solverforge/modeling/list-variables.md" => ["distance_matrix", "travel-time matrices"],
  "src/_posts/releases/2026-11-10-solverforge-0-26-x.md" => [
    "`cargo add solverforge` installs 0.26.0", "docs.rs serves the 0.26.0", "The first release is",
    "`cargo add solverforge` installs 0.26.1", "docs.rs serves the 0.26.1", "| Core runtime | `solverforge 0.26.1` |"
  ],
  "src/_posts/releases/2026-11-13-solverforge-0-27-x.md" => [
    "`cargo add solverforge` installs 0.27.0", "docs.rs serves the 0.27.0", "| Core runtime | `solverforge 0.27.0` |"
  ],
  "src/_posts/releases/2026-11-10-solverforge-cli-4-0-x.md" => [
    "| CLI | `solverforge-cli 4.0.4` | Fresh scaffolds target `solverforge 0.26.1` |"
  ],
  "src/docs/solverforge/solver/construction.md" => ["By default `list_clarke_wright` scores every pair"],
  "src/docs/solverforge/constraints/score-analysis.md" => ["use the lower-level\n`solverforge::analysis`", "as_entity"],
  "src/docs/solverforge/solver/local-search.md" => [
    "a new phase-best committed score fills the entire ring", "re-anchoring the acceptance window"
  ],
  "src/reference/crate-map.md" => ["ReplicaDescriptor", "AcceptedCount(256)", "solverforge 0.27.0", "tree/v0.27.0", "solverforge 0.25.0", "solverforge 0.26.0", "tree/v0.26.0", "solverforge 0.26.1", "tree/v0.26.1"],
  "src/_posts/releases/2026-05-03-solverforge-maps-2-1-x.md" => ["is the current maps line", "Use the crates.io package pin"],
  "src/_posts/releases/2026-11-06-solverforge-maps-2-2-2-3-x.md" => ["| `2.3.4` | current |"],
  "src/docs/solverforge-maps/routing.md" => ["snaps both endpoints to the nearest graph nodes"],
  "src/docs/solverforge-maps/getting-started.md" => ["snaps both endpoints to the nearest graph nodes"],
  "src/docs/solverforge-python/getting-started.md" => ["solverforge==0.7.2", "git checkout v0.7.2", "0.23.0 runtime", "solverforge==0.7.0", "solverforge==0.7.1", "git checkout v0.7.0", "git checkout v0.7.1", "solverforge==0.6.15", "v0.6.15", "0.22.0 runtime"],
  "src/docs/solverforge-python/solving-and-runtime.md" => ["0.22.0 runtime graph", "0.23.0 runtime graph", "currently sequential", "Counts of zero or one stay sequential"],
  "src/docs/solverforge/index.md" => [
    "These pages track `solverforge 0.25.0`", "solverforge@=0.25.0", "tree/v0.25.0",
    "These pages track `solverforge 0.26.0`", "solverforge@=0.26.0", "tree/v0.26.0",
    "These pages track `solverforge 0.26.1`", "solverforge@=0.26.1", "tree/v0.26.1",
    "These pages track `solverforge 0.27.0`", "solverforge@=0.27.0", "tree/v0.27.0",
    "`solverforge-cli 4.0.4` scaffolds `solverforge 0.26.1`",
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
  "src/docs/solverforge-python/index.md" => ["solverforge-py 0.6.15", "solverforge==0.6.15", "published binding remains on core `0.22.0`", "solverforge-py 0.6.3", "solverforge==0.6.3", "solverforge-py 0.6.10", "solverforge==0.6.10"],
  "src/docs/solverforge-cli/index.md" => [
    "solverforge-cli 3.7.1", "Fresh scaffolds target `solverforge 0.23.0`",
    "solverforge-cli 3.0.0",
    "solverforge-cli 3.3.1",
    "solverforge-cli 3.3.2",
    "--only"
  ],
  "src/docs/solverforge-cli/command-reference.md" => [
    "CLI version: 4.0.1", "SolverForge crate target 0.25.1",
    "CLI version: 3.7.1", "SolverForge crate target 0.23.0",
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
    "cli_version = \"4.0.1\"", "target = \"solverforge 0.25.1\"",
    "cli_version = \"3.7.1\"", "target = \"solverforge 0.23.0\"",
    "construction_heuristic_type = \"first_fit\"\n\n[[phases]]",
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
    "only `vscode`", "[EXTRA_ARGS]..."
  ],
  "src/docs/solverforge-cli/getting-started.md" => [
    "registers it in",
    "--field name:String", "--field id:String", "`BendableScore<",
    "cannot localize entity indexes", "--entity Route"
  ],
  "src/docs/solverforge-cli/generator-commands.md" => [
    "`BendableScore<2, 3>`", "for_each_unique_pair", "--target Task.primary_idx",
    "module and registry entry"
  ],
  "src/docs/solverforge-cli/modeling-and-generation.md" => [
    "`BendableScore<N, M>`", "for_each_unique_pair", "--target Task.primary_idx",
    "solverforge destroy entity task\nsolverforge destroy variable"
  ],
  "src/docs/solverforge-cli/mcp-shell.md" => [
    "only `vscode`"
  ],
  "src/docs/solverforge-cli/agent-skill.md" => [
    "--only"
  ],
  "src/docs/status-and-roadmap.md" => [
    "resets the window on a new phase best",
    "documentation tracks the `solverforge 0.26.0` release", "`cargo add solverforge` installs 0.26.0",
    "documentation tracks the `solverforge 0.26.1` release", "`cargo add solverforge` installs 0.26.1",
    "documentation tracks the `solverforge 0.27.0` release", "`cargo add solverforge` installs 0.27.0",
    "Native Rust constraint solver published as `solverforge 0.27.0`",
    "The independently published CLI line is `solverforge-cli 4.0.4`", "**Grouped-scalar foraging**",
    "Native Rust constraint solver published as `solverforge 0.26.1`",
    "Native Rust constraint solver published as `solverforge 0.26.0`",
    "The independently published CLI line is `solverforge-cli 4.0.3`",
    "The independently published CLI line is `solverforge-cli 4.0.2`",
    "The independently published CLI line is `solverforge-cli 4.0.1`",
    "eight apps on `solverforge 0.25.1`", "eight apps on `solverforge 0.26.0`",
    "`cargo add solverforge` installs 0.25.0", "documentation tracks the `solverforge 0.25.0` release",
    "Native Rust constraint solver published as `solverforge 0.25.0`",
    "`cargo add solverforge` installs 0.23.0", "docs.rs serves the 0.23.0 API",
    "documentation tracks the `solverforge 0.23.0` release",
    "Native Rust constraint solver published as `solverforge 0.23.0`",
    "The independently published CLI line is `solverforge-cli 3.7.1`",
    "TOML/YAML parsing helpers",
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
  "src/docs/getting-started/solverforge-hospital-use-case.md" => ["solverforge-hospital@3.0.4", "solverforge 0.26.1", "uuid = {", "solverforge-ui 0.9.0", "solverforge-hospital@2.0.6", "solverforge-hospital@3.0.1", "solverforge-hospital@3.0.2", "solverforge-hospital@3.0.3", "solverforge 0.25.1", "solverforge 0.26.0", "registers it in"],
  "src/docs/getting-started/solverforge-lessons-use-case.md" => ["solverforge-lessons@3.0.4", "solverforge 0.26.1", "uuid = {", "solverforge-ui 0.9.0", "solverforge-lessons@2.0.6", "solverforge-lessons@3.0.1", "solverforge-lessons@3.0.2", "solverforge-lessons@3.0.3", "solverforge 0.25.1", "solverforge 0.26.0"],
  "src/docs/getting-started/solverforge-deliveries-use-case.md" => ["solverforge-deliveries@3.0.5", "solverforge 0.26.1", "uuid = {", "solverforge-ui 0.9.0", "solverforge-deliveries@2.0.6", "solverforge-deliveries@3.0.2", "solverforge-deliveries@3.0.3", "solverforge-deliveries@3.0.4", "solverforge 0.25.1", "solverforge 0.26.0"],
  "src/docs/getting-started/solverforge-fsr-use-case.md" => ["solverforge-fsr@3.0.5", "solverforge 0.26.1", "uuid = {", "solverforge-ui 0.9.0", "solverforge-fsr@2.0.7", "solverforge-fsr@3.0.2", "solverforge-fsr@3.0.3", "solverforge-fsr@3.0.4", "solverforge 0.25.1", "solverforge 0.26.0"],
  "src/docs/solverforge-cli/project-anatomy.md" => ["shared `create_constraints()` registry"],
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

failures = ReleasePins.registry_failures

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