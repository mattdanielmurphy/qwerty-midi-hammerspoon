local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
local hud = require("hud")
local controls = require("controls")
local settings_ui = require("settings_ui")

local function profileLog(msg)
  local f = io.open("/tmp/midi_startup.log", "a")
  if f then
    f:write(os.clock() .. ": " .. msg .. "\n")
    f:close()
  end
end
profileLog("Start init.lua")

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

  -- Persist window-open state so reload can auto-reopen if needed
  hs.settings.set("qwertyMidi_wasOpen", state.midiActive)

  if state.midiActive then
    profileLog("Starting midiActive logic")
    _G.activeWatchers.midiKeyTap:start()
    _G.activeWatchers.midiScrollTap:start()
    profileLog("Before createMidiWebview")
    local h = hud.createMidiWebview()
    profileLog("After createMidiWebview, before show")
    h:show()
    profileLog("After show")
  else
    -- Stop all key repeats before tearing down
    if controls.stopAllControlRepeats then
      controls.stopAllControlRepeats()
    end
    _G.activeWatchers.midiKeyTap:stop()
    _G.activeWatchers.midiScrollTap:stop()
    state.pressedKeys = {}
    state.sustainKeyDownTime = nil
    if _G.activeWatchers.midiWebview then
      _G.activeWatchers.midiWebview:hide()
    end
  end
end

_G.activeWatchers.midiScrollTap = hs.eventtap.new({ hs.eventtap.event.types.scrollWheel }, function(event)
  if not state.midiActive then return false end

  local ok, result = xpcall(function()
    local deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1) or 0
    if deltaY == 0 then
      deltaY = event:getProperty(hs.eventtap.event.properties.scrollWheelEventPointDeltaAxis1) or 0
    end

    -- Dampen (not block) momentum/inertia events so deceleration feels natural but short
    local phase = event:getProperty(hs.eventtap.event.properties.scrollWheelEventScrollPhase) or 0
    local inertiaScale = (phase == 0) and state.scrollMomentumScale or 1.0

    -- Allow native webview scrolling only when cursor is specifically over a scrollable pane in the HUD
    if _G.activeWatchers.isHoveringScrollable then
      return false
    end

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
        local sensitivity = state.scrollSensitivity * inertiaScale
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
  end, function(err)
    print("QWERTY MIDI: CRITICAL SCROLLTAP ERROR: " .. tostring(err))
    print(debug.traceback())
    return false
  end)

  if not ok then
    return false
  end
  return result
end)

_G.activeWatchers.midiKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp, hs.eventtap.event.types.flagsChanged }, function(event)
  if not state.midiActive then return false end

  local function errorHandler(err)
    print("QWERTY MIDI: CRITICAL EVENTTAP ERROR: " .. tostring(err))
    print(debug.traceback())
    -- Failsafe: if we crash during a key event, try to prevent stuck keys
    pcall(function()
      if state and state.pressedKeys then
        local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
        if code then state.pressedKeys[code] = nil end
      end
    end)
    return false -- allow event to pass to OS so we don't lock the keyboard
  end

  local ok, result = xpcall(function()

      -- Exception: Let text input fields receive keystrokes natively
      if state.textInputActive then
        return false
      end

      -- Exception: Let Delete/Backspace work in the webview's edit mode
      local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
      local isDown = (event:getType() == hs.eventtap.event.types.keyDown)
      if code == 51 or code == 117 then -- Delete (51) or Forward Delete (117)
        if event:getType() == hs.eventtap.event.types.keyDown then
          return false
        end
        return true
      end

      -- Exception: Pass keys through natively ONLY if Web Inspector or DevTools window is focused
      local focusedWin = hs.window.focusedWindow()
      if focusedWin then
        local title = focusedWin:title() or ""
        if string.find(title, "Inspector") or string.find(title, "DevTools") then
          return false
        end
      end

      local flags = event:getFlags()

      -- Handle Cmd-, for QWERTY MIDI settings while MIDI controller is enabled
      if flags.cmd and not flags.alt and not flags.ctrl then
        local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
        if code == 43 then -- keycode 43 is ','
          if event:getType() == hs.eventtap.event.types.keyDown then
            settings_ui.toggleSettingsWindow()
          end
          return true
        end
      end

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

      if flags.cmd or flags.alt or flags.ctrl or flags.capslock then
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
        local ok, status = xpcall(function() return controls.handleKeyDown(code) end, function(err) print('QWERTY MIDI: handleKeyDown error: '..tostring(err)); print(debug.traceback()); return false end)
        if not ok then
          print("QWERTY MIDI: handleKeyDown error: " .. tostring(status))
          return false
        end
        return status
      else
        local ok, status = xpcall(function() return controls.handleKeyUp(code) end, function(err) print('QWERTY MIDI: handleKeyUp error: '..tostring(err)); print(debug.traceback()); return false end)
        if not ok then
          print("QWERTY MIDI: handleKeyUp error: " .. tostring(status))
          return false
        end
        return status
      end

  end, errorHandler)

  if not ok then
    return false
  end
  return result
end)

-- Watchdog timer: if the key eventtap stops silently (e.g. uncaught pcall error), restart it
-- Also checks webview liveness via JS heartbeat — if no heartbeat for 6s, web process is dead
_G.activeWatchers.keyTapWatchdog = hs.timer.doEvery(3.0, function()
  if state.midiActive then
    if _G.activeWatchers.midiKeyTap and not _G.activeWatchers.midiKeyTap:isEnabled() then
      print("QWERTY MIDI: Watchdog detected dead keyTap, restarting...")
      _G.activeWatchers.midiKeyTap:start()
    end
    if _G.activeWatchers.midiScrollTap and not _G.activeWatchers.midiScrollTap:isEnabled() then
      print("QWERTY MIDI: Watchdog detected dead scrollTap, restarting...")
      _G.activeWatchers.midiScrollTap:start()
    end
    -- Webview liveness: if heartbeat stopped for 6s, web content process is dead
    if _G.activeWatchers.midiWebview and hud.getLastHeartbeat() > 0 then
      local elapsed = os.time() - hud.getLastHeartbeat()
      if elapsed >= 6 then
        print("QWERTY MIDI: Watchdog detected dead webview (no heartbeat for " .. elapsed .. "s) — recreating")
        local ok, err = pcall(function()
          local h = hud.createMidiWebview()
          h:show()
        end)
        if not ok then
          print("QWERTY MIDI: Watchdog webview recreate failed: " .. tostring(err))
        end
      end
    end
  end
end)

_G.activeWatchers.midiToggleHotkey = hs.hotkey.bind({ "cmd", "alt" }, "M", function()
  _G.toggleMidiMode()
end)

if _G.activeWatchers.settingsHotkey then
  _G.activeWatchers.settingsHotkey:delete()
  _G.activeWatchers.settingsHotkey = nil
end

profileLog("Before panicAllChannels")
midi.panicAllChannels()

-- Auto-reopen window if it was open when the last reload occurred
local wasOpen = hs.settings.get("qwertyMidi_wasOpen")
if wasOpen then
  profileLog("Auto-reopening controller window (was open before reload)")
  hs.timer.doAfter(0.3, function()
    local ok, err = pcall(function()
      _G.toggleMidiMode(true)
    end)
    if not ok then
      print("QWERTY MIDI: auto-reopen failed: " .. tostring(err))
    end
  end)
end

profileLog("Init complete!")

return {
  toggleMidiMode = _G.toggleMidiMode,
  toggleSettingsWindow = settings_ui.toggleSettingsWindow
}
