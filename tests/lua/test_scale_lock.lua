-- tests/lua/test_scale_lock.lua — weekly scale + key-lock engine (pure Lua)
package.path = "packages/music-engine/?.lua;" .. package.path
package.loaded["scale_lock"] = nil
local S = require("scale_lock")

local failures = 0
local function check(cond, msg)
  if cond then print("  ✓ " .. msg) else print("  ✗ " .. msg); failures = failures + 1 end
end
local function at(y, mo, d, h, mi) return os.time({ year = y, month = mo, day = d, hour = h, min = mi or 0, sec = 0 }) end

S._reset()

-- Week boundaries: Monday 04:00 local
check(S.weeklyScaleAt(at(2026, 11, 7, 12)).rootName == "C", "Sat Nov 7 2026 is week 0 = C")
check(S.weeklyScaleAt(at(2026, 11, 9, 3, 59)).rootName == "C", "Mon Nov 9 03:59 still C")
check(S.weeklyScaleAt(at(2026, 11, 9, 4, 0)).rootName == "G", "Mon Nov 9 04:00 rolls to G")
check(S.weeklyScaleAt(at(2026, 11, 16, 5)).rootName == "F", "week 2 = F (one flat)")
check(S.weeklyScaleAt(at(2026, 11, 23, 5)).rootName == "D", "week 3 = D (two sharps)")
check(S.weeklyScaleAt(at(2027, 1, 25, 5)).rootName == "C", "week 12 wraps to C")
check(S.weeklyScaleAt(at(2026, 11, 7, 12)).name == "C major / A minor", "week 0 name")
check(S.weeklyScaleAt(at(2026, 11, 16, 5)).name == "F major / D minor", "F week name")
check(S.weeklyScaleAt(at(2026, 11, 30, 5)).name == "Bb major / G minor", "Bb week spelled with flats")
-- Across the Mar 2027 DST change the rollover stays 04:00
check(S.weeklyScaleAt(at(2027, 3, 15, 4, 0)).week == 19, "DST week boundary at 04:00")
check(S.weeklyScaleAt(at(2027, 3, 15, 3, 59)).week == 18, "DST: 03:59 still previous week")

-- Custom order from tweaks
check(S.weeklyScaleAt(at(2026, 11, 9, 5), "C,D,E").rootName == "D", "custom order")
check(S.weeklyScaleAt(at(2026, 11, 9, 5), "junk").rootName == "G", "bad order falls back to default")

-- Filtering
S.clock = function() return at(2026, 11, 7, 12) end
S.startSession()
check(S.isAllowed(60) and S.isAllowed(62) and S.isAllowed(71), "C major: white keys pass")
check(not S.isAllowed(61) and not S.isAllowed(66), "C major: black keys dropped")
check(S.getState().mode == "weekly", "mode weekly")

-- setScale
local ok, name = S.setScale("Eb major")
check(ok and name == "Eb major", "setScale Eb major")
check(S.isAllowed(63) and not S.isAllowed(64), "Eb major filters")
check(S.getState().mode == "manual" and S.getState().weekly == "C major / A minor", "state shows manual + weekly")
check(not S.setScale("H major"), "bad name rejected")
check(S.setScale("f# dorian") and S.current().name == "F# dorian", "lowercase + sharp + mode")
S.startSession()
check(S.current().source == "weekly", "new session clears override")
S.setScale("D dorian")
S.clock = function() return at(2026, 11, 9, 4, 1) end
check(S.current().name == "G major / E minor" and S.current().source == "weekly", "rollover clears override")

-- Disabled passes everything
S.setEnabled(false)
check(S.isAllowed(61) and S.getState().mode == "off", "lock off passes all")
S.setEnabled(true)

-- Listeners
local heard
S.on("t", function(st) heard = st.current end)
S.setScale("A minor")
check(heard == "A minor", "listener notified")
S.off("t")

-- getState shape for the HUD
local st = S.getState()
check(type(st.pitchClasses) == "table" and #st.pitchClasses == 7, "pitchClasses")
check(st.noteNames[1] == "A" or st.noteNames[1] == "C", "noteNames")
check(st.nextRollover > S.clock(), "nextRollover in future")

S._reset()
if failures > 0 then error(failures .. " scale_lock checks failed") end
