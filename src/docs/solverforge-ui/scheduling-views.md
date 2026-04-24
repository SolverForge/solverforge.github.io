---
title: Scheduling Views
description: >
  Build the canonical dense timeline, low-level rail primitives, and split-pane
  Gantt views with the shipped solverforge-ui APIs.
weight: 3
---

# Scheduling Views

`solverforge-ui` ships one canonical dense scheduling surface and one
complementary chart-first surface:

- **Timeline** for compact, lane-by-lane operator workflows with overview
  clustering, inline expand/collapse, and packed detailed lanes
- **Gantt** for dense, timeline-first planning and diagnostics

## Timeline API

The shipped dense timeline surface is built around:

- `SF.rail.createTimeline(config)` →
  `{el, setModel, setViewport, expandCluster, destroy}`

Use this as the default scheduling surface when you need sticky time headers,
sticky lane labels, synchronized scrolling, overview clustering, or packed
detailed inspection.

### Timeline Model Contract

`SF.rail.createTimeline(...)` expects a normalized integer-minute model. All
time coordinates are absolute minutes:

- `model.axis.startMinute` and `model.axis.endMinute`
- `model.axis.initialViewport.startMinute` and `endMinute`
- `model.axis.days[].startMinute` and `endMinute`
- `model.axis.ticks[].minute`
- `model.lanes[].items[].startMinute` and `endMinute`
- overlay `startMinute` and `endMinute` when an overlay is time-positioned

Use application code to convert dates, shifts, and route windows into these
integer-minute coordinates before calling `createTimeline(...)`.

### Timeline Example

```js
var timeline = SF.rail.createTimeline({
  label: 'Staffing lane',
  labelWidth: 280,
  model: {
    axis: {
      startMinute: 0,
      endMinute: 28 * 1440,
      days: buildDays(28),
      ticks: buildSixHourTicks(28),
      initialViewport: { startMinute: 0, endMinute: 14 * 1440 },
    },
    lanes: [
      {
        id: 'ward-east',
        label: 'By location · Ward East',
        mode: 'overview',
        items: [
          {
            id: 'east-rush',
            clusterId: 'east-rush',
            startMinute: 360,
            endMinute: 1080,
            label: 'Monday intake surge',
            tone: 'blue',
            summary: {
              primaryLabel: 'Monday intake surge',
              secondaryLabel: 'ER intake · trauma hold · overflow beds',
              count: 24,
              openCount: 3,
              toneSegments: [
                { tone: 'blue', count: 15 },
                { tone: 'amber', count: 6 },
                { tone: 'rose', count: 3 },
              ],
            },
            detailItems: [
              {
                id: 'east-1',
                startMinute: 360,
                endMinute: 840,
                label: 'ER intake',
                tone: 'blue',
              },
              {
                id: 'east-2',
                startMinute: 420,
                endMinute: 960,
                label: 'Trauma hold',
                tone: 'amber',
              },
              {
                id: 'east-3',
                startMinute: 480,
                endMinute: 1080,
                label: 'Overflow beds',
                tone: 'rose',
              },
            ],
          },
        ],
      },
      {
        id: 'employee-ada',
        label: 'By employee · Ada',
        mode: 'detailed',
        items: [
          {
            id: 'ada-1',
            startMinute: 2 * 1440 + 360,
            endMinute: 2 * 1440 + 840,
            label: 'Primary shift',
            tone: 'amber',
          },
          {
            id: 'ada-2',
            startMinute: 2 * 1440 + 660,
            endMinute: 2 * 1440 + 1020,
            label: 'Handoff overlap',
            tone: 'amber',
          },
        ],
      },
    ],
  },
});

container.appendChild(timeline.el);
timeline.expandCluster('ward-east', 'east-rush');
```

Overview summaries are additive per field. If a summary item overrides aggregate
`count` beyond the concrete items the library can inspect, provide
`summary.openCount` and `summary.toneSegments` explicitly if you want those
aggregate signals rendered.

## Low-level Rail Primitives

The original rail helpers remain shipped for custom primitive compositions:

- `SF.rail.createHeader(config)` → `HTMLElement`
- `SF.rail.createCard(config)` →
  `{el, rail, addBlock, clearBlocks, setSolving, setUnassigned}`
- `SF.rail.addBlock(rail, config)` → `HTMLElement`
- `SF.rail.addChangeover(rail, config)` → `HTMLElement`
- `SF.rail.createHeatmap(config)` → `HTMLElement | null`
- `SF.rail.createUnassignedRail(tasks, onTaskClick)` → `HTMLElement`

Use these when you need bespoke resource-card layouts rather than the canonical
dense timeline surface.

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

## Choosing Timeline, Rail, or Gantt

Use **timeline** when operators need overview clustering, inline detail
inspection, synchronized time navigation, and dense lane scanning.

Use the **low-level rail primitives** when you are composing custom resource
cards, gauges, and changeover-aware lanes by hand.

Use **Gantt** when analysts need sortable task grids, dependency arrows, and
high-density timeline review.
