-- packages/piano-lock/piano_lock.lua  (symlinked to ~/.hammerspoon/modules/piano_lock.lua)
-- Piano key-lock: the Yamaha digital piano plays into Ableton through Hammerspoon,
-- and notes outside this week's scale don't sound.
--
--   Digital Piano (USB) ──► Hammerspoon ──► IAC Driver (Bus 1), MIDI channel 16 ──► Ableton
--
--   • Note-on outside the active note set is dropped. Note-off always passes (so a
--     note can never stick, even if the scale changes while you hold it).
--   • Pedals, pitch bend and everything else pass straight through.
--   • Runs with the screen off or every HUD hidden: no UI, just a MIDI callback.
--   • When the piano connects, it is told Local Control OFF (CC 122 = 0) so its own
--     speakers stay silent and you only hear what Ableton plays. When the lock is
--     turned off or Hammerspoon stops, it gets Local Control ON back.
--   • Each piano connection or Hammerspoon load is a new session: it starts on this
--     week's scale (scale_lock.lua), dropping any switch made with setScale().
--
-- For the HUD:  local lock = require("scale_lock")
--   lock.getState()       current set, mode ("weekly"|"manual"|"off"), weekly scale, last note time
--   lock.setScale("D dorian") / lock.setScale("weekly")
--   lock.on(id, fn) / lock.off(id)   change notifications
-- Also global: _G.pianoLock.setScale(name), .setEnabled(bool), .getState().

local lock = require("scale_lock")

local KNOBS = {
  ["weekly.order"] = { lock.DEFAULT_ORDER, note = "Weekly scale order (major roots; relative minor is the same notes). Circle of fifths, one accidental at a time" },
  ["weekly.anchor"] = { lock.DEFAULT_ANCHOR, note = "Monday (YYYY-MM-DD) that is week 1 of the order. Weeks roll over Monday 04:00" },
  ["weekly.current"] = { "", note = "This week's scale (written by Hammerspoon each session; editing it does nothing)" },
  ["lock.enabled"] = { 1, min = 0, max = 1, step = 1, note = "1 = drop out-of-key notes, 0 = pass everything" },
  ["midi.outChannel"] = { 16, min = 1, max = 16, step = 1, note = "MIDI channel the piano arrives on in Ableton (IAC Driver Bus 1)" },
  ["midi.localOff"] = { 1, min = 0, max = 1, step = 1, note = "1 = mute the piano's own speakers (Local Control off) while the lock runs" },
  ["midi.pollSeconds"] = { 3, min = 1, max = 30, step = 1, note = "How often to look for the piano being plugged in or switched on (applies on reload)" },
}

local tweaks = require("modules.tweaks")
local TWEAKS_FILE = tweaks.dir .. "/piano_lock.json"

local M = { id = "piano_lock", name = "Piano Key-Lock" }

_G.activeWatchers = _G.activeWatchers or {}
local W = _G.activeWatchers

local PIANO_MATCH = { "Digital Piano", "Yamaha" } -- USB device names to treat as the piano
local OUT_MATCH = { "IAC" }

local T
local st = { inDev = nil, inName = nil, outDev = nil, held = {} }

local function log(msg) print("🎹 piano_lock: " .. msg) end

local function matches(name, list)
  for _, m in ipairs(list) do if name:find(m, 1, true) then return true end end
  return false
end

local function findPianoName()
  for _, name in ipairs(hs.midi.devices() or {}) do
    if matches(name, PIANO_MATCH) then return name end
  end
end

local function outDevice()
  if st.outDev then return st.outDev end
  for _, name in ipairs(hs.midi.devices() or {}) do
    if matches(name, OUT_MATCH) then st.outDev = hs.midi.new(name); return st.outDev end
  end
end

local function outChannel() return math.floor(tonumber(T("midi.outChannel")) or 16) - 1 end

local function sendLocal(on)
  if not st.inDev or tonumber(T("midi.localOff")) ~= 1 then return end
  -- CC 122 Local Control, recognised by the P-45 (MIDI implementation chart). Channel 1.
  st.inDev:sendCommand("controlChange", { controllerNumber = 122, controllerValue = on and 127 or 0, channel = 0 })
  log("Local Control " .. (on and "ON (piano speakers back)" or "OFF (piano speakers muted)"))
end

-- Pass-through commands (channel remapped). Realtime/system bytes (clock, active
-- sensing) are ignored. Each builds the sendCommand table from hs.midi's metadata.
local PASS = {
  controlChange = function(m) return { controllerNumber = m.controllerNumber, controllerValue = m.controllerValue } end,
  pitchWheelChange = function(m) return { pitchChange = m.pitchChange } end,
  polyphonicKeyPressure = function(m) return { note = m.note, pressure = m.pressure } end,
  channelPressure = function(m) return { pressure = m.pressure } end,
  programChange = function(m) return { programNumber = m.programNumber } end,
}

-- hs.midi callback: (object, deviceName, commandType, description string, metadata table)
local function onMidi(_, _, cmd, _, m)
  if type(m) ~= "table" then return end
  local out = outDevice()
  if not out then return end
  local ch = outChannel()
  if cmd == "noteOn" and (m.velocity or 0) > 0 then
    local note = m.note
    local ok = lock.isAllowed(note)
    lock.record(note, ok)
    if ok then
      st.held[note] = true
      out:sendCommand("noteOn", { note = note, velocity = m.velocity, channel = ch })
    end
  elseif cmd == "noteOff" or cmd == "noteOn" then
    -- Always pass note-off, allowed or not: nothing can stick.
    st.held[m.note] = nil
    out:sendCommand("noteOff", { note = m.note, velocity = m.velocity or 0, channel = ch })
  elseif PASS[cmd] then
    local d = PASS[cmd](m)
    d.channel = ch
    out:sendCommand(cmd, d)
  end
end

local function releaseHeld()
  local out = outDevice()
  if out then
    for note in pairs(st.held) do out:sendCommand("noteOff", { note = note, velocity = 0, channel = outChannel() }) end
  end
  st.held = {}
end

local function disconnect()
  if st.inDev then
    st.inDev:callback(nil)
    log("piano disconnected: " .. tostring(st.inName))
  end
  releaseHeld()
  st.inDev, st.inName = nil, nil
end

local function connect(name)
  local dev = hs.midi.new(name)
  if not dev then return end
  st.inDev, st.inName = dev, name
  dev:callback(onMidi)
  lock.startSession() -- piano switched on = new session = this week's scale
  pcall(tweaks.setValue, TWEAKS_FILE, "weekly.current", lock.getState().weekly)
  if lock.enabled then sendLocal(false) end
  log("listening to " .. name .. " → IAC ch " .. (outChannel() + 1) .. " · " .. lock.getState().current)
end

local function checkDevice()
  local name = findPianoName()
  if name and not st.inDev then connect(name)
  elseif not name and st.inDev then disconnect()
  elseif st.inDev and not st.inDev:isOnline() then disconnect() end
end

local function applyTweaks()
  lock.configure({ order = T("weekly.order"), anchor = T("weekly.anchor") })
  local want = tonumber(T("lock.enabled")) == 1
  if want ~= lock.enabled then M.setEnabled(want) end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.setScale(name) return lock.setScale(name) end
function M.getState()
  local s = lock.getState()
  s.connected = st.inDev ~= nil
  s.device = st.inName
  s.outChannel = outChannel() + 1
  return s
end
function M.setEnabled(on)
  lock.setEnabled(on)
  sendLocal(not on) -- lock off → the piano's own speakers come back
end

-- Feed a note without the piano (tests): M.simulate("noteOn", 61, 90)
function M.simulate(cmd, note, vel)
  onMidi(nil, nil, cmd, "", { note = note, velocity = vel or 0, channel = 0 })
end

function M.start()
  M.stop()
  T = tweaks.open{ app = "Piano Key-Lock", file = TWEAKS_FILE, knobs = KNOBS, onChange = applyTweaks }
  lock.configure({ order = T("weekly.order"), anchor = T("weekly.anchor") })
  lock.setEnabled(tonumber(T("lock.enabled")) == 1)
  lock.startSession()
  pcall(tweaks.setValue, TWEAKS_FILE, "weekly.current", lock.getState().weekly)
  checkDevice()
  W.pianoLockPoll = hs.timer.doEvery(tonumber(T("midi.pollSeconds")) or 3, checkDevice)
  _G.pianoLock = M
end

function M.stop()
  if W.pianoLockPoll then W.pianoLockPoll:stop(); W.pianoLockPoll = nil end
  if st.inDev then sendLocal(true) end -- leave the piano playable on its own
  disconnect()
  st.outDev = nil
end

return M
