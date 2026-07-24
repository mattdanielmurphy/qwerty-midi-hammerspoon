---
id: arp-settings-expansion
status: "review"
priority: "high"
assignee: null
epic: null
dueDate: null
created: 2026-07-24T14:50:00-06:00
modified: 2026-07-24T14:50:00-06:00
completedAt: null
labels: []
order: 2
---

# Arpeggiator Settings Expansion: Power Button, Direction Dropdown, Rate & Gate Controls

1. Separate Arp On/Off and Arp Direction into distinct HUD UI controls.
2. Arp Direction control rendered as a `<select>` dropdown (`UP`, `DOWN`, `UP-DOWN`, `RANDOM`).
3. Add Note Division / Rate dropdown (`1/4`, `1/8`, `1/16`, `1/32`, `1/8T`, `1/16T`).
4. Add Note Gate / Length dropdown (`25%`, `50%`, `80%`, `100%`).
5. Update Lua engine, timer logic, and event handlers to support rate division and gate duration.
