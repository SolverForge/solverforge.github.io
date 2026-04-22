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

1. `make install`
2. `make build`
3. `make start`

Direct Bridgetown commands:

1. `bundle install`
2. `npm install`
3. `bundle exec rake frontend:build`
4. `bundle exec bridgetown build`
5. `bundle exec bridgetown start -P 4017`

## Publishing

This repo is meant to be served directly as the GitHub Pages source for
`solverforge.github.io`. GitHub Actions builds the site from repository root
and deploys `output/` to Pages.
