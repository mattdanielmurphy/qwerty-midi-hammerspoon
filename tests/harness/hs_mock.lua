-- tests/harness/hs_mock.lua
-- Minimal, zero-dependency pure-Lua headless mock environment for Hammerspoon
-- Simulates hs.timer, hs.settings, hs.midi, hs.eventtap, hs.logger, hs.fs, hs.json, etc.

local mock = {
  currentTime = 1000.0,
  activeTimers = {},
  activeEventTaps = {},
  sentMidiMessages = {},
  settingsStore = {},
  sentKeyStrokes = {},
  alerts = {},
  notifications = {},
}

local hs = {}

-- ---------------------------------------------------------------------------
-- hs.timer Mock
-- ---------------------------------------------------------------------------
hs.timer = {}

function hs.timer.secondsSinceEpoch()
  return mock.currentTime
end

function hs.timer.absoluteTime()
  return math.floor(mock.currentTime * 1e9)
end

local Timer = {}
Timer.__index = Timer

function Timer:running()
  return self._running == true
end

function Timer:stop()
  self._running = false
  for i, t in ipairs(mock.activeTimers) do
    if t == self then
      table.remove(mock.activeTimers, i)
      break
    end
  end
  return self
end

function Timer:start()
  if not self._running then
    self._running = true
    self.nextFire = mock.currentTime + (self.interval or 0)
    table.insert(mock.activeTimers, self)
  end
  return self
end

function Timer:fire()
  if self.fn then
    local ok, err = pcall(self.fn)
    if not ok then
      print("[hs_mock timer error] " .. tostring(err))
    end
  end
  if not self.repeats then
    self:stop()
  else
    self.nextFire = mock.currentTime + self.interval
  end
  return self
end

-- hs.timer.new creates an unstarted repeating timer matching Hammerspoon C API
function hs.timer.new(sec, fn)
  local t = setmetatable({
    interval = sec,
    fn = fn,
    repeats = true,
    _running = false,
    nextFire = nil,
  }, Timer)
  return t
end

function hs.timer.doAfter(sec, fn)
  local t = setmetatable({
    interval = sec,
    fn = fn,
    repeats = false,
    _running = true,
    nextFire = mock.currentTime + sec,
  }, Timer)
  table.insert(mock.activeTimers, t)
  return t
end

function hs.timer.doEvery(sec, fn)
  local t = setmetatable({
    interval = sec,
    fn = fn,
    repeats = true,
    _running = true,
    nextFire = mock.currentTime + sec,
  }, Timer)
  table.insert(mock.activeTimers, t)
  return t
end

hs.timer.delayed = {}
function hs.timer.delayed.new(sec, fn)
  local obj = {
    interval = sec,
    fn = fn,
    timer = nil,
  }
  function obj:start()
    if self.timer then self.timer:stop() end
    self.timer = hs.timer.doAfter(self.interval, self.fn)
    return self
  end
  function obj:stop()
    if self.timer then
      self.timer:stop()
      self.timer = nil
    end
    return self
  end
  return obj
end

-- ---------------------------------------------------------------------------
-- hs.eventtap Mock
-- ---------------------------------------------------------------------------
hs.eventtap = {}

hs.eventtap.event = {
  types = {
    leftMouseDown = 1,
    leftMouseUp = 2,
    rightMouseDown = 3,
    rightMouseUp = 4,
    mouseMoved = 5,
    leftMouseDragged = 6,
    rightMouseDragged = 7,
    keyDown = 10,
    keyUp = 11,
    flagsChanged = 12,
    scrollWheel = 22,
  },
  properties = {
    keyboardEventKeycode = 0,
    keyboardEventAutorepeat = 1,
    scrollWheelEventDeltaAxis1 = 11,
    scrollWheelEventDeltaAxis2 = 12,
    scrollWheelEventPointDeltaAxis1 = 96,
    scrollWheelEventPointDeltaAxis2 = 97,
    scrollWheelEventScrollPhase = 99,
  }
}

local Event = {}
Event.__index = Event

function Event:getType()
  return self._type
end

function Event:getProperty(prop)
  return self._properties and self._properties[prop]
end

function Event:setProperty(prop, val)
  self._properties = self._properties or {}
  self._properties[prop] = val
  return self
end

function Event:getFlags()
  return self._flags or {}
end

function Event:setFlags(flags)
  self._flags = flags or {}
  return self
end

function Event:post()
  table.insert(mock.sentKeyStrokes, { event = self, time = mock.currentTime })
  return self
end

local EventTap = {}
EventTap.__index = EventTap

function EventTap:isEnabled()
  return self._enabled == true
end

function EventTap:start()
  if not self._enabled then
    self._enabled = true
    table.insert(mock.activeEventTaps, self)
  end
  return self
end

function EventTap:stop()
  self._enabled = false
  for i, tap in ipairs(mock.activeEventTaps) do
    if tap == self then
      table.remove(mock.activeEventTaps, i)
      break
    end
  end
  return self
end

function hs.eventtap.new(types, callback)
  local typeSet = {}
  if type(types) == "table" then
    for _, t in ipairs(types) do
      typeSet[t] = true
    end
  elseif type(types) == "number" then
    typeSet[types] = true
  end

  return setmetatable({
    types = typeSet,
    callback = callback,
    _enabled = false,
  }, EventTap)
end

function hs.eventtap.keyStroke(mods, key)
  table.insert(mock.sentKeyStrokes, {
    modifiers = mods or {},
    key = key,
    type = "keyStroke",
    time = mock.currentTime,
  })
end

function hs.eventtap.keyStrokes(str)
  table.insert(mock.sentKeyStrokes, {
    text = str,
    type = "keyStrokes",
    time = mock.currentTime,
  })
end

function hs.eventtap.event.newKeyEvent(flags, keycode, isDown)
  local evType = isDown and hs.eventtap.event.types.keyDown or hs.eventtap.event.types.keyUp
  return setmetatable({
    _type = evType,
    _flags = flags or {},
    _properties = {
      [hs.eventtap.event.properties.keyboardEventKeycode] = keycode
    }
  }, Event)
end

function hs.eventtap.event.newMouseEvent(eventType, point)
  return setmetatable({
    _type = eventType,
    _point = point or { x = 0, y = 0 },
    _flags = {},
    _properties = {}
  }, Event)
end

-- ---------------------------------------------------------------------------
-- hs.settings Mock
-- ---------------------------------------------------------------------------
hs.settings = {}

function hs.settings.get(key)
  return mock.settingsStore[key]
end

function hs.settings.set(key, val)
  mock.settingsStore[key] = val
end

function hs.settings.clear(key)
  mock.settingsStore[key] = nil
end

-- ---------------------------------------------------------------------------
-- hs.midi Mock
-- ---------------------------------------------------------------------------
hs.midi = {}

local MidiEndpoint = {}
MidiEndpoint.__index = MidiEndpoint

function MidiEndpoint:sendCommand(cmd, arg2, arg3, arg4)
  local msg = {
    command = cmd,
    timestamp = mock.currentTime,
  }
  if type(arg2) == "table" then
    msg.metadata = arg2
    msg.channel = arg2.channel
    msg.note = arg2.note
    msg.velocity = arg2.velocity
    msg.controllerNumber = arg2.controllerNumber
    msg.controllerValue = arg2.controllerValue
  else
    msg.channel = arg2
    msg.data1 = arg3
    msg.data2 = arg4
  end
  table.insert(mock.sentMidiMessages, msg)
  return self
end

function hs.midi.devices()
  return { "IAC Driver Bus 1" }
end

function hs.midi.virtualSources()
  return { "IAC Driver Bus 1" }
end

function hs.midi.new(name)
  return setmetatable({ name = name or "IAC Driver Bus 1" }, MidiEndpoint)
end

function hs.midi.newVirtualSource(name)
  return setmetatable({ name = name or "IAC Driver Bus 1" }, MidiEndpoint)
end

function hs.midi.newVirtualEndpoint(name)
  return setmetatable({ name = name or "IAC Driver Bus 1" }, MidiEndpoint)
end

-- ---------------------------------------------------------------------------
-- hs.logger Mock
-- ---------------------------------------------------------------------------
hs.logger = {}
function hs.logger.new(name, level)
  return {
    d = function(...) end,
    i = function(...) end,
    w = function(...) end,
    e = function(...) end,
  }
end

-- ---------------------------------------------------------------------------
-- hs.fs, hs.json, hs.window, hs.mouse, hs.alert, hs.notify Stubs
-- ---------------------------------------------------------------------------
hs.fs = {
  pathToAbsolute = function(p) return p end,
  attributes = function(p) return { modification = mock.currentTime } end,
  dir = function(path) return function() return nil end end
}

hs.json = {
  encode = function(v) return "{}" end,
  decode = function(s) return {} end
}

hs.window = {
  focusedWindow = function() return nil end
}

hs.mouse = {
  absolutePosition = function() return { x = 0, y = 0 } end
}

hs.alert = {
  show = function(msg, duration)
    table.insert(mock.alerts, { msg = msg, duration = duration, time = mock.currentTime })
  end
}

hs.notify = {
  new = function(opts)
    return {
      send = function(self)
        table.insert(mock.notifications, opts)
        return self
      end
    }
  end
}

hs.task = {
  new = function(path, cb, args)
    return { start = function(self) return self end, terminate = function(self) end }
  end
}

hs.hotkey = {
  bind = function(mods, key, fn)
    return { delete = function() end, enable = function() end, disable = function() end }
  end
}

-- ---------------------------------------------------------------------------
-- Discrete-Event Simulation Loop in advanceTime
-- ---------------------------------------------------------------------------
function mock.advanceTime(seconds)
  local duration = tonumber(seconds) or 0
  if duration < 0 then duration = 0 end
  local targetTime = mock.currentTime + duration
  local maxSteps = 100000
  local steps = 0

  while steps < maxSteps do
    steps = steps + 1
    local earliestTimer = nil
    local earliestFire = nil

    for _, t in ipairs(mock.activeTimers) do
      if t:running() and t.nextFire and t.nextFire <= targetTime then
        if earliestFire == nil or t.nextFire < earliestFire then
          earliestFire = t.nextFire
          earliestTimer = t
        end
      end
    end

    if not earliestTimer then
      break
    end

    mock.currentTime = earliestFire
    earliestTimer:fire()
  end

  mock.currentTime = targetTime
end

function mock.setTime(t)
  mock.currentTime = t
end

function mock.getSentMidi()
  return mock.sentMidiMessages
end

function mock.clearSentMidi()
  mock.sentMidiMessages = {}
end

function mock.emitKeyEvent(eventType, keycode, flags)
  local ev = hs.eventtap.event.newKeyEvent(flags, keycode, eventType == hs.eventtap.event.types.keyDown)
  local swallowed = false
  for _, tap in ipairs(mock.activeEventTaps) do
    if tap:isEnabled() and tap.types[eventType] then
      local res = tap.callback(ev)
      if res == true then
        swallowed = true
        break
      end
    end
  end
  return { swallowed = swallowed, event = ev }
end

function mock.reset()
  mock.currentTime = 1000.0
  mock.activeTimers = {}
  mock.activeEventTaps = {}
  mock.sentMidiMessages = {}
  mock.settingsStore = {}
  mock.sentKeyStrokes = {}
  mock.alerts = {}
  mock.notifications = {}
end

-- Preload registration for all hs.* modules
local hsModules = {
  "hs", "hs.timer", "hs.settings", "hs.midi", "hs.eventtap",
  "hs.logger", "hs.fs", "hs.json", "hs.window", "hs.mouse",
  "hs.alert", "hs.notify", "hs.task", "hs.hotkey"
}
for _, mod in ipairs(hsModules) do
  package.preload[mod] = function()
    local parts = {}
    for part in string.gmatch(mod, "[^.]+") do table.insert(parts, part) end
    local cur = _G
    for _, p in ipairs(parts) do
      if cur then cur = cur[p] end
    end
    return cur or {}
  end
end

_G.hs = hs
_G.hs_mock = mock

return mock
