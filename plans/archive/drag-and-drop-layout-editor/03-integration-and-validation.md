# Step 03: End-to-End Integration, Validation & Bundle Reload

## Goal
Integrate the custom layout storage with event swallowing in `controls.lua`, verify live key mapping updates during runtime, and perform build validation with `bin/bundle_and_reload.sh`.

## Target Files
- `src/controls.lua`: Ensure dynamic key lookup handles customized note and control key mapping seamlessly during key down/up events.
- `bin/bundle_and_reload.sh`: Sync HTML UI to `src/ui_html.lua` and bundle into `qwerty_midi.lua`.

## Requirements & Detailed Specifications
1. **Controls Engine Binding**:
   - Ensure `controls.lua` checks dynamic customized key tables before falling back to defaults for event swallowing and MIDI execution.
2. **Full Workflow Test**:
   - Enable Edit Mode -> Drag new action onto a key -> Save -> Verify key press executes new assigned action -> Reset -> Verify original mapping restored.
3. **Bundle & Post-Flight Reload**:
   - Run `bash /Users/matt/projects/qwerty-midi-hammerspoon/bin/bundle_and_reload.sh` to compile production assets.

## Verification Criteria
- Execute `bash /Users/matt/projects/qwerty-midi-hammerspoon/bin/bundle_and_reload.sh` cleanly without errors.
- Confirm full functionality in Hammerspoon HUD webview.
