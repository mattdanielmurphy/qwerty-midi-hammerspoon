local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
local hud = require("hud")
local controls = require("controls")
local settings_ui = require("settings_ui")
local sync = require("sync")
local nanokey = nil
pcall(function()
  nanokey = require("nanokey")
end)

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
sync.init(config, hud)
_G.activeWatchers.sync = sync

if nanokey then
  nanokey.setHud(hud)
  _G.activeWatchers.nanokey = nanokey
  pcall(function() nanokey.connect("nanoKEY Studio") end)
end

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
    if nanokey and nanokey.connect and not nanokey.isConnected() then
      pcall(function() nanokey.connect("nanoKEY Studio") end)
    end
  else
    -- Stop all key repeats before tearing down
    if controls.stopAllControlRepeats then
      controls.stopAllControlRepeats()
    end
    -- Stop arpeggiator and reset sustain to prevent stuck notes on disable
    if arpeggiator and arpeggiator.stopArpTimer then
      arpeggiator.stopArpTimer()
    end
    state.sustainActive = false
    midi.sendMidiCC(64, 0)
    
    -- Keep nanokey hardware driver connected so physical controller macros and playing remain active
    -- Do not call nanokey.disconnect() here

    _G.activeWatchers.midiKeyTap:stop()
    _G.activeWatchers.midiScrollTap:stop()
    state.bpmInputMode = false
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

    -- Scroll handling
    local phase = event:getProperty(hs.eventtap.event.properties.scrollWheelEventScrollPhase) or 0
    if phase == 0 then
      _G.activeWatchers.lastActiveTouchTime = hs.timer.absoluteTime()
    end

    local sens = state.scrollSensitivity or 0.15
    local accel = state.scrollAcceleration or 1.0
    local initGain = state.scrollInertiaInitial or 1.0
    local decay = state.scrollInertiaDecay or 0.85
    local curveExp = state.scrollCurveExponent or 1.0
    local maxInertiaMs = state.scrollMaxInertiaMs or 250
    local inertiaCutoff = state.scrollInertiaCutoff or 0.5

    deltaY = math.max(-100, math.min(100, deltaY))

    -- Curve shape mapping: apply curve exponent on magnitude
    local absDelta = math.abs(deltaY)
    local curvedDelta = (absDelta ^ curveExp) * (deltaY >= 0 and 1 or -1)

    local scaledDelta = curvedDelta * sens * accel

    if phase ~= 0 then
      local timeSinceTouch = (hs.timer.absoluteTime() - (_G.activeWatchers.lastActiveTouchTime or 0)) / 1e6
      if timeSinceTouch > maxInertiaMs then return true end
      if math.abs(scaledDelta) < inertiaCutoff then return true end

      if initGain == 0 then return true end
      scaledDelta = scaledDelta * initGain * decay
    end

    deltaY = scaledDelta

    -- Allow native webview scrolling when cursor is over settings window or hovering a scrollable HUD pane
    if _G.activeWatchers.isHoveringSettings or _G.activeWatchers.isHoveringScrollable then
      return false
    end

    if _G.activeWatchers.settingsWebview and _G.activeWatchers.settingsWebview:isVisible() then
      local mPos = hs.mouse.absolutePosition()
      local sf = _G.activeWatchers.settingsWebview:frame()
      if mPos.x >= sf.x and mPos.x <= (sf.x + sf.w) and mPos.y >= sf.y and mPos.y <= (sf.y + sf.h) then
        return false
      end
    end

    if deltaY ~= 0 then
      if state.shiftHeld then
        local avgVol = (state.topRowVolume + state.bottomRowVolume) / 2
        _G.activeWatchers.volAccumulator = _G.activeWatchers.volAccumulator or avgVol
        -- Adjusting volume with new scroll mechanics
        _G.activeWatchers.volAccumulator = math.max(0, math.min(127, _G.activeWatchers.volAccumulator - deltaY))
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
        _G.activeWatchers.modAccumulator = math.max(0, math.min(127, _G.activeWatchers.modAccumulator - deltaY))
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
        local ok, status = xpcall(function() return controls.handleKeyDown(code) end, function(err) print('QWERTY MIDI: handleKeyDown error: '..tostring(err)); print(debug.traceback()); return true end)
        if not ok then
          print("QWERTY MIDI: handleKeyDown error: " .. tostring(status))
        end
        return true
      else
        local ok, status = xpcall(function() return controls.handleKeyUp(code) end, function(err) print('QWERTY MIDI: handleKeyUp error: '..tostring(err)); print(debug.traceback()); return true end)
        if not ok then
          print("QWERTY MIDI: handleKeyUp error: " .. tostring(status))
        end
        return true
      end

  end, errorHandler)

  if not ok then
    return false
  end
  return result
end)

-- Watchdog timer: if the key eventtap stops silently (e.g. uncaught pcall error), restart it
-- Also checks webview liveness via JS ping/pong — if no response for 5s, web process is dead
local lastRefreshClickTime = 0
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

    if nanokey and nanokey.checkConnection then
      pcall(function() nanokey.checkConnection() end)
    end
    
    hud.pingWebview()
    local hb = hud.getLastHeartbeat()
    local pong = hud.getLastPongTime()
    local lastSeen = math.max(hb, pong)
    if _G.activeWatchers.midiWebview and lastSeen > 0 then
      local elapsed = os.time() - lastSeen
      if elapsed >= 5 then
        local msg = "QWERTY MIDI: Watchdog detected unresponsive webview (no heartbeat/pong for " .. elapsed .. "s) — executing webview hard respawn"
        local f = io.open("/Users/matt/projects/qwerty-midi-hammerspoon/tmp/qwerty_midi_debug.log", "a")
        if f then f:write(os.date("%H:%M:%S") .. " [WATCHDOG]: " .. msg .. "\n"); f:close() end
        
        pcall(function()
          local h = hud.reloadMidiWebview()
          if h then h:show() end
          hs.alert.show("UI Auto-Recovered by Watchdog", 2.0)
        end)
      end
    end
  end
end)

_G.activeWatchers.midiToggleHotkey = hs.hotkey.bind({ "cmd", "shift" }, "M", function()
  _G.toggleMidiMode()
end)

_G.activeWatchers.midiRefreshHotkey = hs.hotkey.bind({ "cmd", "alt" }, "R", function()
  _G.dumpMidiLogs()
  hs.alert.show("⚡ Hard Reloading Hammerspoon...", 1.5)
  hs.notify.new({ title = "QWERTY MIDI", informativeText = "Logs copied to clipboard. Hard reloading..." }):send()
  hs.timer.doAfter(0.1, function() hs.reload() end)
end)

if _G.activeWatchers.settingsHotkey then
  _G.activeWatchers.settingsHotkey:delete()
  _G.activeWatchers.settingsHotkey = nil
end

profileLog("Before panicAllChannels")
midi.panicAllChannels()



_G.pingController = function() return hud.pingController() end
_G.dumpMidiLogs = function() return hud.dumpMidiLogs() end
_G.hardResetController = function()
  _G.dumpMidiLogs()
  hs.alert.show("⚡ Hard Reloading Hammerspoon...", 1.5)
  hs.notify.new({ title = "QWERTY MIDI", informativeText = "Logs copied to clipboard. Hard reloading..." }):send()
  hs.timer.doAfter(0.1, function() hs.reload() end)
end

profileLog("Init complete!")

local M = {
  id = "qwerty_midi",
  name = "QWERTY MIDI Controller",
  toggleMidiMode = _G.toggleMidiMode,
  toggleSettingsWindow = settings_ui.toggleSettingsWindow,
  start = function(isAutoReload)
    if isAutoReload then
      local wasOpen = hs.settings.get("qwertyMidi_wasOpen")
      if wasOpen then
        _G.toggleMidiMode(true)
      end
    else
      _G.toggleMidiMode(true)
    end
  end,
  stop = function()
    _G.toggleMidiMode(false)
  end,
  isEnabled = function()
    return state.midiActive == true
  end
}
return M
