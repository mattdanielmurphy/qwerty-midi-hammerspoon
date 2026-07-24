---
id: keyboard-ui-readability-zoom-persistence-notes
status: review
priority: medium
assignee: null
epic: null
dueDate: null
created: '2026-07-24'
modified: '2026-07-24'
completedAt: null
labels: []
order: 5
---

# UI Readability, Zoom Persistence, Note Interval Highlights & Keybinding Adjustments

- Fix readability issue when mod intensity is at 100% (text and keys become hard to read).
- Fix zoom level resetting & persistence: baseline 1.0 (100%) zoom should be set to what was previously 1.4 (140%). Remember and recall zoom level and window position across restarts and shift key toggles (fix bug where shift key trigger causes zoom jump).
- Remove `(R)` text for Root notes.
- Make root, 3rd, and 5th notes visually distinct with variations of glowing outline look (root style as base, add complementary glowing outline styles for 3rd and 5th without off-putting text).
- Fix change indicator disappearing too quickly & text heavy: make change indicator more visual with icons, less text-dense, and cleaner presentation.
- Fix mode bar: ensure mode bar never grows/shrinks or shifts layout when holding shift or changing modes. Make mode bar narrower and fix layout element positions.
- Position octave indicators visually: top octave near the top row of keys, bottom octave near the bottom row of keys.
- Adjust home row keybindings: move mode +/- to default home row keys (replacing mod +/- on home row).
