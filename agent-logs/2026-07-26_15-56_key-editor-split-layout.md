## Goal
The user wanted the Key Editor mode to expand the whole window to about twice its height. Instead of having a separate Shift mode toggled for the editor, they requested a modified version of the keyboard where every key is split vertically into two (bottom for the default action, and above it for the shift action).

## User Feedback & Decisions
User approved the architectural implementation plan. Decided to expand the window downwards via IPC from `src/web/index.html` to `src/hud.lua`.

## Changes Made
- Modified `src/hud.lua` to add a `toggleEditMode` IPC handler that saves the normal height and doubles it when active.
- Modified `src/web/index.html` to split every non-dummy key pad into `.key-half-top` and `.key-half-bottom` when the `edit-mode-active` class is present.
- Updated `index.html` JavaScript to route drag-and-drop actions to `isShift = true` when dropped on the top half, and `isShift = false` when dropped on the bottom half.
- Removed the old editor shift mode toggle since both halves are visible at all times in edit mode.

## What Worked
The window resizing and vertical key split rendering works as intended via `claude-sonnet-5` subagent delegation. Drag-and-drop correctly targets specific halves for standard vs shift actions.

## What Didn't Work / Known Issues
N/A.

## Architecture Notes
Hammerspoon `hs.webview` frame updates must manually adjust the `h` property while preserving the anchor (x,y), which expands the window downwards by default.
