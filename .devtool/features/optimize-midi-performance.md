---
id: optimize-midi-performance
status: "review"
priority: "high"
assignee: null
epic: null
dueDate: null
created: "2026-07-24"
modified: "2026-07-24"
completedAt: null
labels: ["performance", "midi", "hud"]
order: 1
---

# Eliminate Hiccups and Optimize Fast Note Performance

Decouple MIDI output execution from Webview IPC, throttle HUD visual rendering to 60 FPS frame batching, eliminate synchronous frame querying, and convert Logic Pro BPM polling to asynchronous background process execution.
