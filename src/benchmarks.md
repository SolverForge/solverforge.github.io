---
title: Benchmarks
eyebrow: Measured performance
page_class: benchmarks-page
description: Latest full benchmark results from solverforge-bench, grouped by problem and labeled with the versions actually tested.
---

Latest completed **full canonical nightly runs**, with the versions actually tested.
Quick and partial runs are excluded; these are not measurements of newer releases.

**Ranking:** feasibility → time to a viable solution → solution quality.
Each priority breaks ties in the one before it. Time averages only feasible results;
quality averages only feasible results with a reference. **0% gap matches the reference.**
Each table ranks its own budget. Charts use the longest-budget ranking, matching
the first table. Problems are ranked separately.

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
        Reference values cover <strong><%= problem.fetch('reference_covered_run_instances') %></strong> of
        <strong><%= problem.fetch('instances') %></strong> instances in this run — the catalog holds
        <%= problem.fetch('reference_instances') %> published values for this problem, on
        history/week tuples this run does not select — so their mean gap is not shown. The values come from
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
    <div class="benchmark-table" data-budget="<%= budget %>" role="region" aria-label="<%= problem.fetch('title') %>, <%= budget %>-second results" tabindex="0">
      <table>
        <thead><tr><th scope="col">Solver / tested version</th><th scope="col">Feasible</th><th scope="col">Time to viable</th><th scope="col">Mean gap</th><th scope="col">Mean runtime</th><th scope="col">Over budget</th></tr></thead>
        <tbody>
          <% solver_rank = problem.fetch('solver_orders').fetch(budget.to_s).each_with_index.to_h %>
          <% problem.fetch('summaries').select { |row| row.fetch('budget') == budget }.sort_by { |row| solver_rank.fetch(row.fetch('solver'), 999) }.each do |row| %>
            <tr class="<%= row.fetch('solver').start_with?('solverforge') ? 'benchmark-solverforge' : '' %>">
              <th scope="row"><%= row.fetch('solver') %> <small><%= row.fetch('version') %></small></th>
              <td><%= row.fetch('feasible') %> / <%= row.fetch('total') %></td>
              <td><%= row['mean_feasible_seconds'].nil? ? '—' : format('%.2f s', row.fetch('mean_feasible_seconds')) %> <small>(<%= row.fetch('feasible_time_samples') %> feasible)</small></td>
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

Runtime is measured wall-clock time, not the requested budget. “Time to viable”
covers only invocations that returned a hard-feasible solution; “mean runtime”
covers every invocation, so the difference between the two columns is what
failed or ran to the watchdog. “Over budget” counts results flagged by the
harness's wall-time tolerance; late returned solutions are retained. The tables
show the longest tested budget first; expand the shorter budgets to see those
results.

[Download the recorded results and run metadata (JSON)](<%= relative_url '/benchmarks/results.json' %>) ·
[How we benchmark SolverForge](<%= relative_url '/blog/technical/2026/05/14/how-we-benchmark-solverforge/' %>) ·
[Benchmark source](https://github.com/SolverForge/solverforge-bench)
