---
id: mod-wheel-display-improvement
status: review
priority: medium
assignee: null
epic: null
dueDate: null
created: 2026-07-24
modified: 2026-07-24
completedAt: null
labels: []
order: 25
---

# Mod Wheel Display Improvement

The existing mod wheel indicator was too subtle (only a faint glow/box-shadow on the container), making it very hard to tell the current level at a glance.

Added a dedicated horizontal fill bar widget in the header (`#mod-wheel-widget`) showing the exact mod wheel value (0–127):
- Bar fills amber left-to-right proportionally
- Label shows `MOD <value>` in bright amber when active, dim when 0
- At values ≥ 80 the fill bar adds a "hot" glow effect
- The existing ambient glow on the container is retained as a secondary indicator
