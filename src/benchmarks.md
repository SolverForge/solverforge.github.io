---
title: Benchmarks
eyebrow: Measured performance
description: Latest full benchmark results from solverforge-bench, grouped by problem and labeled with the versions actually tested.
---

These are the latest publishable **full canonical runs** recorded in our benchmark
warehouse, not new measurements of the current release. Each problem uses its own
latest completed nightly candidate run. Quick runs and partial runs are excluded.

Feasibility comes first. The mean gap is calculated only for feasible results with
a reference cost: **0% matches the reference; lower is better**. Read it alongside
the feasible count — an average over fewer successful instances is not a win over
a solver that solved them all. Different problems are not combined into one score.

<% site.data.benchmarks.problems.each do |problem| %>
<section class="benchmark-problem" id="<%= problem.fetch('benchmark_name') %>">
  <h2><%= problem.fetch('title') %></h2>
  <p><%= problem.fetch('description') %></p>
  <p>
    <strong><%= problem.fetch('datasets').join(', ') %></strong> ·
    <%= problem.fetch('instances') %> instances ·
    <%= problem.fetch('result_count') %> recorded results ·
    Completed <time datetime="<%= problem.fetch('completed_at') %>"><%= problem.fetch('completed_at')[0, 10] %></time>
  </p>
  <% if problem.fetch('reference_present') %>
    <p class="benchmark-references">
      <% if problem.fetch('reference_covers_run') %>
        Reference values for all <strong><%= problem.fetch('instances') %></strong> instances, from
      <% else %>
        Reference values for <strong><%= problem.fetch('reference_instances') %></strong> of
        <%= problem.fetch('instances') %> instances — the run's instances are not in this set, so
        their mean gap is not shown. The values come from
      <% end %>
      <% problem.fetch('reference_sources').each_with_index do |source, index| %><%= ', ' if index > 0 %><%= source.fetch('name') %><% end %>:
      <% if problem.fetch('reference_kinds').include?('known_optimum') && problem.fetch('reference_kinds').include?('best_known_upper_bound') %>
        proven optima where the source closed the instance, best known bounds otherwise.
      <% elsif problem.fetch('reference_kinds').include?('known_optimum') %>
        all proven optima.
      <% else %>
        best known bounds, not proven optima.
      <% end %>
    </p>
  <% else %>
    <p class="benchmark-references">
      No published reference values exist for this problem's instances, so the mean gap is not shown;
      feasibility is the comparison this run supports.
    </p>
  <% end %>
  <%= render Benchmark::Charts.new(problem: problem) %>
  <% problem.fetch('time_limits_seconds').sort.reverse.each_with_index do |budget, index| %>
    <% if index > 0 %><details><summary><%= budget %>-second budget</summary><% else %><h3><%= budget %>-second budget</h3><% end %>
    <div class="benchmark-table" role="region" aria-label="<%= problem.fetch('title') %>, <%= budget %>-second results" tabindex="0">
      <table>
        <thead><tr><th scope="col">Solver / tested version</th><th scope="col">Feasible</th><th scope="col">Mean gap</th><th scope="col">Mean runtime</th><th scope="col">Over budget</th></tr></thead>
        <tbody>
          <% problem.fetch('summaries').select { |row| row.fetch('budget') == budget }.each do |row| %>
            <tr class="<%= row.fetch('solver').start_with?('solverforge') ? 'benchmark-solverforge' : '' %>">
              <th scope="row"><%= row.fetch('solver') %> <small><%= row.fetch('version') %></small></th>
              <td><%= row.fetch('feasible') %> / <%= row.fetch('total') %></td>
              <td><%= row['gap_percent'].nil? ? '—' : format('%.2f%%', row.fetch('gap_percent')) %> <small>(<%= row.fetch('quality_samples') %> samples)</small></td>
              <td><%= row['mean_seconds'].nil? ? '—' : format('%.2f s', row.fetch('mean_seconds')) %></td>
              <td><%= row.fetch('over_budget') %> / <%= row.fetch('total') %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    <% if index > 0 %></details><% end %>
  <% end %>
  <details>
    <summary>Run provenance</summary>
    <p>Full canonical nightly candidate · completed <%= problem.fetch('completed_at') %> (UTC). The warehouse's publication checks passed; the benchmark repository was clean.</p>
    <p>Run <code><%= problem.fetch('id') %></code><br />Harness commit <a href="https://github.com/SolverForge/solverforge-bench/commit/<%= problem.fetch('git_commit') %>"><code><%= problem.fetch('git_commit')[0, 12] %></code></a>.</p>
  </details>
</section>
<% end %>

<% site.data.benchmarks.unavailable.each do |problem| %>
<section class="benchmark-unavailable" id="<%= problem.fetch('id') %>">
  <h2><%= problem.fetch('title') %></h2>
  <p>No publishable full canonical run is available in the warehouse. Smaller quick runs are not substituted.</p>
</section>
<% end %>

## Evidence and methodology

Runtime is measured wall-clock time, not the requested budget. “Over budget” counts
results flagged by the harness's wall-time tolerance; late returned solutions are
retained. The tables show the longest tested budget first; expand the shorter
budgets to see those results.

[Download the recorded results and run metadata (JSON)](<%= relative_url '/benchmarks/results.json' %>) ·
[How we benchmark SolverForge](<%= relative_url '/blog/technical/2026/05/14/how-we-benchmark-solverforge/' %>) ·
[Benchmark source](https://github.com/SolverForge/solverforge-bench)
