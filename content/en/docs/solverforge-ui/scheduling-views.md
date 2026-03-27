---
title: Scheduling Views
description: >
  Build timeline-rail and split-pane Gantt views with the shipped solverforge-ui
  APIs.
weight: 3
---

# Scheduling Views

`solverforge-ui` ships two complementary scheduling view styles:

- **Timeline rail** for compact, lane-by-lane operator workflows
- **Gantt** for dense, timeline-first planning and diagnostics

## Timeline Rail API

The shipped rail surface is built around:

- `SF.rail.createHeader(config)` → `HTMLElement`
- `SF.rail.createCard(config)` → `{el, rail, addBlock, clearBlocks, setSolving}`
- `SF.rail.addBlock(rail, config)` → `HTMLElement`
- `SF.rail.addChangeover(rail, config)` → `HTMLElement`

### Rail Example

```js
var header = SF.rail.createHeader({
  label: 'Resource',
  labelWidth: 200,
  columns: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
});
container.appendChild(header);

var card = SF.rail.createCard({
  id: 'furnace-1',
  name: 'FORNO 1',
  labelWidth: 200,
  columns: 5,
  type: 'CAMERA',
  typeStyle: {
    bg: 'rgba(59,130,246,0.15)',
    color: '#1d4ed8',
    border: '1px solid rgba(59,130,246,0.3)',
  },
  badges: ['TEMPRA'],
  gauges: [{ label: 'Temp', pct: 85, style: 'heat', text: '850/1000°C' }],
  stats: [{ label: 'Jobs', value: 12 }],
});
container.appendChild(card.el);

card.addBlock({
  start: 120,
  end: 360,
  horizon: 4800,
  label: 'ODL-2847',
  meta: 'Bianchi',
  color: 'rgba(59,130,246,0.6)',
  borderColor: '#3b82f6',
  late: false,
});

SF.rail.addChangeover(card.rail, { start: 360, end: 400, horizon: 4800 });

card.setSolving(true);
```

Gauge styles include `heat`, `load`, and `emerald`. `badges` accepts either
plain strings or `{ label, style }` objects.

## Gantt API

`SF.gantt.create(config)` returns:

- `el`, `mount`, `setTasks`, `refresh`, `changeViewMode`, `highlightTask`,
  `destroy`

### Gantt Example

```js
var gantt = SF.gantt.create({
  gridTitle: 'Tasks',
  chartTitle: 'Schedule',
  viewMode: 'Quarter Day',
  splitSizes: [40, 60],
  columns: [
    { key: 'name', label: 'Task', sortable: true },
    { key: 'start', label: 'Start', sortable: true },
    { key: 'end', label: 'End', sortable: true },
  ],
  onTaskClick: function (task) {
    console.log('clicked', task.id);
  },
  onDateChange: function (task, start, end) {
    console.log('moved', task.id, start, end);
  },
});

gantt.mount('my-container');

gantt.setTasks([
  {
    id: 'task-1',
    name: 'Design review',
    start: '2026-03-15 09:00',
    end: '2026-03-15 10:30',
    priority: 1,
    projectIndex: 0,
    pinned: true,
    custom_class: 'project-color-0 priority-1',
    dependencies: '',
  },
]);

gantt.changeViewMode('Day');
gantt.highlightTask('task-1');
```

View modes include `Quarter Day`, `Half Day`, `Day`, `Week`, and `Month`.
Sortable headers are opt-in per column.

## Choosing Rail vs Gantt

Use **rail** when operators need readable resource cards, gauges, and
changeover-aware lanes.

Use **Gantt** when analysts need sortable task grids, dependency arrows, and
high-density timeline review.
