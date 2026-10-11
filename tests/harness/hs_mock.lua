-- tests/harness/hs_mock.lua
-- Minimal, zero-dependency pure-Lua headless mock environment for Hammerspoon
-- Simulates hs.timer, hs.settings, hs.midi, hs.eventtap, and hs.logger

local mock = {
  currentTime = 1000.0,
  activeTimers = {},
  sentMidiMessages = {},
  settingsStore = {},
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

function Timer:stop()
  self.running = false
  for i, t in ipairs(mock.activeTimers) do
    if t == self then
      table.remove(mock.activeTimers, i)
      break
    end
  end
  return self
end

function Timer:start()
  self.running = true
  table.insert(mock.activeTimers, self)
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
end

function hs.timer.doAfter(sec, fn)
  local t = setmetatable({
    interval = sec,
    fn = fn,
    repeats = false,
    running = true,
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
    running = true,
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

function MidiEndpoint:sendCommand(cmd, ch, data1, data2)
  local msg = {
    command = cmd,
    channel = ch,
    data1 = data1,
    data2 = data2,
    timestamp = mock.currentTime,
  }
  table.insert(mock.sentMidiMessages, msg)
end

function hs.midi.newVirtualEndpoint(name)
  return setmetatable({ name = name }, MidiEndpoint)
end

function hs.midi.devices()
  return {}
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
-- Mock Environment Control Functions
-- ---------------------------------------------------------------------------
function mock.advanceTime(seconds)
  mock.currentTime = mock.currentTime + (seconds or 0)
  -- Fire any timers that have expired
  local due = {}
  for _, t in ipairs(mock.activeTimers) do
    if t.running and t.nextFire and t.nextFire <= mock.currentTime then
      table.insert(due, t)
    end
  end
  for _, t in ipairs(due) do
    t:fire()
  end
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

function mock.reset()
  mock.currentTime = 1000.0
  mock.activeTimers = {}
  mock.sentMidiMessages = {}
  mock.settingsStore = {}
end

-- Expose in global table
_G.hs = hs
_G.hs_mock = mock

return mock
