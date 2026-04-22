require "rouge"

class Ui::CodeBlock < Bridgetown::Component
  def initialize(language:)
    @language = language
  end

  def highlighted_code
    formatter.format(lexer.lex(normalized_code))
  end

  def wrapper_class
    classes = ["highlighter-rouge"]
    classes.unshift("language-#{@language}") if @language && !@language.empty?
    classes.join(" ")
  end

  private

  def normalized_code
    lines = content.to_s.lines
    lines.shift while lines.first&.strip&.empty?
    lines.pop while lines.last&.strip&.empty?

    indent = lines
      .reject { |line| line.strip.empty? }
      .map { |line| line[/\A[ \t]*/].size }
      .min || 0

    stripped = lines.map { |line| line.sub(/^[ \t]{0,#{indent}}/, "") }.join
    stripped.end_with?("\n") ? stripped : "#{stripped}\n"
  end

  def lexer
    Rouge::Lexer.find_fancy(@language, normalized_code) || Rouge::Lexers::PlainText
  end

  def formatter
    @formatter ||= Rouge::Formatters::HTMLLegacy.new(css_class: "highlight")
  end
end
