# Step 01: Layout Configuration Data Model, Customization Storage & Hammerspoon Bridge

## Goal
Establish custom layout data storage in Hammerspoon (`hs.settings`), allow dynamic overrides of key assignments for note keys and control keys, and expose IPC handlers to load, save, reset, and update key assignments from the HTML webview UI.

## Target Files
- `src/config.lua`: Add user custom layout loading/saving logic, dynamic mapping functions, and default action catalog.
- `src/hud.lua`: Add IPC messaging handlers (`getLayoutConfig`, `saveCustomLayout`, `resetLayout`, `updateKeyMapping`) between Hammerspoon and the HTML webview.

## Requirements & Detailed Specifications
1. **Catalog of Actions & Key Library Items**:
   - Define a comprehensive catalog of control actions (e.g., `arpToggle`, `panic`, `octaveDown`, `octaveUp`, `modeDown`, `modeUp`, `rootDown`, `rootUp`, `trnspDown`, `trnspUp`, `sustain`, `randomScale`, `volDown`, `volUp`, etc.) and note key offset items (or base note assignments).
2. **Persistent Settings**:
   - Save custom mappings under `qwertyMidi_customKeyLayout` in `hs.settings`.
   - Provide clean fallback to default `numberRowControls`, `homeRowControls`, `upperRowKeys`, `lowerRowKeys` when custom mapping is absent or reset.
3. **IPC Bridge Methods**:
   - `getLayoutConfig`: Returns current active key layout (rows and key slots), default layout state, and the catalog/library of all assignable actions.
   - `saveCustomLayout`: Accepts updated key bindings object, persists via `config.saveSettings()`, re-registers key listeners if needed, and broadcasts UI update.
   - `resetLayout`: Clears custom overrides and reverts to defaults.

## Verification Criteria
- Verify Lua syntax and bundle execution via `bash bin/bundle_and_reload.sh`.
- Test IPC call from webview console: `window.webkit.messageHandlers.hammerspoon.postMessage(...)` returns full layout state.
