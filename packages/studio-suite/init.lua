-- packages/studio-suite/init.lua
-- Master Studio Suite: Synchronized dual-surface controller for QWERTY keyboard + Arturia KeyStep 32.

local config = require("config")
local midi = require("midi")
local harmony = require("harmony")
local clock = require("clock")
local arpeggiator = require("arpeggiator")
local hud = require("hud")
local controls = require("controls")
local settings_ui = require("settings_ui")
local keystep = require("keystep")

local state = config.state
_G.activeWatchers = _G.activeWatchers or {}

-- 1. Wire internal module dependencies
arpeggiator.setHudModule(hud)
hud.setControlsModule(controls)
keystep.setHud(hud)

-- 2. Hardware connection
keystep.connect("Arturia KeyStep 32")

-- 3. Master Toggle Function (QWERTY + Arturia KeyStep 32)
function _G.toggleStudioSuite(newState)
  if _G.toggleMidiMode then
    _G.toggleMidiMode(newState)
  end

  if state.midiActive then
    keystep.connect("Arturia KeyStep 32")
    hs.alert.show("🎹 Studio Suite: ACTIVE (QWERTY + KeyStep 32)", 1.2)
  else
    hs.alert.show("⏹️ Studio Suite: OFF", 1.0)
  end
end

-- Cmd-Shift-M is intentionally unbound. It previously shadowed the MIDI HUD
-- close experiment and could survive a partial reload as a global interceptor.
if _G.activeWatchers.studioSuiteToggle then
  _G.activeWatchers.studioSuiteToggle:delete()
  _G.activeWatchers.studioSuiteToggle = nil
end

local M = {
  id = "studio_suite",
  name = "Surface Studio Suite (QWERTY + KeyStep 32)",
  keystep = keystep,
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
