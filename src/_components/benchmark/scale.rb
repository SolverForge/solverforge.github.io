class Benchmark::Scale < Bridgetown::Component
  # Large-scale problems rank solvers by score, hard violations first, then soft
  # cost. Every number is printed in full beside its bar.
  def initialize(problem:)
    @problem = problem
  end

  def instances
    @problem.fetch("scale").fetch("instances")
  end

  def delimit(value)
    whole, fraction = value.to_s.split(".")
    whole = whole.reverse.scan(/\d{1,3}/).join(",").reverse.prepend(value.negative? ? "-" : "")
    fraction ? "#{whole}.#{fraction}" : whole
  end

  def shape_text(shape)
    shape.map { |field, value| "#{delimit(value)} #{field}" }.join(" · ")
  end

  def value_text(metric, value)
    return "—" if value.nil?

    metric["unit"] ? "#{delimit(value)} #{metric['unit']}" : delimit(value)
  end

  # Context a reader needs to read the number without arithmetic: hours for
  # travel seconds, share of the required total, distance from the best value.
  def context_text(metric, rows, value)
    return "no plan returned" if value.nil?

    parts = []
    parts << "#{delimit((value / 3600.0).round(1))} h" if metric["unit"] == "s"
    parts << format("%.1f%% of %s", 100.0 * value / metric.fetch("max"), delimit(metric.fetch("max"))) if metric["better"] == "higher"
    best = best_value(metric, rows)
    if value == best
      parts << "best"
    elsif metric["better"] == "higher"
      parts << "#{delimit(best - value)} fewer than the best"
    elsif best.zero?
      parts << "#{delimit(value - best)} more than the best"
    else
      parts << format("%.2f× the best", value.to_f / best)
    end
    parts.join(" · ")
  end

  def best_value(metric, rows)
    values = rows.map { |row| row[metric.fetch("id")] }.compact
    metric["better"] == "higher" ? values.max : values.min
  end

  def fill(metric, value)
    max = metric.fetch("max")
    return nil if value.nil? || max.nil? || max.zero?

    (100.0 * value / max).round(2)
  end

  def soft_label(instance)
    metric = instance.fetch("metrics").find { |candidate| candidate.fetch("id") == "soft_cost" }
    metric ? "#{metric.fetch('title')} (#{metric.fetch('unit')})" : "Soft penalty"
  end

  def assigned?(instance)
    instance.fetch("rows").any? { |row| row.key?("assigned") }
  end

  def solverforge?(solver)
    solver.start_with?("solverforge")
  end
end
