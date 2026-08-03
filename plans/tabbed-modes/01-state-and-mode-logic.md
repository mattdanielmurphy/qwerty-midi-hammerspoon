# Step 1: State and Mode Logic

## Feature Overview
We are implementing "Tabbed Modes" for the keyboard controller. The QWERTY keyboard will dynamically change its entire layout based on the current mode (e.g., "Home" mode vs "ArpAdvanced" mode). The backtick key (`\``, keycode 50) will act as the mode selector modifier. While held down, the keyboard enters a mode-selection state, where pressing keys like `a` switches the active tabbed mode.

## Objective
Update the core state, config, and `controls.lua` key event handlers to intercept the backtick key, manage `state.currentMode`, and release held keys upon mode switch.

## Instructions
1. **Add to `src/config.lua`**:
   In `M.state` (around line 20-30), add:
   ```lua
     currentMode = "Home",
     modeSelectHeld = false,
     modeWasSelectedDuringHold = false,
   ```

2. **Intercept Backtick in `src/controls.lua`**:
   In `handleKeyDown(code)` (near the top):
   ```lua
   local function handleKeyDown(code)
     if code == 50 then -- Backtick
       state.modeSelectHeld = true
       state.modeWasSelectedDuringHold = false
       hud.updateWebviewHud()
       return true
     end

     if state.modeSelectHeld then
       -- Mode Selector is Active!
       if code == 0 then -- 'a' key
         state.currentMode = "ArpAdvanced"
         state.modeWasSelectedDuringHold = true
         -- Release any currently pressed piano keys to prevent stuck notes
         for heldCode, isHeld in pairs(state.pressedKeys) do
           if isHeld then handleKeyUp(heldCode) end
         end
         hud.updateWebviewHud()
         return true
       end
       -- If it's another key, maybe block it or ignore it while mode selector is held
       return true 
     end
   ```

   In `handleKeyUp(code)`:
   ```lua
   local function handleKeyUp(code)
     if code == 50 then -- Backtick released
       state.modeSelectHeld = false
       if not state.modeWasSelectedDuringHold then
         state.currentMode = "Home"
         for heldCode, isHeld in pairs(state.pressedKeys) do
           if isHeld then handleKeyUp(heldCode) end
         end
       end
       hud.updateWebviewHud()
       return true
     end
   ```

3. **Modify `numberRowControls` in `src/config.lua`**:
   Remove the existing `arpToggle` and `panic` from keycode 50, since it is now hardcoded as the Mode Selector. (Set keycode 50 to `nil` or remove it from `defaultNumberRowControls`).

## Verification
- Pressing and holding backtick should trigger the `modeSelectHeld` state (which we'll visualize in Step 4).
- Pressing `a` while holding backtick changes `currentMode` to `"ArpAdvanced"`.
- Releasing backtick without pressing `a` changes `currentMode` back to `"Home"`.
