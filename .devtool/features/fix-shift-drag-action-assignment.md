---
id: fix-shift-drag-action-assignment
status: review
priority: high
assignee: null
epic: null
dueDate: null
created: '2026-07-25'
modified: '2026-07-25'
completedAt: null
labels: []
order: 1
---

# Bug: Shift Drag Action Assignment Ignored

Dragging an action card from the action library onto a key pad while holding Shift previously resulted in silent drop of the binding.

## Root Cause
`applyCustomLayout` in `src/config.lua` evaluated `if binding.action ~= nil then`. For Shift-only bindings (`shiftAction` and `shiftName` populated, `action` nil), the condition evaluated to `false`, causing the layout manager to drop the custom binding.

## Fix
1. Updated layout condition to `if binding.action ~= nil or binding.shiftAction ~= nil then`.
2. Added visual update glow animation (`just-updated-glow`) to keypad on Shift-drag drops in `src/web/index.html`.
