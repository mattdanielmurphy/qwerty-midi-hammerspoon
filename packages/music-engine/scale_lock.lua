-- packages/music-engine/scale_lock.lua
-- Shared scale engine: which notes are allowed right now.
-- Used by the piano key-lock router (piano_lock.lua), and readable by the QWERTY
-- controller and the reference HUD via require("scale_lock") (music-engine is on
-- package.path in ~/.hammerspoon/init.lua). One instance per Hammerspoon run.
--
-- Weekly scale: every week (rolling over Monday 04:00 local time) has one note set.
-- The order walks the circle of fifths one accidental at a time, alternating sharps
-- and flats: C, G, F, D, Bb, A, Eb, E, Ab, B, Db, F#, then repeats.
-- setScale(name) overrides it until the next session (reload, piano reconnect) or
-- the next weekly rollover, whichever comes first; then it falls back to the week's.
--
-- Pure Lua apart from the clock (injectable), so tests run with plain `lua`.

local M = {}

local NOTE_PC = {
  C = 0, ["C#"] = 1, Db = 1, D = 2, ["D#"] = 3, Eb = 3, E = 4, Fb = 4, ["E#"] = 5, F = 5,
  ["F#"] = 6, Gb = 6, G = 7, ["G#"] = 8, Ab = 8, A = 9, ["A#"] = 10, Bb = 10, B = 11, Cb = 11, ["B#"] = 0,
}
local FLAT_NAMES = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }
local SHARP_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

M.MODES = {
  major = { 0, 2, 4, 5, 7, 9, 11 }, ionian = { 0, 2, 4, 5, 7, 9, 11 },
  minor = { 0, 2, 3, 5, 7, 8, 10 }, aeolian = { 0, 2, 3, 5, 7, 8, 10 },
  dorian = { 0, 2, 3, 5, 7, 9, 10 }, phrygian = { 0, 1, 3, 5, 7, 8, 10 },
  lydian = { 0, 2, 4, 6, 7, 9, 11 }, mixolydian = { 0, 2, 4, 5, 7, 9, 10 },
  locrian = { 0, 1, 3, 5, 6, 8, 10 },
  ["harmonic minor"] = { 0, 2, 3, 5, 7, 8, 11 }, ["melodic minor"] = { 0, 2, 3, 5, 7, 9, 11 },
  ["major pentatonic"] = { 0, 2, 4, 7, 9 }, ["minor pentatonic"] = { 0, 3, 5, 7, 10 },
  blues = { 0, 3, 5, 6, 7, 10 }, chromatic = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
}

M.DEFAULT_ORDER = "C,G,F,D,Bb,A,Eb,E,Ab,B,Db,F#"
-- Week 0 = the Monday this shipped (2026-11-02 04:00 local) = C major / A minor.
M.DEFAULT_ANCHOR = "2026-11-02"
M.ROLLOVER_HOUR = 4

-- ── Pure helpers ──────────────────────────────────────────────────────────────

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

--- Parse "C major", "A minor", "F# dorian", "Bb", "eb harmonic minor".
-- @return root pc (0..11), mode key, canonical display name; or nil, error
function M.parse(name)
  if type(name) ~= "string" then return nil, "scale name must be a string" end
  local s = trim(name)
  local letter, acc, rest = s:match("^([A-Ga-g])([#b♯♭]?)%s*(.*)$")
  if not letter then return nil, "unknown scale: " .. name end
  acc = (acc == "♯" and "#") or (acc == "♭" and "b") or acc
  local rootName = letter:upper() .. acc
  local pc = NOTE_PC[rootName]
  if not pc then return nil, "unknown root: " .. rootName end
  local mode = trim(rest):lower()
  if mode == "" or mode == "maj" then mode = "major" end
  if mode == "m" or mode == "min" then mode = "minor" end
  if not M.MODES[mode] then return nil, "unknown mode: " .. mode end
  return pc, mode, rootName .. " " .. mode
end

--- Pitch-class set {[pc]=true} for a root + mode.
function M.pcSet(root, mode)
  local set = {}
  for _, iv in ipairs(M.MODES[mode] or M.MODES.major) do set[(root + iv) % 12] = true end
  return set
end

--- Note names in the set, spelled with flats for flat keys and sharps for sharp keys.
function M.noteNames(set, preferFlats)
  local names, table_ = {}, preferFlats and FLAT_NAMES or SHARP_NAMES
  for pc = 0, 11 do if set[pc] then names[#names + 1] = table_[pc + 1] end end
  return names
end

--- Relative-minor label for a major root, e.g. 0 -> "A minor".
function M.relativeMinor(root, preferFlats)
  local n = (preferFlats and FLAT_NAMES or SHARP_NAMES)[((root + 9) % 12) + 1]
  return n .. " minor"
end

function M.parseOrder(orderStr)
  local out = {}
  for item in tostring(orderStr or M.DEFAULT_ORDER):gmatch("[^,]+") do
    local r = trim(item)
    if NOTE_PC[r] then out[#out + 1] = r end
  end
  if #out == 0 then return M.parseOrder(M.DEFAULT_ORDER) end
  return out
end

--- Local timestamp of the anchor Monday at ROLLOVER_HOUR.
function M.anchorTime(anchorStr)
  local y, mo, d = tostring(anchorStr or M.DEFAULT_ANCHOR):match("^(%d+)-(%d+)-(%d+)$")
  if not y then y, mo, d = M.DEFAULT_ANCHOR:match("^(%d+)-(%d+)-(%d+)$") end
  return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
    hour = M.ROLLOVER_HOUR, min = 0, sec = 0, isdst = nil })
end

--- Which week we are in and when the next rollover is (DST-safe: steps by calendar day).
-- @return weekIndex (0-based, can be negative before the anchor), nextRollover timestamp
function M.weekAt(now, anchorStr)
  local anchor = M.anchorTime(anchorStr)
  local a = os.date("*t", anchor)
  -- Rough guess from seconds, then correct using real calendar boundaries.
  local week = math.floor((now - anchor) / (7 * 86400))
  local function boundary(w)
    return os.time({ year = a.year, month = a.month, day = a.day + 7 * w,
      hour = M.ROLLOVER_HOUR, min = 0, sec = 0, isdst = nil })
  end
  while boundary(week) > now do week = week - 1 end
  while boundary(week + 1) <= now do week = week + 1 end
  return week, boundary(week + 1)
end

--- The weekly scale for a timestamp.
function M.weeklyScaleAt(now, orderStr, anchorStr)
  local order = M.parseOrder(orderStr)
  local week, nextRollover = M.weekAt(now, anchorStr)
  local rootName = order[(week % #order) + 1]
  local root = NOTE_PC[rootName]
  local flats = rootName:find("b") ~= nil or rootName == "F"
  return {
    root = root, mode = "major", rootName = rootName,
    name = rootName .. " major / " .. M.relativeMinor(root, flats),
    week = week, nextRollover = nextRollover, preferFlats = flats,
  }
end

-- ── Live state (one per Hammerspoon run) ──────────────────────────────────────

M.clock = os.time
M.config = { order = M.DEFAULT_ORDER, anchor = M.DEFAULT_ANCHOR } -- overwritten from tweaks
M.enabled = true
local override = nil       -- { root, mode, name, set, untilTime }
local weekly = nil         -- cached weekly scale
local listeners = {}
M.stats = { passed = 0, dropped = 0, lastNoteTime = nil, lastNote = nil, lastDropped = nil }

local function notify()
  for _, fn in pairs(listeners) do pcall(fn, M.getState()) end
end

--- Register fn(state) to hear every scale or mode change. Returns an id for off().
function M.on(id, fn) listeners[id] = fn end
function M.off(id) listeners[id] = nil end

local function refreshWeekly(force)
  local now = M.clock()
  if force or not weekly or now >= weekly.nextRollover then
    local rolled = weekly ~= nil and not force
    weekly = M.weeklyScaleAt(now, M.config.order, M.config.anchor)
    weekly.set = M.pcSet(weekly.root, weekly.mode)
    if rolled then override = nil; notify() end -- new week: back to the weekly scale
  end
  if override and now >= override.untilTime then override = nil end
  return weekly
end

--- Current scale table { root, mode, name, set, source = "weekly"|"manual" }.
function M.current()
  local w = refreshWeekly()
  if override then
    return { root = override.root, mode = override.mode, name = override.name, set = override.set, source = "manual" }
  end
  return { root = w.root, mode = w.mode, name = w.name, set = w.set, source = "weekly" }
end

--- Switch to another scale until the next session or weekly rollover.
-- @param name e.g. "D dorian", "Eb major", "A minor"; nil or "weekly" goes back to the week's scale.
-- @return true, canonical name; or false, error
function M.setScale(name)
  local w = refreshWeekly()
  if name == nil or name == "weekly" or name == "" then
    override = nil
    notify()
    return true, w.name
  end
  local root, mode, display = M.parse(name)
  if not root then return false, mode end
  override = { root = root, mode = mode, name = display, set = M.pcSet(root, mode), untilTime = w.nextRollover }
  notify()
  return true, display
end

--- New session (Hammerspoon load, piano power-on): drop any manual override.
function M.startSession()
  override = nil
  refreshWeekly(true)
  notify()
end

--- Turn the lock on or off (off lets every note through).
function M.setEnabled(on)
  M.enabled = on and true or false
  notify()
end

--- Is this MIDI note allowed? Pure check; does not touch stats.
function M.isAllowed(note)
  if not M.enabled then return true end
  return M.current().set[note % 12] == true
end

--- Record a note-on decision for the HUD.
function M.record(note, allowed)
  M.stats.lastNoteTime = M.clock()
  M.stats.lastNote = note
  if allowed then M.stats.passed = M.stats.passed + 1
  else M.stats.dropped = M.stats.dropped + 1; M.stats.lastDropped = note end
end

--- Everything a HUD needs, as plain data.
function M.getState()
  local w = refreshWeekly()
  local cur = M.current()
  local flats = (cur.source == "weekly" and w.preferFlats) or (FLAT_NAMES[cur.root + 1]:find("b") ~= nil) or cur.root == 5
  local pcs = {}
  for pc = 0, 11 do if cur.set[pc] then pcs[#pcs + 1] = pc end end
  return {
    enabled = M.enabled,
    mode = (not M.enabled) and "off" or cur.source, -- "off" | "weekly" | "manual"
    current = cur.name,
    root = cur.root,
    scaleMode = cur.mode,
    pitchClasses = pcs,
    noteNames = M.noteNames(cur.set, flats),
    weekly = w.name,
    week = w.week,
    nextRollover = w.nextRollover,
    order = M.parseOrder(M.config.order),
    passed = M.stats.passed,
    dropped = M.stats.dropped,
    lastNote = M.stats.lastNote,
    lastNoteTime = M.stats.lastNoteTime,
    lastDropped = M.stats.lastDropped,
  }
end

--- Apply new order/anchor (from tweaks) and recompute the week.
function M.configure(cfg)
  if cfg.order then M.config.order = cfg.order end
  if cfg.anchor then M.config.anchor = cfg.anchor end
  refreshWeekly(true)
  if override then -- keep the override but re-clamp its expiry to the new week
    override.untilTime = weekly.nextRollover
  end
  notify()
end

-- Test hook: reset everything.
function M._reset()
  override, weekly, listeners = nil, nil, {}
  M.enabled = true
  M.clock = os.time
  M.config = { order = M.DEFAULT_ORDER, anchor = M.DEFAULT_ANCHOR }
  M.stats = { passed = 0, dropped = 0, lastNoteTime = nil, lastNote = nil, lastDropped = nil }
end

return M
