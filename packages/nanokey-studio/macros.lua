-- packages/nanokey-studio/macros.lua
-- Macro dispatch engine for Korg nanoKEY Studio hold-to-reveal layer.

local macros = {}

local MACRO_HANDLERS = {
  ["Play/Pause"] = function()
    hs.eventtap.keyStroke({}, "space")
  end,
  ["Record"] = function()
    hs.eventtap.keyStroke({}, "r")
  end,
  ["Rewind"] = function()
    hs.eventtap.keyStroke({}, ",")
  end,
  ["Forward"] = function()
    hs.eventtap.keyStroke({}, ".")
  end,
  ["Left Half"] = function()
    local win = hs.window.focusedWindow()
    if win then
      local screen = win:screen():frame()
      win:setFrame({ x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h })
    end
  end,
  ["Right Half"] = function()
    local win = hs.window.focusedWindow()
    if win then
      local screen = win:screen():frame()
      win:setFrame({ x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h })
    end
  end,
  ["Maximize"] = function()
    local win = hs.window.focusedWindow()
    if win then win:maximize() end
  end,
  ["Center Win"] = function()
    local win = hs.window.focusedWindow()
    if win then
      local screen = win:screen():frame()
      local w = math.floor(screen.w * 0.8)
      local h = math.floor(screen.h * 0.8)
      win:setFrame({
        x = math.floor(screen.x + (screen.w - w) / 2),
        y = math.floor(screen.y + (screen.h - h) / 2),
        w = w,
        h = h
      })
    end
  end,
  ["Undo"] = function()
    hs.eventtap.keyStroke({ "cmd" }, "z")
  end,
  ["Redo"] = function()
    hs.eventtap.keyStroke({ "cmd", "shift" }, "z")
  end,
  ["Save Project"] = function()
    hs.eventtap.keyStroke({ "cmd" }, "s")
  end,
  ["Metronome"] = function()
    hs.eventtap.keyStroke({}, "k")
  end,
  ["Panic All"] = function()
    local midi = require("midi")
    if midi and midi.panicAllChannels then midi.panicAllChannels() end
    hs.alert.show("🚨 MIDI PANIC (All Channels Off)", 1.5)
  end,
  ["Volume +"] = function()
    local dev = hs.audiodevice.defaultOutputDevice()
    if dev then dev:setVolume(math.min(100, (dev:volume() or 50) + 5)) end
  end,
  ["Volume -"] = function()
    local dev = hs.audiodevice.defaultOutputDevice()
    if dev then dev:setVolume(math.max(0, (dev:volume() or 50) - 5)) end
  end,
  ["Mute Mic"] = function()
    local mic = hs.audiodevice.defaultInputDevice()
    if mic then
      local muted = mic:muted()
      mic:setMuted(not muted)
      hs.alert.show(not muted and "🎤 Mic MUTED" or "🎤 Mic LIVE", 1.2)
    end
  end,
  ["Screenshot"] = function()
    hs.eventtap.keyStroke({ "cmd", "shift" }, "4")
  end,
  ["Terminal"] = function()
    hs.application.launchOrFocus("Terminal")
  end,
  ["Logic Pro"] = function()
    hs.application.launchOrFocus("Logic Pro")
  end,
  ["Browser"] = function()
    hs.application.launchOrFocus("Google Chrome")
  end
}

function macros.execute(macroName)
  if not macroName then return false end
  local handler = MACRO_HANDLERS[macroName]
  if handler then
    handler()
    hs.alert.show("⚡ Macro: " .. macroName, 0.8)
    return true
  else
    print("[nanoKEY-Macro]: No handler defined for macro '" .. tostring(macroName) .. "'")
    return false
  end
end

return macros
