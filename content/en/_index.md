---
title: SolverForge
date: 2025-12-08
---

{{< blocks/cover title="SolverForge" image_anchor="top" height="full" >}}
<a class="btn btn-lg btn-primary me-3 mb-4" href="/docs/">
  Learn More <i class="fas fa-arrow-alt-circle-right ms-2"></i>
</a>
<a class="btn btn-lg btn-secondary me-3 mb-4" href="https://github.com/SolverForge">
  Download <i class="fab fa-github ms-2 "></i>
</a>
<p class="lead mt-5">Write constraints like you write code.</p>
{{< blocks/link-down color="info" >}}
{{< /blocks/cover >}}

{{% blocks/lead %}}
Model your planning problems with an expressive, business-object oriented syntax

<a class="td-link-down" href="#td-block-2"><i class="fas fa-chevron-down"></i></a>
{{% /blocks/lead %}}

{{% blocks/section %}}

<div class="terminal-card">
  <div class="terminal-header">
    <span class="terminal-btn close"></span>
    <span class="terminal-btn minimize"></span>
    <span class="terminal-btn maximize"></span>
    <span class="terminal-title">constraints.py</span>
  </div>
  <div class="terminal-body">

```python
def desired_day_for_employee(constraint_factory: ConstraintFactory):
    return (
        constraint_factory.for_each(Shift)
        .join(
            Employee,
            Joiners.equal(lambda shift: shift.employee, lambda employee: employee),
        )
        .flatten_last(lambda employee: employee.desired_dates)
        .filter(lambda shift, desired_date: shift.is_overlapping_with_date(desired_date))
        .reward(
            HardSoftDecimalScore.ONE_SOFT,
            lambda shift, desired_date: shift.get_overlapping_duration_in_minutes(desired_date),
        )
        .as_constraint("Desired day for employee")
    )
```

  </div>
</div>

<a class="td-link-down" href="#td-block-3"><i class="fas fa-chevron-down"></i></a>

<div class="text-center td-arrow-down"></div>

{{% /blocks/section %}}

{{% blocks/section %}}

<div class="text-center mb-4">
  <span class="install-badge">
    <i class="fas fa-rocket"></i> Get started in seconds
  </span>
</div>

<div class="terminal-card">
  <div class="terminal-header">
    <span class="terminal-btn close"></span>
    <span class="terminal-btn minimize"></span>
    <span class="terminal-btn maximize"></span>
    <span class="terminal-title">bash - solverforge</span>
  </div>
  <div class="terminal-body">
    <pre><code><span class="command-line">git clone https://github.com/SolverForge/solverforge-quickstarts</span>
<span class="command-line">cd solverforge-quickstarts/fast/employee-scheduling-fast</span>
<span class="command-line">python -m venv .venv && source .venv/bin/activate</span>
<span class="command-line">pip install -e .</span>
<span class="command-line">run-app</span></code></pre>
  </div>
</div>

{{% /blocks/section %}}
