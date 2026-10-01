# SolverForge Site

This repository is the dedicated Bridgetown source for
`https://solverforge.org/`.

## What lives here

- `src/docs/**` for public product docs and tutorials
- `src/reference/**` for dense engineering reference and clearly labeled
  maintainer notes
- `src/_posts/**` for blog and release posts
- `src/use-cases.md`, `src/_data/use_cases.yml`, `src/images/use-cases/**`, and
  `src/videos/use-cases/**` for the public use-case showcase: one slide per case
  with its metrics, constraints, narrated runtime walkthrough, and annotated
  screenshots
- `plugins/use_case_page_generator.rb` and `src/_layouts/use_case.erb` for the
  per-case pages at `/use-cases/<id>/`, generated from the same data file so the
  carousel and the individual pages cannot disagree about a case
- `frontend/**` for bundled CSS/JS sources
- `plugins/**` for build-time extensions, including static search generation

## Source-of-truth boundaries

This repo owns the published website. It does not replace repo-local
engineering surfaces in the product repositories.

- `SolverForge/solverforge` keeps the Rust workspace `README.md` and
  `crates/*/WIREFRAME.md` files.
- `SolverForge/solverforge-cli`, `SolverForge/solverforge-ui`, and
  `SolverForge/solverforge-maps` keep their own repo-local maintainer files,
  architecture notes, and implementation detail.
- This site should summarize and integrate those surfaces where useful, but it
  should not mirror them wholesale.

When a source repo changes public APIs, naming, onboarding, or maintainer
workflow, update the matching published pages here in the same effort.

## Local workflow

Preferred entry points:

1. `make help`
2. `make install`
3. `make ci-local`
4. `make pre-release`
5. `make start`

Direct Bridgetown commands:

1. `bundle install`
2. `npm ci`
3. `bundle exec rake frontend:build`
4. `bundle exec bridgetown build`
5. `ruby scripts/verify-cli-release.rb`
6. `ruby scripts/verify-use-cases-page.rb`
7. `ruby scripts/verify-hospital-tutorial.rb`
8. `ruby scripts/verify-deliveries-tutorial.rb`
9. `bundle exec bridgetown start -P 4017`

`make verify-hospital-tutorial` always runs site-local copy and snippet checks.
When `SOLVERFORGE_CLI_REPO` or `SOLVERFORGE_HOSPITAL_REPO` point to local
product checkouts, it also runs the CLI scaffold and live hospital app checks.
The Make target is the stable public workflow; the Ruby script is an
implementation detail behind that target.

`make verify-deliveries-tutorial` follows the same pattern for
`solverforge-deliveries`. It always checks the published guide and dependency
snippets, then adds source-level and live app checks when
`SOLVERFORGE_DELIVERIES_REPO` points to the app checkout.

`make ci-local` runs the same path as GitHub Actions: toolchain checks, syntax
linting, a full Bridgetown build, the public-page copy/link/nav/layout checks,
and the portable tutorial verifiers.
`make pre-release` first installs the published `solverforge-cli` release into
`/tmp`, verifies the scaffold targets, and then delegates to the local CI gate.

## Benchmark snapshot

`/benchmarks/` renders a checked-in warehouse snapshot, grouped by problem. Refresh
it with `python3 scripts/import-benchmarks.py` (requires `psql`; defaults to the
local `solverforge_bench` database, or uses `BENCH_DATABASE_URL`). The importer uses
one read-only transaction and **never runs benchmarks**. It selects the latest
publishable full canonical nightly candidate run per problem, excluding quick,
custom, partial, and publication-rejected runs.

`src/_data/benchmarks.json` holds computed summaries; `src/benchmarks/results.json`
is the downloadable evidence, including every selected result and tested solver
version. Missing full runs are shown as unavailable, not replaced by smaller
runs. Publication timestamps and versions describe the recorded runs, not current
package releases. Normal builds and CI need no warehouse connection.

`make verify-benchmarks` recomputes summaries from the evidence and checks full-run
scope, versions, matrix completeness, and rejection of quick or partial data.
This gate runs in `make test` and `make ci-local`.

Each problem renders two charts from that same data: feasibility per solver and
budget, and mean gap to the run's reference costs. A problem whose run holds no
reference cost states that in prose instead of drawing an empty panel, since no
comparison exists to draw. `scripts/check-public-pages.mjs` reads
`src/_data/benchmarks.json` and checks the rendered sections, budgets, rows, bar
fills, measured-zero marks, legends, and provenance against it, so a problem or
budget that stops rendering fails the gate rather than quietly disappearing.

## Lint follow-up

The current `make lint` target is dependency-light and only performs Ruby and
JavaScript syntax checks with the existing toolchain. A stricter follow-up
should add configured tooling before broadening the gate:

- Ruby: StandardRB or RuboCop, chosen once the repo style is settled
- JavaScript/CSS: ESLint plus Prettier
- Markdown/content: markdownlint and an internal link checker

After those tools are configured, extend `fmt`, `fmt-check`, and `lint` to use
them instead of relying only on syntax checks.

## Publishing

This repo is meant to be served as `solverforge.org`. GitHub Actions installs
dependencies with `make install`, runs `make ci-local`, and deploys `output/` to
Pages.
