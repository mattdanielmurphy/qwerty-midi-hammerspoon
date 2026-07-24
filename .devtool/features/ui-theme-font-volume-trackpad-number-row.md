---
id: ui-theme-font-volume-trackpad-number-row
status: review
priority: medium
assignee: null
epic: null
dueDate: null
created: '2026-07-24'
modified: '2026-07-24'
completedAt: null
labels: []
order: 4
---

# UI Theme, Fraunces Font, Trackpad Volume, Smaller Shifts, Key Jitter Fix & Number Row

- Fix text jitter / shift / vibration on keys during key presses (prevent DOM layout reflow/shift on active key press styling).
- Redesign root, 3rd, and 5th note highlights: make them much more subtle, removing bright heavy colors.
- Trackpad / Scroll wheel: When Shift is held, scrolling controls Volume (CC 7 or master volume CC). When Shift is not held, scrolling controls Mod Wheel (CC 1).
- Make Volume shift and Mod shift key presses use smaller increment shifts (especially Volume, which was jarring).
- Add Number Row to the HUD display: show extra functions currently seen when Shift is held (e.g. octave, velocity, mod, scale/root controls), plus Transpose Up/Down controls.
- Theme visual redesign: Less blue (more neutral/warm/dark slate tone), and adopt 'Fraunces' font throughout.
