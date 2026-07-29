# 2026-07-25 — Layout Preset Switching & Management UI

## Overview
Added support for creating, switching, renaming, duplicating, and deleting layout presets directly from the Action Library drawer in QWERTY MIDI.

## Key Changes
1. **`src/config.lua`**:
   - Added `qwertyMidi_layoutPresets` and `qwertyMidi_activePresetId` management in `hs.settings`.
   - Built `getPresetsList()`, `selectPreset()`, `savePreset()`, `renamePreset()`, `duplicatePreset()`, and `deletePreset()`.
   - Updated `saveCustomLayout()` and `resetLayout()` to update current active preset data.

2. **`src/hud.lua`**:
   - Wired Webview user content handlers for `selectPreset`, `savePreset`, `renamePreset`, `deletePreset`, and `duplicatePreset`.
   - Automatically broadcasts updated `getLayoutConfig()` payload with presets list back to Webview on changes.

3. **`src/web/index.html` & `src/ui_html.lua`**:
   - Added layout preset toolbar inside Action Library drawer with dropdown selection, `+ Save As`, `✏️ Rename`, `📋 Duplicate`, and `🗑️ Delete` actions.
   - Built modal dialog overlay for entering preset names on save/rename/duplicate.
   - Added `• Modified` badge when unsaved key mapping changes exist.
   - Auto-prompts *Save As* when editing keys on the built-in default preset.

4. **`qwerty_midi.lua`**:
   - Rebundled via `bin/bundle_and_reload.sh`.
