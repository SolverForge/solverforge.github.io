# frozen_string_literal: true

# Pages whose Rust blocks scripts/verify-rust-snippets.rb compiles against the
# published solverforge crate. scripts/verify-rust-snippets-legacy.rb skips
# them, so a page is checked by exactly one gate.
module RustSnippetScope
  GLOBS = [
    "src/docs/overview.md",
    "src/docs/architecture.md",
    "src/docs/concepts/**/*.md",
    "src/docs/solverforge/index.md",
    "src/docs/solverforge/modeling/**/*.md",
    "src/docs/solverforge/constraints/**/*.md",
    "src/reference/modeling-cheat-sheet.md",
    "src/reference/extend-domain.md",
    "src/reference/extend-solver.md",
    "src/reference/crate-map.md",
    "src/reference/library/**/*.md"
  ].freeze

  # Pages whose Rust blocks a dedicated gate builds as the reader does: the
  # solver pages verbatim in scripts/fixtures/solver-config (crates.io
  # solverforge), the use-case and maintenance pages and the CLI pages by
  # replaying them into a running app, the UI Getting Started page by building and loading
  # the getting-started app in a browser. The legacy snippet check skips these too.
  REPLAYED_GLOBS = [
    "src/docs/solverforge/solver/**/*.md",
    "src/docs/getting-started/*.md",
    "src/docs/solverforge-cli/**/*.md",
    "src/docs/solverforge-ui/getting-started.md"
  ].freeze

  def self.replayed_pages(root)
    REPLAYED_GLOBS.flat_map { |glob| Dir.glob(File.join(root, glob)) }.uniq.sort
  end

  def self.pages(root)
    GLOBS.flat_map { |glob| Dir.glob(File.join(root, glob)) }.uniq.sort
  end

  def self.include?(root, relpath)
    pages(root).include?(File.join(root, relpath))
  end
end
