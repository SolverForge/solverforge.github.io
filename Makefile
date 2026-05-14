PORT ?= 4017
BIND ?= 0.0.0.0
RUBY_VERSION_REQUIRED ?= 3.4
NODE_VERSION_REQUIRED ?= 22

.DEFAULT_GOAL := help

export RUBY_VERSION_REQUIRED
export NODE_VERSION_REQUIRED

# The Codex desktop shell can inherit a truncated exported Bash function for
# Midnight Commander. Dash imports it before every recipe line and prints
# syntax errors, which makes `make doctor` look broken even when checks pass.
unexport BASH_FUNC_mc%%

.PHONY: help doctor install frontend frontend-watch build test lint ci-local pre-release verify-cli-release verify-rust-snippets verify-hospital-tutorial verify-lessons-tutorial verify-deliveries-tutorial verify-fsr-tutorial start clean version

define status
	@printf '\n==> %s\n' "$(1)"
endef

help:
	@printf 'SolverForge.org Bridgetown site\n\n'
	@printf 'Setup\n'
	@printf '  make doctor                     Verify local Ruby, Bundler, Node, and npm\n'
	@printf '  make install                    Install Ruby gems and Node packages\n'
	@printf '\nBuild and run\n'
	@printf '  make frontend                   Build esbuild assets\n'
	@printf '  make frontend-watch             Watch esbuild assets during development\n'
	@printf '  make build                      Build frontend assets and Bridgetown output\n'
	@printf '  make start                      Serve locally on BIND=%s PORT=%s\n' "$(BIND)" "$(PORT)"
	@printf '  make clean                      Remove Bridgetown build output\n'
	@printf '\nQuality gates\n'
	@printf '  make test                       Build in test mode and verify worked examples\n'
	@printf '  make lint                       Run Ruby and JavaScript syntax checks\n'
	@printf '  make verify-cli-release         Install the published CLI and verify scaffold targets\n'
	@printf '  make verify-rust-snippets       Compile-check Rust snippets in docs\n'
	@printf '  make verify-hospital-tutorial   Run portable tutorial contract checks\n'
	@printf '  make verify-lessons-tutorial    Run portable lessons contract checks\n'
	@printf '  make verify-deliveries-tutorial Run portable deliveries contract checks\n'
	@printf '  make verify-fsr-tutorial        Run portable FSR tutorial contract checks\n'
	@printf '  make ci-local                   Run the same gate used by CI\n'
	@printf '  make pre-release                Run the release-readiness gate\n'
	@printf '\nInspection\n'
	@printf '  make version                    Print toolchain and site tool versions\n'

doctor:
	$(call status,Checking required tools)
	@command -v ruby >/dev/null || { printf 'missing required command: ruby\n' >&2; exit 1; }
	@command -v bundle >/dev/null || { printf 'missing required command: bundle\n' >&2; exit 1; }
	@command -v node >/dev/null || { printf 'missing required command: node\n' >&2; exit 1; }
	@command -v npm >/dev/null || { printf 'missing required command: npm\n' >&2; exit 1; }
	@ruby -e 'required = ENV.fetch("RUBY_VERSION_REQUIRED"); actual = RUBY_VERSION; abort("Ruby #{required}.x required; found #{actual}") unless actual.start_with?("#{required}.")'
	@node -e 'const required = process.env.NODE_VERSION_REQUIRED; const actual = process.versions.node; if (!actual.startsWith(`$${required}.`)) { console.error(`Node $${required}.x required; found $${actual}`); process.exit(1); }'
	@printf 'Ruby:   '; ruby -v
	@printf 'Bundler: '; bundle -v
	@printf 'Node:   '; node -v
	@printf 'npm:    '; npm -v

install:
	$(call status,Installing Ruby gems)
	@bundle install
	$(call status,Installing Node packages)
	@npm ci

frontend:
	$(call status,Building frontend assets)
	@bundle exec rake frontend:build

frontend-watch:
	$(call status,Watching frontend assets)
	@bundle exec rake frontend:dev

build: frontend
	$(call status,Building Bridgetown site)
	@bundle exec bridgetown build

test: frontend
	$(call status,Building Bridgetown site in test mode)
	@BRIDGETOWN_ENV=test bundle exec rake test
	$(call status,Verifying hospital tutorial contract)
	@ruby scripts/verify-hospital-tutorial.rb
	$(call status,Verifying lessons tutorial contract)
	@ruby scripts/verify-lessons-tutorial.rb
	$(call status,Verifying deliveries tutorial contract)
	@ruby scripts/verify-deliveries-tutorial.rb
	$(call status,Verifying FSR tutorial contract)
	@ruby scripts/verify-fsr-tutorial.rb

lint:
	$(call status,Checking Ruby syntax)
	@ruby -c Gemfile
	@ruby -c Rakefile
	@find . \( -path './.git' -o -path './.bridgetown-cache' -o -path './node_modules' -o -path './output' -o -path './vendor' \) -prune -o -name '*.rb' -print0 | xargs -0 -n 1 ruby -c
	$(call status,Checking JavaScript syntax)
	@find . \( -path './.git' -o -path './.bridgetown-cache' -o -path './node_modules' -o -path './output' -o -path './vendor' \) -prune -o \( -name '*.js' -o -name '*.mjs' \) -print0 | xargs -0 -n 1 node --check

ci-local: doctor lint verify-rust-snippets build verify-hospital-tutorial verify-lessons-tutorial verify-deliveries-tutorial verify-fsr-tutorial

pre-release: verify-cli-release ci-local
	$(call status,Ready for release)

verify-cli-release:
	$(call status,Verifying published solverforge-cli release)
	@ruby scripts/verify-cli-release.rb

verify-rust-snippets:
	$(call status,Verifying Rust documentation snippets)
	@ruby scripts/verify-rust-snippets.rb

verify-hospital-tutorial:
	$(call status,Verifying hospital tutorial contract)
	@ruby scripts/verify-hospital-tutorial.rb

verify-lessons-tutorial:
	$(call status,Verifying lessons tutorial contract)
	@ruby scripts/verify-lessons-tutorial.rb

verify-deliveries-tutorial:
	$(call status,Verifying deliveries tutorial contract)
	@ruby scripts/verify-deliveries-tutorial.rb

verify-fsr-tutorial:
	$(call status,Verifying FSR tutorial contract)
	@ruby scripts/verify-fsr-tutorial.rb

start:
	$(call status,Starting Bridgetown on $(BIND):$(PORT))
	@bundle exec bridgetown start -P $(PORT) -B $(BIND)

clean:
	$(call status,Cleaning Bridgetown output)
	@bundle exec bridgetown clean

version:
	$(call status,Tool versions)
	@printf 'Ruby:      '; ruby -v
	@printf 'Bundler:   '; bundle -v
	@printf 'Node:      '; node -v
	@printf 'npm:       '; npm -v
	@printf 'Bridgetown: '; bundle exec bridgetown -v
