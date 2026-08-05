# Modular JSON Layouts & Action Catalog Refactor Log

## Summary
Refactored the keyboard layout and action catalog systems in `qwerty-midi-hammerspoon` to be completely modular and driven by JSON files, eliminating the complex and bug-prone "Edit Layout" mode from the UI.

## Details
1. **Action Catalog:** Extracted hardcoded catalog array to `actions/actions.json`. `config.getActionCatalog()` loads it on demand.
2. **Layout Files:** Saved layout specifications as `.json` files in `layouts/` directory (`default.json`, `synth_lead.json`). `config.getAvailableLayouts()` reads and parses all layout JSON files in `layouts/`.
3. **UI Clean-up:** Removed `#action-library-drawer`, drag & drop event handlers, layout editing buttons, and context menus from `src/web/index.html`. Added `#layout-select` dropdown in the header for switching layouts via IPC (`selectPreset`).
4. **Build & Bundling:** Verified Lua module compilation and bundled into `qwerty_midi.lua`.
