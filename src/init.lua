local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")
local hud = require("hud")
local controls = require("controls")
local settings_ui = require("settings_ui")
local sync = require("sync")
local logic_names = require("logic_names")
local keystep = nil
pcall(function()
  keystep = require("keystep")
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
sync.init(config, hud, controls)
_G.activeWatchers.logic_names = logic_names
_G.activeWatchers.sync = sync
_G.activeWatchers.hud = hud
_G.activeWatchers.state = state
_G.activeWatchers.controls = controls
_G.activeWatchers.arpeggiator = arpeggiator

local function disarmMidiInput(reason)
  state.midiActive = false
  state.cmdHeld = false
  hs.settings.set("qwertyMidi_wasOpen", false)
  if _G.activeWatchers.midiKeyTap then _G.activeWatchers.midiKeyTap:stop() end
  if _G.activeWatchers.midiScrollTap then _G.activeWatchers.midiScrollTap:stop() end
  if _G.activeWatchers.keyTapWatchdog then _G.activeWatchers.keyTapWatchdog:stop() end
  if logic_names and logic_names.stop then logic_names.stop() end
  if arpeggiator and arpeggiator.stopLogicSync then arpeggiator.stopLogicSync() end
  state.pressedKeys = {}
  state.bpmInputMode = false
  print("QWERTY MIDI: keyboard interception disabled — " .. tostring(reason))
end

-- A broken HUD must never leave a live event tap consuming ordinary keyboard
-- input. Event-callback callers defer teardown so the current event can pass.
local function failOpenMidiInput(reason)
  if _G.activeWatchers.midiInputFailOpenScheduled then return end
  _G.activeWatchers.midiInputFailOpenScheduled = true
  print("QWERTY MIDI: disabling keyboard interception — " .. tostring(reason))
  hs.timer.doAfter(0, function()
    disarmMidiInput(reason)
    _G.activeWatchers.midiInputFailOpenScheduled = false
    hs.alert.show("QWERTY MIDI input disabled after an error", 3)
  end)
end

-- This is the only project-owned HUD close path. It removes QWERTY capture
-- before touching WebKit, while retaining external hardware connections.
function _G.closeMidiHud(reason)
  disarmMidiInput(reason or "HUD closed")
  local ok, err = pcall(hud.hideMidiWebview)
  if not ok then
    print("QWERTY MIDI: HUD close error: " .. tostring(err))
  end
end

function _G.openMidiHud(reason)
  if state.midiActive and hud.isMidiWebviewHealthy() then return end
  _G.toggleMidiMode(true)
end

-- The HUD toggle intentionally lives outside midiKeyTap. It is an explicit,
-- visible global hotkey and never performs WebKit work inside an event-tap
-- callback. The QWERTY tap remains independently fail-open.
if _G.activeWatchers.midiHudToggleHotkey then
  _G.activeWatchers.midiHudToggleHotkey:delete()
end
_G.activeWatchers.midiHudToggleHotkey = hs.hotkey.bind({ "cmd", "shift" }, "M", function()
  if _G.activeWatchers.midiHudTogglePending then return end
  _G.activeWatchers.midiHudTogglePending = true
  hs.timer.doAfter(0.05, function()
    _G.activeWatchers.midiHudTogglePending = false
    if state.midiActive and hud.isMidiWebviewHealthy() then
      _G.closeMidiHud("Cmd-Shift-M")
    else
      _G.openMidiHud("Cmd-Shift-M")
    end
  end)
end)

if controls and controls.selectTrack then
  controls.selectTrack(state.activeTrack or 1)
end

if keystep then
  if keystep.setHud then keystep.setHud(hud) end
  if keystep.setTransposer then keystep.setTransposer(transposer, state) end
  if keystep.setNoteHandler then
    keystep.setNoteHandler({
      noteOn = controls.handleKeyStepNoteOn,
      noteOff = controls.handleKeyStepNoteOff,
      disconnect = controls.handleKeyStepDisconnect
    })
  end
  _G.activeWatchers.keystep = keystep
  pcall(function() keystep.connect("Arturia KeyStep 32") end)
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
    if controls and controls.selectTrack then
      controls.selectTrack(state.activeTrack or 1)
    end
    profileLog("Starting midiActive logic")
    _G.activeWatchers.midiKeyTap:start()
    _G.activeWatchers.midiScrollTap:start()
    if _G.activeWatchers.keyTapWatchdog and not _G.activeWatchers.keyTapWatchdog:running() then
      _G.activeWatchers.keyTapWatchdog:start()
    end
    if logic_names and logic_names.init then
      logic_names.init()
    end
    if arpeggiator and arpeggiator.startLogicSync then
      arpeggiator.startLogicSync()
    end
    profileLog("Before showMidiWebview")
    hud.showMidiWebview()
    profileLog("After showMidiWebview")
    if keystep and keystep.connect and not keystep.isConnected() then
      pcall(function() keystep.connect("Arturia KeyStep 32") end)
    end
    if keystep and keystep.syncToHud then
      pcall(function() keystep.syncToHud() end)
    end
  else
    -- Stop all key repeats before tearing down
    if controls.stopAllControlRepeats then
      controls.stopAllControlRepeats()
    end
    -- Reset sustain to prevent stuck notes on disable
    state.sustainActive = false
    state.cmdHeld = false
    midi.sendMidiCC(64, 0)
    
    -- NOTE: Arpeggiator continues running in background when window is closed,
    -- allowing autonomous multi-track background playback until explicit panic or stop.

    -- Keep keystep hardware driver connected so physical controller playing remains active
    -- Do not call keystep.disconnect() here

    _G.activeWatchers.midiKeyTap:stop()
    _G.activeWatchers.midiScrollTap:stop()
    if _G.activeWatchers.keyTapWatchdog then _G.activeWatchers.keyTapWatchdog:stop() end
    if logic_names and logic_names.stop then logic_names.stop() end
    if arpeggiator and arpeggiator.stopLogicSync then arpeggiator.stopLogicSync() end
    state.bpmInputMode = false
    state.pressedKeys = {}
    state.sustainKeyDownTime = nil
    if _G.activeWatchers.midiWebview then
      _G.activeWatchers.midiWebview:hide()
    end
  end
end

_G.activeWatchers.midiScrollTap = hs.eventtap.new({ hs.eventtap.event.types.scrollWheel }, function(event)
  if not state.midiActive or not hud.isMidiWebviewHealthy() then return false end

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
    end

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

if _G.activeWatchers.midiKeyTap then _G.activeWatchers.midiKeyTap:stop() end
if _G.activeWatchers.midiScrollTap then _G.activeWatchers.midiScrollTap:stop() end

_G.activeWatchers.midiKeyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp, hs.eventtap.event.types.flagsChanged }, function(event)
  if not state.midiActive then return false end
  if not hud.isMidiWebviewHealthy() then return false end

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
    failOpenMidiInput("event tap error")
    return false -- allow event to pass to OS so we don't lock the keyboard
  end

  local ok, result = xpcall(function()

      local code = event:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
      local flags = event:getFlags()
      local isDown = (event:getType() == hs.eventtap.event.types.keyDown)

      local modifierChanges = (state.cmdHeld ~= (flags.cmd == true)) or
        (state.shiftHeld ~= (flags.shift == true)) or
        (state.altHeld ~= (flags.alt == true)) or
        (state.ctrlHeld ~= (flags.ctrl == true))
      if modifierChanges then
        state.cmdHeld = flags.cmd == true
        state.shiftHeld = flags.shift == true
        state.altHeld = flags.alt == true
        state.ctrlHeld = flags.ctrl == true
        hud.updateWebviewHud()
      end

      -- Exception: Let text input fields receive keystrokes natively
      if state.textInputActive then
        return false
      end

      -- Exception: Let Delete/Backspace work in the webview's edit mode
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

      if flags.cmd then
        return false
      end

      -- Control+Tab belongs to macOS/app navigation.
      if (flags.cmd or flags.ctrl) and code == 48 then
        return false
      end

      if state.bpmInputMode then
        if event:getType() == hs.eventtap.event.types.flagsChanged then
          return false
        end
        if flags.cmd or flags.ctrl then return false end
        if isDown then
          return arpeggiator.handleBpmInput(code, flags)
        end
        return true
      end

      -- Allow shift, alt (option), ctrl, and their combinations for macro layers!
      -- Pass cmd and capslock through to macOS for system hotkeys (Cmd+Tab, Cmd+Q, etc.)
      if flags.cmd or flags.capslock then
        return false
      end

      if event:getType() == hs.eventtap.event.types.flagsChanged then
        return false
      end

      if isDown then
        local ok, status = xpcall(function() return controls.handleKeyDown(code) end, function(err)
          print('QWERTY MIDI: handleKeyDown error: '..tostring(err))
          print(debug.traceback())
          failOpenMidiInput("key-down handler error")
          return err
        end)
        if not ok then
          print("QWERTY MIDI: handleKeyDown error: " .. tostring(status))
          return false
        end
        return true
      else
        local ok, status = xpcall(function() return controls.handleKeyUp(code) end, function(err)
          print('QWERTY MIDI: handleKeyUp error: '..tostring(err))
          print(debug.traceback())
          failOpenMidiInput("key-up handler error")
          return err
        end)
        if not ok then
          print("QWERTY MIDI: handleKeyUp error: " .. tostring(status))
          return false
        end
        return true
      end

  end, errorHandler)

  if not ok then
    failOpenMidiInput("event tap error")
    return false
  end
  return result
end)

-- Watchdog fails open. A controller with a dead UI must release the physical
-- keyboard instead of silently restarting and continuing to consume it.
if _G.activeWatchers.keyTapWatchdog then _G.activeWatchers.keyTapWatchdog:stop() end
local lastRefreshClickTime = 0
_G.activeWatchers.keyTapWatchdog = hs.timer.new(3.0, function()
  if state.midiActive then
    if _G.activeWatchers.midiKeyTap and not _G.activeWatchers.midiKeyTap:isEnabled() then
      failOpenMidiInput("keyboard event tap stopped")
      return
    end
    if _G.activeWatchers.midiScrollTap and not _G.activeWatchers.midiScrollTap:isEnabled() then
      failOpenMidiInput("scroll event tap stopped")
      return
    end

    if keystep and keystep.checkConnection then
      pcall(function() keystep.checkConnection() end)
    end
    
    hud.pingWebview()
    local hb = hud.getLastHeartbeat()
    local pong = hud.getLastPongTime()
    local lastSeen = math.max(hb, pong)
    if _G.activeWatchers.midiWebview and lastSeen > 0 then
      local elapsed = os.time() - lastSeen
      if elapsed >= 5 then
        local msg = "QWERTY MIDI: Watchdog detected unresponsive webview (no heartbeat/pong for " .. elapsed .. "s) — disabling input"
        local f = io.open("/Users/matt/projects/qwerty-midi-hammerspoon/tmp/qwerty_midi_debug.log", "a")
        if f then f:write(os.date("%H:%M:%S") .. " [WATCHDOG]: " .. msg .. "\n"); f:close() end
        
        failOpenMidiInput("HUD webview stopped responding")
      end
    end
  end
end)
if state.midiActive and _G.activeWatchers.keyTapWatchdog then
  _G.activeWatchers.keyTapWatchdog:start()
end

-- Reloads keep this global watcher table alive, so delete retired invisible
-- hotkeys from older bundles as well as avoiding new registrations.
for _, retiredHotkey in ipairs({ "midiToggleHotkey", "midiRefreshHotkey" }) do
  if _G.activeWatchers[retiredHotkey] then
    _G.activeWatchers[retiredHotkey]:delete()
    _G.activeWatchers[retiredHotkey] = nil
  end
end

if _G.activeWatchers.settingsHotkey then
  _G.activeWatchers.settingsHotkey:delete()
  _G.activeWatchers.settingsHotkey = nil
end

profileLog("Before panicAllChannels")
midi.panicAllChannels()
if controls and controls.syncTrackAudibility then
  controls.syncTrackAudibility()
end



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
    if not isAutoReload then
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
