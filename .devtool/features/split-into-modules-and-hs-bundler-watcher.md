---
id: split-into-modules-and-hs-bundler-watcher
status: review
priority: medium
assignee: null
epic: null
dueDate: null
created: "2026-07-24"
modified: "2026-07-24"
completedAt: null
labels: []
order: 11
---

# Split into Modules, Hammerspoon Bundler & Watcher Launch Agent

- Split `qwerty_midi.lua` into logical Lua modular files in `src/`.
- Create reusable Hammerspoon bundling tool / watcher script (`hs-bundler`).
- Setup Launch Agent watcher daemon following system rules to auto-bundle and reload Hammerspoon on changes.
- Remove manual postflight `hs.reload` step where applicable.
