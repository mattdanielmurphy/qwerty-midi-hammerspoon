---
id: fix-bundler-watcher-config-reload
status: review
priority: high
assignee: null
epic: null
dueDate: null
created: 2026-07-24
modified: 2026-07-24
completedAt: null
labels: []
order: 0
---

# Bug: Bundler Watcher Failed to Reload Config After First Change

The `watch_src.sh` watcher permanently stopped detecting file changes after the first save
due to a broken `read -d "" -t timeout` pattern in bash 3.2 (macOS system bash).

After the initial event, the drain loops used to consume rapid-fire fswatch events would
hang indefinitely, blocking all subsequent event processing.

Fixed by using `fswatch --latency` for built-in coalescing instead of manual drain loops.
