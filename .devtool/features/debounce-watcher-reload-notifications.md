---
id: debounce-watcher-reload-notifications
status: review
priority: medium
assignee: null
epic: null
dueDate: null
created: "2026-07-24"
modified: "2026-07-24"
completedAt: null
labels: []
order: 15
---

# Debounce Watcher Reload Notifications

- Add a debounce mechanism to `bin/watch_src.sh` (or `bin/bundle_and_reload.sh`) to prevent notification spam when multiple files are written rapidly by agents or editor saves.
