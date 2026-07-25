---
id: settings-window-fixes-and-scaling
status: "review"
priority: "high"
assignee: null
epic: null
dueDate: null
created: 2026-07-24T19:50:00-06:00
modified: 2026-07-24T19:50:00-06:00
completedAt: null
labels: []
order: 1
---

# Fix Settings Window Actions and Scale Window 1.2x

1. Fix settings message handler bridge in `src/settings_ui.lua` by correctly assigning handler injection (`window.settingsHandler = webkit.messageHandlers.settingsUserContent;` or using `webkit.messageHandlers.settingsUserContent.postMessage`) so setting updates and the close button work properly.
2. Update config state saving and call `arpeggiator.applyBpmChange()` or sync modules when settings change.
3. Scale the settings window dimensions by 1.2x (from 440x510 to 528x612) and scale UI fonts/padding accordingly for enhanced readability.
