---
title: Components
description: Build pages with the shipped solverforge-ui base components and helpers.
weight: 2
---

# Components

`solverforge-ui` ships a base component surface for common scheduling and operations UIs.

## Core Factory Functions

### Header

Use `SF.createHeader` for page titles, subtitle context, and top-level action areas.

```js
SF.createHeader(document.getElementById('header'), {
  title: 'Plant Schedule',
  subtitle: 'Line 3 · Morning Shift'
});
```

### Status Bar

Use `SF.createStatusBar` for run state, sync state, and user-facing health messages.

```js
const status = SF.createStatusBar(document.getElementById('status'));
status.setStatus('ok', 'Data loaded');
```

### Button

Use `SF.createButton` for standardized button rendering and behavior.

```js
const runBtn = SF.createButton({
  label: 'Run Solver',
  icon: 'fa-solid fa-play',
  onClick: () => runSolver()
});
document.getElementById('actions').append(runBtn);
```

### Modal

Use `SF.createModal` for confirmations, detail panes, and error drill-downs.

```js
const modal = SF.createModal({ title: 'Schedule Details' });
modal.setBody('<p>Batch A starts at 08:00.</p>');
modal.open();
```

### Table

Use `SF.createTable` to render structured rows with consistent styles.

```js
SF.createTable(document.getElementById('table'), {
  columns: ['Job', 'Line', 'Start', 'End'],
  rows: [
    ['J-102', 'L3', '08:00', '09:20'],
    ['J-103', 'L2', '08:15', '10:00']
  ]
});
```

### Tabs

Use `SF.createTabs` for view switching and section organization.

```js
SF.createTabs(document.getElementById('tabs'), {
  tabs: [
    { id: 'overview', label: 'Overview', active: true },
    { id: 'timeline', label: 'Timeline' },
    { id: 'analysis', label: 'Analysis' }
  ]
});
```

### Footer

Use `SF.createFooter` for build/version info and support links.

```js
SF.createFooter(document.getElementById('footer'), {
  text: 'SolverForge UI · Production'
});
```

### API Guide

Use `SF.createApiGuide` for built-in API reference panels in operator tools.

```js
SF.createApiGuide(document.getElementById('api-guide'), {
  title: 'Scheduler API',
  sections: []
});
```

### Toasts and Error Helpers

Use `SF.showToast` for transient notifications and `SF.showError` for consistent error presentation.

```js
SF.showToast('Schedule queued');

try {
  await doWork();
} catch (err) {
  SF.showError(err);
}
```

### Tab Switching

Use `SF.showTab` to activate a tab and its related content region.

```js
SF.showTab('timeline');
```

## Unsafe HTML APIs

Some component APIs accept HTML strings (for example, custom modal body content). Treat untrusted user data as unsafe.

- Escape user-provided text before injecting into HTML.
- Prefer text-only rendering paths when possible.
- Only pass trusted HTML if it is sanitized.

A practical helper pattern is `SF.escHtml` before interpolation.

## Useful Helpers

The following helpers are optional but often useful in real pages:

- `SF.score.*` for score formatting and display helpers
- `SF.colors.*` for consistent palette usage
- `SF.escHtml` for HTML escaping
- `SF.el` for lightweight DOM element creation
