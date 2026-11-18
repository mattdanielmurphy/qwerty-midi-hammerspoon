-- packages/piano-lock/piano_lock.lua  (symlinked to ~/.hammerspoon/modules/piano_lock.lua)
-- Piano key-lock CONTROLLER. Hammerspoon no longer carries any piano MIDI.
--
--   Digital Piano (USB) ──► piano-thru (own launchd daemon) ──► IAC Driver Bus 1, ch 16 ──► Ableton
--                                  ▲
--     this module writes ~/Library/Application Support/piano-thru/filter.json
--
-- piano-thru (~/projects/piano-thru) forwards every message itself, so reloading,
-- editing or crashing Hammerspoon can never interrupt playing ("Piano MIDI is
-- sacred", Matt 2026-11-14). This module only says which notes are allowed:
--   • Note-ons outside the active note set are dropped by the daemon; note-offs,
--     pedals and everything else always pass.
--   • The file carries an expiry (the next weekly rollover). If Hammerspoon is gone
--     past it, or the file is missing or broken, the daemon passes every note.
--   • Each piano connection (daemon's status.json `connectedAt`) is a new session: it
--     starts on this week's scale (scale_lock.lua), dropping any setScale() switch.
--     A Hammerspoon reload keeps the current scale (it is restored from the file).
--   • Local Control (piano speakers) is the daemon's job, from `localOff`.
--   • stop() never touches the daemon or the file.
--
-- For the HUD:  local lock = require("scale_lock")
--   lock.getState()       current set, mode ("weekly"|"manual"|"off"), weekly scale, last note time
--   lock.setScale("D dorian") / lock.setScale("weekly")
--   lock.on(id, fn) / lock.off(id)   change notifications
-- Also global: _G.pianoLock.setScale(name), .setEnabled(bool), .getState(),
--   .setOff(bool) / .toggleOff() / .isOff()   Off / Chromatic for this session (HUD chip, ⌃⌥⌘O).
--
-- Off / Chromatic (Matt 2026-11-18, "so I can play whatever I want"): writes enabled=false,
-- which piano-thru already reads as "pass everything". It behaves like a key pick: it survives
-- Hammerspoon reloads, and a new piano session or the weekly rollover turns the lock back on.
-- The lock.enabled tweak stays the permanent master switch; Off sits on top of it.

local lock = require("scale_lock")

local KNOBS = {
  ["weekly.order"] = { lock.DEFAULT_ORDER, note = "Weekly scale order (major roots; relative minor is the same notes). Circle of fifths, one accidental at a time" },
  ["weekly.anchor"] = { lock.DEFAULT_ANCHOR, note = "Monday (YYYY-MM-DD) that is week 1 of the order. Weeks roll over Monday 04:00" },
  ["weekly.current"] = { "", note = "This week's scale (written by Hammerspoon each session; editing it does nothing)" },
  ["lock.enabled"] = { 1, min = 0, max = 1, step = 1, note = "1 = drop out-of-key notes, 0 = pass everything" },
  ["midi.outChannel"] = { 16, min = 1, max = 16, step = 1, note = "MIDI channel the piano arrives on in Ableton (IAC Driver Bus 1)" },
  ["midi.localOff"] = { 1, min = 0, max = 1, step = 1, note = "1 = mute the piano's own speakers (Local Control off); piano-thru sends it" },
  ["midi.pollSeconds"] = { 3, min = 1, max = 30, step = 1, note = "How often to check piano-thru's status (piano reconnects) and the weekly rollover (applies on reload)" },
}

local tweaks = require("modules.tweaks")
local TWEAKS_FILE = tweaks.dir .. "/piano_lock.json"

local DIR = os.getenv("HOME") .. "/Library/Application Support/piano-thru"
local FILTER = DIR .. "/filter.json"
local STATUS = DIR .. "/status.json"

local M = { id = "piano_lock", name = "Piano Key-Lock" }

_G.activeWatchers = _G.activeWatchers or {}
local W = _G.activeWatchers

local T
local st = { lastWritten = nil, connectedAt = nil, off = false, offUntil = nil }

local function wantEnabled() return tonumber(T("lock.enabled")) == 1 and not st.off end

local function log(msg) print("🎹 piano_lock: " .. msg) end

local function readJson(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a"); f:close()
  local ok, v = pcall(hs.json.decode, s)
  return ok and type(v) == "table" and v or nil
end

local function status() return readJson(STATUS) end

-- The filter file the daemon reads. Written atomically (tmp + rename), only on change.
local function writeFilter()
  local s = lock.getState()
  local body = {
    enabled = s.enabled,
    pitchClasses = s.pitchClasses,
    scale = s.current,
    source = s.mode,                     -- "weekly" | "manual" | "off"
    resume = lock.current().source,      -- what Off goes back to: "weekly" | "manual" (scale = that key)
    sessionOff = st.off,                 -- true = Off / Chromatic from the HUD (not the lock.enabled tweak)
    outChannel = math.floor(tonumber(T("midi.outChannel")) or 16),
    localOff = tonumber(T("midi.localOff")) == 1,
    expires = s.nextRollover,
    writtenBy = "hammerspoon piano_lock",
  }
  local key = hs.json.encode({ body.enabled, body.pitchClasses, body.scale, body.outChannel, body.localOff, body.expires,
    body.resume, body.sessionOff })
  if key == st.lastWritten then return end
  hs.fs.mkdir(DIR)
  local tmp = FILTER .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then log("can't write " .. tmp); return end
  f:write(hs.json.encode(body, true)); f:close()
  os.rename(tmp, FILTER)
  st.lastWritten = key
  log("filter → " .. (s.enabled and s.current or "pass all") .. " · ch " .. body.outChannel)
end

local function newSession(why)
  st.off, st.offUntil = false, nil
  lock.setEnabled(wantEnabled())
  lock.startSession()
  pcall(tweaks.setValue, TWEAKS_FILE, "weekly.current", lock.getState().weekly)
  log("new session (" .. why .. ") · " .. lock.getState().current)
end

local function poll()
  local s = status()
  local c = s and tonumber(s.connectedAt) or 0
  if c > 0 and st.connectedAt ~= nil and c ~= st.connectedAt then newSession("piano connected") end
  if c > 0 or st.connectedAt == nil then st.connectedAt = c end
  if st.off and st.offUntil and os.time() >= st.offUntil then   -- weekly rollover ends Off, like a pick
    st.off, st.offUntil = false, nil
    lock.setEnabled(wantEnabled())
    log("Off ended at the weekly rollover")
  end
  writeFilter() -- also catches the weekly rollover (getState refreshes the week)
end

local function applyTweaks()
  lock.configure({ order = T("weekly.order"), anchor = T("weekly.anchor") })
  local want = wantEnabled()
  if want ~= lock.enabled then lock.setEnabled(want) end
  writeFilter()
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.setScale(name) return lock.setScale(name) end
function M.getState()
  local s = lock.getState()
  local d = status() or {}
  s.connected = d.connected == true
  s.device = d.piano
  s.outChannel = math.floor(tonumber(T("midi.outChannel")) or 16)
  s.daemon = d
  return s
end
function M.setEnabled(on)
  pcall(tweaks.setValue, TWEAKS_FILE, "lock.enabled", on and 1 or 0)
  lock.setEnabled(on and not st.off)
end

-- Off / Chromatic: every note passes until you pick a key again (or a new session starts).
function M.setOff(off)
  off = off and true or false
  st.off = off
  st.offUntil = off and lock.getState().nextRollover or nil
  lock.setEnabled(wantEnabled())   -- notifies → writeFilter + HUD redraw
  log(off and "Off · all notes" or ("lock back on · " .. lock.getState().current))
end
function M.toggleOff() M.setOff(not st.off) end
function M.isOff() return st.off end

function M.start()
  M.stop()
  T = tweaks.open{ app = "Piano Key-Lock", file = TWEAKS_FILE, knobs = KNOBS, onChange = applyTweaks }
  lock.configure({ order = T("weekly.order"), anchor = T("weekly.anchor") })
  -- A reload keeps what you were on: a manual pick, or Off (and the pick under it), until it expires.
  local prev = readJson(FILTER)
  local fresh = prev and (tonumber(prev.expires) or 0) > os.time()
  st.off, st.offUntil = false, nil
  if fresh and prev.sessionOff == true then
    st.off, st.offUntil = true, tonumber(prev.expires)
  end
  if fresh and type(prev.scale) == "string"
      and (prev.source == "manual" or (prev.source == "off" and prev.resume == "manual")) then
    lock.setScale(prev.scale)
  end
  lock.setEnabled(wantEnabled())
  pcall(tweaks.setValue, TWEAKS_FILE, "weekly.current", lock.getState().weekly)
  lock.on("piano_lock", function() writeFilter() end)
  st.lastWritten = nil
  poll()
  W.pianoLockPoll = hs.timer.doEvery(tonumber(T("midi.pollSeconds")) or 3, poll)
  _G.pianoLock = M
end

function M.stop()
  if W.pianoLockPoll then W.pianoLockPoll:stop(); W.pianoLockPoll = nil end
  lock.off("piano_lock")
  -- Never touch the daemon or the filter file here: playing carries on through reloads.
end

return M
