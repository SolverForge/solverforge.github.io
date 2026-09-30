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
<h2><%= problem.fetch('title') %></h2>
<p>No publishable full canonical run is available in the warehouse. Smaller quick runs are not substituted.</p>
<% end %>

## Evidence and methodology

Runtime is measured wall-clock time, not the requested budget. “Over budget” counts
results flagged by the harness's wall-time tolerance; late returned solutions are
retained. The tables show the longest tested budget first; expand the shorter
budgets to see those results.

[Download the recorded results and run metadata (JSON)](<%= relative_url '/benchmarks/results.json' %>) ·
[How we benchmark SolverForge](<%= relative_url '/blog/technical/2026/05/14/how-we-benchmark-solverforge/' %>) ·
[Benchmark source](https://github.com/SolverForge/solverforge-bench)
