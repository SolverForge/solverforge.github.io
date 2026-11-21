---
title: "Constraint explorer"
linkTitle: "Constraint explorer"
description: >
  Every constraint of the four stock models, searchable by name, group, level
  or meaning.
---

Type any part of a name, group, level or description. The match is fuzzy in
the same way as the Workbench's own lists: a substring always matches, and
otherwise the letters must appear in order, starting words, so `rst btwn` finds
*Rest between shifts*. Each result links to its rule on the model page, beside
the rest of its group and the data tables the model reads.

Each constraint states when it fires and what one violation costs. **Hard**
rules must hold for a plan to be feasible; **medium** rules count work left
undone; **soft** rules weigh preferences and costs. A profile's weight
multiplies the cost: 1 as designed, 0 off, 10 ten times as important.

<%= render Workbench::Explorer.new(site: site) %>
