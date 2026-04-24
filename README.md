# SolverForge Site

This repository is the dedicated Bridgetown source for
`https://solverforge.github.io/`.

## What lives here

- `src/docs/**` for public product docs and tutorials
- `src/reference/**` for dense engineering reference and clearly labeled
  maintainer notes
- `src/_posts/**` for blog and release posts
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
6. `ruby scripts/verify-hospital-tutorial.rb`
7. `bundle exec bridgetown start -P 4017`

`make verify-hospital-tutorial` always runs site-local copy and snippet checks.
When `SOLVERFORGE_CLI_REPO` or `SOLVERFORGE_HOSPITAL_REPO` point to local
product checkouts, it also runs the CLI scaffold and live hospital app checks.
The Make target is the stable public workflow; the Ruby script is an
implementation detail behind that target.

`make ci-local` runs the same path as GitHub Actions: toolchain checks, syntax
linting, a full Bridgetown build, and the portable hospital tutorial verifier.
`make pre-release` first installs the published `solverforge-cli` release into
`/tmp`, verifies the scaffold targets, and then delegates to the local CI gate.

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

This repo is meant to be served directly as the GitHub Pages source for
`solverforge.github.io`. GitHub Actions installs dependencies with
`make install`, runs `make ci-local`, and deploys `output/` to Pages.
