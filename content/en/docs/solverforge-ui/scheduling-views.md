---
title: Scheduling Views
description: Build timeline-rail and Gantt views for schedule visualization.
weight: 3
---

# Scheduling Views

`solverforge-ui` includes two complementary scheduling view styles.

- **Timeline rail** is card-oriented and ideal for compact, lane-by-lane operator workflows.
- **Gantt** is bar-oriented and ideal for dense timeline analysis across many jobs.

## Timeline Rail API

The rail surface is built around:

- `SF.rail.createHeader`
- `SF.rail.createCard`
- `card.addBlock`
- `SF.rail.addChangeover`

### Rail Example

```js
const root = document.getElementById('rail');

SF.rail.createHeader(root, {
  title: 'Line 3',
  horizonStart: '2026-03-27T08:00:00Z',
  horizonEnd: '2026-03-27T16:00:00Z'
});

const card = SF.rail.createCard(root, {
  id: 'line-3',
  label: 'Mixer A'
});

card.addBlock({
  id: 'job-1002',
  label: 'Batch A',
  start: '2026-03-27T08:00:00Z',
  end: '2026-03-27T09:30:00Z'
});

SF.rail.addChangeover(card, {
  label: 'Clean + Setup',
  start: '2026-03-27T09:30:00Z',
  end: '2026-03-27T10:00:00Z'
});
```

## Gantt API

Use `SF.gantt.create` when you need a high-density, timeline-first visualization.

### Gantt Example

```js
SF.gantt.create(document.getElementById('gantt'), {
  start: '2026-03-27T08:00:00Z',
  end: '2026-03-27T16:00:00Z',
  rows: [
    {
      id: 'line-2',
      label: 'Line 2',
      items: [
        { id: 'j-201', label: 'Order 201', start: '2026-03-27T08:10:00Z', end: '2026-03-27T10:20:00Z' },
        { id: 'j-202', label: 'Order 202', start: '2026-03-27T10:30:00Z', end: '2026-03-27T12:10:00Z' }
      ]
    }
  ]
});
```

## Choosing Rail vs Gantt

Use **rail** when operators need readable, card-level status and transitions.

Use **Gantt** when analysts need broad time-window comparisons and overlap visibility.

Combine them when you want:

- a rail for day-to-day control actions
- a Gantt for cross-line diagnostics and planning review
