---
title: Components
description: >
  Core factories, return values, and helpers in the shipped solverforge-ui
  surface.
weight: 2
---

# Components

`solverforge-ui` ships a verified component surface for common scheduling and
operations UIs, including header and status primitives that pair with the
retained-job solver lifecycle.

## Core Factories

The current public API documents these factories:

| Factory                       | Returns                                                                                                                                    | Description                                                                                      |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| `SF.createHeader(config)`     | `HTMLElement`                                                                                                                              | Sticky header with logo, title, nav tabs, and optional solve/pause/resume/cancel/analyze actions |
| `SF.createStatusBar(config)`  | `{el, bindHeader, updateScore, setLifecycleState, setSolving, updateMoves, updateConstraintDots, colorDotsByScore, colorDotsFromAnalysis}` | Score display with constraint indicators                                                         |
| `SF.createButton(config)`     | `HTMLButtonElement`                                                                                                                        | Button with variant, size, icon, and shape modifiers                                             |
| `SF.createModal(config)`      | `{el, body, open, close, setBody}`                                                                                                         | Dialog with backdrop and header                                                                  |
| `SF.createTable(config)`      | `HTMLElement`                                                                                                                              | Data table with headers and row click support                                                    |
| `SF.createTabs(config)`       | `{el, show}`                                                                                                                               | Tab panel container with instance-scoped tab switching                                           |
| `SF.createFooter(config)`     | `HTMLElement`                                                                                                                              | Footer with links and version                                                                    |
| `SF.createApiGuide(config)`   | `HTMLElement`                                                                                                                              | REST API documentation panel                                                                     |
| `SF.showToast(config)`        | `void`                                                                                                                                     | Auto-dismissing toast notification                                                               |
| `SF.showError(title, detail)` | `void`                                                                                                                                     | Error toast shorthand                                                                            |
| `SF.showTab(tabId, root?)`    | `void`                                                                                                                                     | Activate tab panels globally or within one root                                                  |

## Composition Example

```js
var tabs = SF.createTabs({
  tabs: [
    { id: "plan", content: "<div>Plan view</div>", active: true },
    { id: "gantt", content: "<div>Gantt view</div>" },
  ],
});
document.body.appendChild(tabs.el);

var header = SF.createHeader({
  title: "My Scheduler",
  subtitle: "by SolverForge",
  tabs: [
    { id: "plan", label: "Plan", active: true },
    { id: "gantt", label: "Gantt" },
  ],
  onTabChange: function (id) {
    tabs.show(id);
  },
});
document.body.prepend(header);

var statusBar = SF.createStatusBar({ header: header, constraints: [] });
header.after(statusBar.el);
```

## Unsafe HTML APIs

Default content is text-rendered. These opt-ins accept trusted HTML:

| Factory                   | Unsafe HTML field                                      |
| ------------------------- | ------------------------------------------------------ |
| `SF.el(tag, attrs, ...)`  | `unsafeHtml`                                           |
| `SF.createModal(config)`  | `unsafeBody`                                           |
| `SF.createTabs(config)`   | `tabs[].content.unsafeHtml`                            |
| `SF.createTable(config)`  | `cells[].unsafeHtml`                                   |
| `SF.gantt.create(config)` | `unsafePopupHtml`, `columns[].render(task).unsafeHtml` |

Escape user-provided content before interpolation. `SF.escHtml(...)` is the
shipped helper for that.

## Button Variants

```js
SF.createButton({ text: "Solve", variant: "success" });
SF.createButton({ text: "Stop", variant: "danger" });
SF.createButton({ text: "Save", variant: "primary" });
SF.createButton({ text: "Cancel", variant: "default" });
SF.createButton({ icon: "fa-gear", variant: "ghost", circle: true });
```

## Useful Helpers

These helpers are documented in the current public API:

- `SF.score.parseHard`, `parseSoft`, `parseMedium`, `getComponents`,
  `colorClass`
- `SF.colors.pick`, `project`, `reset`
- `SF.escHtml(...)` for safe HTML escaping
- `SF.el(tag, attrs, ...children)` for lightweight DOM element creation
