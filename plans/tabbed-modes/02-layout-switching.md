# Step 2: Layout Switching Architecture

## Feature Overview
We are implementing "Tabbed Modes" for the keyboard controller. The QWERTY keyboard will dynamically change its entire layout based on the current mode. 

## Objective
Update the `getActiveControlKeysMap` and `getActiveNoteKeysMap` functions in `src/config.lua` so that they return different layout tables based on `state.currentMode`.

## Instructions
1. **Define `ArpAdvanced` Maps in `src/config.lua`**:
   Around line 200, where `defaultNumberRowControls` is defined, create empty placeholder maps for the new mode:
   ```lua
   local arpAdvancedControlKeysMap = {
     -- We will populate this in Step 3
   }
   local arpAdvancedNoteKeysMap = {
     -- Empty, as piano keys might be disabled or act as controls in this mode
   }
   ```

2. **Modify `getActiveControlKeysMap` in `src/config.lua`**:
   ```lua
   local function getActiveControlKeysMap()
     if state.currentMode == "ArpAdvanced" then
       return arpAdvancedControlKeysMap
     end
     
     -- The existing logic for "Home" mode:
     if _cachedActiveControlKeysMap then return _cachedActiveControlKeysMap end
     local map = {}
     for code, k in pairs(homeRowControls) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
     for code, k in pairs(upperRowKeys) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
     for code, k in pairs(lowerRowKeys) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
     for code, k in pairs(numberRowControls) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
     
     _cachedActiveControlKeysMap = map
     return map
   end
   ```

3. **Modify `getActiveNoteKeysMap` in `src/config.lua`**:
   ```lua
   local function getActiveNoteKeysMap()
     if state.currentMode == "ArpAdvanced" then
       return arpAdvancedNoteKeysMap
     end

     -- The existing logic for "Home" mode:
     if _cachedActiveNoteKeysMap then return _cachedActiveNoteKeysMap end
     -- ... existing map building logic ...
     _cachedActiveNoteKeysMap = map
     return map
   end
   ```

4. **Expose the new maps via `M` (if needed)**:
   Ensure `arpAdvancedControlKeysMap` and `arpAdvancedNoteKeysMap` are accessible if they need to be populated from `controls.lua`. Better yet, we can populate them directly inside `config.lua` in Step 3.

## Verification
- When `state.currentMode == "ArpAdvanced"`, no notes should play when pressing QWERTY keys because `getActiveNoteKeysMap()` returns an empty table.
