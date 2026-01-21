---
title: "How We Build Frontends: jQuery in 2026"
date: 2026-01-21
draft: false
tags: [quickstart]
description: >
  In 2026, we still ship jQuery. The intentional frontend architecture behind SolverForge quickstarts.
---

In 2026, we still ship jQuery. This isn't technical debt or legacy code we haven't gotten around to modernizing. It's an intentional choice.

SolverForge quickstarts are educational demos for constraint optimization. Their purpose is to show developers how to model scheduling, routing, and resource allocation problems—not to demonstrate frontend engineering. Every architectural decision in these applications prioritizes transparency.

## The Stack We Chose (and Why)

Our frontend stack:

- **jQuery 3.7** — DOM manipulation, AJAX
- **Bootstrap 5.3** — Responsive layout, components
- **No React/Vue/Angular** — Intentional

The reasoning: when a developer opens the browser devtools, we want them to see exactly what's happening. No virtual DOM diffing. No state management abstractions. No build step artifacts. Just JavaScript that reads like what it does.

### Extending jQuery for REST

HTTP semantics matter in REST APIs. jQuery doesn't include `PUT` or `DELETE` out of the box, so we add them:

```javascript
$.put = function (url, data) {
    return $.ajax({
        url: url,
        type: 'PUT',
        data: JSON.stringify(data),
        contentType: 'application/json',
    });
};

$.delete = function (url) {
    return $.ajax({
        url: url,
        type: 'DELETE',
    });
};
```

Four lines per method. A React developer would reach for axios. A Vue developer might use the Fetch API with async/await. Both are fine choices for production applications. But for a demo where someone is learning constraint modeling, this explicitness matters.

## Visualization Strategy

Different optimization problems need different visualizations. The principle: **match the tool to the domain**.

### Problem Types and Their Natural Representations

**Scheduling problems** need timeline views. Employees as rows, shifts as blocks, time as the x-axis. Gantt-style charts make resource allocation over time immediately comprehensible. Whether you use vis-timeline, a commercial scheduler component, or build something custom, the representation matters more than the library.

**Routing problems** need maps. A table of coordinates tells you nothing; lines on a map tell you everything. The solver's output is geographic—the visualization should be too.

**Warehouse and spatial problems** need 2D or isometric views. When physical layout affects the optimization (picking paths, equipment placement), abstract representations lose critical information.

**Financial problems** have established conventions. Risk-return scatter plots, allocation pie charts, time series. Analysts expect these formats; deviating creates cognitive friction.

### Choosing Components

We don't standardize on one visualization library. Each quickstart uses whatever component best serves its domain—sometimes lightweight open-source libraries, sometimes more capable commercial components when the complexity warrants it.

The trade-off is maintenance overhead across different APIs. The benefit is using tools designed specifically for each visualization type rather than forcing everything through a general-purpose abstraction.

For educational demos, this trade-off works. The quickstarts aren't a unified product; they're independent examples. Consistency between them matters less than clarity within each one.

## The Shared Component System

All quickstarts share utilities through a webjars structure:

```
/webjars/solverforge/
├── js/
│   └── solverforge-webui.js
└── css/
    └── solverforge.css
```

### solverforge-webui.js Utilities

This file contains cross-cutting concerns:

```javascript
// Error handling
function showError(title, xhr) {
    const message = xhr.responseJSON?.message || xhr.statusText || 'Unknown error';
    const alert = $('<div class="alert alert-danger alert-dismissible fade show">')
        .append($('<strong>').text(title + ': '))
        .append(document.createTextNode(message))
        .append($('<button type="button" class="btn-close" data-bs-dismiss="alert">'));
    $('#alerts').append(alert);
}

// Tango color palette for consistency across visualizations
const TANGO_COLORS = [
    '#3465a4', // Blue
    '#73d216', // Green
    '#f57900', // Orange
    '#cc0000', // Red
    '#75507b', // Purple
    '#c17d11', // Brown
    '#edd400', // Yellow
    '#555753'  // Grey
];

function getTangoColor(index) {
    return TANGO_COLORS[index % TANGO_COLORS.length];
}
```

### Why Tango Colors?

The [Tango Desktop Project](http://tango.freedesktop.org/Tango_Icon_Theme_Guidelines) defined a color palette in 2004 for consistent icon design across Linux desktops. These colors were specifically chosen for:

- Distinguishability at small sizes
- Accessibility across different displays
- Aesthetic harmony when used together

Perfect for distinguishing multiple routes, employees, or resources in visualization.

## State Management Without a Framework

React has useState. Vue has reactive refs. Angular has services. We have global variables:

```javascript
var scheduleId = null;
var schedule = null;
var solving = false;
var timeline = null;
var employeeGroup = null;
var locationGroup = null;
var autoRefreshEnabled = true;
```

Seven variables. That's the entire state of the application.

### Data Flow

The data flow is explicit and traceable:

```
Backend (FastAPI)
    ↓ JSON
Frontend receives response
    ↓ JavaScript objects
Rendering functions
    ↓ jQuery DOM manipulation
User sees updated UI
```

No state synchronization. No computed properties. No watchers. When data changes, we explicitly call the function that updates the relevant UI section.

### Card-Based Rendering

Most quickstarts render entities as Bootstrap cards:

```javascript
function createTaskCard(task) {
    const card = $('<div class="card task-card">')
        .addClass(getStateClass(task));

    const header = $('<div class="card-header">')
        .append($('<span class="task-name">').text(task.name));

    if (task.violations && task.violations.length > 0) {
        header.append(
            $('<span class="badge bg-danger ms-2">')
                .text(task.violations.length + ' violations')
        );
    }

    const body = $('<div class="card-body">')
        .append($('<p>').text('Assigned to: ' + (task.employee?.name || 'Unassigned')))
        .append($('<p>').text('Duration: ' + formatDuration(task.duration)));

    return card.append(header).append(body);
}

function getStateClass(task) {
    if (task.violations?.some(v => v.type === 'HARD')) return 'border-danger';
    if (task.violations?.some(v => v.type === 'SOFT')) return 'border-warning';
    return 'border-success';
}
```

Violation detection happens at render time. Cards show red borders for hard constraint violations, yellow for soft, green for satisfied. The visual feedback is immediate and requires no explanation.

## The Code-Link System

Every UI element in a quickstart can be clicked to reveal its source code.

### How It Works

```javascript
function attachCodeLinks() {
    $('[data-code-ref]').each(function () {
        const $el = $(this);
        const ref = $el.data('code-ref');

        $el.addClass('code-linked');
        $el.on('click', function (e) {
            if (e.ctrlKey || e.metaKey) {
                e.preventDefault();
                showCodePanel(ref);
            }
        });
    });
}

function showCodePanel(ref) {
    const [file, pattern] = ref.split(':');

    $.get('/api/source/' + encodeURIComponent(file))
        .done(function (source) {
            const lineNumber = findPatternLine(source, pattern);
            highlightCode(source, lineNumber, file);
        });
}

function findPatternLine(source, pattern) {
    const lines = source.split('\n');
    for (let i = 0; i < lines.length; i++) {
        if (lines[i].includes(pattern)) {
            return i + 1;
        }
    }
    return 1;
}
```

### Runtime Line Detection

Notice that we don't hardcode line numbers. The `data-code-ref` attribute contains a file path and a search pattern:

```html
<button data-code-ref="constraints.py:def required_skill">
    Required Skill Constraint
</button>
```

When clicked, we fetch the source file and find the line containing `def required_skill`. This means:

- Line numbers stay correct as code changes
- Refactoring doesn't break links
- The same pattern works across different quickstarts

### Syntax Highlighting

We use [Prism.js](https://prismjs.com/) for syntax highlighting:

```javascript
function highlightCode(source, lineNumber, filename) {
    const language = getLanguage(filename);
    const highlighted = Prism.highlight(source, Prism.languages[language], language);

    const $panel = $('#code-panel');
    $panel.find('.code-content').html(highlighted);
    $panel.find('.code-filename').text(filename);

    // Scroll to the relevant line
    const $line = $panel.find('.line-' + lineNumber);
    if ($line.length) {
        $line.addClass('highlighted');
        $line[0].scrollIntoView({ block: 'center' });
    }

    $panel.show();
}
```

### Bidirectional Navigation

The documentation site has a corresponding "See in Demo" feature. When reading about a constraint in the docs, you can click through to the running application with that constraint highlighted. Education flows both ways: from UI to code, and from code to UI.

## CSS Architecture

Our CSS follows a clear pattern for optimization-specific styling:

### Constraint State Colors

```css
/* Hard constraint violations - must fix */
.constraint-hard-violated {
    background-color: var(--sf-error-bg);
    border-left: 4px solid var(--sf-error);
}

/* Soft constraint violations - should improve */
.constraint-soft-violated {
    background-color: var(--sf-warning-bg);
    border-left: 4px solid var(--sf-warning);
}

/* Constraint satisfied */
.constraint-satisfied {
    background-color: var(--sf-success-bg);
    border-left: 4px solid var(--sf-success);
}
```

### Capacity Bars

Resource utilization appears throughout optimization UIs:

```css
.capacity-bar {
    height: 20px;
    background-color: var(--sf-neutral-bg);
    border-radius: 4px;
    overflow: hidden;
}

.capacity-fill {
    height: 100%;
    transition: width 0.3s ease;
}

.capacity-fill.under { background-color: var(--sf-success); }
.capacity-fill.warning { background-color: var(--sf-warning); }
.capacity-fill.over { background-color: var(--sf-error); }
```

### Code Link Hover Effects

The code-link system needs visual affordance:

```css
.code-linked {
    cursor: pointer;
    position: relative;
}

.code-linked::after {
    content: '</>';
    position: absolute;
    top: -8px;
    right: -8px;
    font-size: 10px;
    color: var(--sf-muted);
    opacity: 0;
    transition: opacity 0.2s;
}

.code-linked:hover::after {
    opacity: 1;
}

.code-linked:hover {
    outline: 2px dashed var(--sf-primary);
    outline-offset: 2px;
}
```

A dashed outline and `</>` indicator tells users this element reveals source code.

## API Design for Frontend Consumption

The backend API is designed for straightforward frontend consumption:

### Endpoint Structure

```
GET  /demo-data              → List available datasets
GET  /demo-data/{id}         → Generate sample problem
POST /schedules              → Submit problem, start solving
GET  /schedules/{id}         → Get current solution
GET  /schedules/{id}/status  → Lightweight status check
PUT  /schedules/{id}/analyze → Score breakdown
DELETE /schedules/{id}       → Stop solving
```

### Score Format

Scores come back as strings: `0hard/-45soft`

The frontend parses these:

```javascript
function parseScore(scoreString) {
    if (!scoreString) return null;

    const match = scoreString.match(/(-?\d+)hard\/(-?\d+)soft/);
    if (!match) return null;

    return {
        hard: parseInt(match[1], 10),
        soft: parseInt(match[2], 10),
        isFeasible: parseInt(match[1], 10) >= 0
    };
}
```

Why string format? It's human-readable in logs and network traces. When debugging why a solution looks wrong, seeing `0hard/-45soft` immediately tells you: feasible (hard = 0), 45 units of soft penalty remaining.

### Constraint Weight Sliders

Some quickstarts let users adjust constraint weights:

```javascript
$('#weight-balance').on('input', function () {
    const weight = $(this).val();
    $('#weight-balance-value').text(weight);

    constraintWeights.balance = parseInt(weight, 10);
});

function submitWithWeights() {
    const payload = {
        ...currentSchedule,
        constraintWeights: constraintWeights
    };

    $.post('/schedules', JSON.stringify(payload), function (id) {
        scheduleId = id;
        solving = true;
        refreshSolvingButtons();
    });
}
```

The weights integrate naturally with the REST payload structure. No separate configuration endpoint needed.

## Trade-offs We Accepted

This architecture has real costs:

**No component reuse** — Every quickstart duplicates similar UI patterns. When we improve card rendering in one, we manually copy to others.

**No type safety** — JavaScript string manipulation means typos in property names fail silently. We rely on manual testing.

**No hot module replacement** — Changes require a full page refresh. Development is slower than modern frameworks.

**No state persistence** — Refresh the page and state is lost. We could add localStorage, but haven't needed it.

**Limited testing** — UI logic isn't unit tested. We test the backend constraint logic thoroughly; the frontend gets manual testing.

## When This Approach Works

This architecture excels when:

- **Primary goal is education** — Readers need to understand the code, not just use the product
- **Scope is bounded** — Each quickstart is a single-page application under 1000 lines of JavaScript
- **Longevity isn't critical** — Quickstarts are reference implementations, not production systems
- **Team is small** — One or two developers maintaining all quickstarts

It would be wrong for:

- Production applications with multiple developers
- Complex state management requirements
- Long-term maintenance expectations
- Performance-critical real-time updates

## Conclusion

The SolverForge quickstart frontend architecture optimizes for a specific goal: helping developers understand constraint optimization by example. Every decision—jQuery over React, global variables over state management, domain-specific libraries over unified abstractions—serves that goal.

Modern frameworks solve real problems. Build tools enable powerful abstractions. Type systems catch bugs. None of that is wrong.

But when your audience is learning, when every abstraction layer is one more thing to understand before getting to the actual concept you're teaching, simplicity has value.

For educational demos, the goal is a frontend architecture that stays out of the way of the concepts being taught.

---

**Repository:** [SolverForge Quickstarts](https://github.com/SolverForge/solverforge-quickstarts)

**Quickstarts:**
- [Employee Scheduling](/docs/getting-started/employee-scheduling/)
- [Vehicle Routing](/docs/getting-started/vehicle-routing/)
- [Portfolio Optimization](/docs/getting-started/portfolio-optimization/)

**Further reading:**
- [Dataclasses vs Pydantic in Constraint Solvers](/blog/technical/python-constraint-solver-architecture/)
- [Order Picking Quickstart: JPype Bridge Overhead](/blog/technical/order-picking-quickstart-jpype-performance/)
