-- packages/studio-suite/init.lua
-- Master Studio Suite: Synchronized dual-surface controller for QWERTY keyboard + Korg nanoKEY Studio.

local config = require("config")
local midi = require("midi")
local harmony = require("harmony")
local clock = require("clock")
local arpeggiator = require("arpeggiator")
local hud = require("hud")
local controls = require("controls")
local settings_ui = require("settings_ui")
local nanokey = require("nanokey")

local state = config.state
_G.activeWatchers = _G.activeWatchers or {}

-- 1. Wire internal module dependencies
arpeggiator.setHudModule(hud)
hud.setControlsModule(controls)
nanokey.setHud(hud)

-- 2. Hardware connection
nanokey.connect("nanoKEY Studio")

-- 3. Live State Synchronization between nanoKEY and QWERTY
nanokey.setOnStateChange(function(change)
  if change.layer then
    state.currentLayer = change.layer
  end
  if hud.updateWebviewHud then
    hud.updateWebviewHud()
  end
end)

-- 4. Master Toggle Function (QWERTY + nanoKEY Studio)
function _G.toggleStudioSuite(newState)
  if _G.toggleMidiMode then
    _G.toggleMidiMode(newState)
  end

  if state.midiActive then
    nanokey.connect("nanoKEY Studio")
    hs.alert.show("🎹 Studio Suite: ACTIVE (QWERTY + nanoKEY)", 1.2)
  else
    nanokey.disconnect()
    hs.alert.show("⏹️ Studio Suite: OFF", 1.0)
  end
end

-- 5. Hotkeys
_G.activeWatchers.studioSuiteToggle = hs.hotkey.bind({ "cmd", "shift" }, "M", function()
  _G.toggleStudioSuite()
end)

local M = {
  id = "studio_suite",
  name = "Surface Studio Suite (QWERTY + nanoKEY)",
  nanokey = nanokey,
  musicEngine = {
    harmony = harmony,
    clock = clock,
    arpeggiator = arpeggiator
  },
  toggle = _G.toggleStudioSuite,
  start = function(isAutoReload)
    if isAutoReload then
      local wasOpen = hs.settings.get("qwertyMidi_wasOpen")
      if wasOpen then
        _G.toggleStudioSuite(true)
      end
    else
      _G.toggleStudioSuite(true)
    end
  end,
  stop = function()
    _G.toggleStudioSuite(false)
  end,
  isEnabled = function()
    return state.midiActive == true
  end
}

return M
