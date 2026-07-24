---
id: arp-latch-bpm-drag-improvements
status: "review"
priority: "high"
assignee: null
epic: null
dueDate: null
created: 2026-07-24T14:43:30-06:00
modified: 2026-07-24T14:43:30-06:00
completedAt: null
labels: []
order: 1
---

# Arpeggiator bottom-row default, Latch root/mode transpose preservation, BPM +/- hold acceleration, and BPM drag control

Improvements and fixes:
1. Arpeggiator default target set to bottom row only. When arp toggles, notify state clearly (e.g. "Arpeggiator: ON (Bottom Row)"). Fix arpeggiator performance/fickleness over time when playing top row.
2. In Arp Latch mode, changing root key or mode/scale shifts the held pitch sequence smoothly to the new key/scale without resetting sequence index/timer.
3. BPM +/- buttons accelerate rate change when held down longer.
4. BPM number display supports click & drag up/down to adjust BPM dynamically.
