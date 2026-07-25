local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
local hud = require("hud")
local controls = require("controls")

local state = config.state

_G.activeWatchers = _G.activeWatchers or {}

arpeggiator.setHudModule(hud)
hud.setControlsModule(controls)

function _G.toggleMidiMode(newState)
  if newState == nil then
    state.midiActive = not state.midiActive
  else
    state.midiActive = newState
  end

  if state.midiActive then
    _G.activeWatchers.midiKeyTap:start()
    _G.activeWatchers.midiScrollTap:start()
    local h = hud.createMidiWebview()
    h:show()
  else
    _G.activeWatchers.midiKeyTap:stop()
    _G.activeWatchers.midiScrollTap:stop()
    state.pressedKeys = {}
    if _G.activeWatchers.midiWebview then
      _G.activeWatchers.midiWebview:hide()
    end
  end
end

_G.activeWatchers.midiScrollTap = hs.eventtap.new({ hs.eventtap.event.types.scrollWheel }, function(event)
  if not state.midiActive then return false end

  local deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1) or 0
  if deltaY == 0 then
    deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventPointDeltaAxis1) or 0
  end

  -- Dampen (not block) momentum/inertia events so deceleration feels natural but short
  local phase = event:getProperty(hs.eventtap.event.properties.scrollWheelEventScrollPhase) or 0
  local inertiaScale = (phase == 0) and 0.3 or 1.0

  if deltaY ~= 0 then
    if state.shiftHeld then
      local avgVol = (state.topRowVolume + state.bottomRowVolume) / 2
      _G.activeWatchers.volAccumulator = _G.activeWatchers.volAccumulator or avgVol
      local sensitivity = 0.25 * inertiaScale
      _G.activeWatchers.volAccumulator = math.max(0, math.min(127, _G.activeWatchers.volAccumulator - (deltaY * sensitivity)))
      local newVol = math.floor(_G.activeWatchers.volAccumulator + 0.5)

      local deltaVol = newVol - math.floor(avgVol + 0.5)
      if deltaVol ~= 0 then
        state.topRowVolume = math.max(0, math.min(127, state.topRowVolume + deltaVol))
        state.bottomRowVolume = math.max(0, math.min(127, state.bottomRowVolume + deltaVol))
        local spot = {
          title = "ROW VOLUMES",
          value = "TOP " .. math.floor((state.topRowVolume / 127) * 100) .. "% | BOT " .. math.floor((state.bottomRowVolume / 127) * 100) .. "%",
          subtext = "Dual Row Volume Level",
          targetId = "header",
          color = "#d4a359"
        }
        hud.updateWebviewHud(spot)
      end
    else
      local currentMod = state.ccStates[1] or 0
      _G.activeWatchers.modAccumulator = _G.activeWatchers.modAccumulator or currentMod
      local sensitivity = 0.15 * inertiaScale
      _G.activeWatchers.modAccumulator = math.max(0, math.min(127, _G.activeWatchers.modAccumulator - (deltaY * sensitivity)))
      local newMod = math.floor(_G.activeWatchers.modAccumulator + 0.5)

      if newMod ~= state.ccStates[1] then
        state.ccStates[1] = newMod
        midi.sendMidiCC(1, newMod)
        local spot = {
          title = "MOD WHEEL (CC #1)",
          value = tostring(newMod),
          subtext = math.floor((newMod / 127) * 100) .. "% Intensity",
          targetId = "header",
          color = "#d4a359"
        }
        hud.updateWebviewHud(spot)
      end
    end
    return true
  end

  return false
end)

_G.activeWatchers.midiKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp, hs.eventtap.event.types.flagsChanged }, function(event)
  if not state.midiActive then return false end

  local flags = event:getFlags()

  if state.bpmInputMode then
    if event:getType() == hs.eventtap.event.types.flagsChanged then
      return false
    end
    if flags.cmd or flags.ctrl then return false end
    local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
    local isDown = (event:getType() == hs.eventtap.event.types.keyDown)
    if isDown then
      return arpeggiator.handleBpmInput(code, flags)
    end
    return true
  end

  if flags.cmd or flags.alt or flags.ctrl then
    return false
  end

  local isShiftNow = flags.shift
  if isShiftNow ~= state.shiftHeld then
    state.shiftHeld = isShiftNow
    hud.updateWebviewHud()
  end

  if event:getType() == hs.eventtap.event.types.flagsChanged then
    return false
  end

  local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
  local isDown = (event:getType() == hs.eventtap.event.types.keyDown)

  if isDown then
    return controls.handleKeyDown(code)
  else
    return controls.handleKeyUp(code)
  end
end)

local settings_ui = require("settings_ui")

_G.activeWatchers.midiToggleHotkey = hs.hotkey.bind({ "cmd", "alt" }, "M", function()
  _G.toggleMidiMode()
end)

_G.activeWatchers.settingsHotkey = hs.hotkey.bind({ "cmd" }, ",", function()
  settings_ui.toggleSettingsWindow()
end)

midi.panicAllChannels()
_G.toggleMidiMode(true)

return {
  toggleMidiMode = _G.toggleMidiMode,
  toggleSettingsWindow = settings_ui.toggleSettingsWindow
}
