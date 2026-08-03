# Step 3: Arpeggiator Advanced Layout

## Feature Overview
With the mode-switching architecture in place, we can now populate the `ArpAdvanced` control map to turn the entire keyboard into a dedicated arpeggiator control surface.

## Objective
Define the `arpAdvancedControlKeysMap` and implement the corresponding action handlers in `controls.lua`.

## Instructions
1. **Define `arpAdvancedControlKeysMap` in `src/config.lua`**:
   Populate the table created in Step 2:
   ```lua
   local arpAdvancedControlKeysMap = {
     -- Arp Rate
     [18] = { key = "1", name = "Rate 1/4",   action = "setArpRate_5" },
     [19] = { key = "2", name = "Rate 1/8",   action = "setArpRate_6" },
     [20] = { key = "3", name = "Rate 1/16",  action = "setArpRate_7" },
     [21] = { key = "4", name = "Rate 1/32",  action = "setArpRate_8" },

     -- Arp Direction
     [12] = { key = "q", name = "Dir UP",     action = "setArpDir_1" },
     [13] = { key = "w", name = "Dir DOWN",   action = "setArpDir_2" },
     [14] = { key = "e", name = "Dir UP/DN",  action = "setArpDir_3" },
     [15] = { key = "r", name = "Dir DN/UP",  action = "setArpDir_4" },
     [17] = { key = "t", name = "Dir RAND",   action = "setArpDir_7" },

     -- Arp Quantize
     [6] = { key = "z", name = "Sync OFF",    action = "setArpQuantize_None" },
     [7] = { key = "x", name = "Sync BEAT",   action = "setArpQuantize_Beat" },
     [8] = { key = "c", name = "Sync BAR",    action = "setArpQuantize_Bar" },

     -- Arp Latch
     [49] = { key = "Space", name = "Arp Latch", action = "arpLatchToggle" },
   }
   ```
   *(Note: Ensure you include all desired Arp settings and use correct keycodes. Keycodes: `1=18, 2=19, 3=20, 4=21`, `q=12, w=13, e=14, r=15, t=17`, `z=6, x=7, c=8`, `space=49`)*

2. **Handle the new actions in `src/controls.lua`**:
   In `executeControlAction(act, code)` (around line 234):
   Add logic to parse these new explicit setter actions.
   ```lua
   if string.match(act, "^setArpRate_(%d+)$") then
     local rate = tonumber(string.match(act, "^setArpRate_(%d+)$"))
     state.arpRateIdx = rate
     arpeggiator.applyBpmChange()
     hud.updateWebviewHud()
     return
   elseif string.match(act, "^setArpDir_(%d+)$") then
     local dir = tonumber(string.match(act, "^setArpDir_(%d+)$"))
     state.arpDirectionIdx = dir
     hud.updateWebviewHud()
     return
   elseif string.match(act, "^setArpQuantize_(.+)$") then
     local quant = string.match(act, "^setArpQuantize_(.+)$")
     state.arpQuantizeMode = quant
     hs.settings.set("qwertyMidi_arpQuantizeMode", quant)
     hud.updateWebviewHud()
     return
   end
   ```

## Verification
- Enter `ArpAdvanced` mode (hold backtick, press 'a').
- Press `1`, `2`, `3`, `4` and verify the arp rate changes.
- Press `Q`, `W`, `E` and verify the arp direction changes.
