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

  def self.pages(root)
    GLOBS.flat_map { |glob| Dir.glob(File.join(root, glob)) }.uniq.sort
  end

  def self.include?(root, relpath)
    pages(root).include?(File.join(root, relpath))
  end
end
