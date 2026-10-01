class Benchmark::Charts < Bridgetown::Component
  # Three panels per problem, drawn from the same exported run data as the tables
  # beside them and presented in the order the results are ranked by: whether a
  # solver returned a usable answer at all, how quickly it returned one, and how
  # good that answer was. The order is the ranking rule, not a layout choice --
  # a fast bad answer does not beat a slow good one, but among solvers that
  # deliver, the one that delivers sooner is the better tool.
  def initialize(problem:)
    @problem = problem
  end

  def budgets
    @budgets ||= @problem.fetch("time_limits_seconds").sort
  end

  def solvers(budget)
    @problem.fetch("solver_orders").fetch(budget.to_s)
  end

  def total_instances
    @problem.fetch("instances")
  end

  def summary(budget, solver)
    summaries.find { |row| row.fetch("budget") == budget && row.fetch("solver") == solver }
  end

  # A bar's length is only meaningful against a shared scale, so every budget of
  # this problem is measured against the largest mean gap it contains, and the
  # caption states that maximum rather than leaving the reader to guess it.
  def max_gap
    @max_gap ||= summaries.filter_map { |row| row["gap_percent"] }.max
  end

  # Time is compared against the longest mean time to a viable solution among
  # solvers that produced one, so the slowest delivering solver is the full bar.
  def max_feasible_seconds
    @max_feasible_seconds ||= summaries.filter_map { |row| row["mean_feasible_seconds"] }.max
  end

  def feasible_percent(row)
    return nil if row.nil? || row.fetch("total").zero?

    100.0 * row.fetch("feasible") / row.fetch("total")
  end

  # Fewer than one feasible result with a reference cost means there is no mean
  # to draw. That is a missing measurement, not a zero, so it renders as an
  # empty slot rather than a bar of length nothing.
  def gap_percent(row)
    row && row["gap_percent"]
  end

  # Time to a viable solution: the measured wall-clock time of the invocations
  # that returned one. Nil when a solver never delivered, which is a different
  # statement from delivering instantly.
  def feasible_seconds(row)
    row && row["mean_feasible_seconds"]
  end

  def feasible_time_samples(row)
    row ? row.fetch("feasible_time_samples") : 0
  end

  # A measured zero has to be visibly different from a measurement that does not
  # exist, or a solver that failed every instance reads the same as one that was
  # never run. Zero gets a tick of its own colour; nil gets the empty slot.
  def zero?(value)
    !value.nil? && value.to_f.zero?
  end

  # A whole panel of empty slots states nothing: it looks like a rendering
  # failure and pushes the reader to invent a reason. When the run holds no
  # usable mean gap, the page says so in words and keeps the feasibility chart,
  # which does carry the comparison.
  def drawable_gaps?
    summaries.any? { |row| row["gap_percent"].to_f.positive? }
  end

  def drawable_times?
    summaries.any? { |row| row["mean_feasible_seconds"].to_f.positive? }
  end

  def fill(value, scale)
    return nil if value.nil? || scale.nil? || scale.zero?

    (100.0 * value / scale).round(2)
  end

  def solverforge?(solver)
    solver.start_with?("solverforge")
  end

  private

  def summaries
    @summaries ||= @problem.fetch("summaries")
  end
end
